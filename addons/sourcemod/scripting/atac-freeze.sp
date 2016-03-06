#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <atac>

#pragma newdecls required
#pragma semicolon 1

#define SOUND_BEEP		"buttons/button17.wav"
#define SOUND_BOOM		"weapons/explode3.wav"
#define SOUND_FINAL		"weapons/cguard/charging.wav"
#define SOUND_FREEZE	"physics/glass/glass_impact_bullet4.wav"

public Plugin myinfo =
{
    name        = "ATAC - Freeze Punishment",
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
int g_iFreezeBombTime[MAXPLAYERS + 1];
int g_iGlowSprite;
int g_iGreyColor[4]  = {128, 128, 128, 255};
int g_iHaloSprite;
int g_iTime[MAXPLAYERS + 1];
int g_iWhiteColor[4] = {255, 255, 255, 255};
ConVar g_hDuration;
ConVar g_hTicks;


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    // Create convars
    g_hDuration = CreateConVar("atac_freeze_duration",  "10", "ATAC Freeze Duration");
    g_hTicks    = CreateConVar("atac_freezebomb_ticks", "10", "ATAC FreezeBomb Ticks");

    // Load translations
    LoadTranslations("atac-freeze.phrases");

    if (LibraryExists("atac")) {
        OnLibraryAdded("atac");
    }
}

public void OnMapStart()
{
    g_iGlowSprite = PrecacheModel("sprites/blueglow2.vmt");

    PrecacheSound(SOUND_BEEP,   true);
    PrecacheSound(SOUND_BOOM,   true);
    PrecacheSound(SOUND_FREEZE, true);
    PrecacheSound(SOUND_FINAL,  true);
}

public void OnLibraryAdded(const char[] name)
{
    if (!StrEqual(name, "atac")) {
        return;
    }

    char sName[32];
    Format(sName, sizeof(sName), "%T", "Freeze",     LANG_SERVER);
    ATAC_RegisterPunishment(sName, AtacPunishment_Freeze);

    Format(sName, sizeof(sName), "%T", "FreezeBomb", LANG_SERVER);
    ATAC_RegisterPunishment(sName, AtacPunishment_FreezeBomb);
}


/**
 * ATAC Punishments
 */
public void AtacPunishment_Freeze(int victim, int attacker)
{
    PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Frozen",       attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));

    SetEntityMoveType(attacker,    MOVETYPE_NONE);
    SetEntityRenderColor(attacker, 0, 128, 255, 192);

    float flPos[3];
    GetClientEyePosition(attacker, flPos);
    EmitAmbientSound(SOUND_FREEZE, flPos, attacker, SNDLEVEL_RAIDSIREN);

    g_iTime[attacker]           = g_hDuration.IntValue;
    CreateTimer(1.0, Timer_Freeze,     attacker, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public void AtacPunishment_FreezeBomb(int victim, int attacker)
{
    PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "FreezeBombed", attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));

    g_iFreezeBombTime[attacker] = g_hTicks.IntValue;
    CreateTimer(1.0, Timer_FreezeBomb, attacker, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}


/**
 * Timers
 */
public Action Timer_Freeze(Handle timer, any client)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
        return Plugin_Stop;
    }

    float flPos[3];
    if (--g_iTime[client]) {
        SetEntityMoveType(client,    MOVETYPE_NONE);
        SetEntityRenderColor(client, 0, 128, 255, 135);

        GetClientAbsOrigin(client, flPos);
        flPos[2] += 10;

        TE_SetupGlowSprite(flPos, g_iGlowSprite, 0.95, 1.5, 50);
        TE_SendToAll();

        return Plugin_Continue;
    } else {
        GetClientEyePosition(client,   flPos);
        EmitAmbientSound(SOUND_FREEZE, flPos, client, SNDLEVEL_RAIDSIREN);

        SetEntityMoveType(client,    MOVETYPE_WALK);
        SetEntityRenderColor(client, 255, 255, 255, 255);

        return Plugin_Stop;
    }
}

public Action Timer_FreezeBomb(Handle timer, any client)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
        return Plugin_Stop;
    }

    float flPos[3];
    GetClientEyePosition(client, flPos);

    if (--g_iFreezeBombTime[client]) {
        int iColor = 0;
        if (g_iFreezeBombTime[client] == 1) {
            EmitAmbientSound(SOUND_FINAL, flPos, client, SNDLEVEL_RAIDSIREN);
        } else {
            iColor = RoundToFloor(g_iFreezeBombTime[client] * (255.0 / g_hTicks.IntValue));
            EmitAmbientSound(SOUND_BEEP,  flPos, client, SNDLEVEL_RAIDSIREN);
        }

        SetEntityRenderColor(client, 255, iColor, iColor, 255);
        PrintCenterTextAll("%t", "Till Explodes", g_iFreezeBombTime[client], client);

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

        EmitAmbientSound(SOUND_BOOM,   flPos, client, SNDLEVEL_RAIDSIREN);
        EmitAmbientSound(SOUND_FREEZE, flPos, client, SNDLEVEL_RAIDSIREN);

        SetEntityMoveType(client,    MOVETYPE_NONE);
        SetEntityRenderColor(client, 0, 128, 255, 192);

        g_iTime[client] = g_hDuration.IntValue;
        CreateTimer(1.0, Timer_Freeze, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

        return Plugin_Stop;
    }
}
