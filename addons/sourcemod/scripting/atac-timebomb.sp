#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <atac>

#pragma newdecls required
#pragma semicolon 1

#define SOUND_BEEP	"buttons/button17.wav"
#define SOUND_BOOM	"weapons/explode3.wav"
#define SOUND_FINAL	"weapons/cguard/charging.wav"

public Plugin myinfo =
{
    name        = "ATAC - TimeBomb Punishment",
    author      = "GameConnect",
    description = "Advanced Team Attack Control",
    version     = ATAC_VERSION,
    url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
int g_iBeamSprite;
int g_iExplosionSprite;
int g_iTimeBombTime[MAXPLAYERS + 1];
int g_iGreyColor[4]  = {128, 128, 128, 255};
int g_iHaloSprite;
int g_iWhiteColor[4] = {255, 255, 255, 255};
ConVar g_hTicks;


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    // Create convars
    g_hTicks = CreateConVar("atac_timebomb_ticks", "10", "ATAC TimeBomb Ticks");

    // Load translations
    LoadTranslations("atac-timebomb.phrases");

    if (LibraryExists("atac")) {
        OnLibraryAdded("atac");
    }
}

public void OnMapStart()
{
    g_iBeamSprite      = PrecacheModel("materials/sprites/laser.vmt");
    g_iExplosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");
    g_iHaloSprite      = PrecacheModel("materials/sprites/halo01.vmt");

    PrecacheSound(SOUND_BEEP,  true);
    PrecacheSound(SOUND_BOOM,  true);
    PrecacheSound(SOUND_FINAL, true);
}

public void OnLibraryAdded(const char[] name)
{
    if (!StrEqual(name, "atac")) {
        return;
    }

    char sName[32];
    Format(sName, sizeof(sName), "%T", "TimeBomb", LANG_SERVER);
    ATAC_RegisterPunishment(sName, AtacPunishment_TimeBomb);
}


/**
 * ATAC Punishments
 */
public void AtacPunishment_TimeBomb(int victim, int attacker)
{
    PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "TimeBombed", attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));

    g_iTimeBombTime[attacker] = g_hTicks.IntValue;
    CreateTimer(1.0, Timer_TimeBomb, attacker, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}


/**
 * Timers
 */
public Action Timer_TimeBomb(Handle timer, any client)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
        return Plugin_Stop;
    }

    float flPos[3];
    GetClientEyePosition(client, flPos);

    if (--g_iTimeBombTime[client]) {
        int iColor = 0;
        if (g_iTimeBombTime[client] == 1) {
            EmitAmbientSound(SOUND_FINAL, flPos, client, SNDLEVEL_RAIDSIREN);
        } else {
            iColor = RoundToFloor(g_iTimeBombTime[client] * (255.0 / g_hTicks.IntValue));
            EmitAmbientSound(SOUND_BEEP,  flPos, client, SNDLEVEL_RAIDSIREN);
        }

        SetEntityRenderColor(client, 255, iColor, iColor, 255);
        PrintCenterTextAll("%t", "Till Explodes", g_iTimeBombTime[client], client);

        GetClientAbsOrigin(client, flPos);
        flPos[2] += 10;

        TE_SetupBeamRingPoint(flPos, 10.0, 200.0, g_iBeamSprite, g_iHaloSprite, 0, 15, 0.5, 5.0,  0.0, g_iGreyColor,  10, 0);
        TE_SendToAll();
        TE_SetupBeamRingPoint(flPos, 10.0, 200.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.6, 10.0, 0.5, g_iWhiteColor, 10, 0);
        TE_SendToAll();

        return Plugin_Continue;
    } else {
        TE_SetupExplosion(flPos, g_iExplosionSprite, 0.1, 1, 0, 600, 5000);
        TE_SendToAll();

        EmitAmbientSound(SOUND_BOOM, flPos, client, SNDLEVEL_RAIDSIREN);

        ForcePlayerSuicide(client);
        SetEntityRenderColor(client, 255, 255, 255, 255);

        return Plugin_Stop;
    }
}
