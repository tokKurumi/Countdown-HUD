#include <sourcemod>
#include <multicolors>
#include <morecolors>

#define TIMER_CHAT_TAG "{yellow}[{darkred}kurumi{orange}test{yellow}] ► {green}"

#define MAX_STRING_LENGTH 255
#define MAX_HUD_LENGTH 42

public Plugin myinfo =
{
	name			= "Test",
	author		= "kurumi",
	description = "Test.",
	version		= "1.0",
	url			= "https://github.com/tokKurumi"
};

char wordsBlackList[][] = 
{
	"recharge",
	"cd",
	"tips",
	"recast",
	"cooldown",
	"cool"
};

char filterSymbolsList[] = ".,!:;<>()[]{}_/\\";

Handle g_CurrentCountdownTimer;
int g_TimerCountValue;
char g_TimerMessageValue[MAX_HUD_LENGTH];

bool ContainBlackListWords(const char[] string)
{
	for(int i = 0; i < sizeof(wordsBlackList); i++)
	{
		if(StrContains(string, wordsBlackList[i], false) != -1)
		{
			return true;
		}
	}
	return false;
}

bool ContainNumber(const char[] string)
{
	for(int i = 0; i < strlen(string); i++)
	{
		if(IsCharNumeric(string[i]))
		{
			return true;
		}
	}
	return false;
}

int SearchNumber(const char[] string)
{
	int numericCount;
	char result[MAX_STRING_LENGTH];

	for(int i = 0; i < strlen(string); i++)
	{
		if(IsCharNumeric(string[i]))
		{
			result[numericCount] = string[i];
			numericCount++;
		}
		else if(numericCount != 0)
		{
			break;
		}
	}

	return StringToInt(result);
}

bool IsValidSymbol(char symbol)
{
	for(int i = 0; i < sizeof(filterSymbolsList); i++)
	{
		if(symbol == filterSymbolsList[i])
		{
			return false;
		}
	}
	return true;
}

void FilterText(char string[MAX_HUD_LENGTH])
{
	char buffer[MAX_HUD_LENGTH];
	int bufferPos;

	for(int i = 0; i < strlen(string); i++)
	{
		if(IsValidSymbol(string[i]))
		{
			buffer[bufferPos++] = string[i];
		}
	}

	string = buffer;
}

void TextMessageShow(int client, const char[] message = NULL_STRING, int hold = 1)
{
	Event countdownHud = CreateEvent("show_survival_respawn_status", true);
	if (countdownHud != null)
	{
		countdownHud.SetString("loc_token", message);
		countdownHud.SetInt("duration", hold);
		countdownHud.SetInt("userid", -1);

		countdownHud.FireToClient(client);

		countdownHud.Cancel(); 
	}
}

void StartCountDown(const char message[MAX_HUD_LENGTH])
{
	g_TimerCountValue = SearchNumber(message);
	g_TimerMessageValue = message;

	if (g_CurrentCountdownTimer != INVALID_HANDLE)
	{
		KillTimer(g_CurrentCountdownTimer);
		g_CurrentCountdownTimer = INVALID_HANDLE;
	}

	g_CurrentCountdownTimer = CreateTimer(1.0, Timer_CountDown, _, TIMER_REPEAT);
}

public Action Timer_CountDown(Handle hTimer)
{
	char secondsCount1[MAX_HUD_LENGTH];
	IntToString(g_TimerCountValue, secondsCount1, sizeof(secondsCount1));

	g_TimerCountValue--;
	if(g_TimerCountValue < 1)
	{
		return Plugin_Handled;
	}

	char secondsCount2[MAX_HUD_LENGTH];
	IntToString(g_TimerCountValue, secondsCount2, sizeof(secondsCount2));

	ReplaceString(g_TimerMessageValue, sizeof(g_TimerMessageValue), secondsCount1, secondsCount2);

	for(int i = 1; i < MAXPLAYERS; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			TextMessageShow(i, g_TimerMessageValue, 2);
		}
	}

	return Plugin_Continue;
}

public void OnPluginStart()
{
	AddCommandListener(OnSay, "say");
}

public Action OnSay(int iClient, char[] command, int args)
{
	if(iClient)
	{
		return Plugin_Continue;
	}

	char buffer[MAX_HUD_LENGTH];
	GetCmdArgString(buffer, sizeof(buffer));

	char chatMsg[MAX_STRING_LENGTH];
	GetCmdArgString(chatMsg, sizeof(chatMsg));

	Format(chatMsg, sizeof(chatMsg), "%s%s", TIMER_CHAT_TAG, chatMsg);

	if(!ContainBlackListWords(buffer) && ContainNumber(buffer))
	{
		FilterText(buffer);
		
		StartCountDown(buffer);

		CPrintToChatAll(chatMsg);
	}
	else
	{
		CPrintToChatAll(chatMsg);
	}

	return Plugin_Handled;
}
