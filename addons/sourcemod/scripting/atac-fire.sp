#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <atac>

#define SOUND_BEEP	"buttons/button17.wav"
#define SOUND_BOOM	"weapons/explode3.wav"
#define SOUND_FINAL	"weapons/cguard/charging.wav"

public Plugin:myinfo =
{
	name        = "ATAC - Fire Punishment",
	author      = "GameConnect",
	description = "Advanced Team Attack Control",
	version     = ATAC_VERSION,
	url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
new g_iBeamSprite;
new g_iExplosionSprite;
new g_iFireBombTime[MAXPLAYERS + 1];
new g_iGreyColor[4]   = {128, 128, 128, 255};
new g_iHaloSprite;
new g_iOrangeColor[4] = {255, 128,   0, 255};
new g_iWhiteColor[4]  = {255, 255, 255, 255};
new Handle:g_hDuration;
new Handle:g_hTicks;


/**
 * Plugin Forwards
 */
public OnPluginStart()
{
	// Create convars
	g_hDuration = CreateConVar("atac_burn_duration",  "20.0", "ATAC Burn Duration",  FCVAR_PLUGIN);
	g_hTicks    = CreateConVar("atac_firebomb_ticks", "10",   "ATAC FireBomb Ticks", FCVAR_PLUGIN);
	
	// Load translations
	LoadTranslations("atac-fire.phrases");
	
	if(LibraryExists("atac"))
		OnLibraryAdded("atac");
}

public OnMapStart()
{
	g_iBeamSprite      = PrecacheModel("materials/sprites/laser.vmt");
	g_iExplosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");
	g_iHaloSprite      = PrecacheModel("materials/sprites/halo01.vmt");
	
	PrecacheSound(SOUND_BEEP,  true);
	PrecacheSound(SOUND_BOOM,  true);
	PrecacheSound(SOUND_FINAL, true);
}

public OnLibraryAdded(const String:name[])
{
	if(!StrEqual(name, "atac"))
		return;
	
	decl String:sName[32];
	Format(sName, sizeof(sName), "%T", "Burn",     LANG_SERVER);
	ATAC_RegisterPunishment(sName, AtacPunishment_Burn);
	
	Format(sName, sizeof(sName), "%T", "FireBomb", LANG_SERVER);
	ATAC_RegisterPunishment(sName, AtacPunishment_FireBomb);
}


/**
 * ATAC Punishments
 */
public AtacPunishment_Burn(victim, attacker)
{
	PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Burned",     attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));
	
	IgniteEntity(attacker, GetConVarFloat(g_hDuration));
}

public AtacPunishment_FireBomb(victim, attacker)
{
	PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "FireBombed", attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));
	
	g_iFireBombTime[attacker] = GetConVarInt(g_hTicks);
	CreateTimer(1.0, Timer_FireBomb, attacker, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}


/**
 * Timers
 */
public Action:Timer_FireBomb(Handle:timer, any:client)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;
	
	decl Float:flPos[3];
	GetClientEyePosition(client, flPos);
	
	if(--g_iFireBombTime[client])
	{
		new iColor = 0;
		if(g_iFireBombTime[client] == 1)
			EmitAmbientSound(SOUND_FINAL, flPos, client, SNDLEVEL_RAIDSIREN);
		else
		{
			iColor = RoundToFloor(g_iFireBombTime[client] * (255.0 / GetConVarInt(g_hTicks)));
			EmitAmbientSound(SOUND_BEEP,  flPos, client, SNDLEVEL_RAIDSIREN);	
		}
		
		SetEntityRenderColor(client, 255, iColor, iColor, 255);
		PrintCenterTextAll("%t", "Till Explodes", g_iFireBombTime[client], client);		
		
		GetClientAbsOrigin(client, flPos);
		flPos[2] += 10;
		
		TE_SetupBeamRingPoint(flPos, 10.0, 200.0, g_iBeamSprite, g_iHaloSprite, 0, 15, 0.5, 5.0,  0.0, g_iGreyColor,  10, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(flPos, 10.0, 200.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.6, 10.0, 0.5, g_iWhiteColor, 10, 0);
		TE_SendToAll();
		
		return Plugin_Continue;
	}
	else
	{
		TE_SetupExplosion(flPos, g_iExplosionSprite, 0.1, 1, 0, 600, 5000);
		TE_SendToAll();
		
		EmitAmbientSound(SOUND_BOOM, flPos, client, SNDLEVEL_RAIDSIREN);
		GetClientAbsOrigin(client, flPos);
		
		flPos[2] += 10;
		TE_SetupBeamRingPoint(flPos, 50.0, 600.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.5, 30.0, 1.5, g_iOrangeColor, 5, 0);
		TE_SendToAll();
		
		flPos[2] += 15;
		TE_SetupBeamRingPoint(flPos, 40.0, 600.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.6, 30.0, 1.5, g_iOrangeColor, 5, 0);
		TE_SendToAll();
		
		flPos[2] += 15;
		TE_SetupBeamRingPoint(flPos, 30.0, 600.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.7, 30.0, 1.5, g_iOrangeColor, 5, 0);
		TE_SendToAll();
		
		flPos[2] += 15;
		TE_SetupBeamRingPoint(flPos, 20.0, 600.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.8, 30.0, 1.5, g_iOrangeColor, 5, 0);
		TE_SendToAll();
		
		IgniteEntity(client, GetConVarFloat(g_hDuration));
		SetEntityRenderColor(client, 255, 255, 255, 255);
		
		return Plugin_Stop;
	}
}