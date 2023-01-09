#include <sourcemod>
#include <multicolors>

#define TIMER_CHAT_TAG " \x09[\x02kurumi\x10test\x09] ► \x06"

#define TIMER_TEXT_COLOR "blue"
#define TIMER_NUMBER_COLOR "red"

#define MAX_STRING_LENGTH 255

#define TIMERS_COUNT 4
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

void StartCountDown(int client, const char message[MAX_HUD_LENGTH])
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
			TextMessageShow(i, g_TimerMessageValue);
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

	Format(chatMsg, sizeof(chatMsg), "%s%s", TIMER_CHAT_TAG, chatMsg)
	PrintToChatAll("%s", chatMsg);

	if(!ContainBlackListWords(buffer) && ContainNumber(buffer))
	{
		for(int i = 1; i < MAXPLAYERS; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				StartCountDown(i, buffer);
			}
		}
	}

	return Plugin_Handled;
}