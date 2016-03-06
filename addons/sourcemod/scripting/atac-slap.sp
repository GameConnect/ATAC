#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <atac>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
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
ConVar g_hDamage;


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    // Create convars
    g_hDamage = CreateConVar("atac_slap_damage", "50", "ATAC Slap Damage");

    // Load translations
    LoadTranslations("atac-slap.phrases");

    if (LibraryExists("atac")) {
        OnLibraryAdded("atac");
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (!StrEqual(name, "atac")) {
        return;
    }

    char sName[32];
    Format(sName, sizeof(sName), "%T", "Slap", LANG_SERVER);
    ATAC_RegisterPunishment(sName, AtacPunishment_Slap);
}


/**
 * ATAC Punishments
 */
public void AtacPunishment_Slap(int victim, int attacker)
{
    PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Slapped", attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));

    SlapPlayer(attacker, g_hDamage.IntValue);
}
