#include <sourcemod>
#include <sdktools>
#include <loghelper>
#include <atac>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
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

int g_iAttacker[MAXPLAYERS + 1] = {-1};
int g_iAttacks[MAXPLAYERS + 1];
int g_iAttacksLimit;
int g_iBansLimit;
int g_iBanTime;
int g_iBanType;
int g_iBans[MAXPLAYERS + 1];
int g_iKarma[MAXPLAYERS + 1];
int g_iKarmaLimit;
int g_iKicks[MAXPLAYERS + 1];
int g_iKicksLimit;
int g_iKillKarma;
int g_iKills[MAXPLAYERS + 1];
int g_iKillsLimit;
int g_iSpawnPunishDelay;
bool g_bEnabled;
bool g_bIgnoreBots;
bool g_bImmunity;
Function g_fPunishmentCallbacks[64];
ConVar g_hAttacksLimit;
ConVar g_hBansLimit;
ConVar g_hBanTime;
ConVar g_hBanType;
ConVar g_hEnabled;
ConVar g_hIgnoreBots;
ConVar g_hImmunity;
ConVar g_hKarmaLimit;
ConVar g_hKicksLimit;
ConVar g_hKillKarma;
ConVar g_hKillsLimit;
Handle g_hPunishmentPlugins[64];
ArrayList g_hPunishments;
ConVar g_hSpawnPunishDelay;
DataPack g_hSpawnPunishment[MAXPLAYERS + 1];
Database g_hSQLiteDB;
Mod g_iMod = Mod_Default;


/**
 * Plugin Forwards
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("ATAC_GetInfo",            Native_GetInfo);
    CreateNative("ATAC_GetSetting",         Native_GetSetting);
    CreateNative("ATAC_GiveKarma",          Native_GiveKarma);
    CreateNative("ATAC_RegisterPunishment", Native_RegisterPunishment);
    CreateNative("ATAC_SetInfo",            Native_SetInfo);
    RegPluginLibrary("atac");

    return APLRes_Success;
}

public void OnPluginStart()
{
    // Create convars
    CreateConVar("atac_version", ATAC_VERSION, "Advanced Team Attack Control: Source", FCVAR_NOTIFY);
    g_hAttacksLimit     = CreateConVar("atac_attacks_limit",     "10", "ATAC Attacks Limit");
    g_hBansLimit        = CreateConVar("atac_bans_limit",        "3",  "ATAC Bans Limit");
    g_hBanTime          = CreateConVar("atac_ban_time",          "60", "ATAC Ban Time");
    g_hBanType          = CreateConVar("atac_ban_type",          "0",  "ATAC Ban Type");
    g_hEnabled          = CreateConVar("atac_enabled",           "1",  "ATAC Enabled");
    g_hIgnoreBots       = CreateConVar("atac_ignore_bots",       "1",  "ATAC Ignore Bots");
    g_hImmunity         = CreateConVar("atac_immunity",          "0",  "ATAC Immunity");
    g_hKarmaLimit       = CreateConVar("atac_karma_limit",       "5",  "ATAC Karma Limit");
    g_hKicksLimit       = CreateConVar("atac_kicks_limit",       "3",  "ATAC Kicks Limit");
    g_hKillKarma        = CreateConVar("atac_kill_karma",        "1",  "ATAC Kill Karma");
    g_hKillsLimit       = CreateConVar("atac_kills_limit",       "3",  "ATAC Kills Limit");
    g_hSpawnPunishDelay = CreateConVar("atac_spawnpunish_delay", "6",  "ATAC Spawn Punish Delay");

    // Hook convar changes
    g_hAttacksLimit.AddChangeHook(ConVarChanged_ConVars);
    g_hBansLimit.AddChangeHook(ConVarChanged_ConVars);
    g_hBanTime.AddChangeHook(ConVarChanged_ConVars);
    g_hBanType.AddChangeHook(ConVarChanged_ConVars);
    g_hEnabled.AddChangeHook(ConVarChanged_ConVars);
    g_hIgnoreBots.AddChangeHook(ConVarChanged_ConVars);
    g_hImmunity.AddChangeHook(ConVarChanged_ConVars);
    g_hKarmaLimit.AddChangeHook(ConVarChanged_ConVars);
    g_hKicksLimit.AddChangeHook(ConVarChanged_ConVars);
    g_hKillKarma.AddChangeHook(ConVarChanged_ConVars);
    g_hKillsLimit.AddChangeHook(ConVarChanged_ConVars);
    g_hSpawnPunishDelay.AddChangeHook(ConVarChanged_ConVars);

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
    g_hPunishments = new ArrayList(64);

    // Store mod
    char sBuffer[65];
    GetGameFolderName(sBuffer, sizeof(sBuffer));

    if (StrContains(sBuffer, "insurgency", false) != -1) {
        g_iMod = Mod_Insurgency;
    } else {
        GetGameDescription(sBuffer, sizeof(sBuffer));

        if (StrContains(sBuffer, "Insurgency", false) != -1) {
            g_iMod = Mod_Insurgency;
        }
    }

    AutoExecConfig(true, "atac");
}

public void OnMapStart()
{
    GetTeams(g_iMod == Mod_Insurgency);

    if (!g_hSQLiteDB) {
        // Connect to local database
        char sError[256] = "";
        g_hSQLiteDB      = SQLite_UseDatabase("sourcemod-local", sError, sizeof(sError));
        if (sError[0]) {
            LogError("%T (%s)", "Could not connect to database", LANG_SERVER, sError);
            return;
        }

        // Create local table
        SQL_FastQuery(g_hSQLiteDB, "CREATE TABLE IF NOT EXISTS atac (identity TEXT PRIMARY KEY ON CONFLICT REPLACE, attacks INTEGER, kills INTEGER, kicks INTEGER, bans INTEGER, karma INTEGER, time INTEGER)");
    }

    // Delete players that haven't played for two weeks
    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "DELETE FROM atac \
                                    WHERE       time + %i <= %i",
                                    60 * 60 * 24 * 7 * 2, GetTime());
    SQL_FastQuery(g_hSQLiteDB, sQuery);

    // Load client information on late load
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            LoadClient(i);
        }
    }
}

public void OnPluginEnd()
{
    // Save client information on unload
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            SaveClient(i);
        }
    }
}

public void OnConfigsExecuted()
{
    g_bEnabled          = g_hEnabled.BoolValue;
    g_bIgnoreBots       = g_hIgnoreBots.BoolValue;
    g_bImmunity         = g_hImmunity.BoolValue;
    g_iAttacksLimit     = g_hAttacksLimit.IntValue;
    g_iBansLimit        = g_hBansLimit.IntValue;
    g_iBanTime          = g_hBanTime.IntValue;
    g_iBanType          = g_hBanType.IntValue;
    g_iKarmaLimit       = g_hKarmaLimit.IntValue;
    g_iKicksLimit       = g_hKicksLimit.IntValue;
    g_iKillKarma        = g_hKillKarma.IntValue;
    g_iKillsLimit       = g_hKillsLimit.IntValue;
    g_iSpawnPunishDelay = g_hSpawnPunishDelay.IntValue;
}

public void OnClientAuthorized(int client, const char[] auth)
{
    // Reset client variables
    g_hSpawnPunishment[client] = null;
    g_iAttacks[client]         =
    g_iBans[client]            =
    g_iKarma[client]           =
    g_iKicks[client]           =
    g_iKills[client]           = 0;

    LoadClient(client);
}

public void OnClientDisconnect(int client)
{
    SaveClient(client);
}

public void ConVarChanged_ConVars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar      == g_hEnabled) {
        g_bEnabled          = view_as<bool>(StringToInt(newValue));
    }
    else if (convar == g_hIgnoreBots) {
        g_bIgnoreBots       = view_as<bool>(StringToInt(newValue));
    }
    else if (convar == g_hImmunity) {
        g_bImmunity         = view_as<bool>(StringToInt(newValue));
    }
    else if (convar == g_hAttacksLimit) {
        g_iAttacksLimit     = StringToInt(newValue);
    }
    else if (convar == g_hBansLimit) {
        g_iBansLimit        = StringToInt(newValue);
    }
    else if (convar == g_hBanTime) {
        g_iBanTime          = StringToInt(newValue);
    }
    else if (convar == g_hBanType) {
        g_iBanType          = StringToInt(newValue);
    }
    else if (convar == g_hKarmaLimit) {
        g_iKarmaLimit       = StringToInt(newValue);
    }
    else if (convar == g_hKicksLimit) {
        g_iKicksLimit       = StringToInt(newValue);
    }
    else if (convar == g_hKillKarma) {
        g_iKillKarma        = StringToInt(newValue);
    }
    else if (convar == g_hKillsLimit) {
        g_iKillsLimit       = StringToInt(newValue);
    }
    else if (convar == g_hSpawnPunishDelay) {
        g_iSpawnPunishDelay = StringToInt(newValue);
    }
}


/**
 * Commands
 */
public Action Command_KarmaHelp(int client, int args)
{
    if (!g_bEnabled || !client) {
        return Plugin_Handled;
    }

    char sExit[32], sLine1[256], sLine2[256], sLine3[256], sTitle[256];
    Format(sTitle, sizeof(sTitle), "%T",    "Karma Help Title", client);
    Format(sLine1, sizeof(sLine1), "%T",    "Karma Help 1",     client);
    Format(sLine2, sizeof(sLine2), "%T",    "Karma Help 2",     client, g_iKarmaLimit);
    Format(sLine3, sizeof(sLine3), "%T",    "Karma Help 3",     client, g_iKarma[client]);
    Format(sExit,  sizeof(sExit),  "0. %T", "Exit",             client);

    Panel hPanel = new Panel();
    hPanel.SetTitle(sTitle);
    hPanel.DrawText(" ");
    hPanel.DrawText(sLine1);
    hPanel.DrawText(" ");
    hPanel.DrawText(sLine2);
    hPanel.DrawText(" ");
    hPanel.DrawText(sLine3);
    hPanel.DrawText(" ");
    hPanel.DrawText(sExit);
    hPanel.Send(client, MenuHandler_DoNothing, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public Action Command_TKStatus(int client, int args)
{
    if (!g_bEnabled || !client) {
        return Plugin_Handled;
    }

    char sTarget[MAX_NAME_LENGTH + 1];
    int iTarget = client;
    if (GetCmdArgString(sTarget, sizeof(sTarget)) && (iTarget = FindTarget(client, sTarget)) == -1) {
        return Plugin_Handled;
    }

    char sAttacks[255], sBans[255], sExit[32], sKarma[255], sKicks[255], sKills[255], sName[MAX_NAME_LENGTH + 1], sTitle[255];
    GetClientName(client, sName, sizeof(sName));
    Format(sTitle,   sizeof(sTitle),   "%T",    "TK Status Title", client, iTarget);
    Format(sKarma,   sizeof(sKarma),   "%T",    "Karma Count",     client, g_iKarma[iTarget],   g_iKarmaLimit);
    Format(sAttacks, sizeof(sAttacks), "%T",    "Attacks Count",   client, g_iAttacks[iTarget], g_iAttacksLimit);
    Format(sKills,   sizeof(sKills),   "%T",    "Kills Count",     client, g_iKills[iTarget],   g_iKillsLimit);
    Format(sKicks,   sizeof(sKicks),   "%T",    "Kicks Count",     client, g_iKicks[iTarget],   g_iKicksLimit);
    Format(sBans,    sizeof(sBans),    "%T",    "Bans Count",      client, g_iBans[iTarget],    g_iBansLimit);
    Format(sExit,    sizeof(sExit),    "0. %T", "Exit",            client);

    Panel hPanel = new Panel();
    hPanel.SetTitle(sTitle);
    hPanel.DrawText(" ");
    hPanel.DrawText(sKarma);
    hPanel.DrawText(sAttacks);
    hPanel.DrawText(sKills);
    hPanel.DrawText(sKicks);
    hPanel.DrawText(sBans);
    hPanel.DrawText(" ");
    hPanel.DrawText(sExit);
    hPanel.Send(client, MenuHandler_DoNothing, MENU_TIME_FOREVER);

    return Plugin_Handled;
}


/**
 * Events
 */
public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
    int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker")),
        iVictim   = GetClientOfUserId(GetEventInt(event, "userid"));

    // If ATAC is disabled, there is no team kill limit, attacker is the world or it was self-damage, ignore
    if (!g_bEnabled   || !g_iKillsLimit || !iAttacker || iAttacker == iVictim) {
        return;
    }
    // If ignoring bots is enabled, and attacker or victim is a bot, ignore
    if (g_bIgnoreBots && (IsFakeClient(iAttacker) || IsFakeClient(iVictim))) {
        return;
    }

    // If it was not a team attack
    if (GetClientTeam(iAttacker) != GetClientTeam(iVictim)) {
        // Handle karma for kills
        char sReason[256];
        Format(sReason, sizeof(sReason), "%T", "Killing Enemy", iAttacker);
        ATAC_GiveKarma(iAttacker, g_iKillKarma, sReason);
        return;
    }

    PrintToChat(iVictim, "%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "You Were Killed", iAttacker);

    // If immunity is enabled, and attacker has custom6 or root flag, ignore
    if (g_bImmunity   && GetUserFlagBits(iAttacker) & (ADMFLAG_CUSTOM6|ADMFLAG_ROOT)) {
        return;
    }

    char sForgive[32], sPunish[32];
    Format(sForgive, sizeof(sForgive), "%T", "Forgive",        iVictim);
    Format(sPunish,  sizeof(sPunish),  "%T", "Do Not Forgive", iVictim);
    g_iAttacker[iVictim] = GetClientUserId(iAttacker);

    // Create punishment menu
    Menu hMenu       = new Menu(MenuHandler_Punishment);
    hMenu.ExitButton = false;
    hMenu.SetTitle("[ATAC] %T", "You Were Killed", iVictim, iAttacker);
    hMenu.AddItem("Forgive",   sForgive);
    hMenu.AddItem("Punish",    sPunish);

    // If immunity is disabled, or victim can target attacker, add punishments
    if (!g_bImmunity  || CanAdminTarget(GetUserAdmin(iVictim), GetUserAdmin(iAttacker))) {
        char sPunishment[32];
        for (int i = 0, iSize = g_hPunishments.Length; i < iSize; i++) {
            // If callback is invalid, remove punishment
            if (g_fPunishmentCallbacks[i] == INVALID_FUNCTION) {
                g_hPunishments.Erase(i);
                continue;
            }

            g_hPunishments.GetString(i, sPunishment, sizeof(sPunishment));
            hMenu.AddItem(sPunishment, sPunishment);
        }
    }

    hMenu.Display(iVictim, MENU_TIME_FOREVER);
}

public void Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
    int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker")),
        iVictim   = GetClientOfUserId(GetEventInt(event, "userid"));

    // If ATAC is disabled, there is no team attack limit, attacker is the world, it was self-damage or it was not a team attack, ignore
    if (!g_bEnabled   || !g_iAttacksLimit || !iAttacker || iAttacker == iVictim || GetClientTeam(iAttacker) != GetClientTeam(iVictim)) {
        return;
    }
    // If ignoring bots is enabled, and attacker or victim is a bot, ignore
    if (g_bIgnoreBots && (IsFakeClient(iAttacker) || IsFakeClient(iVictim))) {
        return;
    }
    // If immunity is enabled and attacker is immune, ignore
    if (g_bImmunity   && GetUserFlagBits(iAttacker) & (ADMFLAG_CUSTOM6|ADMFLAG_ROOT)) {
        return;
    }

    g_iAttacks[iAttacker]++;
    PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Attacks", iAttacker, g_iAttacks[iAttacker], g_iAttacksLimit);

    if (g_iAttacks[iAttacker] < g_iAttacksLimit) {
        return;
    }

    g_iAttacks[iAttacker] = 0;
    g_iKills[iAttacker]++;
    PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Kills",   iAttacker, g_iKills[iAttacker],   g_iKillsLimit);

    if (g_iKills[iAttacker]   < g_iKillsLimit) {
        return;
    }

    if (g_iKicksLimit) {
        g_iKills[iAttacker] = 0;
        if (++g_iKicks[iAttacker] >= g_iKicksLimit && g_iBansLimit) {
            char sReason[256];
            Format(sReason, sizeof(sReason), "[ATAC] %t", "Ban Reason", iAttacker);

            g_iKicks[iAttacker] = 0;
            if (++g_iBans[iAttacker] >= g_iBansLimit) {
                g_iBans[iAttacker] = 0;
                BanClient(iAttacker, 0,          g_iBanType == IP_BAN_TYPE ? BANFLAG_IP : BANFLAG_AUTHID, sReason, sReason, "atac");
            } else {
                BanClient(iAttacker, g_iBanTime, g_iBanType == IP_BAN_TYPE ? BANFLAG_IP : BANFLAG_AUTHID, sReason, sReason, "atac");
            }
        } else {
            KickClient(iAttacker, "[ATAC] %t", "You Were Kicked");
        }
    }
}

public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    if (g_hSpawnPunishment[iClient]) {
        CreateTimer(g_iSpawnPunishDelay * 1.0, Timer_SpawnPunishment, iClient);
    }
}


/**
 * Menu Handlers
 */
public int MenuHandler_DoNothing(Menu menu, MenuAction action, int param1, int param2) {}

public int MenuHandler_Punishment(Menu menu, MenuAction action, int param1, int param2)
{
    // If there was no item selected, ignore
    if (action != MenuAction_Select) {
        return;
    }

    char sPunishment[32];
    GetMenuItem(menu, param2, sPunishment, sizeof(sPunishment));

    int iAttacker       = GetClientOfUserId(g_iAttacker[param1]),
        iPunishment     = g_hPunishments.FindString(sPunishment);
    g_iAttacker[param1] = -1;

    // If attacker or punishment is invalid, ignore
    if (!iAttacker || iPunishment == -1) {
        return;
    }

    // If forgiven
    if (StrEqual(sPunishment,      "Forgive")) {
        LogPlayerEvent(iAttacker, "triggered", "Forgiven_For_TeamKill");
        LogAction(param1, iAttacker, "\"%L\" forgave \"%L\" for team killing",    param1, iAttacker);

        PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Forgiven",     param1,    iAttacker);
    }
    // If not forgiven
    else if (StrEqual(sPunishment, "Punish")) {
        LogPlayerEvent(iAttacker, "triggered", "Punished_For_TeamKill");
        LogAction(param1, iAttacker, "\"%L\" punished \"%L\" for team killing",   param1, iAttacker);

        PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Not Forgiven", iAttacker, g_iKills[iAttacker], g_iKillsLimit);
    }
    // If punished
    else {
        char sProperties[64];
        Format(sProperties, sizeof(sProperties), " (punishment \"%s\")", sPunishment);

        LogPlayerEvent(iAttacker, "triggered", "Punished_For_TeamKill", false, sProperties);
        LogAction(param1, iAttacker, "\"%L\" punished \"%L\" for team killing%s", param1, iAttacker, sProperties);

        // If attacker is alive, punish now
        if (IsPlayerAlive(iAttacker)) {
            PunishPlayer(iPunishment, param1, iAttacker);
        }
        // Otherwise, punish on next spawn
        else {
            g_hSpawnPunishment[iAttacker] = new DataPack();
            g_hSpawnPunishment[iAttacker].WriteCell(param1);
            g_hSpawnPunishment[iAttacker].WriteString(sPunishment);
        }
    }
}


/**
 * Timers
 */
public Action Timer_SpawnPunishment(Handle timer, any client)
{
    g_hSpawnPunishment[client].Reset();
    char sPunishment[32];
    int iVictim = g_hSpawnPunishment[client].ReadCell();
    g_hSpawnPunishment[client].ReadString(sPunishment, sizeof(sPunishment));

    delete g_hSpawnPunishment[client];

    int iPunishment = g_hPunishments.FindString(sPunishment);
    if (iPunishment != -1) {
        PunishPlayer(iPunishment, iVictim, client);
    }
}


/**
 * Natives
 */
public int Native_GetInfo(Handle plugin, int numParams)
{
    int iClient = GetNativeCell(1);

    switch (GetNativeCell(2)) {
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

public int Native_GetSetting(Handle plugin, int numParams)
{
    switch (GetNativeCell(1)) {
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

public int Native_GiveKarma(Handle plugin, int numParams)
{
    int iClient = GetNativeCell(1),
        iKarma  = GetNativeCell(2);

    if (!g_iKarmaLimit || !iKarma || !g_iKills[iClient]) {
        return;
    }

    g_iKarma[iClient] += iKarma;
    if (g_iKarma[iClient] > g_iKarmaLimit) {
        g_iKarma[iClient] = g_iKarmaLimit;
    }

    char sReason[32];
    GetNativeString(3, sReason, sizeof(sReason));

    if (sReason[0]) {
        PrintToChat(iClient, "%c[ATAC]%c %t %s", CLR_GREEN, CLR_DEFAULT, "Earned Karma", g_iKarma[iClient], g_iKarmaLimit, sReason);
    }
    if (g_iKarma[iClient] < g_iKarmaLimit) {
        return;
    }

    g_iKarma[iClient] = 0;
    g_iKills[iClient]--;
    PrintToChat(iClient, "%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Now Have Kills",  g_iKills[iClient], g_iKillsLimit);
}

public int Native_RegisterPunishment(Handle plugin, int numParams)
{
    char sName[32];
    GetNativeString(1, sName, sizeof(sName));

    int iPunishment = g_hPunishments.FindString(sName);
    if (iPunishment == -1) {
        iPunishment = g_hPunishments.PushString(sName);
    }

    g_fPunishmentCallbacks[iPunishment] = GetNativeFunction(2);
    g_hPunishmentPlugins[iPunishment]   = plugin;
}

public int Native_SetInfo(Handle plugin, int numParams)
{
    int iClient = GetNativeCell(1),
        iValue  = GetNativeCell(3);

    switch (GetNativeCell(2)) {
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
void LoadClient(int client)
{
    if (!g_hSQLiteDB) {
        return;
    }

    // Query local table
    char sAuth[20], sIp[15], sQuery[256];
    GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
    GetClientIP(client,                    sIp,   sizeof(sIp));
    Format(sQuery, sizeof(sQuery), "SELECT attacks, kills, kicks, bans, karma \
                                    FROM   atac \
                                    WHERE  identity = '%s' \
                                       OR  identity = '%s'",
                                    sAuth, sIp);

    DBResultSet hResults = SQL_Query(g_hSQLiteDB, sQuery);
    if (!hResults || !hResults.FetchRow()) {
        return;
    }

    // Store counts
    g_iAttacks[client] = hResults.FetchInt(0);
    g_iBans[client]    = hResults.FetchInt(3);
    g_iKarma[client]   = hResults.FetchInt(4);
    g_iKicks[client]   = hResults.FetchInt(2);
    g_iKills[client]   = hResults.FetchInt(1);
}

void PunishPlayer(int punishment, int victim, int attacker)
{
    Call_StartFunction(g_hPunishmentPlugins[punishment], g_fPunishmentCallbacks[punishment]);
    Call_PushCell(victim);
    Call_PushCell(attacker);
    Call_Finish();
}

void SaveClient(int client)
{
    if (!g_hSQLiteDB) {
        return;
    }

    char sIdentity[20], sQuery[256];
    if (!GetClientAuthId(client, AuthId_Steam2, sIdentity, sizeof(sIdentity))) {
        GetClientIP(client, sIdentity, sizeof(sIdentity));
    }

    Format(sQuery, sizeof(sQuery), "INSERT INTO atac (identity, attacks, kills, kicks, bans, karma, time) \
                                                                    VALUES ('%s', %i, %i, %i, %i, %i, %i)",
                                                                    sIdentity, g_iAttacks[client], g_iKills[client], g_iKicks[client], g_iBans[client], g_iKarma[client], GetTime());
    SQL_FastQuery(g_hSQLiteDB, sQuery);
}
