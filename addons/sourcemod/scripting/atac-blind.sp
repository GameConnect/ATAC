#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <atac>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
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
ConVar g_hAmount;


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    // Create convars
    g_hAmount = CreateConVar("atac_blind_amount", "255", "ATAC Blind Amount");

    // Load translations
    LoadTranslations("atac-blind.phrases");

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
    Format(sName, sizeof(sName), "%T", "Blind", LANG_SERVER);
    ATAC_RegisterPunishment(sName, AtacPunishment_Blind);
}


/**
 * ATAC Punishments
 */
public void AtacPunishment_Blind(int victim, int attacker)
{
    PrintToChatAll("%c[ATAC]%c %t", CLR_GREEN, CLR_DEFAULT, "Blinded", attacker, ATAC_GetInfo(attacker, AtacInfo_Kills), ATAC_GetSetting(AtacSetting_KillsLimit));

    int iDuration = 1536,
        iHoldTime = 1536,
        iFlags    = (0x0002 | 0x0008),
        iColor[4] = {0, 0, 0, 0};
    iColor[3]     = g_hAmount.IntValue;

    Handle hMessage = StartMessageOne("Fade", attacker);
    if (GetUserMessageType() == UM_Protobuf) {
        PbSetInt(hMessage,   "duration",  iDuration);
        PbSetInt(hMessage,   "hold_time", iHoldTime);
        PbSetInt(hMessage,   "flags",     iFlags);
        PbSetColor(hMessage, "clr",       iColor);
    } else {
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
