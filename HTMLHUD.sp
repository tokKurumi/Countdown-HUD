#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <csgocolors_fix>
#include <clientprefs>

#define HUD_PREFIX "▻"
#define HUD_POSTFIX "◅"

#define HUD_APPEAR_SOUND "ui/beepclear.wav"

// TODO: rewrite using ConVars
#define countdown_chat_tag "{yellow}[{darkred}kurumi{orange}test{yellow}] ►"
#define countdown_chat_text_color "{green}"
#define countdown_chat_number_color "{yellow}"
#define countdown_chat_end_symbol "@"
#define countdown_chat_end_color "{orange}"
#define countdown_hud_warning_timing 3
#define countdown_hud_text_color "#00CCFF"
#define countdown_hud_number_color "#FF2400"
#define countdown_hud_prefix_color "#00FF00"
#define countdown_hud_postfix_color "#00FF00"

#define MAX_SEARCH_NUMBER_LEN 4

public Plugin myinfo =
{
	name			= "Console Chat manager",
	author		= "kurumi",
	description = "Countdown HTML HUD for ZE servers.",
	version		= "3.0",
	url			= "https://github.com/tokKurumi"
}

char g_BlackListWords[][] = 
{
	"recharge",
	"cd",
	"tips",
	"recast",
	"cooldown",
	"cool",
	"m4dara",
	"4Echo",
	"level",
	"lvl"
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

Handle g_toggleCookie;
Handle g_toggleSoundCookie;
bool g_toggle[MAXPLAYERS + 1];
bool g_toggleSound[MAXPLAYERS + 1];

int g_RoundStartTime;

int g_countOfTimers = 0;
int g_currentSeconds = 0;

enum struct CountdownTimer
{
	Handle secondsTimer; 								// Main countdown timer

	int seconds; 											// Timer seconds
	int currentWarningSeconds; 						// Current warning seconsd ticks

	// Map messege splits to 2 parts by seconds which easy to format
	char mapMessagePart1[MAX_MESSAGE_LENGTH];
	char mapMessagePart2[MAX_MESSAGE_LENGTH];

	// Constructor
	void Construct(const int seconds, const char[] mapMessage = EOS)
	{
		g_countOfTimers++;

		this.seconds = seconds;
		g_currentSeconds = seconds + 1;

		char seconds_string[MAX_SEARCH_NUMBER_LEN];
		IntToString(seconds, seconds_string, sizeof(seconds_string));
		char mapMessagePartsBuffer[2][MAX_MESSAGE_LENGTH];

		ExplodeString(mapMessage, seconds_string, mapMessagePartsBuffer, 2, sizeof(mapMessagePartsBuffer[]));

		strcopy(this.mapMessagePart1, MAX_MESSAGE_LENGTH, mapMessagePartsBuffer[0]);
		strcopy(this.mapMessagePart2, MAX_MESSAGE_LENGTH, mapMessagePartsBuffer[1]);
	}

	// Returns timer end minutes
	int minEnd()
	{
		int endOfTimer = GetCurrentRoundTime() - this.seconds;

		if(endOfTimer < 0)
		{
			return 0;
		}

		return endOfTimer / 60;
	}

	// Returns timer end seconds
	int secEnd()
	{
		int endOfTimer = GetCurrentRoundTime() - this.seconds;
		
		if(endOfTimer < 0)
		{
			return 0;
		}

		int minEnd = this.minEnd();

		return endOfTimer - minEnd * 60;
	}

	// Prints map message and countdown end with formating according to chat_tag, chat_text_color, chat_number_color, chat_end_symbol, chat_end_color
	void PrintMapCDMessage(int client)
	{
		int min = this.minEnd();
		int sec = this.secEnd();

		CPrintToChat(client, "%s %s%s%s%d%s%s %s%s%s%d:%s%d", countdown_chat_tag, countdown_chat_text_color, this.mapMessagePart1, countdown_chat_number_color, this.seconds, countdown_chat_text_color, this.mapMessagePart2, countdown_chat_end_color, countdown_chat_end_symbol, ((min < 10) ? "0" : ""), min, ((sec < 10) ? "0" : ""), sec);
	}

	// Display Countdown HTML HUD
	void StartCountdown(int client)
	{
		if(g_toggleSound[client])
		{
			EmitSoundToAll(HUD_APPEAR_SOUND);
		}

		if (this.secondsTimer != INVALID_HANDLE)
		{
			KillTimer(this.secondsTimer);
			this.secondsTimer = INVALID_HANDLE;
		}

		DataPack data;
		this.secondsTimer = CreateDataTimer(1.0, Timer_CountdownTick, data, TIMER_REPEAT);
		data.WriteCell(client);
		data.WriteString(this.mapMessagePart1);
		data.WriteString(this.mapMessagePart2);
	}
}

Action Timer_CountdownTick(Handle timer, Handle dataPack)
{
	g_currentSeconds--;
	if(g_currentSeconds < 1)
	{
		g_countOfTimers--;
		return Plugin_Handled;
	}

	DataPack data = view_as<DataPack>(dataPack);
	data.Reset();

	int client = data.ReadCell();
	char mapMessagePart1[MAX_MESSAGE_LENGTH];
	char mapMessagePart2[MAX_MESSAGE_LENGTH];
	data.ReadString(mapMessagePart1, sizeof(mapMessagePart1));
	data.ReadString(mapMessagePart2, sizeof(mapMessagePart2));

	char output[MAX_MESSAGE_LENGTH];
	FormatCountdownMessage(mapMessagePart1, g_currentSeconds, mapMessagePart2, output); 

	HTMLHUDMessageShow(client, output, 2);

	return Plugin_Continue;
}

public void OnMapStart()
{
	AddCommandListener(Listener_OnSay, "say");

	PrecacheSound(HUD_APPEAR_SOUND, true);
}

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);

	g_toggleCookie = RegClientCookie("cookie_CCM_hud_show", "Toggle countdown hud.", CookieAccess_Protected);
	g_toggleSoundCookie = RegClientCookie("cookie_CCM_playsound", "Toggle appear countdown hud sound.", CookieAccess_Protected);
	RegConsoleCmd("sm_timer", CMD_timer, "Toggle countdown timer");
	RegConsoleCmd("sm_timersound", CMD_timer, "Toggle countdown timer");

	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsClientInGame(i) && AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client)) 
	{
		return;
	}

	char cookieBuffer[2];

	GetClientCookie(client, g_toggleCookie, cookieBuffer, sizeof(cookieBuffer));
	g_toggle[client] = (cookieBuffer[0] == '\0') ? true : view_as<bool>(StringToInt(cookieBuffer));

	GetClientCookie(client, g_toggleSoundCookie, cookieBuffer, sizeof(cookieBuffer));
	g_toggle[client] = (cookieBuffer[0] == '\0') ? true : view_as<bool>(StringToInt(cookieBuffer));
}

public Action CMD_timer(int client, int args)
{
	char cookieBuffer[2];
	GetClientCookie(client, g_toggleCookie, cookieBuffer, sizeof(cookieBuffer));

	char toggleMessage[MAX_MESSAGE_LENGTH];

	if(cookieBuffer[0] == '0')
	{
		SetClientCookie(client, g_toggleCookie, "1");
		g_toggle[client] = true;

		Format(toggleMessage, sizeof(toggleMessage), "%s %s", countdown_chat_tag, "{default}Countdown HUD has been {green}enabled{default}.");
		CPrintToChat(client, toggleMessage);
	}
	else
	{
		SetClientCookie(client, g_toggleCookie, "0");
		g_toggle[client] = false;
		
		Format(toggleMessage, sizeof(toggleMessage), "%s %s", countdown_chat_tag, "{default}Countdown HUD has been {red}disabled{default}.");
		CPrintToChat(client, toggleMessage);

		HTMLHUDMessageShow(client, "", 2);
	}

	return Plugin_Handled;
}

public void Event_RoundStart(Handle event, const char[] command, bool dontBroadcast)
{
	g_RoundStartTime = GetTime();
}

public void Event_RoundEnd(Handle event, const char[] command, bool dontBroadcast)
{
	CountdownTimer reset;
	reset.Construct(0);
	for(int i = 1; i < MAXPLAYERS; ++i)
	{
		if(IsClientInGame(i))
		{
			reset.StartCountdown(i);
		}
	}

	g_countOfTimers = 0;
	g_currentSeconds = 0;
}

// Removes all g_FilterSymbolsList symbols from input string
public void FilterText(char[] string)
{
	for(int i = 0; i < sizeof(g_FilterSymbolsList); ++i)
	{
		ReplaceString(string, strlen(string), g_FilterSymbolsList[i], "");
	}
}

// Check if input string contains word from blacklist.
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

// Find int number in string, if did not find - returns 0
public int StrSearchInt(const char[] string)
{
	int currentItPosition;
	char result[MAX_SEARCH_NUMBER_LEN]; // the maximum search number contains 4 symbols

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

// Get current moment time
public int GetCurrentRoundTime()
{
	return GameRules_GetProp("m_iRoundTime") - (GetTime() - g_RoundStartTime - GetConVarInt(FindConVar("mp_freezetime")));
}

// Prints map message to chat with formating according to chat_tag, chat_text_color
void PrintMapMessage(int client, const char[] message)
{
	if(IsClientInGame(client) && !IsFakeClient(client))
	{
		CPrintToChat(client, "%s %s%s", countdown_chat_tag, countdown_chat_text_color, message);
	}
}

// Formating HUD message according to hud_text_color, hud_number_color, hud_prefix, hud_prefix_color, hud_postfix and hud_postfix_color
void FormatCountdownMessage(const char[] mapMessagePart1, const int seconds, const char[] mapMessagePart2, char output[MAX_MESSAGE_LENGTH])
{
	Format(output, sizeof(output), "<font color='%s'>%s</font> <font color='%s'>%s</font><font color='%s'>%d</font><font color='%s'>%s</font> <font color='%s'>%s</font>", countdown_hud_prefix_color, HUD_PREFIX, countdown_hud_text_color, mapMessagePart1, countdown_hud_number_color, seconds, countdown_hud_text_color, mapMessagePart2, countdown_hud_postfix_color, HUD_POSTFIX);
}

//Shows HTML message in player's HUD
public void HTMLHUDMessageShow(int client, const char[] message, int hold)
{
	if(IsClientInGame(client) && !IsFakeClient(client))
	{
		Event HTMLHUDMessage = CreateEvent("show_survival_respawn_status", true);

		if(HTMLHUDMessage != null)
		{
			HTMLHUDMessage.SetString("loc_token", message);
			HTMLHUDMessage.SetInt("duration", hold);
			HTMLHUDMessage.SetInt("userid", -1);

			HTMLHUDMessage.FireToClient(client);

			HTMLHUDMessage.Cancel();
		}
	}
}

public Action Listener_OnSay(int client, char[] command, int args)
{
	if(client) // skip message if typed by clients
	{
		return Plugin_Continue;
	}

	char mapMessage[MAX_MESSAGE_LENGTH];
	GetCmdArgString(mapMessage, sizeof(mapMessage));

	FilterText(mapMessage);

	int seconds = StrSearchInt(mapMessage);
	if(!StrContainBlackListWord(mapMessage) && seconds!= 0)
	{
		CountdownTimer timer;
		timer.Construct(seconds, mapMessage);
		
		for(int i = 1; i < MAXPLAYERS; ++i)
		{
			if(IsClientInGame(i))
			{
				if(g_toggle[i])
				{
					timer.PrintMapCDMessage(i);
				}
				PrintToChatAll("%d", g_toggle[i]);
				timer.StartCountdown(i);
			}
		}
	}
	else
	{
		for(int i = 1; i < MAXPLAYERS; ++i)
		{
			if(IsClientInGame(i))
			{
				PrintMapMessage(i, mapMessage);
			}
		}
	}

	return Plugin_Handled;
}
