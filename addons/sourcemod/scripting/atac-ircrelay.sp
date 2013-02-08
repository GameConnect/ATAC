#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <atac>
#include <ircrelay>

public Plugin:myinfo =
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
new Handle:g_hXsGetAttacks;
new Handle:g_hXsGetBans;
new Handle:g_hXsGetKarma;
new Handle:g_hXsGetKicks;
new Handle:g_hXsGetKills;
new Handle:g_hXsSetAttacks;
new Handle:g_hXsSetBans;
new Handle:g_hXsSetKarma;
new Handle:g_hXsSetKicks;
new Handle:g_hXsSetKills;
new Handle:g_hXsTKStatus;


/**
 * Plugin Forwards
 */
public OnPluginStart()
{
	// Create convars
	g_hXsGetAttacks = CreateConVar("atac_xs_getattacks", "",  "Access level needed for getattacks command", FCVAR_PLUGIN);
	g_hXsGetBans    = CreateConVar("atac_xs_getbans",    "",  "Access level needed for getbans command",    FCVAR_PLUGIN);
	g_hXsGetKarma   = CreateConVar("atac_xs_getkarma",   "",  "Access level needed for getkarma command",   FCVAR_PLUGIN);
	g_hXsGetKicks   = CreateConVar("atac_xs_getkicks",   "",  "Access level needed for getkicks command",   FCVAR_PLUGIN);
	g_hXsGetKills   = CreateConVar("atac_xs_getkills",   "",  "Access level needed for getkills command",   FCVAR_PLUGIN);
	g_hXsSetAttacks = CreateConVar("atac_xs_setattacks", "o", "Access level needed for setattacks command", FCVAR_PLUGIN);
	g_hXsSetBans    = CreateConVar("atac_xs_setbans",    "o", "Access level needed for setbans command",    FCVAR_PLUGIN);
	g_hXsSetKarma   = CreateConVar("atac_xs_setkarma",   "o", "Access level needed for setkarma command",   FCVAR_PLUGIN);
	g_hXsSetKicks   = CreateConVar("atac_xs_setkicks",   "o", "Access level needed for setkicks command",   FCVAR_PLUGIN);
	g_hXsSetKills   = CreateConVar("atac_xs_setkills",   "o", "Access level needed for setkills command",   FCVAR_PLUGIN);
	g_hXsTKStatus   = CreateConVar("atac_xs_tkstatus",   "",  "Access level needed for tkstatus command",   FCVAR_PLUGIN);
	
	// Hook convar changes
	HookConVarChange(g_hXsGetAttacks, ConVarChanged_ConVars);
	HookConVarChange(g_hXsGetBans,    ConVarChanged_ConVars);
	HookConVarChange(g_hXsGetKarma,   ConVarChanged_ConVars);
	HookConVarChange(g_hXsGetKicks,   ConVarChanged_ConVars);
	HookConVarChange(g_hXsGetKills,   ConVarChanged_ConVars);
	HookConVarChange(g_hXsSetAttacks, ConVarChanged_ConVars);
	HookConVarChange(g_hXsSetBans,    ConVarChanged_ConVars);
	HookConVarChange(g_hXsSetKarma,   ConVarChanged_ConVars);
	HookConVarChange(g_hXsSetKicks,   ConVarChanged_ConVars);
	HookConVarChange(g_hXsSetKills,   ConVarChanged_ConVars);
	HookConVarChange(g_hXsTKStatus,   ConVarChanged_ConVars);
	
	// Load translations
	LoadTranslations("common.phrases");
	LoadTranslations("atac-ircrelay.phrases");
	
	if(LibraryExists("ircrelay"))
		OnLibraryAdded("ircrelay");
}

public OnLibraryAdded(const String:name[])
{
	if(!StrEqual(name, "ircrelay"))
		return;
	
	decl String:sXsGetAttacks[2], String:sXsGetBans[2], String:sXsGetKarma[2], String:sXsGetKicks[2], String:sXsGetKills[2],
	     String:sXsSetAttacks[2], String:sXsSetBans[2], String:sXsSetKarma[2], String:sXsSetKicks[2], String:sXsSetKills[2], String:sXsTKStatus[2];
	GetConVarString(g_hXsGetAttacks, sXsGetAttacks, sizeof(sXsGetAttacks));
	GetConVarString(g_hXsGetBans,    sXsGetBans,    sizeof(sXsGetBans));
	GetConVarString(g_hXsGetKarma,   sXsGetKarma,   sizeof(sXsGetKarma));
	GetConVarString(g_hXsGetKicks,   sXsGetKicks,   sizeof(sXsGetKicks));
	GetConVarString(g_hXsGetKills,   sXsGetKills,   sizeof(sXsGetKills));
	GetConVarString(g_hXsSetAttacks, sXsSetAttacks, sizeof(sXsSetAttacks));
	GetConVarString(g_hXsSetBans,    sXsSetBans,    sizeof(sXsSetBans));
	GetConVarString(g_hXsSetKarma,   sXsSetKarma,   sizeof(sXsSetKarma));
	GetConVarString(g_hXsSetKicks,   sXsSetKicks,   sizeof(sXsSetKicks));
	GetConVarString(g_hXsSetKills,   sXsSetKills,   sizeof(sXsSetKills));
	GetConVarString(g_hXsTKStatus,   sXsTKStatus,   sizeof(sXsTKStatus));
	
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

public ConVarChanged_ConVars(Handle:convar, const String:oldValue[], const String:newValue[])
{
	OnLibraryAdded("ircrelay");
}


/**
 * IRC Commands
 */
public IrcCommand_GetAttacks(const String:channel[], const String:name[], const String:arg[])
{
	new iTarget = FindTarget(0, arg);
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	IRC_PrivMsg(channel, "[ATAC] %t", "IRC TA Count", sName, ATAC_GetInfo(iTarget, AtacInfo_Attacks), ATAC_GetSetting(AtacSetting_AttacksLimit));
}

public IrcCommand_GetBans(const String:channel[], const String:name[], const String:arg[])
{
	new iTarget = FindTarget(0, arg);
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	IRC_PrivMsg(channel, "[ATAC] %t", "IRC Ban Count", sName, ATAC_GetInfo(iTarget, AtacInfo_Bans), ATAC_GetSetting(AtacSetting_BansLimit));
}

public IrcCommand_GetKarma(const String:channel[], const String:name[], const String:arg[])
{
	new iTarget = FindTarget(0, arg);
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	IRC_PrivMsg(channel, "[ATAC] %t", "IRC Karma Count", sName, ATAC_GetInfo(iTarget, AtacInfo_Karma), ATAC_GetSetting(AtacSetting_KarmaLimit));
}

public IrcCommand_GetKicks(const String:channel[], const String:name[], const String:arg[])
{
	new iTarget = FindTarget(0, arg);
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	IRC_PrivMsg(channel, "[ATAC] %t", "IRC Kick Count", sName, ATAC_GetInfo(iTarget, AtacInfo_Kicks), ATAC_GetSetting(AtacSetting_KicksLimit));
}

public IrcCommand_GetKills(const String:channel[], const String:name[], const String:arg[])
{
	new iTarget = FindTarget(0, arg);
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	IRC_PrivMsg(channel, "[ATAC] %t", "IRC TK Count", sName, ATAC_GetInfo(iTarget, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));
}

public IrcCommand_SetAttacks(const String:channel[], const String:name[], const String:arg[])
{
	decl String:sTarget[MAX_NAME_LENGTH + 1];
	new iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
			iTarget = FindTarget(0, sTarget);
	
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	ATAC_SetInfo(iTarget, AtacInfo_Attacks, StringToInt(arg[iLen]));
	IRC_PrivMsg(channel, "[ATAC] %t", "IRC Set TA", sName, StringToInt(arg[iLen]), ATAC_GetSetting(AtacSetting_AttacksLimit));
}

public IrcCommand_SetBans(const String:channel[], const String:name[], const String:arg[])
{
	decl String:sTarget[MAX_NAME_LENGTH + 1];
	new iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
			iTarget = FindTarget(0, sTarget);
	
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	ATAC_SetInfo(iTarget, AtacInfo_Bans, StringToInt(arg[iLen]));
	IRC_PrivMsg(channel, "[ATAC] %t", "IRC Set Bans", sName, StringToInt(arg[iLen]), ATAC_GetSetting(AtacSetting_BansLimit));
}

public IrcCommand_SetKarma(const String:channel[], const String:name[], const String:arg[])
{
	decl String:sTarget[MAX_NAME_LENGTH + 1];
	new iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
			iTarget = FindTarget(0, sTarget);
	
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	ATAC_SetInfo(iTarget, AtacInfo_Karma, StringToInt(arg[iLen]));
	IRC_PrivMsg(channel, "[ATAC] %t", "IRC Set Karma", sName, StringToInt(arg[iLen]), ATAC_GetSetting(AtacSetting_KarmaLimit));
}

public IrcCommand_SetKicks(const String:channel[], const String:name[], const String:arg[])
{
	decl String:sTarget[MAX_NAME_LENGTH + 1];
	new iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
			iTarget = FindTarget(0, sTarget);
	
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	ATAC_SetInfo(iTarget, AtacInfo_Kicks, StringToInt(arg[iLen]));
	IRC_PrivMsg(channel, "[ATAC] %t", "IRC Set Kicks", sName, StringToInt(arg[iLen]), ATAC_GetSetting(AtacSetting_KicksLimit));
}

public IrcCommand_SetKills(const String:channel[], const String:name[], const String:arg[])
{
	decl String:sTarget[MAX_NAME_LENGTH + 1];
	new iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
			iTarget = FindTarget(0, sTarget);
	
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	ATAC_SetInfo(iTarget, AtacInfo_Kills, StringToInt(arg[iLen]));
	IRC_PrivMsg(channel, "[ATAC] %t", "IRC Set TK", sName, StringToInt(arg[iLen]), ATAC_GetSetting(AtacSetting_KillsLimit));
}

public IrcCommand_TKStatus(const String:channel[], const String:name[], const String:arg[])
{
	new iTarget = FindTarget(0, arg);
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	IRC_PrivMsg(channel, "[ATAC] %T", "IRC TK Status Title", LANG_SERVER, sName);
	IRC_PrivMsg(channel, "[ATAC] %T", "IRC Karma Count",     LANG_SERVER, sName, ATAC_GetInfo(iTarget, AtacInfo_Karma),   ATAC_GetSetting(AtacSetting_KarmaLimit));
	IRC_PrivMsg(channel, "[ATAC] %T", "IRC TA Count",        LANG_SERVER, sName, ATAC_GetInfo(iTarget, AtacInfo_Attacks), ATAC_GetSetting(AtacSetting_AttacksLimit));
	IRC_PrivMsg(channel, "[ATAC] %T", "IRC TK Count",        LANG_SERVER, sName, ATAC_GetInfo(iTarget, AtacInfo_Kills),   ATAC_GetSetting(AtacSetting_KillsLimit));
	IRC_PrivMsg(channel, "[ATAC] %T", "IRC Kick Count",      LANG_SERVER, sName, ATAC_GetInfo(iTarget, AtacInfo_Kicks),   ATAC_GetSetting(AtacSetting_KicksLimit));
	IRC_PrivMsg(channel, "[ATAC] %T", "IRC Ban Count",       LANG_SERVER, sName, ATAC_GetInfo(iTarget, AtacInfo_Bans),    ATAC_GetSetting(AtacSetting_BansLimit));
}