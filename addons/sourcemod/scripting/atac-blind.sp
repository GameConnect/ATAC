#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <atac>

public Plugin:myinfo =
{
	name        = "ATAC - Blind Punishment",
	author      = "GameConnect",
	description = "Advanced Team Attack Control",
	version     = ATAC_VERSION,
	url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
new Handle:g_hAmount;


/**
 * Plugin Forwards
 */
public OnPluginStart()
{
	// Create convars
	g_hAmount = CreateConVar("atac_blind_amount", "255", "ATAC Blind Amount", FCVAR_PLUGIN);
	
	// Load translations
	LoadTranslations("atac-blind.phrases");
	
	if(LibraryExists("atac"))
		OnLibraryAdded("atac");
}

public OnLibraryAdded(const String:name[])
{
	if(!StrEqual(name, "atac"))
		return;
	
	decl String:sName[32];
	Format(sName, sizeof(sName), "%T", "Blind", LANG_SERVER);
	ATAC_RegisterPunishment(sName, AtacPunishment_Blind);
}


/**
 * ATAC Punishments
 */
public AtacPunishment_Blind(victim, attacker)
{
	PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Blinded", attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));
	
	new iDuration = 1536;
	new iHoldTime = 1536;
	new iFlags    = (0x0002 | 0x0008);
	new iColor[4] = {0, 0, 0, 0};
	iColor[3]     = GetConVarInt(g_hAmount);
	
	new Handle:hMessage = StartMessageOne("Fade", attacker);
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
}