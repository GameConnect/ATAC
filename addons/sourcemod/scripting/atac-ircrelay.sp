#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <atac>
#include <ircrelay>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
    name        = "ATAC - IRC Relay Module",
    author      = "GameConnect",
    description = "Advanced Team Attack Control",
    version     = ATAC_VERSION,
    url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
ConVar g_hXsGetAttacks;
ConVar g_hXsGetBans;
ConVar g_hXsGetKarma;
ConVar g_hXsGetKicks;
ConVar g_hXsGetKills;
ConVar g_hXsSetAttacks;
ConVar g_hXsSetBans;
ConVar g_hXsSetKarma;
ConVar g_hXsSetKicks;
ConVar g_hXsSetKills;
ConVar g_hXsTKStatus;


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    // Create convars
    g_hXsGetAttacks = CreateConVar("atac_xs_getattacks", "",  "Access level needed for getattacks command");
    g_hXsGetBans    = CreateConVar("atac_xs_getbans",    "",  "Access level needed for getbans command");
    g_hXsGetKarma   = CreateConVar("atac_xs_getkarma",   "",  "Access level needed for getkarma command");
    g_hXsGetKicks   = CreateConVar("atac_xs_getkicks",   "",  "Access level needed for getkicks command");
    g_hXsGetKills   = CreateConVar("atac_xs_getkills",   "",  "Access level needed for getkills command");
    g_hXsSetAttacks = CreateConVar("atac_xs_setattacks", "o", "Access level needed for setattacks command");
    g_hXsSetBans    = CreateConVar("atac_xs_setbans",    "o", "Access level needed for setbans command");
    g_hXsSetKarma   = CreateConVar("atac_xs_setkarma",   "o", "Access level needed for setkarma command");
    g_hXsSetKicks   = CreateConVar("atac_xs_setkicks",   "o", "Access level needed for setkicks command");
    g_hXsSetKills   = CreateConVar("atac_xs_setkills",   "o", "Access level needed for setkills command");
    g_hXsTKStatus   = CreateConVar("atac_xs_tkstatus",   "",  "Access level needed for tkstatus command");

    // Hook convar changes
    g_hXsGetAttacks.AddChangeHook(ConVarChanged_ConVars);
    g_hXsGetBans.AddChangeHook(ConVarChanged_ConVars);
    g_hXsGetKarma.AddChangeHook(ConVarChanged_ConVars);
    g_hXsGetKicks.AddChangeHook(ConVarChanged_ConVars);
    g_hXsGetKills.AddChangeHook(ConVarChanged_ConVars);
    g_hXsSetAttacks.AddChangeHook(ConVarChanged_ConVars);
    g_hXsSetBans.AddChangeHook(ConVarChanged_ConVars);
    g_hXsSetKarma.AddChangeHook(ConVarChanged_ConVars);
    g_hXsSetKicks.AddChangeHook(ConVarChanged_ConVars);
    g_hXsSetKills.AddChangeHook(ConVarChanged_ConVars);
    g_hXsTKStatus.AddChangeHook(ConVarChanged_ConVars);

    // Load translations
    LoadTranslations("common.phrases");
    LoadTranslations("atac-ircrelay.phrases");

    if (LibraryExists("ircrelay")) {
        OnLibraryAdded("ircrelay");
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (!StrEqual(name, "ircrelay")) {
        return;
    }

    char sXsGetAttacks[2], sXsGetBans[2], sXsGetKarma[2], sXsGetKicks[2], sXsGetKills[2],
         sXsSetAttacks[2], sXsSetBans[2], sXsSetKarma[2], sXsSetKicks[2], sXsSetKills[2], sXsTKStatus[2];
    g_hXsGetAttacks.GetString(sXsGetAttacks, sizeof(sXsGetAttacks));
    g_hXsGetBans.GetString(sXsGetBans,       sizeof(sXsGetBans));
    g_hXsGetKarma.GetString(sXsGetKarma,     sizeof(sXsGetKarma));
    g_hXsGetKicks.GetString(sXsGetKicks,     sizeof(sXsGetKicks));
    g_hXsGetKills.GetString(sXsGetKills,     sizeof(sXsGetKills));
    g_hXsSetAttacks.GetString(sXsSetAttacks, sizeof(sXsSetAttacks));
    g_hXsSetBans.GetString(sXsSetBans,       sizeof(sXsSetBans));
    g_hXsSetKarma.GetString(sXsSetKarma,     sizeof(sXsSetKarma));
    g_hXsSetKicks.GetString(sXsSetKicks,     sizeof(sXsSetKicks));
    g_hXsSetKills.GetString(sXsSetKills,     sizeof(sXsSetKills));
    g_hXsTKStatus.GetString(sXsTKStatus,     sizeof(sXsTKStatus));

    IRC_RegisterCommand("getattacks", IrcCommand_GetAttacks, IRC_GetAccess(sXsGetAttacks));
    IRC_RegisterCommand("getbans",    IrcCommand_GetBans,    IRC_GetAccess(sXsGetBans));
    IRC_RegisterCommand("getkarma",   IrcCommand_GetKarma,   IRC_GetAccess(sXsGetKarma));
    IRC_RegisterCommand("getkicks",   IrcCommand_GetKicks,   IRC_GetAccess(sXsGetKicks));
    IRC_RegisterCommand("getkills",   IrcCommand_GetKills,   IRC_GetAccess(sXsGetKills));
    IRC_RegisterCommand("setattacks", IrcCommand_SetAttacks, IRC_GetAccess(sXsSetAttacks));
    IRC_RegisterCommand("setbans",    IrcCommand_SetBans,    IRC_GetAccess(sXsSetBans));
    IRC_RegisterCommand("setkarma",   IrcCommand_SetKarma,   IRC_GetAccess(sXsSetKarma));
    IRC_RegisterCommand("setkicks",   IrcCommand_SetKicks,   IRC_GetAccess(sXsSetKicks));
    IRC_RegisterCommand("setkills",   IrcCommand_SetKills,   IRC_GetAccess(sXsSetKills));
    IRC_RegisterCommand("tkstatus",   IrcCommand_TKStatus,   IRC_GetAccess(sXsTKStatus));
}

public void ConVarChanged_ConVars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    OnLibraryAdded("ircrelay");
}


/**
 * IRC Commands
 */
public void IrcCommand_GetAttacks(const char[] channel, const char[] name, const char[] arg)
{
    int iTarget = FindTarget(0, arg);
    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    char sName[MAX_NAME_LENGTH + 1];
    IRC_GetClientName(iTarget, sName, sizeof(sName));

    IRC_PrivMsg(channel, "[ATAC] %t", "IRC TA Count", sName, ATAC_GetInfo(iTarget, AtacInfo_Attacks), ATAC_GetSetting(AtacSetting_AttacksLimit));
}

public void IrcCommand_GetBans(const char[] channel, const char[] name, const char[] arg)
{
    int iTarget = FindTarget(0, arg);
    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    char sName[MAX_NAME_LENGTH + 1];
    IRC_GetClientName(iTarget, sName, sizeof(sName));

    IRC_PrivMsg(channel, "[ATAC] %t", "IRC Ban Count", sName, ATAC_GetInfo(iTarget, AtacInfo_Bans), ATAC_GetSetting(AtacSetting_BansLimit));
}

public void IrcCommand_GetKarma(const char[] channel, const char[] name, const char[] arg)
{
    int iTarget = FindTarget(0, arg);
    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    char sName[MAX_NAME_LENGTH + 1];
    IRC_GetClientName(iTarget, sName, sizeof(sName));

    IRC_PrivMsg(channel, "[ATAC] %t", "IRC Karma Count", sName, ATAC_GetInfo(iTarget, AtacInfo_Karma), ATAC_GetSetting(AtacSetting_KarmaLimit));
}

public void IrcCommand_GetKicks(const char[] channel, const char[] name, const char[] arg)
{
    int iTarget = FindTarget(0, arg);
    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    char sName[MAX_NAME_LENGTH + 1];
    IRC_GetClientName(iTarget, sName, sizeof(sName));

    IRC_PrivMsg(channel, "[ATAC] %t", "IRC Kick Count", sName, ATAC_GetInfo(iTarget, AtacInfo_Kicks), ATAC_GetSetting(AtacSetting_KicksLimit));
}

public void IrcCommand_GetKills(const char[] channel, const char[] name, const char[] arg)
{
    int iTarget = FindTarget(0, arg);
    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    char sName[MAX_NAME_LENGTH + 1];
    IRC_GetClientName(iTarget, sName, sizeof(sName));

    IRC_PrivMsg(channel, "[ATAC] %t", "IRC TK Count", sName, ATAC_GetInfo(iTarget, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));
}

public void IrcCommand_SetAttacks(const char[] channel, const char[] name, const char[] arg)
{
    char sName[MAX_NAME_LENGTH + 1], sTarget[MAX_NAME_LENGTH + 1];
    int iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
        iTarget = FindTarget(0, sTarget);

    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    IRC_GetClientName(iTarget, sName, sizeof(sName));

    ATAC_SetInfo(iTarget, AtacInfo_Attacks, StringToInt(arg[iLen]));
    IRC_PrivMsg(channel, "[ATAC] %t", "IRC Set TA", sName, StringToInt(arg[iLen]), ATAC_GetSetting(AtacSetting_AttacksLimit));
}

public void IrcCommand_SetBans(const char[] channel, const char[] name, const char[] arg)
{
    char sName[MAX_NAME_LENGTH + 1], sTarget[MAX_NAME_LENGTH + 1];
    int iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
        iTarget = FindTarget(0, sTarget);

    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    IRC_GetClientName(iTarget, sName, sizeof(sName));

    ATAC_SetInfo(iTarget, AtacInfo_Bans, StringToInt(arg[iLen]));
    IRC_PrivMsg(channel, "[ATAC] %t", "IRC Set Bans", sName, StringToInt(arg[iLen]), ATAC_GetSetting(AtacSetting_BansLimit));
}

public void IrcCommand_SetKarma(const char[] channel, const char[] name, const char[] arg)
{
    char sName[MAX_NAME_LENGTH + 1], sTarget[MAX_NAME_LENGTH + 1];
    int iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
        iTarget = FindTarget(0, sTarget);

    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    IRC_GetClientName(iTarget, sName, sizeof(sName));

    ATAC_SetInfo(iTarget, AtacInfo_Karma, StringToInt(arg[iLen]));
    IRC_PrivMsg(channel, "[ATAC] %t", "IRC Set Karma", sName, StringToInt(arg[iLen]), ATAC_GetSetting(AtacSetting_KarmaLimit));
}

public void IrcCommand_SetKicks(const char[] channel, const char[] name, const char[] arg)
{
    char sName[MAX_NAME_LENGTH + 1], sTarget[MAX_NAME_LENGTH + 1];
    int iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
        iTarget = FindTarget(0, sTarget);

    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    IRC_GetClientName(iTarget, sName, sizeof(sName));

    ATAC_SetInfo(iTarget, AtacInfo_Kicks, StringToInt(arg[iLen]));
    IRC_PrivMsg(channel, "[ATAC] %t", "IRC Set Kicks", sName, StringToInt(arg[iLen]), ATAC_GetSetting(AtacSetting_KicksLimit));
}

public void IrcCommand_SetKills(const char[] channel, const char[] name, const char[] arg)
{
    char sName[MAX_NAME_LENGTH + 1], sTarget[MAX_NAME_LENGTH + 1];
    int iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
        iTarget = FindTarget(0, sTarget);

    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    IRC_GetClientName(iTarget, sName, sizeof(sName));

    ATAC_SetInfo(iTarget, AtacInfo_Kills, StringToInt(arg[iLen]));
    IRC_PrivMsg(channel, "[ATAC] %t", "IRC Set TK", sName, StringToInt(arg[iLen]), ATAC_GetSetting(AtacSetting_KillsLimit));
}

public void IrcCommand_TKStatus(const char[] channel, const char[] name, const char[] arg)
{
    int iTarget = FindTarget(0, arg);
    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    char sName[MAX_NAME_LENGTH + 1];
    IRC_GetClientName(iTarget, sName, sizeof(sName));

    IRC_PrivMsg(channel, "[ATAC] %T", "IRC TK Status Title", LANG_SERVER, sName);
    IRC_PrivMsg(channel, "[ATAC] %T", "IRC Karma Count",     LANG_SERVER, sName, ATAC_GetInfo(iTarget, AtacInfo_Karma),   ATAC_GetSetting(AtacSetting_KarmaLimit));
    IRC_PrivMsg(channel, "[ATAC] %T", "IRC TA Count",        LANG_SERVER, sName, ATAC_GetInfo(iTarget, AtacInfo_Attacks), ATAC_GetSetting(AtacSetting_AttacksLimit));
    IRC_PrivMsg(channel, "[ATAC] %T", "IRC TK Count",        LANG_SERVER, sName, ATAC_GetInfo(iTarget, AtacInfo_Kills),   ATAC_GetSetting(AtacSetting_KillsLimit));
    IRC_PrivMsg(channel, "[ATAC] %T", "IRC Kick Count",      LANG_SERVER, sName, ATAC_GetInfo(iTarget, AtacInfo_Kicks),   ATAC_GetSetting(AtacSetting_KicksLimit));
    IRC_PrivMsg(channel, "[ATAC] %T", "IRC Ban Count",       LANG_SERVER, sName, ATAC_GetInfo(iTarget, AtacInfo_Bans),    ATAC_GetSetting(AtacSetting_BansLimit));
}
