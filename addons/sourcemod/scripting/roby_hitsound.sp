#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>

public Plugin myinfo = {
	name = "Hitsound menu",
	author = "roby",
	description = "Play a sound when hitting a player",
	version = "",
	url = "https://steamcommunity.com/groups/EraSurfCommunity"
};

#define TAG ">"
#define TOTAL_HITSOUNDS sizeof(g_sounds)
#define SPECMODE_NONE 0
#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_3RDPERSON 5
#define SPECMODE_FREELOOK 6

Handle cookie_hitsound = INVALID_HANDLE;

// roby_hitsound_kill_only
// 0: sound will always play when hitting
// 1: sound will only play on kill
ConVar cv_hitsound_kill_only;

// client array (each client will have X hitmarker, default = 1 = skeet)
int g_cl_hitsound[MAXPLAYERS + 1] = {1, ...};

// add hitsounds here (WARNING: THEY HAVE TO BE IN THE SAME ORDER), which means, 
// hitsound Skeet refers to erasounds/fdp_era.wav
// hitsound MySound refers to myfolder/mysound.wav
// READ: mysounds or erasounds HAVE TO BE IN csgo/sound folder
char g_sounds[][] = {
	"",
	"play */ptrunners/hitsounds/fdp_era.wav",
    "play */ptrunners/hitsounds/cod_era.mp3",
    "play */ptrunners/hitsounds/nojohit_era.wav",
    "play */ptrunners/hitsounds/nojohittwo_era.wav",
	"play */ptrunners/hitsounds/bubble_era.wav",
	"play */ptrunners/hitsounds/bounce_era.wav",
	"play */ptrunners/hitsounds/catgun_fire01_era.wav",
	"play */ptrunners/hitsounds/firework_1_era.mp3",
	"play */ptrunners/hitsounds/punch_era.mp3",
	"play */ptrunners/hitsounds/laser_era.mp3",
	"play */ptrunners/hitsounds/bonk.wav",
	"play */ptrunners/hitsounds/bameware_era.wav",
	//"play */myfolder/mysound.wav"
};
char g_sounds_name[][] = {
	"Nenhum",
    "Skeet",
	"Cod",
	"Nojo1",
	"Nojo2",
	"Bubble",
	"Bounce",
	"Catgun",
	"Firework",
	"Punch",
	"Laser",
	"Bonk",
	"Bameware",
	//"MySound"
};

public void OnPluginStart() {		
	RegConsoleCmd("sm_hitsound", cmd_hit_sound);
	
	HookEvent("player_hurt", event_player_hurt);
	
	cv_hitsound_kill_only = CreateConVar("roby_hitsound_kill_only", "0", "0: sound will always play when you hit/kill someone; 1: sound will only play on kill");
	cv_hitsound_kill_only.AddChangeHook(on_cvar_change);
	
	do_cookie_stuff();
	
	precache_sounds();
}

public void on_cvar_change(ConVar cvar, char[] old_value, char[] new_value) {
	if (cvar == cv_hitsound_kill_only) {
		LogMessage(TAG ... "%s", StringToInt(new_value) == 0 ? "hitsounds are enabled on kill and hit":"hitsounds will play only on kills");
	}
}


// ** ** ** **
// commands

public Action cmd_hit_sound(int client, int args) {
	if (!is_valid_client(client)) {
		return Plugin_Handled;
	}
	
	initialize_hit_sound_menu(client);
	return Plugin_Handled;
}


// ** ** ** ** ** **
// menu & callback

// create menu to client with all hitsounds and his current one
public void initialize_hit_sound_menu(int client) {
	Handle menu = INVALID_HANDLE;
	char info[4], item[64];
	menu = CreateMenu(callback_hitsound_menu, MenuAction_Start|MenuAction_Select|MenuAction_End|MenuAction_Cancel);
	SetMenuTitle(menu, "Escolhe o teu HitSound:");
	for (int i = 0; i < TOTAL_HITSOUNDS; i++) {
		Format(item, sizeof(item), "%s %s", g_sounds_name[i], i == g_cl_hitsound[client] ? "[X]" : " ");
		IntToString(i, info, sizeof(info));
		AddMenuItem(menu, info, item);
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int callback_hitsound_menu(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			int option = StringToInt(item);
			g_cl_hitsound[param1] = option;
			
			SetClientCookie(param1, cookie_hitsound, item); // pls work

			if (!option) {
				PrintToChat(param1, "%s {lightred}Desativaste{default} os HitSounds.", TAG);
			} else {
				PrintToChat(param1, "%s Escolheste {green}\"%s\" {default}como HitSound.", TAG, g_sounds_name[option]);
			}				
		}
		
		case MenuAction_End: { 	
			delete menu; 
		}
	}
	
	return 0;
}


// ** ** **
// events

public Action event_player_hurt(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!is_valid_client(attacker)) {
		return Plugin_Handled;
	}
	
	if (cv_hitsound_kill_only.BoolValue && GetEventInt(event, "health") > 0) {
		return Plugin_Handled;
	}
	
	play_sound(attacker, g_sounds[g_cl_hitsound[attacker]]);
	play_sound_for_specs(attacker);
	return Plugin_Handled;
}


// ** ** ** **
// functions

stock bool is_valid_client(int client) {
    return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client));
}

// this function will also play the sound to the spectators
void play_sound_for_specs(int attacker) {
	for (int spec = 1; spec <= MaxClients; spec++) {
		if (!is_valid_client(spec) || !IsClientObserver(spec))
			continue;

		int spec_mode = GetEntProp(spec, Prop_Send, "m_iObserverMode");
		if (spec_mode == SPECMODE_FIRSTPERSON || spec_mode == SPECMODE_3RDPERSON) {
			int target = GetEntPropEnt(spec, Prop_Send, "m_hObserverTarget");
			if (target == attacker) {
				ClientCommand(spec, g_sounds[g_cl_hitsound[spec]]);
			}
		}
	}
}

void play_sound(int client, const char[] sound) {
	if (strcmp("", sound) || strlen(sound) > 1) {
		ClientCommand(client, sound);
	}
}


// ** ** ** **
// cookies ( do they work? :] )
void do_cookie_stuff() {
	cookie_hitsound = RegClientCookie("roby_cookie_hitsound", "hitsound choice", CookieAccess_Protected);
	for (int i = MaxClients; i > 0; --i) {
        if(AreClientCookiesCached(i)) {
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientDisconnect(int client) {
	char hs_option[4];
	IntToString(g_cl_hitsound[client], hs_option, sizeof(hs_option));
	SetClientCookie(client, cookie_hitsound, hs_option);
}

public OnClientCookiesCached(int client) {
	char hs[4];
	GetClientCookie(client, cookie_hitsound, hs, sizeof(hs));
	g_cl_hitsound[client] = (hs[0] == '\0') ? 1:StringToInt(hs);
}


// ** ** ** **
// precache (make sure ur fastdl works lol)

void precache_sounds() {
	char str1[102], str2[128];
	for (int i = 1; i < TOTAL_HITSOUNDS; i++) {
		Format(str1, sizeof(str1), "%s", g_sounds[i][FindCharInString(g_sounds[i], '*', false)+2]);
		Format(str2, sizeof(str2), "sound/%s", str1);
		AddFileToDownloadsTable(str2);
		PrecacheSound(str1, true);
	}
}