#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <atac>

public Plugin:myinfo =
{
	name        = "ATAC - Drug Punishment",
	author      = "GameConnect",
	description = "Advanced Team Attack Control",
	version     = ATAC_VERSION,
	url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
new Float:g_flDrugAngles[] = {0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 20.0, 15.0, 10.0, 5.0, 0.0, -5.0, -10.0, -15.0, -20.0, -25.0, -20.0, -15.0, -10.0, -5.0};


/**
 * Plugin Forwards
 */
public OnPluginStart()
{
	// Load translations
	LoadTranslations("atac-drug.phrases");
	
	if(LibraryExists("atac"))
		OnLibraryAdded("atac");
}

public OnLibraryAdded(const String:name[])
{
	if(!StrEqual(name, "atac"))
		return;
	
	decl String:sName[32];
	Format(sName, sizeof(sName), "%T", "Drug", LANG_SERVER);
	ATAC_RegisterPunishment(sName, AtacPunishment_Drug);
}


/**
 * ATAC Punishments
 */
public AtacPunishment_Drug(victim, attacker)
{
	PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Drugged", attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));
	
	CreateTimer(1.0, Timer_Drug, attacker, TIMER_REPEAT);
}


/**
 * Timers
 */
public Action:Timer_Drug(Handle:timer, any:client)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;
	
	decl Float:flAngles[3], Float:flPos[3];
	GetClientEyeAngles(client, flAngles);
	GetClientAbsOrigin(client, flPos);
	
	flAngles[2] = g_flDrugAngles[GetRandomInt(0, 100) % sizeof(g_flDrugAngles)];
	
	TeleportEntity(client, flPos, flAngles, NULL_VECTOR);
	
	new Handle:hMessage = StartMessageOne("Fade", client);
	BfWriteShort(hMessage, 255);
	BfWriteShort(hMessage, 255);
	BfWriteShort(hMessage, (0x0002));
	BfWriteByte(hMessage,  GetRandomInt(0, 255));
	BfWriteByte(hMessage,  GetRandomInt(0, 255));
	BfWriteByte(hMessage,  GetRandomInt(0, 255));
	BfWriteByte(hMessage,  128);
	EndMessage();	
	
	return Plugin_Continue;
}