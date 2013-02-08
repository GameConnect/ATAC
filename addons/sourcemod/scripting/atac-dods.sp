#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <atac>

public Plugin:myinfo =
{
	name        = "ATAC - Day of Defeat: Source Module",
	author      = "GameConnect",
	description = "Advanced Team Attack Control",
	version     = ATAC_VERSION,
	url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
new g_iExplosionModel;
new g_iLightningModel;
new g_iSmokeModel;
new g_iSpawnTime[MAXPLAYERS + 1];
new Handle:g_hBombDefusedKarma;
new Handle:g_hBombExplodedKarma;
new Handle:g_hBombPlantedKarma;
new Handle:g_hCaptureBlockedKarma;
new Handle:g_hHealDamage;
new Handle:g_hKillDefuserKarma;
new Handle:g_hKillPlanterKarma;
new Handle:g_hMirrorDamage;
new Handle:g_hMirrorDamageSlap;
new Handle:g_hPointCaptureKarma;
new Handle:g_hRoundWinKarma;
new Handle:g_hSpawnProtectTime;


/**
 * Plugin Forwards
 */
public OnPluginStart()
{
	decl String:sGameDir[64];
	GetGameFolderName(sGameDir, sizeof(sGameDir));
	if(!StrEqual(sGameDir, "dod"))
		SetFailState("This plugin only works on Day of Defeat: Source.");
	
	// Create convars
	g_hBombDefusedKarma    = CreateConVar("atac_bombdefused_karma",    "2",  "ATAC Bomb Defused Karma",    FCVAR_PLUGIN);
	g_hBombExplodedKarma   = CreateConVar("atac_bombexploded_karma",   "2",  "ATAC Bomb Exploded Karma",   FCVAR_PLUGIN);
	g_hBombPlantedKarma    = CreateConVar("atac_bombplanted_karma",    "1",  "ATAC Bomb Planted Karma",    FCVAR_PLUGIN);
	g_hCaptureBlockedKarma = CreateConVar("atac_captureblocked_karma", "2",  "ATAC Capture Blocked Karma", FCVAR_PLUGIN);
	g_hHealDamage          = CreateConVar("atac_heal_damage",          "0",  "ATAC Heal Damage",           FCVAR_PLUGIN);
	g_hKillDefuserKarma    = CreateConVar("atac_killdefuser_karma",    "1",  "ATAC Kill Defuser Karma",    FCVAR_PLUGIN);
	g_hKillPlanterKarma    = CreateConVar("atac_killplanter_karma",    "1",  "ATAC Kill Planter Karma",    FCVAR_PLUGIN);
	g_hMirrorDamage        = CreateConVar("atac_mirrordamage",         "1",  "ATAC Mirror Damage",         FCVAR_PLUGIN);
	g_hMirrorDamageSlap    = CreateConVar("atac_mirrordamage_slap",    "0",  "ATAC Mirror Damage Slap",    FCVAR_PLUGIN);
	g_hPointCaptureKarma   = CreateConVar("atac_pointcapture_karma",   "3",  "ATAC Point Capture Karma",   FCVAR_PLUGIN);
	g_hRoundWinKarma       = CreateConVar("atac_roundwin_karma",       "2",  "ATAC Round Win Karma",       FCVAR_PLUGIN);
	g_hSpawnProtectTime    = CreateConVar("atac_spawnprotect_time",    "10", "ATAC Spawn Protect Time",    FCVAR_PLUGIN);
	
	// Hook events
	HookEvent("dod_bomb_planted",    Event_BombPlanted);
	HookEvent("dod_bomb_exploded",   Event_BombExploded);
	HookEvent("dod_bomb_defused",    Event_BombDefused);
	HookEvent("dod_capture_blocked", Event_CaptureBlocked);
	HookEvent("dod_kill_defuser",    Event_KillDefuser);
	HookEvent("dod_kill_planter",    Event_KillPlanter);
	HookEvent("player_hurt",         Event_PlayerHurt);
	HookEvent("player_spawn",        Event_PlayerSpawn);
	HookEvent("dod_point_captured",  Event_PointCaptured);
	HookEvent("dod_round_win",       Event_RoundWin);
	
	// Load translations
	LoadTranslations("atac-dods.phrases");
}

public OnMapStart()
{
	g_iExplosionModel = PrecacheModel("materials/effects/fire_cloud1.vmt");
	g_iLightningModel = PrecacheModel("materials/sprites/tp_beam001.vmt");
	g_iSmokeModel     = PrecacheModel("materials/effects/fire_cloud2.vmt");
	
	PrecacheSound("ambient/explosions/explode_8.wav");
}


/**
 * Events
 */
public Event_BombDefused(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!ATAC_GetSetting(AtacSetting_Enabled))
		return;
	
	decl String:sReason[256];
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	
	Format(sReason, sizeof(sReason), "%T", "Defusing Bomb", iClient);
	ATAC_GiveKarma(iClient, GetConVarInt(g_hBombDefusedKarma), sReason);
}

public Event_BombExploded(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!ATAC_GetSetting(AtacSetting_Enabled))
		return;
	
	decl String:sReason[256];
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	
	Format(sReason, sizeof(sReason), "%T", "Detonating Bomb", iClient);
	ATAC_GiveKarma(iClient, GetConVarInt(g_hBombExplodedKarma), sReason);
}

public Event_BombPlanted(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!ATAC_GetSetting(AtacSetting_Enabled))
		return;
	
	decl String:sReason[256];
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	
	Format(sReason, sizeof(sReason), "%T", "Planting Bomb", iClient);
	ATAC_GiveKarma(iClient, GetConVarInt(g_hBombPlantedKarma), sReason);
}

public Event_CaptureBlocked(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!ATAC_GetSetting(AtacSetting_Enabled))
		return;
	
	decl String:sReason[256];
	new iClient = GetClientOfUserId(GetEventInt(event, "blocker"));
	
	Format(sReason, sizeof(sReason), "%T", "Blocking Capture", iClient);
	ATAC_GiveKarma(iClient, GetConVarInt(g_hCaptureBlockedKarma), sReason);
}

public Event_KillDefuser(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!ATAC_GetSetting(AtacSetting_Enabled))
		return;
	
	decl String:sReason[256];
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	
	Format(sReason, sizeof(sReason), "%T", "Killing Defuser", iClient);
	ATAC_GiveKarma(iClient, GetConVarInt(g_hKillDefuserKarma), sReason);
}

public Event_KillPlanter(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!ATAC_GetSetting(AtacSetting_Enabled))
		return;
	
	decl String:sReason[256];
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	
	Format(sReason, sizeof(sReason), "%T", "Killing Planter", iClient);
	ATAC_GiveKarma(iClient, GetConVarInt(g_hKillPlanterKarma), sReason);
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iAttacker = GetClientOfUserId(GetEventInt(event, "attacker")),
			iDamage   = GetEventInt(event, "damage"),
			iVictim   = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!ATAC_GetSetting(AtacSetting_Enabled)   || !iAttacker || iAttacker == iVictim || GetClientTeam(iAttacker) != GetClientTeam(iVictim))
		return;
	
	if(GetConVarBool(g_hHealDamage))
		SetEntityHealth(iVictim, GetClientHealth(iVictim) + iDamage);
	
	if(GetConVarBool(g_hMirrorDamage))
	{
		new iHealth = GetClientHealth(iAttacker) - iDamage;
		if(iHealth <= 0)
		{
			ForcePlayerSuicide(iAttacker);
			return;
		}
		if(GetConVarBool(g_hMirrorDamageSlap))
			SlapPlayer(iAttacker,      iDamage);
		else
			SetEntityHealth(iAttacker, iHealth);
	}
	
	// If ignoring bots is enabled, and attacker or victim is a bot, ignore
	if(ATAC_GetSetting(AtacSetting_IgnoreBots) && (IsFakeClient(iAttacker) || IsFakeClient(iVictim)))
		return;
	
	// If immunity is enabled, and attacker has custom6 or root flag, ignore
	if(ATAC_GetSetting(AtacSetting_Immunity)   && GetUserFlagBits(iAttacker) & (ADMFLAG_CUSTOM6|ADMFLAG_ROOT))
		return;
	
	// If spawn protection is disabled, or the spawn protection has expired, ignore
	new iProtectTime = GetConVarInt(g_hSpawnProtectTime);
	if(!iProtectTime || GetTime() - g_iSpawnTime[iVictim] > iProtectTime)
		return;
	
	PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Spawn Attacking", iAttacker, iVictim);
	SlayEffects(iAttacker);
	ForcePlayerSuicide(iAttacker);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_iSpawnTime[GetClientOfUserId(GetEventInt(event, "userid"))] = GetTime();
}

public Event_PointCaptured(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!ATAC_GetSetting(AtacSetting_Enabled) || GetEventBool(event, "bomb"))
		return;
	
	decl String:sCappers[256], String:sReason[256];
	new iKarma = GetConVarInt(g_hPointCaptureKarma);
	GetEventString(event, "cappers", sCappers, sizeof(sCappers));
	
	for(new i, iCappers = strlen(sCappers); i < iCappers; i++)
	{
		Format(sReason, sizeof(sReason), "%T", "Capturing Point", sCappers[i]);
		ATAC_GiveKarma(sCappers[i], iKarma, sReason);
	}
}

public Event_RoundWin(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!ATAC_GetSetting(AtacSetting_Enabled))
		return;
	
	decl String:sReason[256];
	new iKarma = GetConVarInt(g_hRoundWinKarma);
	
	for(new i = 1, iTeam = GetEventInt(event, "team"); i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != iTeam)
			continue;
		
		Format(sReason, sizeof(sReason), "%T", "Winning Round", i);
		ATAC_GiveKarma(i, iKarma, sReason);
	}
}


/**
 * Stocks
 */
stock SlayEffects(client)
{
	decl Float:flEnd[3], Float:flSparkDir[3], Float:flSparkPos[3], Float:flStart[3];
	// Get player position to use as the ending coordinates
	GetClientAbsOrigin(client, flEnd);
	
	// Set the starting coordinates
	flSparkDir     = flEnd;
	flSparkPos     = flEnd;
	flStart        = flEnd;
	
	flSparkDir[2] += 23;
	flSparkPos[2] += 13;
	flStart[2]    += 1000;
	
	// create lightning effects and sparks, and explosion
	TE_SetupBeamPoints(flStart, flEnd, g_iLightningModel, g_iLightningModel, 0, 1, 2.0, 5.0, 5.0, 1, 1.0, {255, 255, 255, 255}, 250);
	TE_SendToAll();
	
	TE_SetupExplosion(flEnd, g_iExplosionModel, 10.0, 10, TE_EXPLFLAG_NONE, 200, 255);
	TE_SendToAll();
	
	TE_SetupSmoke(flEnd,     g_iExplosionModel, 50.0, 2);
	TE_SendToAll();
	
	TE_SetupSmoke(flEnd,     g_iSmokeModel,     50.0, 2);
	TE_SendToAll();
	
	TE_SetupMetalSparks(flSparkPos, flSparkDir);
	TE_SendToAll();
	
	EmitAmbientSound("ambient/explosions/explode_8.wav", flEnd, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL, 0.0);
}