#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <morecolors>

#define MAX_COLOR_STRING_LEN 15
#define MAX_NUMBER_STRING_LEN 4
#define HUD_WARNING_TIMING_DEFAULT 3
#define HUD_PREFIX "▻"
#define HUD_POSTFIX "◅"
#define HUD_APPEAR_SOUND "ui/beepclear.wav"
#define HUD_WARNING_SOUND "ui/beep07.wav"

ConVar g_countdown_chat_tag;
ConVar g_countdown_chat_text_color;
ConVar g_countdown_chat_number_color;
ConVar g_countdown_chat_end_symbol;
ConVar g_countdown_chat_end_color;

ConVar g_countdown_hud_warning_timing;
ConVar g_countdown_hud_text_color;
ConVar g_countdown_hud_number_color;
ConVar g_countdown_hud_prefix_color;
ConVar g_countdown_hud_postfix_color;

char chat_tag[MAX_MESSAGE_LENGTH];
char chat_text_color[MAX_COLOR_STRING_LEN];
char chat_number_color[MAX_COLOR_STRING_LEN];
char chat_end_symbol[2];
char chat_end_color[MAX_COLOR_STRING_LEN];

int hud_warning_timing = HUD_WARNING_TIMING_DEFAULT;
char hud_text_color[MAX_COLOR_STRING_LEN];
char hud_number_color[MAX_COLOR_STRING_LEN];
char hud_prefix_color[MAX_COLOR_STRING_LEN];
char hud_postfix_color[MAX_COLOR_STRING_LEN];

public Plugin myinfo =
{
	name			= "CountdownHUD",
	author		= "kurumi",
	description = "A simple HTML Countdown HUD for ZE.",
	version		= "2.1",
	url			= "https://github.com/tokKurumi"
};

char g_BlackListWords[][] = 
{
	"recharge",
	"cd",
	"tips",
	"recast",
	"cooldown",
	"cool",
	"m4dara",
	"4Echo"
};

char g_FilterSymbolsList[][] = 
{
	"<",
	">",
	"(",
	")",
	"[",
	"]",
	"{",
	"}",
	"/",
	"\\",
	"'",
	"*",
	"%",
	"@",
	"$",
	"^",
	"+",
	"-"
};

Handle g_CurrentCountdownSecondsTimer;
Handle g_CurrentCountdownWarningTimer;
Handle g_CurrentCountdownWarningSoundTimer;

int g_CurrentTimerSeconds;
int g_CurrentTimerWarningRepeats = HUD_WARNING_TIMING_DEFAULT;
char g_TimerPartsBuffer[2][MAX_MESSAGE_LENGTH]; // need to PrintMapCDMessageToAll function

int g_RoundStartTime;

//Check if input string contains word from blacklist.
public bool StrContainBlackListWord(const char[] string)
{
	for(int i = 0; i < sizeof(g_BlackListWords); ++i)
	{
		if(StrContains(string, g_BlackListWords[i], false) != -1)
		{
			return true;
		}
	}
	
	return false;
}

//Check if input string contains number.
public bool StrContainNumber(const char[] string)
{
	for(int i = 0; i < strlen(string); ++i)
	{
		if(IsCharNumeric(string[i]))
		{
			return true;
		}
	}
	
	return false;
}

//Find int number in string, if did not find - returns 0
public int StrSearchInt(const char[] string)
{
	int currentItPosition;
	char result[MAX_NUMBER_STRING_LEN]; // the maximum search number contains 4 symbols

	for(int i = 0; i < strlen(string); ++i)
	{
		if(IsCharNumeric(string[i]))
		{
			result[currentItPosition++] = string[i];
		}
		else if(currentItPosition != 0) // if we already found number and current symbol is not numeric, break searching
		{
			break;
		}
	}

	return StringToInt(result);
}

//Check if symbol is not on g_FilterSymbolsList
public bool IsValidSymbol(const char[] symbol)
{
	for(int i = 0; i < sizeof(g_FilterSymbolsList); ++i)
	{
		if(StrEqual(symbol, g_FilterSymbolsList[i]))
		{
			return false;
		}
	}

	return true;
}

//Removes all g_FilterSymbolsList symbols from input string
public void FilterText(char string[MAX_MESSAGE_LENGTH])
{
	for(int i = 0; i < sizeof(g_FilterSymbolsList); ++i)
	{
		ReplaceString(string, sizeof(string), g_FilterSymbolsList[i], "");
	}
}

//Prints map message to chat with formating according to chat_tag and chat_text_color
public void PrintMapMessageToAll(const char[] message)
{
	RefreshConVarsVariables();

	char formatMessage[MAX_MESSAGE_LENGTH];

	Format(formatMessage, sizeof(formatMessage), "%s %s%s", chat_tag, chat_text_color, message);
	TrimString(formatMessage);

	CPrintToChatAll(formatMessage);
}

//Prints map message and countdown to chat with formating according to chat_tag, chat_text_color, chat_number_color, chat_end_symbol, chat_end_color
public void PrintMapCDMessageToAll(const char[] part1, const int seconds, const char[] part2)
{
	RefreshConVarsVariables();

	int endOfTimer = GetCurrentRoundTime() - seconds;

	int minEnd = endOfTimer / 60;
	int secEnd = endOfTimer - minEnd * 60;

	char formatCDMessage[MAX_MESSAGE_LENGTH];

	Format(formatCDMessage, sizeof(formatCDMessage), "%s %s%s%s%d%s%s %s%s%s%d:%s%d", chat_tag, chat_text_color, part1, chat_number_color, seconds, chat_text_color, part2, chat_end_color, chat_end_symbol, ((minEnd < 10) ? "0" : ""), minEnd, ((secEnd < 10) ? "0" : ""), secEnd);
	TrimString(formatCDMessage);

	CPrintToChatAll(formatCDMessage);
}

//Get current moment time
public int GetCurrentRoundTime()
{
	return GameRules_GetProp("m_iRoundTime") - (GetTime() - g_RoundStartTime - GetConVarInt(FindConVar("mp_freezetime")));
}

//Formating HUD message according to hud_text_color, hud_number_color, hud_prefix, hud_prefix_color, hud_postfix and hud_postfix_color
public void FormatCountdownMessage(const char[] part1, const int seconds, const char[] part2, char output[MAX_MESSAGE_LENGTH])
{
	RefreshConVarsVariables();
	Format(output, sizeof(output), "<font color='%s'>%s</font> <font color='%s'>%s</font><font color='%s'>%d</font><font color='%s'>%s</font> <font color='%s'>%s</font>", hud_prefix_color, HUD_PREFIX, hud_text_color, part1, hud_number_color, seconds, hud_text_color, part2, hud_postfix_color, HUD_POSTFIX);
}

//Shows HTML message in player's HUD
public void HTMLHUDMessageShow(const char[] message, int hold)
{
	Event HTMLHUDMessage = CreateEvent("show_survival_respawn_status", true);

	if(HTMLHUDMessage != null)
	{
		HTMLHUDMessage.SetString("loc_token", message);
		HTMLHUDMessage.SetInt("duration", hold);
		HTMLHUDMessage.SetInt("userid", -1);

		HTMLHUDMessage.Fire();
	}
}

//Display Countdown HTML HUD to everyone
public void StartCountdown(const char[] message, int seconds)
{
	RefreshConVarsVariables();

	EmitSoundToAll(HUD_APPEAR_SOUND);

	if (g_CurrentCountdownSecondsTimer != INVALID_HANDLE)
	{
		KillTimer(g_CurrentCountdownSecondsTimer);
		g_CurrentCountdownSecondsTimer = INVALID_HANDLE;
	}

	if (g_CurrentCountdownWarningTimer != INVALID_HANDLE)
	{
		KillTimer(g_CurrentCountdownWarningTimer);
		g_CurrentCountdownWarningTimer = INVALID_HANDLE;
	}

	if (g_CurrentCountdownWarningSoundTimer != INVALID_HANDLE)
	{
		KillTimer(g_CurrentCountdownWarningSoundTimer);
		g_CurrentCountdownWarningSoundTimer = INVALID_HANDLE;
	}

	g_CurrentCountdownSecondsTimer = CreateTimer(1.0, Timer_CountdownSeconds, _, TIMER_REPEAT);
	g_CurrentTimerSeconds = seconds;

	int warningTiming = seconds - hud_warning_timing;
	if(warningTiming > 0)
	{
		g_CurrentTimerWarningRepeats = hud_warning_timing;
		g_CurrentCountdownWarningTimer = CreateTimer(float(warningTiming), Timer_CountdownWarning, _, TIMER_REPEAT);
	}
}

//Timer seconds
public Action Timer_CountdownSeconds(Handle timer)
{
	g_CurrentTimerSeconds--;
	if(g_CurrentTimerSeconds < 0)
	{
		return Plugin_Handled;
	}

	char message[MAX_MESSAGE_LENGTH];
	FormatCountdownMessage(g_TimerPartsBuffer[0], g_CurrentTimerSeconds, g_TimerPartsBuffer[1], message);

	HTMLHUDMessageShow(message, 2); // hold = 2 because with 1 it is blinking

	return Plugin_Continue;
}

//Timer warning
public Action Timer_CountdownWarning(Handle timer)
{
	KillTimer(g_CurrentCountdownWarningTimer);
	g_CurrentCountdownWarningTimer = INVALID_HANDLE;

	if (g_CurrentCountdownWarningSoundTimer != INVALID_HANDLE)
	{
		KillTimer(g_CurrentCountdownWarningSoundTimer);
		g_CurrentCountdownWarningSoundTimer = INVALID_HANDLE;
	}

	g_CurrentCountdownWarningSoundTimer = CreateTimer(1.0, Timer_CountdownWarningSound, _, TIMER_REPEAT);

	return Plugin_Continue;
}

//Timer warning sounds
public Action Timer_CountdownWarningSound(Handle timer)
{
	g_CurrentTimerWarningRepeats--;

	if(g_CurrentTimerWarningRepeats < 0)
	{
		return Plugin_Handled;
	}

	EmitSoundToAll(HUD_WARNING_SOUND);

	return Plugin_Continue;
}

//ConVars refresh
public void ConVarChange_countdown_chat_tag(ConVar convar, char[] oldValue, char[] newValue)
{
	g_countdown_chat_tag.SetString(newValue);
}

public void ConVarChange_countdown_chat_text_color(ConVar convar, char[] oldValue, char[] newValue)
{
	g_countdown_chat_text_color.SetString(newValue);
}

public void ConVarChange_countdown_chat_number_color(ConVar convar, char[] oldValue, char[] newValue)
{
	g_countdown_chat_number_color.SetString(newValue);
}

public void ConVarChange_countdown_chat_end_symbol(ConVar convar, char[] oldValue, char[] newValue)
{
	g_countdown_chat_end_symbol.SetString(newValue);
}

public void ConVarChange_countdown_chat_end_color(ConVar convar, char[] oldValue, char[] newValue)
{
	g_countdown_chat_end_color.SetString(newValue);
}

public void ConVarChange_countdown_hud_warning_timing(ConVar convar, char[] oldValue, char[] newValue)
{
	g_countdown_hud_warning_timing.SetInt(StringToInt(newValue));
}

public void ConVarChange_countdown_hud_text_color(ConVar convar, char[] oldValue, char[] newValue)
{
	g_countdown_hud_text_color.SetString(newValue);
}

public void ConVarChange_countdown_hud_number_color(ConVar convar, char[] oldValue, char[] newValue)
{
	g_countdown_hud_number_color.SetString(newValue);
}

public void ConVarChange_countdown_hud_prefix_color(ConVar convar, char[] oldValue, char[] newValue)
{
	g_countdown_hud_prefix_color.SetString(newValue);
}

public void ConVarChange_countdown_hud_postfix_color(ConVar convar, char[] oldValue, char[] newValue)
{
	g_countdown_hud_postfix_color.SetString(newValue);
}

//Refresh all global variables based on ConVars
void RefreshConVarsVariables()
{
	g_countdown_chat_tag.GetString(chat_tag, sizeof(chat_tag));
	g_countdown_chat_text_color.GetString(chat_text_color, sizeof(chat_text_color));
	g_countdown_chat_number_color.GetString(chat_number_color, sizeof(chat_number_color));
	g_countdown_chat_end_symbol.GetString(chat_end_symbol, sizeof(chat_end_symbol));
	g_countdown_chat_end_color.GetString(chat_end_color, sizeof(chat_end_color));

	char hud_warning_timing_str[MAX_NUMBER_STRING_LEN];
	g_countdown_hud_warning_timing.GetString(hud_warning_timing_str, sizeof(hud_warning_timing_str));
	hud_warning_timing = StringToInt(hud_warning_timing_str);

	g_countdown_hud_text_color.GetString(hud_text_color, sizeof(hud_text_color));
	g_countdown_hud_number_color.GetString(hud_number_color, sizeof(hud_number_color));
	g_countdown_hud_prefix_color.GetString(hud_prefix_color, sizeof(hud_prefix_color));
	g_countdown_hud_postfix_color.GetString(hud_postfix_color, sizeof(hud_postfix_color));
}

public void OnPluginStart()
{
	AddCommandListener(Listener_OnSay, "say");

	HookEvent("round_start", Event_RoundStart);

	g_countdown_chat_tag = CreateConVar("countdown_chat_tag", "{yellow}[{darkred}kurumi{orange}test{yellow}] ►", "Will shown in chat before map message.");
	g_countdown_chat_text_color = CreateConVar("countdown_chat_text_color", "{green}", "Color of main text in chat.");
	g_countdown_chat_number_color = CreateConVar("countdown_chat_number_color", "{yellow}", "Color of the number in chat.");
	g_countdown_chat_end_symbol = CreateConVar("countdown_chat_end_symbol", "@", "End timing symbol.");
	g_countdown_chat_end_color = CreateConVar("countdown_chat_end_color", "{orange}", "Color of the end timing in chat.");

	g_countdown_hud_warning_timing = CreateConVar("countdown_hud_warning_timing", "3", "Since what moment timer will warn players.");
	g_countdown_hud_text_color = CreateConVar("countdown_hud_text_color", "#00CCFF", "HEX Color of main text in HTML HUD.");
	g_countdown_hud_number_color = CreateConVar("countdown_hud_number_color", "#FFFFFF", "HEX Color of the number in HTML HUD.");
	g_countdown_hud_prefix_color = CreateConVar("countdown_hud_prefix_color", "#00FF00", "HEX Color of the prefix symbol in HTML HUD.");
	g_countdown_hud_postfix_color = CreateConVar("countdown_hud_postfix_color", "#00FF00", "HEX Color of the postfix symbol in HTML HUD.");


	g_countdown_chat_tag.AddChangeHook(ConVarChange_countdown_chat_tag);
	g_countdown_chat_text_color.AddChangeHook(ConVarChange_countdown_chat_text_color);
	g_countdown_chat_number_color.AddChangeHook(ConVarChange_countdown_chat_number_color);
	g_countdown_chat_end_symbol.AddChangeHook(ConVarChange_countdown_chat_end_symbol);
	g_countdown_chat_end_color.AddChangeHook(ConVarChange_countdown_chat_end_color);

	g_countdown_hud_warning_timing.AddChangeHook(ConVarChange_countdown_hud_warning_timing);
	g_countdown_hud_text_color.AddChangeHook(ConVarChange_countdown_hud_text_color);
	g_countdown_hud_number_color.AddChangeHook(ConVarChange_countdown_hud_number_color);
	g_countdown_hud_prefix_color.AddChangeHook(ConVarChange_countdown_hud_prefix_color);
	g_countdown_hud_postfix_color.AddChangeHook(ConVarChange_countdown_hud_postfix_color);
}

public void OnMapStart()
{
	PrecacheSound(HUD_APPEAR_SOUND, true);
	PrecacheSound(HUD_WARNING_SOUND, true);
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	g_RoundStartTime = GetTime();
}

public Action Listener_OnSay(int client, char[] command, int args)
{
	if(client) // skip message if message typed by not console
	{
		return Plugin_Continue;
	}

	char mapMessage[MAX_MESSAGE_LENGTH];
	GetCmdArgString(mapMessage, sizeof(mapMessage));

	FilterText(mapMessage);

	if(!StrContainBlackListWord(mapMessage) && StrContainNumber(mapMessage))
	{
		int seconds = StrSearchInt(mapMessage);

		char seconds_string[MAX_NUMBER_STRING_LEN];
		IntToString(seconds, seconds_string, MAX_NUMBER_STRING_LEN);

		ExplodeString(mapMessage, seconds_string, g_TimerPartsBuffer, 2, sizeof(g_TimerPartsBuffer[]));

		PrintMapCDMessageToAll(g_TimerPartsBuffer[0], seconds, g_TimerPartsBuffer[1]);

		StartCountdown(mapMessage, seconds);
	}
	else
	{
		PrintMapMessageToAll(mapMessage);
	}

	return Plugin_Handled;
}