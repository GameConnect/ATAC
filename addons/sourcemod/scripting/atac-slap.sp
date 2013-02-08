#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <atac>

public Plugin:myinfo =
{
	name        = "ATAC - Slap Punishment",
	author      = "GameConnect",
	description = "Advanced Team Attack Control",
	version     = ATAC_VERSION,
	url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
new Handle:g_hDamage;


/**
 * Plugin Forwards
 */
public OnPluginStart()
{
	// Create convars
	g_hDamage = CreateConVar("atac_slap_damage", "50", "ATAC Slap Damage", FCVAR_PLUGIN);
	
	// Load translations
	LoadTranslations("atac-slap.phrases");
	
	if(LibraryExists("atac"))
		OnLibraryAdded("atac");
}

public OnLibraryAdded(const String:name[])
{
	if(!StrEqual(name, "atac"))
		return;
	
	decl String:sName[32];
	Format(sName, sizeof(sName), "%T", "Slap", LANG_SERVER);
	ATAC_RegisterPunishment(sName, AtacPunishment_Slap);
}


/**
 * ATAC Punishments
 */
public AtacPunishment_Slap(victim, attacker)
{
	PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Slapped", attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));
	
	SlapPlayer(attacker, GetConVarInt(g_hDamage));
}