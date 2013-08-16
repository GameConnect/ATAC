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
	
	new iDuration = 255;
	new iHoldTime = 255;
	new iFlags    = 0x0002;
	new iColor[4] = {0, 0, 0, 128};
	iColor[0]     = GetRandomInt(0, 255);
	iColor[1]     = GetRandomInt(0, 255);
	iColor[2]     = GetRandomInt(0, 255);
	
	new Handle:hMessage = StartMessageOne("Fade", client);
	if(GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(hMessage,   "duration",  iDuration);
		PbSetInt(hMessage,   "hold_time", iHoldTime);
		PbSetInt(hMessage,   "flags",     iFlags);
		PbSetColor(hMessage, "clr",       iColor);
	}
	else
	{
		BfWriteShort(hMessage, iDuration);
		BfWriteShort(hMessage, iHoldTime);
		BfWriteShort(hMessage, iFlags);
		BfWriteByte(hMessage,  iColor[0]);
		BfWriteByte(hMessage,  iColor[1]);
		BfWriteByte(hMessage,  iColor[2]);
		BfWriteByte(hMessage,  iColor[3]);
	}
	EndMessage();	
	
	return Plugin_Continue;
}