#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <atac>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
    name        = "ATAC - Slay Punishment",
    author      = "GameConnect",
    description = "Advanced Team Attack Control",
    version     = ATAC_VERSION,
    url         = "http://www.gameconnect.net"
};


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    // Load translations
    LoadTranslations("atac-slay.phrases");

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
    Format(sName, sizeof(sName), "%T", "Slay", LANG_SERVER);
    ATAC_RegisterPunishment(sName, AtacPunishment_Slay);
}


/**
 * ATAC Punishments
 */
public void AtacPunishment_Slay(int victim, int attacker)
{
    PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Slayed", attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));

    ForcePlayerSuicide(attacker);
}
