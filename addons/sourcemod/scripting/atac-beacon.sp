#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <atac>

#pragma newdecls required
#pragma semicolon 1

#define SOUND_BLIP "buttons/blip1.wav"

public Plugin myinfo =
{
    name        = "ATAC - Beacon Punishment",
    author      = "GameConnect",
    description = "Advanced Team Attack Control",
    version     = ATAC_VERSION,
    url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
int g_iBeamSprite;
int g_iBlueColor[4]  = { 75,  75, 255, 255};
int g_iGreenColor[4] = { 75, 255,  75, 255};
int g_iGreyColor[4]  = {128, 128, 128, 255};
int g_iHaloSprite;
int g_iRedColor[4]   = {255,  75,  75, 255};
ConVar g_hRadius;


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    // Create convars
    g_hRadius = CreateConVar("atac_beacon_radius", "375", "ATAC Beacon Radius");

    // Load translations
    LoadTranslations("atac-beacon.phrases");

    if (LibraryExists("atac")) {
        OnLibraryAdded("atac");
    }
}

public void OnMapStart()
{
    g_iBeamSprite = PrecacheModel("materials/sprites/laser.vmt");
    g_iHaloSprite = PrecacheModel("materials/sprites/halo01.vmt");

    PrecacheSound(SOUND_BLIP, true);
}

public void OnLibraryAdded(const char[] name)
{
    if (!StrEqual(name, "atac")) {
        return;
    }

    char sName[32];
    Format(sName, sizeof(sName), "%T", "Beacon", LANG_SERVER);
    ATAC_RegisterPunishment(sName, AtacPunishment_Beacon);
}


/**
 * ATAC Punishments
 */
public void AtacPunishment_Beacon(int victim, int attacker)
{
    PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Beaconed", attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));

    CreateTimer(1.0, Timer_Beacon, attacker, TIMER_REPEAT);
}


/**
 * Timers
 */
public Action Timer_Beacon(Handle timer, any client)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
        return Plugin_Stop;
    }

    float flPos[3];
    GetClientAbsOrigin(client, flPos);
    flPos[2] += 10;

    float flRadius = g_hRadius.FloatValue;
    TE_SetupBeamRingPoint(flPos, 10.0, flRadius, g_iBeamSprite, g_iHaloSprite, 0, 15, 0.5, 5.0, 0.0, g_iGreyColor, 10, 0);
    TE_SendToAll();

    switch (GetClientTeam(client)) {
        case 2:
            TE_SetupBeamRingPoint(flPos, 10.0, flRadius, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.6, 10.0, 0.5, g_iRedColor,   10, 0);
        case 3:
            TE_SetupBeamRingPoint(flPos, 10.0, flRadius, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.6, 10.0, 0.5, g_iBlueColor,  10, 0);
        default:
            TE_SetupBeamRingPoint(flPos, 10.0, flRadius, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.6, 10.0, 0.5, g_iGreenColor, 10, 0);
    }

    TE_SendToAll();

    GetClientEyePosition(client, flPos);
    EmitAmbientSound(SOUND_BLIP, flPos, client, SNDLEVEL_RAIDSIREN);

    return Plugin_Continue;
}
