#if defined _atac_included_
  #endinput
#endif
#define _atac_included_

#define CLR_DEFAULT			1
#define CLR_LIGHTGREEN	3
#define CLR_GREEN				4
#define CLR_DARKGREEN		5

#define STEAM_BAN_TYPE	0
#define IP_BAN_TYPE			1

#define ATAC_VERSION		"2.5.2"

enum AtacInfo
{
    AtacInfo_Attacks,
    AtacInfo_Bans,
    AtacInfo_Karma,
    AtacInfo_Kicks,
    AtacInfo_Kills
}

enum AtacSetting
{
    AtacSetting_AttacksLimit,
    AtacSetting_BansLimit,
    AtacSetting_BanTime,
    AtacSetting_BanType,
    AtacSetting_Enabled,
    AtacSetting_IgnoreBots,
    AtacSetting_Immunity,
    AtacSetting_KarmaLimit,
    AtacSetting_KicksLimit,
    AtacSetting_KillKarma,
    AtacSetting_KillsLimit
}

typedef AtacPunishment = function void (int victim, int attacker);


/**
 * Retrieves client information
 *
 * @param	 client	Player index
 * @param	 type		AtacInfo type
 * @return Value of client's information type
 */
native any ATAC_GetInfo(client, AtacInfo type);

/**
 * Retrieves a setting's value
 *
 * @param	 type		AtacSetting type
 * @return Value of setting
 */
native any ATAC_GetSetting(AtacSetting type);

/**
 * Gives a client karma
 *
 * @param	 client	Player index
 * @param	 karma	Amount of karma to give
 * @param	 reason	Reason for earning karma
 */
native void ATAC_GiveKarma(int client, int karma, const char[] reason = "");

/**
 * Registers an ATAC punishment
 *
 * @param	name				Name of the punishment
 * @param	callback		Command callback
 */
native void ATAC_RegisterPunishment(const char[] name, AtacPunishment callback);

/**
 * Stores client information
 *
 * @param	client	Player index
 * @param	type		AtacInfo type
 * @param	value		The value to store
 */
native void ATAC_SetInfo(int client, AtacInfo type, any value);


public SharedPlugin __pl_atac =
{
    name = "atac",
    file = "atac.smx",
    #if defined REQUIRE_PLUGIN
    required = 1,
    #else
    required = 0,
    #endif
};

public __pl_atac_SetNTVOptional()
{
    MarkNativeAsOptional("ATAC_GetInfo");
    MarkNativeAsOptional("ATAC_GetSetting");
    MarkNativeAsOptional("ATAC_GiveKarma");
    MarkNativeAsOptional("ATAC_RegisterPunishment");
    MarkNativeAsOptional("ATAC_SetInfo");
}
