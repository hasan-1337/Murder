#if defined _Murder_included
	#endinput
#endif

#define _Murder_included
#define LoopValidClients(%1,%2) for (int %1 = 1; %1 <= MaxClients; %1++) if (IsValidClient(%1, %2)) 
#define TAG 		" \x02[Murder]\x01"
#define VERSION 	"1.0"

/**
 * Retrieves the current Murderer.
 *
 * @noparam
 * @return							Murderer User ID
 */
native int GetMurderer(); 

/**
 * Sets a client to be a Murderer.
 *
 * @param Index						Client's User ID
 * @noreturn
 */
native void SetMurderer(); 

/**
 * Retrieves the current Detective.
 *
 * @noparam
 * @return							Detective User ID
 */
native int GetDetective(); 

/**
 * Sets a client to be a Detective or Special Bystander.
 *
 * @param Index						Client's User ID
 * @noreturn
 */
native void SetDetective(); 

/**
 * Retrieves client's character.
 *
 * @param Index						Client's User ID
 * @param String					Client's Character Name (with chat colors)
 * @noreturn 						
 */
native void GetClientCharacter(int client, char[] sCharacterName); 


/*===============================================================================================================================*/
/********************************************************* [STOCKS] **************************************************************/
/*===============================================================================================================================*/


bool IsValidClient(int client, bool bAllowDead = true)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsFakeClient(client) || (!bAllowDead && !IsPlayerAlive(client)))
		return false;
	return true;
}

stock void RemoveAllWeapons(int client)
{
	int offset = FindDataMapInfo(client, "m_hMyWeapons") - 4;
	
	for (int i = 0; i < 48; i++) 
	{
		offset += 4;

		int iWeapon = GetEntDataEnt2(client, offset);
		
		if (IsValidEdict(iWeapon)) 
		{
			int iAmmo = FindDataMapInfo(client, "m_iAmmo") + (GetEntProp(iWeapon, Prop_Data, "m_iPrimaryAmmoType") * 4);
			SetEntData(client, iAmmo, 0, 4, true);
	
			iAmmo = FindDataMapInfo(client, "m_iAmmo") + (GetEntProp(iWeapon, Prop_Data, "m_iSecondaryAmmoType") * 4);
			SetEntData(client, iAmmo, 0, 4, true);
	
			if (RemovePlayerItem(client, iWeapon)) 
				AcceptEntityInput(iWeapon, "Kill");
		}
	}
}

stock void FadePlayer(int client, int iDuration, int iHold, any aFlags, int iColor[4])
{
    Handle hMessage = StartMessageOne("Fade", client, USERMSG_RELIABLE); 
    PbSetInt(hMessage, "duration", iDuration); 
    PbSetInt(hMessage, "hold_time", iHold); 
    PbSetInt(hMessage, "flags", aFlags); 
    PbSetColor(hMessage, "clr", iColor); 
    EndMessage(); 
}

public SharedPlugin __pl_Murder =
{
	name = "Murder",
	file = "Murder.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_Murder_SetNTVOptional()
{
	MarkNativeAsOptional("GetClientRole");
	MarkNativeAsOptional("SetClientRole");
	MarkNativeAsOptional("GetMurderer");
	MarkNativeAsOptional("SetMurderer");
	MarkNativeAsOptional("GetDetective");
	MarkNativeAsOptional("SetDetective");
	MarkNativeAsOptional("GetClientCharacter");
}
#endif