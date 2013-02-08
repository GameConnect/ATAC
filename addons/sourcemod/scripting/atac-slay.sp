#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <atac>

public Plugin:myinfo =
{
	name        = "ATAC - Slay Punishment",
	author      = "GameConnect",
	description = "Advanced Team Attack Control",
	version     = ATAC_VERSION,
	url         = "http://www.gameconnect.net"
};


/**
 * Plugin Forwards
 */
public OnPluginStart()
{
	// Load translations
	LoadTranslations("atac-slay.phrases");
	
	if(LibraryExists("atac"))
		OnLibraryAdded("atac");
}

public OnLibraryAdded(const String:name[])
{
	if(!StrEqual(name, "atac"))
		return;
	
	decl String:sName[32];
	Format(sName, sizeof(sName), "%T", "Slay", LANG_SERVER);
	ATAC_RegisterPunishment(sName, AtacPunishment_Slay);
}


/**
 * ATAC Punishments
 */
public AtacPunishment_Slay(victim, attacker)
{
	PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Slayed", attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));
	
	ForcePlayerSuicide(attacker);
}