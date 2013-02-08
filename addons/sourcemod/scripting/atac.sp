#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <loghelper>
#include <atac>

public Plugin:myinfo =
{
	name        = "Advanced Team Attack Control",
	author      = "GameConnect",
	description = "Advanced Team Attack Control: Source",
	version     = ATAC_VERSION,
	url         = "http://www.gameconnect.net"
}


/**
 * Globals
 */
enum Mod
{
	Mod_Default,
	Mod_Insurgency
}

new g_iAttacker[MAXPLAYERS + 1] = {-1};
new g_iAttacks[MAXPLAYERS + 1];
new g_iAttacksLimit;
new g_iBansLimit;
new g_iBanTime;
new g_iBanType;
new g_iBans[MAXPLAYERS + 1];
new g_iKarma[MAXPLAYERS + 1];
new g_iKarmaLimit;
new g_iKicks[MAXPLAYERS + 1];
new g_iKicksLimit;
new g_iKillKarma;
new g_iKills[MAXPLAYERS + 1];
new g_iKillsLimit;
new g_iSpawnPunishDelay;
new bool:g_bEnabled;
new bool:g_bIgnoreBots;
new bool:g_bImmunity;
new Function:g_fPunishmentCallbacks[64];
new Handle:g_hAttacksLimit;
new Handle:g_hBansLimit;
new Handle:g_hBanTime;
new Handle:g_hBanType;
new Handle:g_hEnabled;
new Handle:g_hIgnoreBots;
new Handle:g_hImmunity;
new Handle:g_hKarmaLimit;
new Handle:g_hKicksLimit;
new Handle:g_hKillKarma;
new Handle:g_hKillsLimit;
new Handle:g_hPunishmentPlugins[64];
new Handle:g_hPunishments;
new Handle:g_hSpawnPunishDelay;
new Handle:g_hSpawnPunishment[MAXPLAYERS + 1];
new Handle:g_hSQLiteDB;
new Mod:g_iMod = Mod_Default;


/**
 * Plugin Forwards
 */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("ATAC_GetInfo",            Native_GetInfo);
	CreateNative("ATAC_GetSetting",         Native_GetSetting);
	CreateNative("ATAC_GiveKarma",          Native_GiveKarma);
	CreateNative("ATAC_RegisterPunishment", Native_RegisterPunishment);
	CreateNative("ATAC_SetInfo",            Native_SetInfo);
	RegPluginLibrary("atac");
	
	return APLRes_Success;
}

public OnPluginStart()
{
	// Create convars
	CreateConVar("atac_version", ATAC_VERSION, "Advanced Team Attack Control", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_PLUGIN);
	g_hAttacksLimit     = CreateConVar("atac_attacks_limit",     "10", "ATAC Attacks Limit",      FCVAR_PLUGIN);
	g_hBansLimit        = CreateConVar("atac_bans_limit",        "3",  "ATAC Bans Limit",         FCVAR_PLUGIN);
	g_hBanTime          = CreateConVar("atac_ban_time",          "60", "ATAC Ban Time",           FCVAR_PLUGIN);
	g_hBanType          = CreateConVar("atac_ban_type",          "0",  "ATAC Ban Type",           FCVAR_PLUGIN);
	g_hEnabled          = CreateConVar("atac_enabled",           "1",  "ATAC Enabled",            FCVAR_PLUGIN);
	g_hIgnoreBots       = CreateConVar("atac_ignore_bots",       "1",  "ATAC Ignore Bots",        FCVAR_PLUGIN);
	g_hImmunity         = CreateConVar("atac_immunity",          "0",  "ATAC Immunity",           FCVAR_PLUGIN);
	g_hKarmaLimit       = CreateConVar("atac_karma_limit",       "5",  "ATAC Karma Limit",        FCVAR_PLUGIN);
	g_hKicksLimit       = CreateConVar("atac_kicks_limit",       "3",  "ATAC Kicks Limit",        FCVAR_PLUGIN);
	g_hKillKarma        = CreateConVar("atac_kill_karma",        "1",  "ATAC Kill Karma",         FCVAR_PLUGIN);
	g_hKillsLimit       = CreateConVar("atac_kills_limit",       "3",  "ATAC Kills Limit",        FCVAR_PLUGIN);
	g_hSpawnPunishDelay = CreateConVar("atac_spawnpunish_delay", "6",  "ATAC Spawn Punish Delay", FCVAR_PLUGIN);
	
	// Hook convar changes
	HookConVarChange(g_hAttacksLimit,     ConVarChanged_ConVars);
	HookConVarChange(g_hBansLimit,        ConVarChanged_ConVars);
	HookConVarChange(g_hBanTime,          ConVarChanged_ConVars);
	HookConVarChange(g_hBanType,          ConVarChanged_ConVars);
	HookConVarChange(g_hEnabled,          ConVarChanged_ConVars);
	HookConVarChange(g_hIgnoreBots,       ConVarChanged_ConVars);
	HookConVarChange(g_hImmunity,         ConVarChanged_ConVars);
	HookConVarChange(g_hKarmaLimit,       ConVarChanged_ConVars);
	HookConVarChange(g_hKicksLimit,       ConVarChanged_ConVars);
	HookConVarChange(g_hKillKarma,        ConVarChanged_ConVars);
	HookConVarChange(g_hKillsLimit,       ConVarChanged_ConVars);
	HookConVarChange(g_hSpawnPunishDelay, ConVarChanged_ConVars);
	
	// Hook events
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt",  Event_PlayerHurt);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	// Load translations
	LoadTranslations("atac.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	
	// Create commands
	RegConsoleCmd("sm_karmahelp", Command_KarmaHelp, "ATAC Karma Help");
	RegConsoleCmd("sm_tkstatus",  Command_TKStatus,  "ATAC TK Status");
	
	// Create arrays and tries
	g_hPunishments = CreateArray(64);
	
	// Store mod
	decl String:sBuffer[65];
	GetGameFolderName(sBuffer, sizeof(sBuffer));
	
	if(StrContains(sBuffer, "insurgency", false) != -1)
		g_iMod = Mod_Insurgency;
	else
	{
		GetGameDescription(sBuffer, sizeof(sBuffer));
		
		if(StrContains(sBuffer, "Insurgency", false) != -1)
			g_iMod = Mod_Insurgency;
	}
	
	AutoExecConfig(true, "atac");
}

public OnMapStart()
{
	GetTeams(g_iMod == Mod_Insurgency);
	
	if(!g_hSQLiteDB)
	{
		// Connect to local database
		decl String:sError[256] = "";
		g_hSQLiteDB = SQLite_UseDatabase("sourcemod-local", sError, sizeof(sError));
		if(sError[0])
		{
			LogError("%T (%s)", "Could not connect to database", LANG_SERVER, sError);
			return;
		}
		
		// Create local table
		SQL_FastQuery(g_hSQLiteDB, "CREATE TABLE IF NOT EXISTS atac (identity TEXT PRIMARY KEY ON CONFLICT REPLACE, attacks INTEGER, kills INTEGER, kicks INTEGER, bans INTEGER, karma INTEGER, time INTEGER)");
	}
	
	// Delete players that haven't played for two weeks
	decl String:sQuery[256];
	Format(sQuery, sizeof(sQuery), "DELETE FROM atac \
																	WHERE       time + %i <= %i",
																	60 * 60 * 24 * 7 * 2, GetTime());
	SQL_FastQuery(g_hSQLiteDB, sQuery);
	
	// Load client information on late load
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			LoadClient(i);
	}
}

public OnPluginEnd()
{
	// Save client information on unload
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			SaveClient(i);
	}
}

public OnConfigsExecuted()
{
	g_bEnabled          = GetConVarBool(g_hEnabled);
	g_bIgnoreBots       = GetConVarBool(g_hIgnoreBots);
	g_bImmunity         = GetConVarBool(g_hImmunity);
	g_iAttacksLimit     = GetConVarInt(g_hAttacksLimit);
	g_iBansLimit        = GetConVarInt(g_hBansLimit);
	g_iBanTime          = GetConVarInt(g_hBanTime);
	g_iBanType          = GetConVarInt(g_hBanType);
	g_iKarmaLimit       = GetConVarInt(g_hKarmaLimit);
	g_iKicksLimit       = GetConVarInt(g_hKicksLimit);
	g_iKillKarma        = GetConVarInt(g_hKillKarma);
	g_iKillsLimit       = GetConVarInt(g_hKillsLimit);
	g_iSpawnPunishDelay = GetConVarInt(g_hSpawnPunishDelay);
}

public OnClientAuthorized(client, const String:auth[])
{
	// Reset client variables
	g_hSpawnPunishment[client] = INVALID_HANDLE;
	g_iAttacks[client]         =
	g_iBans[client]            =
	g_iKarma[client]           =
	g_iKicks[client]           =
	g_iKills[client]           = 0;
	
	LoadClient(client);
}

public OnClientDisconnect(client)
{
	SaveClient(client);
}

public ConVarChanged_ConVars(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar      == g_hEnabled)
		g_bEnabled          = bool:StringToInt(newValue);
	else if(convar == g_hIgnoreBots)
		g_bIgnoreBots       = bool:StringToInt(newValue);
	else if(convar == g_hImmunity)
		g_bImmunity         = bool:StringToInt(newValue);
	else if(convar == g_hAttacksLimit)
		g_iAttacksLimit     = StringToInt(newValue);
	else if(convar == g_hBansLimit)
		g_iBansLimit        = StringToInt(newValue);
	else if(convar == g_hBanTime)
		g_iBanTime          = StringToInt(newValue);
	else if(convar == g_hBanType)
		g_iBanType          = StringToInt(newValue);
	else if(convar == g_hKarmaLimit)
		g_iKarmaLimit       = StringToInt(newValue);
	else if(convar == g_hKicksLimit)
		g_iKicksLimit       = StringToInt(newValue);
	else if(convar == g_hKillKarma)
		g_iKillKarma        = StringToInt(newValue);
	else if(convar == g_hKillsLimit)
		g_iKillsLimit       = StringToInt(newValue);
	else if(convar == g_hSpawnPunishDelay)
		g_iSpawnPunishDelay = StringToInt(newValue);
}


/**
 * Commands
 */
public Action:Command_KarmaHelp(client, args)
{
	if(!g_bEnabled || !client)
		return Plugin_Handled;
	
	decl String:sExit[32], String:sLine1[256], String:sLine2[256], String:sLine3[256], String:sTitle[256];
	Format(sTitle, sizeof(sTitle), "%T",    "Karma Help Title", client);
	Format(sLine1, sizeof(sLine1), "%T",    "Karma Help 1",     client);
	Format(sLine2, sizeof(sLine2), "%T",    "Karma Help 2",     client, g_iKarmaLimit);
	Format(sLine3, sizeof(sLine3), "%T",    "Karma Help 3",     client, g_iKarma[client]);
	Format(sExit,  sizeof(sExit),  "0. %T", "Exit",             client);
	
	new Handle:hPanel = CreatePanel();
	SetPanelTitle(hPanel, sTitle);
	DrawPanelText(hPanel, " ");
	DrawPanelText(hPanel, sLine1);
	DrawPanelText(hPanel, " ");
	DrawPanelText(hPanel, sLine2);
	DrawPanelText(hPanel, " ");
	DrawPanelText(hPanel, sLine3);
	DrawPanelText(hPanel, " ");
	DrawPanelText(hPanel, sExit);
	SendPanelToClient(hPanel, client, MenuHandler_DoNothing, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Action:Command_TKStatus(client, args)
{
	if(!g_bEnabled || !client)
		return Plugin_Handled;
	
	decl iTarget, String:sTarget[MAX_NAME_LENGTH + 1];
	if(GetCmdArgString(sTarget, sizeof(sTarget)))
	{
		if((iTarget = FindTarget(client, sTarget)) == -1)
			return Plugin_Handled;
	}
	else
		iTarget = client;
	
	decl String:sAttacks[255], String:sBans[255], String:sExit[32], String:sKarma[255], String:sKicks[255], String:sKills[255], String:sName[MAX_NAME_LENGTH + 1], String:sTitle[255];
	GetClientName(client, sName, sizeof(sName));
	Format(sTitle,   sizeof(sTitle),   "%T",    "TK Status Title", client, iTarget);
	Format(sKarma,   sizeof(sKarma),   "%T",    "Karma Count",     client, g_iKarma[iTarget],   g_iKarmaLimit);
	Format(sAttacks, sizeof(sAttacks), "%T",    "Attacks Count",   client, g_iAttacks[iTarget], g_iAttacksLimit);
	Format(sKills,   sizeof(sKills),   "%T",    "Kills Count",     client, g_iKills[iTarget],   g_iKillsLimit);
	Format(sKicks,   sizeof(sKicks),   "%T",    "Kicks Count",     client, g_iKicks[iTarget],   g_iKicksLimit);
	Format(sBans,    sizeof(sBans),    "%T",    "Bans Count",      client, g_iBans[iTarget],    g_iBansLimit);
	Format(sExit,    sizeof(sExit),    "0. %T", "Exit",            client);
	
	new Handle:hPanel = CreatePanel();
	SetPanelTitle(hPanel, sTitle);
	DrawPanelText(hPanel, " ");
	DrawPanelText(hPanel, sKarma);
	DrawPanelText(hPanel, sAttacks);
	DrawPanelText(hPanel, sKills);
	DrawPanelText(hPanel, sKicks);
	DrawPanelText(hPanel, sBans);
	DrawPanelText(hPanel, " ");
	DrawPanelText(hPanel, sExit);
	SendPanelToClient(hPanel, client, MenuHandler_DoNothing, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}


/**
 * Events
 */
public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iAttacker = GetClientOfUserId(GetEventInt(event, "attacker")),
			iVictim   = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// If ATAC is disabled, there is no team kill limit, attacker is the world or it was self-damage, ignore
	if(!g_bEnabled   || !g_iKillsLimit || !iAttacker || iAttacker == iVictim)
		return;
	// If ignoring bots is enabled, and attacker or victim is a bot, ignore
	if(g_bIgnoreBots && (IsFakeClient(iAttacker) || IsFakeClient(iVictim)))
		return;
	
	// If it was not a team attack
	if(GetClientTeam(iAttacker) != GetClientTeam(iVictim))
	{
		// Handle karma for kills
		decl String:sReason[256];
		Format(sReason, sizeof(sReason), "%T", "Killing Enemy", iAttacker);
		ATAC_GiveKarma(iAttacker, g_iKillKarma, sReason);
		return;
	}
	
	PrintToChat(iVictim, "%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "You Were Killed", iAttacker);
	
	// If immunity is enabled, and attacker has custom6 or root flag, ignore
	if(g_bImmunity   && GetUserFlagBits(iAttacker) & (ADMFLAG_CUSTOM6|ADMFLAG_ROOT))
		return;
	
	decl String:sForgive[32], String:sPunish[32];
	Format(sForgive, sizeof(sForgive), "%T", "Forgive",        iVictim);
	Format(sPunish,  sizeof(sPunish),  "%T", "Do Not Forgive", iVictim);
	g_iAttacker[iVictim] = GetClientUserId(iAttacker);
	
	// Create punishment menu
	new Handle:hMenu     = CreateMenu(MenuHandler_Punishment);
	SetMenuExitButton(hMenu, false);
	SetMenuTitle(hMenu,      "[ATAC] %T", "You Were Killed", iVictim, iAttacker);
	AddMenuItem(hMenu,       "Forgive",   sForgive);
	AddMenuItem(hMenu,       "Punish",    sPunish);
	
	// If immunity is disabled, or victim can target attacker, add punishments
	if(!g_bImmunity  || CanAdminTarget(GetUserAdmin(iVictim), GetUserAdmin(iAttacker)))
	{
		decl String:sPunishment[32];
		for(new i = 0, iSize = GetArraySize(g_hPunishments); i < iSize; i++)
		{
			// If callback is invalid, remove punishment
			if(g_fPunishmentCallbacks[i] == INVALID_FUNCTION)
			{
				RemoveFromArray(g_hPunishments, i);
				continue;
			}
			
			GetArrayString(g_hPunishments, i, sPunishment, sizeof(sPunishment));
			AddMenuItem(hMenu, sPunishment, sPunishment);
		}
	}
	
	DisplayMenu(hMenu, iVictim, MENU_TIME_FOREVER);
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iAttacker = GetClientOfUserId(GetEventInt(event, "attacker")),
			iVictim   = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// If ATAC is disabled, there is no team attack limit, attacker is the world, it was self-damage or it was not a team attack, ignore
	if(!g_bEnabled   || !g_iAttacksLimit || !iAttacker || iAttacker == iVictim || GetClientTeam(iAttacker) != GetClientTeam(iVictim))
		return;
	// If ignoring bots is enabled, and attacker or victim is a bot, ignore
	if(g_bIgnoreBots && (IsFakeClient(iAttacker) || IsFakeClient(iVictim)))
		return;
	// If immunity is enabled and attacker is immune, ignore
	if(g_bImmunity   && GetUserFlagBits(iAttacker) & (ADMFLAG_CUSTOM6|ADMFLAG_ROOT))
		return;
	
	g_iAttacks[iAttacker]++;
	PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Attacks", iAttacker, g_iAttacks[iAttacker], g_iAttacksLimit);
	
	if(g_iAttacks[iAttacker] < g_iAttacksLimit)
		return;
	
	g_iAttacks[iAttacker] = 0;
	g_iKills[iAttacker]++;
	PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Kills",   iAttacker, g_iKills[iAttacker],   g_iKillsLimit);
	
	if(g_iKills[iAttacker]   < g_iKillsLimit)
		return;
	
	if(g_iKicksLimit)
	{
		g_iKills[iAttacker] = 0;
		if(++g_iKicks[iAttacker] >= g_iKicksLimit && g_iBansLimit)
		{
			decl String:sReason[256];
			Format(sReason, sizeof(sReason), "[ATAC] %t", "Ban Reason", iAttacker);
			
			g_iKicks[iAttacker] = 0;
			if(++g_iBans[iAttacker] >= g_iBansLimit)
			{
				g_iBans[iAttacker] = 0;
				//BanClient(iAttacker, 0,          g_iBanType == IP_BAN_TYPE ? BANFLAG_IP : BANFLAG_AUTHID, sReason, sReason, "atac");
				ServerCommand("sm_ban #%d %d \"%s\"", GetClientUserId(iAttacker), 0,          sReason);
			}
			else
				//BanClient(iAttacker, g_iBanTime, g_iBanType == IP_BAN_TYPE ? BANFLAG_IP : BANFLAG_AUTHID, sReason, sReason, "atac");
				ServerCommand("sm_ban #%d %d \"%s\"", GetClientUserId(iAttacker), g_iBanTime, sReason);
		}
		else
			KickClient(iAttacker, "[ATAC] %t", "You Were Kicked");
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_hSpawnPunishment[iClient])
		CreateTimer(g_iSpawnPunishDelay * 1.0, Timer_SpawnPunishment, iClient);
}


/**
 * Menu Handlers
 */
public MenuHandler_DoNothing(Handle:menu, MenuAction:action, param1, param2) {}

public MenuHandler_Punishment(Handle:menu, MenuAction:action, param1, param2)
{
	// If there was no item selected, ignore
	if(action != MenuAction_Select)
		return;
	
	decl String:sPunishment[32];
	GetMenuItem(menu, param2, sPunishment, sizeof(sPunishment));
	
	new iAttacker       = GetClientOfUserId(g_iAttacker[param1]),
			iPunishment     = FindStringInArray(g_hPunishments, sPunishment);
	g_iAttacker[param1] = -1;
	
	// If attacker or punishment is invalid, ignore
	if(!iAttacker || iPunishment == -1)
		return;
	
	// If forgiven
	if(StrEqual(sPunishment,      "Forgive"))
	{
		LogPlayerEvent(iAttacker, "triggered", "Forgiven_For_TeamKill");
		LogAction(param1, iAttacker, "\"%L\" forgave \"%L\" for team killing",    param1, iAttacker);
		
		PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Forgiven",     param1,    iAttacker);
	}
	// If not forgiven
	else if(StrEqual(sPunishment, "Punish"))
	{
		LogPlayerEvent(iAttacker, "triggered", "Punished_For_TeamKill");
		LogAction(param1, iAttacker, "\"%L\" punished \"%L\" for team killing",   param1, iAttacker);
		
		PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Not Forgiven", iAttacker, g_iKills[iAttacker], g_iKillsLimit);
	}
	// If punished
	else
	{
		decl String:sProperties[64];
		Format(sProperties, sizeof(sProperties), " (punishment \"%s\")", sPunishment);
		
		LogPlayerEvent(iAttacker, "triggered", "Punished_For_TeamKill", false, sProperties);
		LogAction(param1, iAttacker, "\"%L\" punished \"%L\" for team killing%s", param1, iAttacker, sProperties);
		
		// If attacker is alive, punish now
		if(IsPlayerAlive(iAttacker))
			PunishPlayer(iPunishment, param1, iAttacker);
		// Otherwise, punish on next spawn
		else
		{
			g_hSpawnPunishment[iAttacker] = CreateDataPack();
			WritePackCell(g_hSpawnPunishment[iAttacker],   param1);
			WritePackString(g_hSpawnPunishment[iAttacker], sPunishment);
		}
	}
}


/**
 * Timers
 */
public Action:Timer_SpawnPunishment(Handle:timer, any:client)
{
	ResetPack(g_hSpawnPunishment[client]);
	decl String:sPunishment[32];
	new iVictim = ReadPackCell(g_hSpawnPunishment[client]);
	ReadPackString(g_hSpawnPunishment[client], sPunishment, sizeof(sPunishment));
	
	CloseHandle(g_hSpawnPunishment[client]);
	g_hSpawnPunishment[client] = INVALID_HANDLE;
	
	new iPunishment = FindStringInArray(g_hPunishments, sPunishment);
	if(iPunishment != -1)
		PunishPlayer(iPunishment, iVictim, client);
}


/**
 * Natives
 */
public Native_GetInfo(Handle:plugin, numParams)
{
	new iClient = GetNativeCell(1);
	
	switch(GetNativeCell(2))
	{
		case AtacInfo_Attacks:
			return g_iAttacks[iClient];
		case AtacInfo_Bans:
			return g_iBans[iClient];
		case AtacInfo_Karma:
			return g_iKarma[iClient];
		case AtacInfo_Kicks:
			return g_iKicks[iClient];
		case AtacInfo_Kills:
			return g_iKills[iClient];
	}
	
	return -1;
}

public Native_GetSetting(Handle:plugin, numParams)
{
	switch(GetNativeCell(1))
	{
		case AtacSetting_AttacksLimit:
			return g_iAttacksLimit;
		case AtacSetting_BansLimit:
			return g_iBansLimit;
		case AtacSetting_BanTime:
			return g_iBanTime;
		case AtacSetting_BanType:
			return g_iBanType;
		case AtacSetting_Enabled:
			return g_bEnabled;
		case AtacSetting_IgnoreBots:
			return g_bIgnoreBots;
		case AtacSetting_Immunity:
			return g_bImmunity;
		case AtacSetting_KarmaLimit:
			return g_iKarmaLimit;
		case AtacSetting_KicksLimit:
			return g_iKicksLimit;
		case AtacSetting_KillKarma:
			return g_iKillKarma;
		case AtacSetting_KillsLimit:
			return g_iKillsLimit;
	}
	
	return -1;
}

public Native_GiveKarma(Handle:plugin, numParams)
{
	new iClient = GetNativeCell(1),
			iKarma  = GetNativeCell(2);
	
	if(!g_iKarmaLimit || !iKarma || !g_iKills[iClient])
		return;
	
	g_iKarma[iClient] += iKarma;
	if(g_iKarma[iClient] > g_iKarmaLimit)
		g_iKarma[iClient] = g_iKarmaLimit;
	
	decl String:sReason[32];
	GetNativeString(3, sReason, sizeof(sReason));
	
	if(sReason[0])
		PrintToChat(iClient, "%c[ATAC]%c %t %s", CLR_GREEN, CLR_DEFAULT, "Earned Karma", g_iKarma[iClient], g_iKarmaLimit, sReason);
	if(g_iKarma[iClient] < g_iKarmaLimit)
		return;
	
	g_iKarma[iClient] = 0;
	g_iKills[iClient]--;
	PrintToChat(iClient, "%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Now Have Kills",  g_iKills[iClient], g_iKillsLimit);
}

public Native_RegisterPunishment(Handle:plugin, numParams)
{
	decl String:sName[32];
	GetNativeString(1, sName, sizeof(sName));
	
	new iPunishment = FindStringInArray(g_hPunishments, sName);
	if(iPunishment == -1)
		iPunishment = PushArrayString(g_hPunishments, sName);
	
	g_fPunishmentCallbacks[iPunishment] = Function:GetNativeCell(2);
	g_hPunishmentPlugins[iPunishment]   = plugin;
}

public Native_SetInfo(Handle:plugin, numParams)
{
	new iClient = GetNativeCell(1),
			iValue  = GetNativeCell(3);
	
	switch(GetNativeCell(2))
	{
		case AtacInfo_Attacks:
			g_iAttacks[iClient] = iValue;
		case AtacInfo_Bans:
			g_iBans[iClient]    = iValue;
		case AtacInfo_Karma:
			g_iKarma[iClient]   = iValue;
		case AtacInfo_Kicks:
			g_iKicks[iClient]   = iValue;
		case AtacInfo_Kills:
			g_iKills[iClient]   = iValue;
	}
	
	SaveClient(iClient);
}


/**
 * Stocks
 */
LoadClient(client)
{
	if(!g_hSQLiteDB)
		return;
	
	// Query local table
	decl String:sAuth[20], String:sIp[15], String:sQuery[256];
	GetClientAuthString(client, sAuth, sizeof(sAuth));
	GetClientIP(client,         sIp,   sizeof(sIp));
	Format(sQuery, sizeof(sQuery), "SELECT attacks, kills, kicks, bans, karma \
																	FROM   atac \
																	WHERE  identity = '%s' \
																	   OR  identity = '%s'",
																	sAuth, sIp);
	
	new Handle:hQuery = SQL_Query(g_hSQLiteDB, sQuery);
	if(!hQuery || !SQL_FetchRow(hQuery))
		return;
	
	// Store counts
	g_iAttacks[client] = SQL_FetchInt(hQuery, 0);
	g_iBans[client]    = SQL_FetchInt(hQuery, 3);
	g_iKarma[client]   = SQL_FetchInt(hQuery, 4);
	g_iKicks[client]   = SQL_FetchInt(hQuery, 2);
	g_iKills[client]   = SQL_FetchInt(hQuery, 1);
}

PunishPlayer(punishment, victim, attacker)
{
	Call_StartFunction(g_hPunishmentPlugins[punishment], g_fPunishmentCallbacks[punishment]);
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_Finish();
}

SaveClient(client)
{
	if(!g_hSQLiteDB)
		return;
	
	decl String:sIdentity[20], String:sQuery[256];
	if(!GetClientAuthString(client, sIdentity, sizeof(sIdentity)))
		GetClientIP(client, sIdentity, sizeof(sIdentity));
	
	Format(sQuery, sizeof(sQuery), "INSERT INTO atac (identity, attacks, kills, kicks, bans, karma, time) \
																	VALUES ('%s', %i, %i, %i, %i, %i, %i)",
																	sIdentity, g_iAttacks[client], g_iKills[client], g_iKicks[client], g_iBans[client], g_iKarma[client], GetTime());
	SQL_FastQuery(g_hSQLiteDB, sQuery);
}