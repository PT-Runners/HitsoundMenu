#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>
#include <tVip>

public Plugin myinfo = {
	name = "Hitsound menu",
	author = "roby edited by Trayz",
	description = "Play a sound when hitting a player",
	version = "",
	url = "https://steamcommunity.com/groups/EraSurfCommunity"
};

#define TAG ">"
#define MAX_SOUNDS	50
#define SPECMODE_NONE 0
#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_3RDPERSON 5
#define SPECMODE_FREELOOK 6
#define HIT							1
#define KILL						2

enum struct Sound
{
	char name[32];
	char path[PLATFORM_MAX_PATH];
	char flag[16];
}

Sound g_Hitsounds[MAX_SOUNDS];
int g_HitsoundsSize;

Sound g_Killsounds[MAX_SOUNDS];
int g_KillsoundsSize;

Handle cookie_hitsound = INVALID_HANDLE;
Handle cookie_killsound = INVALID_HANDLE;


int g_cl_hitsound[MAXPLAYERS + 1] = {0, ...};
int g_cl_killsound[MAXPLAYERS + 1] = {0, ...};

public void OnPluginStart()
{		
	cookie_hitsound = RegClientCookie("roby_cookie_hitsound", "hitsound choice", CookieAccess_Protected);
	cookie_killsound = RegClientCookie("roby_cookie_killsound", "killsound choice", CookieAccess_Protected);

	RegConsoleCmd("sm_hitsound", Cmd_HitSound);
	
	HookEvent("player_hurt", OnPlayerHurt);
}

public void OnMapStart()
{
	DownloadPrecacheSounds();
}

public OnClientCookiesCached(int client)
{
	char hs[4], ks[4];
	GetClientCookie(client, cookie_hitsound, hs, sizeof(hs));
	g_cl_hitsound[client] = (hs[0] == '\0') ? 0 : StringToInt(hs);

	GetClientCookie(client, cookie_killsound, ks, sizeof(ks));
	g_cl_killsound[client] = (ks[0] == '\0') ? 0 : StringToInt(ks);
}

public void tVip_OnClientLoadedPost(int client)
{
	if(g_cl_hitsound[client] > 0 && !CheckAdminFlag(client, g_Hitsounds[g_cl_hitsound[client]].flag))
	{
		g_cl_hitsound[client] = 0;
	}

	if(g_cl_killsound[client] > 0 && !CheckAdminFlag(client, g_Killsounds[g_cl_killsound[client]].flag))
	{
		g_cl_killsound[client] = 0;
	}
}

public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientDisconnect(client);
		}
	}
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	int victim = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(attacker) || !IsValidClient(victim) || victim == attacker)
	{
		return Plugin_Handled;
	}

	int health = GetClientHealth(victim);

	if(health < 1)
	{
		if (g_cl_killsound[attacker])
		{
			PlaySound(attacker, g_Killsounds[g_cl_killsound[attacker]].path);
			PlaySoundForSpecs(attacker, g_Killsounds[g_cl_killsound[attacker]].path);
		}
	}
	else
	{
		if(g_cl_hitsound[attacker])
		{
			PlaySound(attacker, g_Hitsounds[g_cl_hitsound[attacker]].path);
			PlaySoundForSpecs(attacker, g_Hitsounds[g_cl_hitsound[attacker]].path);
		}
	}
	
	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	if(AreClientCookiesCached(client))
	{
		char hs_option[4], ks_option[4];
		IntToString(g_cl_hitsound[client], hs_option, sizeof(hs_option));
		SetClientCookie(client, cookie_hitsound, hs_option);

		IntToString(g_cl_killsound[client], ks_option, sizeof(ks_option));
		SetClientCookie(client, cookie_killsound, ks_option);
	}
}


public Action Cmd_HitSound(int client, int args)
{
	if (!IsValidClient(client)) {
		return Plugin_Handled;
	}
	
	Menu_Hitsound(client);
	return Plugin_Handled;
}

void Menu_Hitsound(int client)
{
	char info[8], item[64];
	Menu menu = CreateMenu(Menu_Hitsound_Handler);
	menu.SetTitle("Hitsound Menu");

	IntToString(HIT, info, sizeof(info));
	Format(item, sizeof(item), "Acertar");
	menu.AddItem(info, item);

	IntToString(KILL, info, sizeof(info));
	Format(item, sizeof(item), "Matar");
	menu.AddItem(info, item);

	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Hitsound_Handler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action) {
		case MenuAction_End: { 
			delete menu; 
		}

		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			int option = StringToInt(item);
			switch(option)
			{
				case HIT:
				{
					Menu_Hitsound_Hit(client);
				}

				case KILL:
				{
					Menu_Hitsound_Kill(client);
				}
			}
        }
    }
    
	return 0;
}

void Menu_Hitsound_Kill(int client)
{
	char info[8], item[64];

	Menu menu = CreateMenu(Menu_Hitsound_Kill_Handler);

	menu.SetTitle("Escolhe o teu HitSound (ao matar):");

	for (int i = 0; i < g_KillsoundsSize; i++)
	{
		Format(item, sizeof(item), "%s %s", g_Killsounds[i].name, i == g_cl_killsound[client] ? "[X]" : " ");
		IntToString(i, info, sizeof(info));
		menu.AddItem(info, item, i == g_cl_killsound[client] || !CheckAdminFlag(client, g_Killsounds[i].flag) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;

	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Hitsound_Kill_Handler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
			{
				Menu_Hitsound(client);
			}
		}

		case MenuAction_End:
		{ 
			delete menu; 
		}

		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(itemNum, item, sizeof(item));
			
			int option = StringToInt(item);
			g_cl_killsound[client] = option;

			if (!option)	CPrintToChat(client, "%s {lightred}Desativaste{default} os hitmarkers ao matar", TAG);
			else			CPrintToChat(client, "%s Escolheste {green}\"%s\" {default}como hitmarker (ao matar)", TAG, g_Killsounds[option].name);

			Menu_Hitsound_Kill(client);
        }
    }
    
	return 0;
}

void Menu_Hitsound_Hit(int client)
{
	char info[8], item[64];

	Menu menu = CreateMenu(Menu_Hitsound_Hit_Handler);

	menu.SetTitle("Escolhe o teu HitSound (ao acertar):");

	for (int i = 0; i < g_HitsoundsSize; i++)
	{
		Format(item, sizeof(item), "%s %s", g_Hitsounds[i].name, i == g_cl_hitsound[client] ? "[X]" : " ");
		IntToString(i, info, sizeof(info));
		menu.AddItem(info, item, i == g_cl_hitsound[client] || !CheckAdminFlag(client, g_Hitsounds[i].flag) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;

	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Hitsound_Hit_Handler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{

		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
			{
				Menu_Hitsound(client);
			}
		}

		case MenuAction_End:
		{ 
			delete menu; 
		}

		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(itemNum, item, sizeof(item));
			
			int option = StringToInt(item);
			g_cl_hitsound[client] = option;

			if (!option)	CPrintToChat(client, "%s {lightred}Desativaste{default} os hitsounds ao acertar.", TAG);
			else			CPrintToChat(client, "%s Escolheste {green}\"%s\" {default}como hitsounds (ao acertar)", TAG, g_Hitsounds[option].name);

			Menu_Hitsound_Hit(client);
		}
	}

	return 0;
}

void PlaySoundForSpecs(int attacker, char[] sound)
{
	for (int spec = 1; spec <= MaxClients; spec++) {
		if (!IsValidClient(spec) || !IsClientObserver(spec))
			continue;

		int spec_mode = GetEntProp(spec, Prop_Send, "m_iObserverMode");
		if (spec_mode == SPECMODE_FIRSTPERSON || spec_mode == SPECMODE_3RDPERSON) {
			int target = GetEntPropEnt(spec, Prop_Send, "m_hObserverTarget");
			if (target == attacker) {
				ClientCommand(spec, "play */%s", sound);
			}
		}
	}
}

void PlaySound(int client, char[] sound)
{
	if (strcmp("", sound) || strlen(sound) > 1) {
		ClientCommand(client, "play */%s", sound);
	}
}

void DownloadPrecacheSounds()
{
	char buffer[PLATFORM_MAX_PATH];
	char download[PLATFORM_MAX_PATH];
	char flag[16];
	char precache[64];
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/hitsound/hitsound_menu.cfg");

	Handle kv = CreateKeyValues("HitSoundMenu");
	FileToKeyValues(kv, path);

	if (!KvGotoFirstSubKey(kv)) {
		SetFailState("CFG File not found: %s", path);
		CloseHandle(kv);
	}

	g_HitsoundsSize = 0;

	do {

		KvGetSectionName(kv, buffer, sizeof(buffer));
		Format(g_Hitsounds[g_HitsoundsSize].name, 32, "%s", buffer);

		KvGetString(kv, "path", buffer, sizeof(buffer));
		Format(g_Hitsounds[g_HitsoundsSize].path, PLATFORM_MAX_PATH, "%s", buffer);

		KvGetString(kv, "flag", flag, sizeof(flag));
		Format(g_Hitsounds[g_HitsoundsSize].flag, 16, "%s", flag);

		if(StrEqual(g_Hitsounds[g_HitsoundsSize].path, ""))
		{
			g_HitsoundsSize++;
			continue;
		}

		Format(download, sizeof(download), "sound/%s", g_Hitsounds[g_HitsoundsSize].path);
		AddFileToDownloadsTable(download);

		Format(precache, sizeof(precache), "%s", g_Hitsounds[g_HitsoundsSize].path);
		PrecacheDecal(precache, true);

		g_HitsoundsSize++;

	} while (KvGotoNextKey(kv));

	CloseHandle(kv);


	BuildPath(Path_SM, path, sizeof(path), "configs/hitsound/killsound_menu.cfg");

	kv = CreateKeyValues("KillSoundMenu");
	FileToKeyValues(kv, path);

	if (!KvGotoFirstSubKey(kv)) {
		SetFailState("CFG File not found: %s", path);
		CloseHandle(kv);
	}

	g_KillsoundsSize = 0;

	do {

		KvGetSectionName(kv, buffer, sizeof(buffer));
		Format(g_Killsounds[g_KillsoundsSize].name, 32, "%s", buffer);

		KvGetString(kv, "path", buffer, sizeof(buffer));
		Format(g_Killsounds[g_KillsoundsSize].path, PLATFORM_MAX_PATH, "%s", buffer);

		KvGetString(kv, "flag", flag, sizeof(flag));
		Format(g_Killsounds[g_KillsoundsSize].flag, 16, "%s", flag);

		if(StrEqual(g_Killsounds[g_KillsoundsSize].path, ""))
		{
			g_KillsoundsSize++;
			continue;
		}

		Format(download, sizeof(download), "sound/%s", g_Killsounds[g_KillsoundsSize].path);
		AddFileToDownloadsTable(download);

		Format(precache, sizeof(precache), "%s", g_Killsounds[g_KillsoundsSize].path);
		PrecacheDecal(precache, true);

		g_KillsoundsSize++;

	} while (KvGotoNextKey(kv));

	CloseHandle(kv);
}

stock bool CheckAdminFlag(int client, const char[] flags)
{
	if(StrEqual(flags, "")) {
		return true;
	}
	
	int iCount = 0;
	char sflagNeed[22][8], sflagFormat[64];
	bool bEntitled = false;
	
	Format(sflagFormat, sizeof(sflagFormat), flags);
	ReplaceString(sflagFormat, sizeof(sflagFormat), " ", "");
	iCount = ExplodeString(sflagFormat, ",", sflagNeed, sizeof(sflagNeed), sizeof(sflagNeed[]));
	
	for (int i = 0; i < iCount; i++)
	{
		if ((GetUserFlagBits(client) & ReadFlagString(sflagNeed[i]) == ReadFlagString(sflagNeed[i])) || (GetUserFlagBits(client) & ADMFLAG_ROOT))
		{
			bEntitled = true;
			break;
		}
	}
	
	return bEntitled;
}

stock bool IsValidClient(int client)
{
    return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client));
}