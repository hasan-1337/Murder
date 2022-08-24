#include <sourcemod>
#include <autoexecconfig>
#include <cstrike>
#include <sdkhooks>
#include <emitsoundany>
#include <Murder>

#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma newdecls required
#pragma semicolon 1

#define MAXPROPS  40 

ArrayList gA_ModelName = null;
ArrayList gA_ModelPath = null;
ArrayList gA_RadioName = null;
ArrayList gA_RadioPath = null;

bool gB_Punished[MAXPLAYERS+1] = {false, ...};
bool gB_Delete[MAXPLAYERS+1] = {false, ...};
bool gB_AdminMenu = false;
bool gB_Allow = false;
bool gB_Round = false;
bool gB_Late = false;

char gS_ColoredName[MAXPLAYERS+1][100];
char gS_Characters[][] = // Add more if you really want
{
	"Alpha",
	"Bravo",
	"Charlie",
	"Delta",
	"Echo",
	"Foxtrot",
	"Golf",
	"Hotel",
	"Hitler",
	"Stalin",
	"Oliver",
	"Trump",
	"Mussolini",
	"Osama",
	"Uganda",
	"Bush",
	"Blake",
	"Escobar",
	"India",
	"Julliette",
	"Kilo",
	"Lima",
	"Miko",
	"November",
	"Oscar",
	"Papa",
	"Quebec",
	"Romeo",
	"Sierra",
	"Tango",
	"Uniform",
	"Victor",
	"Whiskey",
	"X-ray",
	"Yankee",
	"Zulu"
};

char gS_Colors[][] = // Don't add more colors
{
	"<font color='#800080'>", // purple
	"<font color='#FFFF00'>", // yellow
	"<font color='#FF00FF'>", // pink
	"<font color='#00FF00'>", // green
	"<font color='#FF0000'>", // red
	"<font color='#0000FF'>", // blue
	"<font color='#A7DE35'>", // olive
	"<font color='#E36E27'>", // orange
	"<font color='#DC381F'>"  // brown
};

char gS_Block[][] = // Console commands to block
{
	"coverme",
	"takepoint",
	"holdpos", 
	"regroup", 
	"followme", 
	"takingfire", 
	"cheer", 
	"thanks", 
	"compliment", 
	"go", 
	"fallback", 
	"sticktog", 
	"getinpos", 
	"stormfront", 
	"report", 
	"roger",
	"enemyspot",
	"needbackup", 
	"sectorclear", 
	"inposition", 
	"reportingin", 
	"getout", 
	"negative", 
	"enemydown",
	"jointeam",
	"drop"
};

ConVar gCV_Players_Needed = null;
ConVar gCV_Radio_Delay = null;
ConVar gCV_Smoke_Time = null;
ConVar gCV_Model_Enabled = null;
ConVar gCV_Items_Disguise = null;
ConVar gCV_Prop_Amount = null;
ConVar gCV_Prop_Respawn = null;
ConVar gCV_Knife_Duration = null;
ConVar gCV_Footsteps_Life = null;
ConVar gCV_DoubleJump_Enabled = null;
ConVar gCV_DoubleJump_Max = null;
ConVar gCV_DoubleJump_Height = null;

Database gD_Database = null;

int gI_Jumps[MAXPLAYERS+1] = {0, ...};
int gI_LastFlags[MAXPLAYERS+1] = {0, ...};
int gI_LastButtons[MAXPLAYERS+1] = {0, ...};
int gI_GrabEntity[MAXPLAYERS+1] = {0, ...};
int gI_Items[MAXPLAYERS+1] = {0, ...};
int gI_Prop[MAXPROPS] = {-1, ...};
int gI_PropID[MAXPROPS] = {-1, ... };
int gI_Precaches[4] = {-1, ...};
int gI_ValidProps = 0;
int gI_Round = 0;
int gI_Knife = 0;
int gI_Winner = -1;
int gI_Murderer = -1;
int gI_Detective = -1;
int gI_Players = 0;

float gF_GrabTime[MAXPLAYERS+1] = {0.0, ...};
float gF_RadioDelay[MAXPLAYERS+1] = {0.0, ...};
float gF_GrabDistance[MAXPLAYERS+1] = {0.0, ...};
float gF_SmokeTime = 0.0;

TopMenu gT_TopMenu = null;

Handle gH_KnifeTimer = null;

public Plugin myinfo =
{
	name = "[CS:GO] Murder",
	author = "LenHard",
	description = "Murder mod via Garry's Mod.",
	version = VERSION,
	url = "http://steamcommunity.com/id/TheOfficalLenHard/"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max)
{
	CreateNative("GetMurderer", Native_GetMurderer);
	CreateNative("SetMurderer", Native_SetMurderer);
	CreateNative("GetDetective", Native_GetDetective);
	CreateNative("SetDetective", Native_SetDetective);
	CreateNative("GetClientCharacter", Native_GetCharacter);
	
	MarkNativeAsOptional("GetMurderer");
	MarkNativeAsOptional("SetMurderer");
	MarkNativeAsOptional("GetDetective");
	MarkNativeAsOptional("SetDetective");
	MarkNativeAsOptional("GetClientCharacter");

	RegPluginLibrary("Murder");
	gB_Late = bLate;
	return APLRes_Success;
}

public int Native_GetMurderer(Handle hHandler, int iNumParams)
{
	if (IsValidClient(gI_Murderer))
		return GetClientUserId(gI_Murderer);
	return -1;
}

public int Native_SetMurderer(Handle hHandler, int iNumParams)
{
	int client = GetNativeCell(1);
	gI_Murderer = client;
}

public int Native_GetDetective(Handle hHandler, int iNumParams)
{
	if (IsValidClient(gI_Detective))
		return GetClientUserId(gI_Detective);
	return -1;
}

public int Native_SetDetective(Handle hHandler, int iNumParams)
{
	int client = GetNativeCell(1);
	gI_Detective = client;
}

public int Native_GetCharacter(Handle hHandler, int iNumParams)
{
	char[] sCharacterName = new char[100];
	char[] sColor = new char[MAX_NAME_LENGTH];
	
	int client = GetNativeCell(1);
	GetNativeString(2, sCharacterName, MAX_NAME_LENGTH);
	
	GetClientColor(client, {1, 3, 3, 7}, true, false, sColor, sCharacterName);
	Format(sCharacterName, 100, "%s%s", sColor, sCharacterName);
	SetNativeString(2, sCharacterName, MAX_NAME_LENGTH);
}


/*===============================================================================================================================*/
/********************************************************* [ONLOADS] *************************************************************/
/*===============================================================================================================================*/


public void OnPluginStart()
{	
	if (GetEngineVersion() != Engine_CSGO)
		SetFailState("This plugin only works in the game CS:GO");
	
	AutoExecConfig_SetFile("Murder");
	AutoExecConfig_SetCreateFile(true);
	CreateConVar("murder_version", VERSION, "LenHard's Murder Plugin Version", FCVAR_DONTRECORD);
	
	gCV_Players_Needed = AutoExecConfig_CreateConVar("murder_players_needed", "3", "Amount of players needed to start a murder game.", FCVAR_NOTIFY, true, 0.0);
	gCV_Radio_Delay = AutoExecConfig_CreateConVar("murder_radio_delay", "2.0", "Amount of time to delay between the uses of the voice commands", FCVAR_NOTIFY, true, 0.0);
	gCV_Smoke_Time = AutoExecConfig_CreateConVar("murder_smoke_time", "250.0", "Amount of time to trigger the smoke effect on the murderer", FCVAR_NOTIFY, true, 120.0);
	gCV_Model_Enabled = AutoExecConfig_CreateConVar("murder_models_enabled", "1", "Enable Model switching during disguise?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCV_Items_Disguise = AutoExecConfig_CreateConVar("murder_prop_disguise_amount", "2", "Amount of clues needed to be able disguise as dead players", FCVAR_NOTIFY, true, 1.0);
	gCV_Prop_Amount = AutoExecConfig_CreateConVar("murder_prop_gun_amount", "5", "Amount of props collected to recieve a gun.", FCVAR_NOTIFY, true, 1.0);
	gCV_Prop_Respawn = AutoExecConfig_CreateConVar("murder_prop_respawn_time", "75.0", "Amount of time till a random set of props spawn.", FCVAR_NOTIFY, true, 30.0);
	gCV_Knife_Duration = AutoExecConfig_CreateConVar("murder_knife_duration", "30.0", "The time that gives the murderer his knife back after throwing.", FCVAR_NOTIFY, true, 10.0);
	gCV_Footsteps_Life = AutoExecConfig_CreateConVar("murder_footsteps_life", "8.0", "Life time of the footsteps displayed on the ground.", FCVAR_NOTIFY, true, 5.0);
	gCV_DoubleJump_Enabled = AutoExecConfig_CreateConVar("murder_doublejump_enabled", "1", "Enable Multi or double Jumping?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCV_DoubleJump_Max = AutoExecConfig_CreateConVar("murder_doublejump_max", "1", "Max amount of jumps allowed in the air?", FCVAR_NOTIFY, true, 1.0);
	gCV_DoubleJump_Height = AutoExecConfig_CreateConVar("murder_doublejump_height", "300.0", "Height of each jump?", FCVAR_NOTIFY);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	SQL_LoadDatabase();
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_footstep", Event_PlayerFootstep, EventHookMode_Post);
	HookEvent("player_activate", Event_PlayerActivate, EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
	HookEvent("weapon_fire_on_empty", Event_WeaponFire, EventHookMode_Post);
	HookEvent("player_team", Event_Stop, EventHookMode_Pre);
	
	HookUserMessage(GetUserMessageId("TextMsg"), OnTextMsg, true);
	HookUserMessage(GetUserMessageId("SayText2"), OnSayText2, true);
	
	AddNormalSoundHook(Event_SoundEmitted);
	AddCommandListener(CL_LAW, "+lookatweapon");
	
	RegConsoleCmd("sm_murder", Cmd_MurderInfo, "Information about the Plugin.");
	RegConsoleCmd("sm_voice", Cmd_Voice, "Displays the voice commands.");
	RegConsoleCmd("buyammo1", Cmd_Voice, "Displays the voice commands.");
	RegConsoleCmd("buyammo2", Cmd_Voice, "Displays the voice commands.");
	
	RegAdminCmd("sm_addprops", Cmd_PropsMenu, ADMFLAG_RCON, "Add Props around the map.");
	RegAdminCmd("sm_spawnprops", Cmd_SpawnMenu, ADMFLAG_RCON, "Spawns Props that are saved in the Database.");
	RegAdminCmd("sm_deleteprops", Cmd_DeleteMenu, ADMFLAG_RCON, "Delete props around the map.");
	
	TopMenu hTopMenu = null;
	
	if ((gB_AdminMenu = LibraryExists("adminmenu")) && ((hTopMenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(hTopMenu);
	
	for (int i = 0; i < sizeof(gS_Block); ++i) AddCommandListener(CL_Block, gS_Block[i]);
	
	if (gB_Late)
	{
		OnMapStart();
		LoopValidClients(i, true) OnClientPutInServer(i);
		FindConVar("mp_restartgame").SetInt(1);
	}
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "adminmenu"))
		gB_AdminMenu = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "adminmenu"))
		gB_AdminMenu = false;
}

public void OnMapStart()
{
	SQL_LoadDatabase();
	LoadModelFile();
	LoadRadioFile();
	
	AddFileToDownloadsTable("sound/Murder/Scream.mp3");
	AddFileToDownloadsTable("sound/Murder/Bell.mp3");
	
	gI_Precaches[0] = PrecacheModel("materials/sprites/laserbeam.vmt");
	gI_Precaches[1] = PrecacheModel("materials/sprites/glow01.vmt");
	gI_Precaches[2] = PrecacheModel("materials/sprites/smoke.vmt");
	gI_Precaches[3] = PrecacheModel("models/weapons/w_knife_default_ct_dropped.mdl");
	
	gI_Players = 0;
	gI_Round = 0;
	gI_Knife = -1;
	gF_SmokeTime = 0.0;
	
	gB_Round = false;
	gB_Allow = false;
	
	ResetKnifeTimer();
	
	FindConVar("mp_freezetime").SetInt(7);
	FindConVar("mp_playerid").SetInt(2);
	FindConVar("mp_friendlyfire").SetInt(1);
	FindConVar("mp_teammates_are_enemies").SetInt(1);
	FindConVar("mp_teamname_1").SetString("Bystanders");
	FindConVar("mp_teamname_2").SetString("Murderer");
	FindConVar("mp_weapons_glow_on_ground").SetInt(1);
	
	SDKHook(FindEntityByClassname(0, "cs_player_manager"), SDKHook_ThinkPost, OnResourceThink);
	CreateTimer(0.1, Timer_Hud, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client)) // No bots
	{	
		++gI_Players;
		
		if (gI_Players == gCV_Players_Needed.IntValue)
		{
			PrintToChatAll("%s The game will start shortly...", TAG);
			FindConVar("mp_restartgame").SetInt(1);
		}
		
		gI_GrabEntity[client] = -1;
		gF_GrabTime[client] = 0.0;
		gF_GrabDistance[client] = 0.0;
		gF_RadioDelay[client] = 0.0;
		gI_Items[client] = 0;
		gB_Punished[client] = false;
		gB_Delete[client] = false;
		
		SDKHook(client, SDKHook_PreThink, OnPreThink);
		SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
		SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage); 
		SDKHook(client, SDKHook_WeaponCanUse, OnWeaponDecideUse);
	}
}

public void OnClientDisconnect(int client)
{	
	if (gI_Murderer == client)
	{
		CS_TerminateRound(7.0, CSRoundEnd_CTWin, true);
		
		char[] sColorName = new char[MAX_NAME_LENGTH];
		char[] sName = new char[MAX_NAME_LENGTH];
		GetClientColor(client, {1, 3, 3, 7}, true, true, sColorName, sName);
		PrintToChatAll("%s The Murder %s%s, %N\x01 has disconnected.", TAG, sColorName, sName, client);
	}
	
	gI_Players--;
	gI_GrabEntity[client] = -1;
	gF_GrabTime[client] = 0.0;
	gF_GrabDistance[client] = 0.0;
}

public Action CS_OnCSWeaponDrop(int client, int iWeapon)
{
	char[] sWeapon = new char[32];
	GetEdictClassname(iWeapon, sWeapon, 32);
	
	if (sWeapon[7] == 'd' && sWeapon[8] == 'e' && sWeapon[9] == 'a') // R8 is somehow a deagle...
		return Plugin_Continue;	
	return Plugin_Handled;	
}

public Action OnTextMsg(UserMsg msg_id, Protobuf hUserMsg, const int[] iClients, int iNumClients, bool bReliable, bool bInit)
{
	if (bReliable)
	{
		char[] sText = new char[64];
		hUserMsg.ReadString("params", sText, 64, 0);
		
		if (StrContains(sText, "Chat_SavePlayer_", false) != -1)
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action OnSayText2(UserMsg msg_id, Protobuf hUserMsg, const int[] iClients, int iNumClients, bool bReliable, bool bInit)
{
	int client = hUserMsg.ReadInt("ent_idx");

	if (IsValidClient(client, false))
	{	
		char[] sTranslationName = new char[32];
		hUserMsg.ReadString("msg_name", sTranslationName, 32);
		
		if (sTranslationName[8] != 'N') // Ignore Name change
		{
			char[] sName = new char[32];
			char[] sColorName = new char[4];
			
			GetClientColor(client, {1, 3, 3, 7}, true, true, sColorName, sName);
			
			if (sName[0] != '\0')
			{
				char[] sTranslation = new char[256];
				char[] sMsg = new char[256];
				
				hUserMsg.ReadString("params", sMsg, 256, 1);
				FormatEx(sTranslation, 256, " %s%s\x01: %s", sColorName, sName, sMsg); // Other chat plugins might ruin the sMsg
				
				hUserMsg.SetInt("ent_idx", client);
				hUserMsg.SetBool("chat", true);
				hUserMsg.SetString("msg_name", sTranslation);
				hUserMsg.SetString("params", "", 0);
				hUserMsg.SetString("params", "", 1);
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}


/*===============================================================================================================================*/
/********************************************************* [SDKHOOKS] ************************************************************/
/*===============================================================================================================================*/


public void OnResourceThink(int iEnt)
{
	static int iAliveOffset = -1;
	if (iAliveOffset == -1) iAliveOffset = FindSendPropInfo("CCSPlayerResource", "m_bAlive");
	
	static int iKillOffset = -1;
	if (iKillOffset == -1) iKillOffset = FindSendPropInfo("CCSPlayerResource", "m_iKills");
	
	static int iAssistOffset = -1;
	if (iAssistOffset == -1) iAssistOffset = FindSendPropInfo("CCSPlayerResource", "m_iAssists");
	
	static int iDeathOffset = -1;
	if (iDeathOffset == -1) iDeathOffset = FindSendPropInfo("CCSPlayerResource", "m_iDeaths");
	
	static int iScoreOffset = -1;
	if (iScoreOffset == -1) iScoreOffset = FindSendPropInfo("CCSPlayerResource", "m_iScore");
			
	int iAlive[MAXPLAYERS+1] = {1, ...};
	int iScore[MAXPLAYERS+1] = {1337, ...};
		
	SetEntDataArray(iEnt, iAliveOffset, iAlive, MaxClients+1);
	SetEntDataArray(iEnt, iKillOffset, iScore, MaxClients+1);
	SetEntDataArray(iEnt, iAssistOffset, iScore, MaxClients+1);
	SetEntDataArray(iEnt, iDeathOffset, iScore, MaxClients+1);
	SetEntDataArray(iEnt, iScoreOffset, iScore, MaxClients+1);
}

public void OnPostThinkPost(int client)
{
	SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &iDamage, int &iDamageType) 
{
	if (iAttacker != iVictim && IsValidClient(iAttacker))
	{
		iDamage = 100.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action OnWeaponDecideUse(int client, int iWeapon)
{
	if (IsValidEdict(iWeapon) && IsValidClient(client, false))
	{
		char[] sWeapon = new char[32];
		GetEdictClassname(iWeapon, sWeapon, 32);
		
		if (gI_Murderer == client)
		{
			if (!(sWeapon[7] == 'k' && sWeapon[8] == 'n') && !(sWeapon[7] == 'd' && sWeapon[8] == 'e') && sWeapon[9] != 'c')
				return Plugin_Handled;
		}
		else if (gB_Punished[client])
		{
			if (sWeapon[7] != 'd' && sWeapon[8] != 'e' && sWeapon[9] != 'c')
				return Plugin_Handled;
		}
		else
		{
			if (sWeapon[7] == 'k' && sWeapon[8] == 'n')
				return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (gB_Allow && IsValidClient(client, false))
	{			
		if (gCV_DoubleJump_Enabled.BoolValue)
			DoubleJump(client);
		
		if (buttons & IN_ATTACK2 && client == gI_Murderer)
		{
			char[] sWeapon = new char[32];
			GetClientWeapon(client, sWeapon, 32);
			
			if (sWeapon[7] == 'k') // Knife
			{
				float fOrigin[3]; GetClientEyePosition(client, fOrigin);
				float fAngle[3]; GetClientEyeAngles(client, fAngle);
				float fPos[3]; GetAngleVectors(fAngle, fPos, NULL_VECTOR, NULL_VECTOR);
				float fCVelocity[3]; GetEntPropVector(client, Prop_Data, "m_vecVelocity", fCVelocity);
				float fVelocity[3]; GetAngleVectors(fAngle, fVelocity, NULL_VECTOR, NULL_VECTOR);
				
				ScaleVector(fPos, 50.0);
				ScaleVector(fVelocity, 1200.0);
				
				AddVectors(fPos, fOrigin, fPos);
				AddVectors(fVelocity, fCVelocity, fVelocity);
				
				RemoveAllWeapons(client);
				GivePlayerItem(client, "weapon_decoy");
				
				gI_Knife = CreateEntityByName("hegrenade_projectile");
				
				if (IsValidEntity(gI_Knife) && DispatchSpawn(gI_Knife))
				{
					SetEntProp(gI_Knife, Prop_Send, "m_nModelIndex", gI_Precaches[3]);
					SetEntPropFloat(gI_Knife, Prop_Send, "m_flModelScale", 2.0);
					SetEntPropFloat(gI_Knife, Prop_Send, "m_flElasticity", 0.5);
					SetEntPropFloat(gI_Knife, Prop_Data, "m_flGravity", 0.7);
					SetEntProp(gI_Knife, Prop_Data, "m_nNextThinkTick", -1);
					AcceptEntityInput(gI_Knife, "FireUser1");
					
					TeleportEntity(gI_Knife, fPos, fAngle, fVelocity);
					SDKHook(gI_Knife, SDKHook_StartTouch, OnKnifeTouch);
					
					ResetKnifeTimer();
					
					DataPack hData = new DataPack();
					gH_KnifeTimer = CreateDataTimer(gCV_Knife_Duration.FloatValue, Timer_Knife, hData, TIMER_FLAG_NO_MAPCHANGE);
					hData.WriteCell(EntIndexToEntRef(gI_Knife));
					hData.WriteCell(GetClientUserId(client));
					hData.WriteCell(gI_Round);
				}
			}
		}
		
		if (buttons & IN_USE)
		{
			if (!ValidGrab(client))
			{
				int ent;
				float VecPos_Ent[3], VecPos_Client[3];
			
				ent = GetObject(client, false);
			
				if (ent != -1)
				{			
					ent = EntRefToEntIndex(ent);
				
					if (ent != INVALID_ENT_REFERENCE && !(0 < ent <= MaxClients))
					{			
						GetEntPropVector(ent, Prop_Send, "m_vecOrigin", VecPos_Ent);
						GetClientEyePosition(client, VecPos_Client);
						
						if (GetVectorDistance(VecPos_Ent, VecPos_Client, false) < 120.0)
						{
							char[] sName = new char[128];
							GetEdictClassname(ent, sName, 128);
			
							if (StrContains(sName, "door", false) == -1 && StrContains(sName, "button", false) == -1)
							{				
								if (StrEqual(sName, "prop_physics") || StrEqual(sName, "prop_physics_multiplayer") || StrEqual(sName, "func_physbox"))
								{
									if (IsValidEdict(ent) && IsValidEntity(ent))
									{
										ent = ReplacePhysicsEntity(ent);
							
										SetEntPropEnt(ent, Prop_Data, "m_hPhysicsAttacker", client);
										SetEntPropFloat(ent, Prop_Data, "m_flLastPhysicsInfluenceTime", GetEngineTime());
									}
								}
							
								gI_GrabEntity[client] = EntIndexToEntRef(ent);
							
								gF_GrabDistance[client] = GetVectorDistance(VecPos_Ent, VecPos_Client, false);
							
								float position[3];
								TeleportEntity(ent, NULL_VECTOR, NULL_VECTOR, position);	
							}
						}
					}
				}
			}
			
			if (!gB_Punished[client])
			{
				int iTarget = GetClientAimTarget(client, false);
				
				if (IsValidEntity(iTarget))
				{
					float fOrigin[3]; GetClientAbsOrigin(client, fOrigin);
					float fVec[3]; GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", fVec);
					
					if (GetVectorDistance(fOrigin, fVec) <= 100.0)
					{
						for (int i = 0; i <= gI_ValidProps; ++i)
						{
							if (IsValidEdict(gI_Prop[i]) && iTarget == gI_Prop[i])
							{
								if (gB_Delete[client])
								{
									AcceptEntityInput(iTarget, "Kill");
									
									if (gI_PropID[i] != -1)
									{
										SQL_DeleteProp(gI_PropID[i]);
										PrintToChat(client, "%s You have \x07deleted\x01 a Prop from the Database!", TAG);
										gI_Prop[i] = -1;
									}
									else PrintToChat(client, "%s First spawns can't be deleted, please reload the set in order to delete from the database.", TAG);
									break;
								}
								
								AcceptEntityInput(iTarget, "Kill");
								gI_Prop[i] = -1;
								++gI_Items[client];
								ClientCommand(client, "play Murder/Bell.mp3");
								
								FadePlayer(client, 300, 500, 0x0001, {0, 255, 0, 100});
								PrintToChat(client, "%s You have found a Clue! (Total: \x04%i\x01)", TAG, gI_Items[client]);
								
								if (gI_Items[client] >= gCV_Prop_Amount.IntValue && gI_Murderer != client && GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) == -1)
								{
									int iWeapon = GivePlayerItem(client, "weapon_revolver");
									SetEntData(iWeapon, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"), 1);
									SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
									gI_Items[client] -= gCV_Prop_Amount.IntValue;
									PrintToChat(client, "%s You have found enough Clues to acquire a weapon!", TAG);
								}
								break;
							}
						}
						
						if (client == gI_Murderer && gI_Items[client] >= gCV_Items_Disguise.IntValue)
						{
							int iEntity = GetEntProp(iTarget, Prop_Send, "m_hOwnerEntity", 4);
							
							if (IsValidEntity(iEntity))
							{
								if (gCV_Model_Enabled.BoolValue)
								{
									char[] sEntityModel = new char[PLATFORM_MAX_PATH];
									GetEntPropString(iEntity, Prop_Data, "m_ModelName", sEntityModel, PLATFORM_MAX_PATH);
									
									char[] sClientModel = new char[PLATFORM_MAX_PATH];
									GetEntPropString(client, Prop_Data, "m_ModelName", sClientModel, PLATFORM_MAX_PATH);
									
									if (sClientModel[0] == 'm')
										SetEntityModel(iEntity, sClientModel);
									
									if (sEntityModel[0] == 'm')
										SetEntityModel(client, sEntityModel);
								}
								
								char[] sColorName = new char[5];
								char[] sName = new char[32];
								int iColor[4]; GetClientColor(iEntity, iColor, true, true, sColorName, sName);
								
								char[] sOld = new char[100];
								strcopy(sOld, 100, gS_ColoredName[client]);
								strcopy(gS_ColoredName[client], 100, gS_ColoredName[iEntity]);
								strcopy(gS_ColoredName[iEntity], 100, sOld);
								
								SetEntityRenderMode(client, RENDER_TRANSCOLOR);
								SetEntityRenderColor(client, iColor[0], iColor[1], iColor[2], 255);
								
								iColor[3] = 100; FadePlayer(client, 300, 500, 0x0001, iColor);
								gI_Items[client] -= gCV_Items_Disguise.IntValue;
								PrintToChat(client, "%s You have disguised as %s%s \x01[Clues: \x04%i\x01]", TAG, sColorName, sName, gI_Items[client]);
								
								GetClientColor(iEntity, iColor, true, true, sColorName, sName);
								SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
								SetEntityRenderColor(iEntity, iColor[0], iColor[1], iColor[2], 255);
							}
						}
					}
				}
			}
		}
		else if (ValidGrab(client))
		{
			char[] sName = new char[128];
			GetEdictClassname(gI_GrabEntity[client], sName, 128);
	
			if (StrEqual(sName, "prop_physics") || StrEqual(sName, "prop_physics_multiplayer") || StrEqual(sName, "func_physbox") || StrEqual(sName, "prop_physics"))
				SetEntPropEnt(gI_GrabEntity[client], Prop_Data, "m_hPhysicsAttacker", 0);
	
			gI_GrabEntity[client] = -1;
			gF_GrabTime[client] = 0.0;
		}
	}
}

public Action OnPreThink(int client)
{
	if (IsValidClient(client, false))
	{
		int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		
		if (iWeapon != -1)
		{		
			float fTime = GetGameTime();
			
			int iPrimary = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack");
			int iSecondary = FindSendPropInfo("CBaseCombatWeapon", "m_flNextSecondaryAttack");
			
			if (!gB_Allow)
			{
				SetEntDataFloat(iWeapon, iPrimary, fTime + 1.0);
				SetEntDataFloat(iWeapon, iSecondary, fTime + 1.0);
			}
			else
			{
				char[] sWeapon = new char[32];
				GetEdictClassname(iWeapon, sWeapon, 32);
				
				if (sWeapon[7] != 'k' && sWeapon[9] != 'a') // Knife or Deagle (Revolver)
				{
					SetEntDataFloat(iWeapon, iPrimary, fTime + 1.0);
					SetEntDataFloat(iWeapon, iSecondary, fTime + 1.0);
				}
				else SetEntDataFloat(iWeapon, iSecondary, fTime + 1.0);
			}
		}
	}
}

public void OnKnifeTouch(int iKnife, int client)
{
	if (IsValidEntity(iKnife) && IsValidClient(client, false))
	{	
		if (client != gI_Murderer)
		{
			float fVelocity[3]; GetEntPropVector(iKnife, Prop_Data, "m_vecAbsVelocity", fVelocity);
			float fSpeed = GetVectorLength(fVelocity);
			
			if (fSpeed > 0.0)
			{				
				gI_Knife = -1;
				AcceptEntityInput(iKnife, "Kill");
				ForcePlayerSuicide(client);
				
				if (IsValidClient(gI_Murderer, false))
				{
					RemoveAllWeapons(gI_Murderer);
					GivePlayerItem(gI_Murderer, "weapon_decoy");
					GivePlayerItem(gI_Murderer, "weapon_knife");
				}
			}
		}
		else
		{
			gI_Knife = -1;
			AcceptEntityInput(iKnife, "Kill");
			RemoveAllWeapons(client);
			GivePlayerItem(client, "weapon_decoy");
			GivePlayerItem(client, "weapon_knife");
		}
		
		ResetKnifeTimer();
	}
}


/*===============================================================================================================================*/
/********************************************************* [EVENTS] **************************************************************/
/*===============================================================================================================================*/


public void Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{	
	for (int i = 0; i <= gI_ValidProps; ++i)
	{
		gI_Prop[i] = -1; 
		gI_PropID[i] = -1; 
	}
	
	ResetKnifeTimer();
	
	int iPlayers = 0;
	
	gF_SmokeTime = GetGameTime() + gCV_Smoke_Time.FloatValue;
	gI_Murderer = -1;
	gI_Detective = -1;
	gI_ValidProps = 0;
	gI_Knife = -1;
	++gI_Round;
	
	gB_Round = true;
	gB_Allow = false;
	
	LoopValidClients(i, true)
	{
		++iPlayers;
		gI_GrabEntity[i] = -1;
		gF_GrabTime[i] = 0.0;
		gF_GrabDistance[i] = 0.0;
		gI_Items[i] = 0;
		gB_Punished[i] = false;
		FadePlayer(i, 100, 3600, 0x0009, {0, 0, 0, 255});
		ClientCommand(i, "play Murder/Scream.mp3");
	}
	
	if (iPlayers >= gCV_Players_Needed.IntValue)
	{
		gI_Murderer = GetRandomPlayer();
		gI_Detective = GetRandomPlayer();
		CreateTimer(8.0, Timer_Allow, gI_Round, TIMER_FLAG_NO_MAPCHANGE);
	}
	else PrintToChatAll("%s You need at least \x04%i\x01 players to start the game!", TAG, gCV_Players_Needed.IntValue);
}

public void Event_RoundEnd(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{	
	gB_Round = false;
	hEvent.BroadcastDisabled = true;
		
	gI_Winner = hEvent.GetInt("winner");
	gF_SmokeTime = 0.0;
	
	ResetKnifeTimer();
	
	char[] sText = new char[PLATFORM_MAX_PATH];
	char[] sColorName = new char[MAX_NAME_LENGTH];
	char[] sName = new char[MAX_NAME_LENGTH];
	char[] sExtra = new char[5];
	char[] sExtra2 = new char[10];
	
	Menu hMenu = new Menu(Menu_RoundData);
	hMenu.SetTitle("#     Role         Clues    Color      Character        Player\n ");

	LoopValidClients(i, true)
	{
		ClientCommand(i, "play Murder/Bell.mp3");
		GetClientColor(i, {1, 3, 3, 7}, true, false, sColorName, sName);

		if (sColorName[0] != '\0' && sName[0] != '\0')  
		{
			switch (strlen(sColorName))
			{
				case 3: FormatEx(sExtra, 5, "     ");
				case 4: FormatEx(sExtra, 5, "    ");
				case 5: FormatEx(sExtra, 5, "  ");
				case 6: FormatEx(sExtra, 5, " ");
				default: FormatEx(sExtra, 5, "");
			}
			
			switch (strlen(sName))
			{
				case 4: FormatEx(sExtra2, 10, "          ");
				case 5: FormatEx(sExtra2, 10, "       ");
				case 6: FormatEx(sExtra2, 10, "      ");
				case 7: FormatEx(sExtra2, 10, "     ");	
				case 8: FormatEx(sExtra2, 10, "    ");	
				case 9: FormatEx(sExtra2, 10, "   ");	
				default: FormatEx(sExtra2, 10, "");	
			}
			
			FormatEx(sText, PLATFORM_MAX_PATH, " %s    %i        %s%s     %s%s     %N", (i == gI_Murderer)? "Murderer  ":"Bystander", gI_Items[i], sColorName, sExtra, sName, sExtra2, i);
			hMenu.AddItem("", sText, ITEMDRAW_DISABLED);
		}
	}
	
	if (hMenu.ItemCount != 0)
	{
		LoopValidClients(i, true)
		{
			hMenu.Display(i, 20);
			
			if (gI_Winner == 2 && IsValidClient(gI_Murderer, true))
			{
				GetClientColor(i, {1, 3, 3, 7}, true, true, sColorName, sName);
				PrintToChat(i, "%s The \x07Murderer Wins! \x01He was %s%s, %N", TAG, sColorName, sName, gI_Murderer);
			}
		}
	}
}

public void Event_PlayerActivate(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if (IsValidClient(client)) ChangeClientTeam(client, 3); 
}

public void Event_PlayerSpawn(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{	
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	
	if (IsValidClient(client) && gI_Players >= gCV_Players_Needed.IntValue) 
	{				
		FormatEx(gS_ColoredName[client], 100, "%s%s", gS_Colors[GetRandomInt(0, sizeof(gS_Colors)-1)], gS_Characters[GetRandomInt(0, sizeof(gS_Characters)-1)]);
		CreateTimer(0.5, Timer_Spawn, GetClientUserId(client));
		gF_RadioDelay[client] = 0.0;
	}
}

public void Event_PlayerDeath(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	hEvent.BroadcastDisabled = true;
	
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	
	if (IsValidClient(client)) 
	{	
		gB_Delete[client] = false;
		gB_Punished[client] = false;
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") & ~(1<<2));
		
		if (client == gI_Murderer)
		{
			CS_TerminateRound(7.0, CSRoundEnd_CTWin, true);
			
			char[] sColorName = new char[MAX_NAME_LENGTH];
			char[] sName = new char[MAX_NAME_LENGTH];
			
			if (iAttacker != gI_Murderer && IsValidClient(iAttacker))
			{
				GetClientColor(iAttacker, {1, 3, 3, 7}, true, true, sColorName, sName);
				PrintToChatAll("%s %s%s, %N \x01has killed the murderer.", TAG, sColorName, sName, iAttacker);
				GetClientColor(client, {1, 3, 3, 7}, true, true, sColorName, sName);
				PrintToChatAll("%s \x0BBystanders win!\x01 The murderer was %s%s, %N", TAG, sColorName, sName, client);
			}
			else 
			{
				GetClientColor(client, {1, 3, 3, 7}, true, true, sColorName, sName);
				PrintToChatAll("%s The Murder %s%s, %N\x01 has died from mysterious circumstances.", TAG, sColorName, sName, client);
			}
		}
		else if (iAttacker != client && iAttacker != gI_Murderer && IsValidClient(iAttacker, false))
		{
			FadePlayer(client, 100, 3000, 0x0009, {0, 0, 0, 255});
			
			char[] sColorName = new char[20]; 
			char[] sName = new char[MAX_NAME_LENGTH];
			GetClientColor(iAttacker, {1, 3, 3, 7}, true, true, sColorName, sName);
			
			PrintToChatAll("%s %s%s\x01 killed an innocent bystander!", TAG, sColorName, sName);
			SetEntPropFloat(iAttacker, Prop_Data, "m_flLaggedMovementValue", 0.4);
			FadePlayer(iAttacker, 100, 15000, 0x0009, {0, 0, 0, 240});
			
			int iWeapon = GetPlayerWeaponSlot(iAttacker, CS_SLOT_SECONDARY);
			if (iWeapon != -1) CS_DropWeapon(iAttacker, iWeapon, false, true);
			
			gB_Punished[iAttacker] = true;
			SetEntProp(iAttacker, Prop_Send, "m_iHideHUD", (1<<2));
			CreateTimer(30.0, Timer_Punish, GetClientUserId(iAttacker), TIMER_FLAG_NO_MAPCHANGE);
		}
		else FadePlayer(client, 100, 3000, 0x0009, {0, 0, 0, 255});
		
		int iRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		if (IsValidEdict(iRagdoll)) AcceptEntityInput(iRagdoll, "Kill");

		float fOrigin[3]; GetClientAbsOrigin(client, fOrigin);
		float fAngles[3]; GetClientAbsAngles(client, fAngles);
		float fVelocity[3]; GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);
		
		int iColor[4]; GetClientColor(client, iColor);

		int iEntity = CreateEntityByName("prop_ragdoll");
		
		if (IsValidEntity(iEntity))
		{
			char[] sPlayerModel = new char[PLATFORM_MAX_PATH];
			GetClientModel(client, sPlayerModel, PLATFORM_MAX_PATH);
			DispatchKeyValue(iEntity, "model", sPlayerModel);
			
			ActivateEntity(iEntity);
			
			if (DispatchSpawn(iEntity))
			{
				float fSpeed = GetVectorLength(fVelocity);
				
				if (fSpeed >= 500)
					TeleportEntity(iEntity, fOrigin, fAngles, NULL_VECTOR);
				else
					TeleportEntity(iEntity, fOrigin, fAngles, fVelocity);
				
				SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 2);
				SetEntProp(iEntity, Prop_Send, "m_hOwnerEntity", client);
				SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
				SetEntityRenderColor(iEntity, iColor[0], iColor[1], iColor[2], iColor[3]);
			}
		}
	}
	
	int iPlayers = 0;
	LoopValidClients(i, false) ++iPlayers;
	
	if (iPlayers == 1)
	{
		if (IsValidClient(gI_Murderer, false))
			CS_TerminateRound(7.0, CSRoundEnd_TerroristWin, true);
		else
			CS_TerminateRound(7.0, CSRoundEnd_CTWin, true);
	}
}

public void Event_PlayerFootstep(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	if (IsValidClient(client, false) && IsValidClient(gI_Murderer, false))
	{
		float fOrigin[3]; GetClientAbsOrigin(client, fOrigin);
		int iColor[4]; GetClientColor(client, iColor);
		TE_SetupBeamRingPoint(fOrigin, 2.0, 0.01, gI_Precaches[0], gI_Precaches[1], 0, 0, gCV_Footsteps_Life.FloatValue, 2.0, 0.0, iColor, 0, 0);
		TE_SendToClient(gI_Murderer);
	}
}

public void Event_WeaponFire(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	if (IsValidClient(client, false))
	{
		int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
		if (iWeapon != -1) SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 1);
	}
}

public Action Event_Stop(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	hEvent.BroadcastDisabled = true;
	return Plugin_Changed;
}

public Action Event_SoundEmitted(int clients[64], int &numClients, char sSample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags) 
{
	if (StrEqual(sSample, "~)weapons/hegrenade/he_bounce-1.wav"))
		return Plugin_Handled;
	return Plugin_Continue;
}


/*===============================================================================================================================*/
/********************************************************* [TIMERS] **************************************************************/
/*===============================================================================================================================*/


public Action Timer_Spawn(Handle hTimer, int iUser)
{
	int client = GetClientOfUserId(iUser);
	
	if (gB_Round && IsValidClient(client, false))
	{ 
		int iColor[4]; GetClientColor(client, iColor);
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, iColor[0], iColor[1], iColor[2], iColor[3]);
		SetEntProp(client, Prop_Send, "m_iHideHUD", (1 << 12)|(1 << 13));
		
		RemoveAllWeapons(client);
		GivePlayerItem(client, "weapon_decoy");
		
		if (client == gI_Murderer)
		{
			GivePlayerItem(client, "weapon_knife");
			PrintToChat(client, "%s You are the \x07Murderer\x01!", TAG);
			PrintToChat(client, "%s Kill everyone and don't get caught!", TAG);
		}
		else if (client == gI_Detective)
		{
			int iEquipped = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			int iWeapon = GivePlayerItem(client, "weapon_revolver");
			SetEntData(iWeapon, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"), 1);
			SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iEquipped);
			PrintToChat(client, "%s You are a \x0CSpecial Bystander\x01!", TAG);
			PrintToChat(client, "%s There is a \x07Murderer\x01 on the loose, find and kill him!", TAG);
		}
		else
		{
			PrintToChat(client, "%s You are a \x0BBystander\x01!", TAG);
			PrintToChat(client, "%s There is a \x07Murderer\x01 on the loose, don't get killed!", TAG);
		}
	}
}

public Action Timer_Hud(Handle hTimer)
{
	if (gI_Players >= gCV_Players_Needed.IntValue)
	{
		float fVecDirection[3];
		float fVecPos[3];
		float fVecPos2[3];
		float fVecVel[3];
		float fAngles[3];
		
		char[] sHint = new char[200];
		char[] sWeapon = new char[32];
		
		LoopValidClients(i, true)
		{
			if (gB_Round)
			{
				if (IsClientObserver(i))
				{
					if (GetEntProp(i, Prop_Send, "m_iObserverMode") >= 3)
					{
						int iObserver = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
	
						if (IsValidClient(iObserver, false) && gS_ColoredName[iObserver][0] != '\0')
							PrintHintText(i, "<font size='20'>%s</font>\nClues: <font color='#00FF00'>%i</font></font>", gS_ColoredName[iObserver], gI_Items[iObserver]);
					}
					continue;
				}
				
				if (IsPlayerAlive(i))
				{
					GetClientWeapon(i, sWeapon, 32);
					
					if (sWeapon[7] == 'd' && sWeapon[8] == 'e')
					{
						SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);  
						SetEntProp(i, Prop_Send, "m_bDrawViewmodel", false);
					}
					else 
					{
						SetEntProp(i, Prop_Send, "m_bDrawViewmodel", true);
						
						if (sWeapon[7] == 'k' && sWeapon[8] == 'n')
							SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.2);  	
					}
					
					if (ValidGrab(i))
					{
						GetClientEyeAngles(i, fAngles);
						GetAngleVectors(fAngles, fVecDirection, NULL_VECTOR, NULL_VECTOR);
						GetClientEyePosition(i, fVecPos);
		
						fVecPos2 = fVecPos;
						fVecPos[0] += fVecDirection[0] * gF_GrabDistance[i];
						fVecPos[1] += fVecDirection[1] * gF_GrabDistance[i];
						fVecPos[2] += fVecDirection[2] * gF_GrabDistance[i];
		
						GetEntPropVector(gI_GrabEntity[i], Prop_Send, "m_vecOrigin", fVecDirection);
		
						gF_GrabTime[i] = GetGameTime() + 1.0;
		
						SubtractVectors(fVecPos, fVecDirection, fVecVel);
						ScaleVector(fVecVel, 10.0);
		
						TeleportEntity(gI_GrabEntity[i], NULL_VECTOR, NULL_VECTOR, fVecVel);
					}
					
					if (gS_ColoredName[i][0] != '\0')
					{
						strcopy(sHint, 200, "<font face='Stratum2'>");
						Format(sHint, 200, "%sName: %s</font>\n", sHint, gS_ColoredName[i]);
						Format(sHint, 200, "%sRole: %s\n", sHint, (i == gI_Murderer)? "<font color='#D72929\'>Murderer</font>":"<font color='#3172CB'>Bystander</font>");
					
						int iTarget = GetClientAimTarget(i, false);
						
						if (IsValidEntity(iTarget)) 
						{
							if (!IsValidClient(iTarget)) 
							{
								int entity = GetEntProp(iTarget, Prop_Send, "m_hOwnerEntity", 4);
								if (IsValidEntity(entity)) Format(sHint, 200, "%sTarget: %s</font>", sHint, gS_ColoredName[entity]);
							}
							else Format(sHint, 200, "%sTarget: %s</font>", sHint, gS_ColoredName[iTarget]);
						}
				
						Format(sHint, 200, "%s</font>", sHint);
						PrintHintText(i, sHint);
					}
					else continue;
					
					if (gF_SmokeTime <= GetGameTime() && i == gI_Murderer)
					{
						float fOrigin[3];
						GetClientAbsOrigin(i, fOrigin);
						fOrigin[2] += 16;
						TE_SetupSmoke(fOrigin, gI_Precaches[2], 2.6, 0); 
						TE_SendToAll(0.0);	
					}
				}
			}
			else 
			{
				switch (gI_Winner)
				{
					case 2: PrintCenterText(i, "<font size='25'><font color='#A51818'>Murderer Wins!</font></font>");
					case 3: PrintCenterText(i, "<font size='25'><font color='#187FA5'>Bystanders Win!</font></font>");
				}
			}
		}
		
		if (IsValidEdict(gI_Knife))
		{
			float fOrigin[3];
			GetEntPropVector(gI_Knife, Prop_Send, "m_vecOrigin", fOrigin);
			TE_SetupSmoke(fOrigin, gI_Precaches[2], 2.0, 0); 
			TE_SendToAll(0.0);		
		}
	}
}

public Action Timer_Knife(Handle hTimer, DataPack hData)
{
	gH_KnifeTimer = null;
	hData.Reset();
	
	int iKnife = EntRefToEntIndex(hData.ReadCell());
	int client = GetClientOfUserId(hData.ReadCell());
	int iRound = hData.ReadCell();
	
	if (iKnife == gI_Knife && IsValidClient(client, false) && GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == -1 && iRound == gI_Round)
	{
		if (IsValidEdict(iKnife))
		{
			gI_Knife = -1;
			AcceptEntityInput(iKnife, "Kill");
		}
		GivePlayerItem(client, "weapon_knife");
	}
}

public Action Timer_Punish(Handle hTimer, int iUser)
{
	int client = GetClientOfUserId(iUser);
	
	if (IsValidClient(client, false) && gB_Punished[client])
	{
		gB_Punished[client] = false;
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") & ~(1<<2));
	}
}

public Action Timer_Allow(Handle hTimer, int iRound)
{
	if (gI_Round == iRound && gB_Round)
	{
		gB_Allow = true;
		SQL_LoadProps();
		CreateTimer(gCV_Prop_Respawn.FloatValue, Timer_Props, gI_Round, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_Props(Handle hTimer, int iRound)
{
	if (gI_Round != iRound || !gB_Round || !IsValidClient(gI_Murderer, false))
		return Plugin_Stop;
		
	for (int i = 0; i <= gI_ValidProps; ++i)
	{
		if (IsValidEdict(gI_Prop[i]))
		{
			gI_PropID[i] = -1;
			AcceptEntityInput(gI_Prop[i], "Kill");
		}
	}
	
	gI_ValidProps = 0;
	
	SQL_LoadProps();	
	return Plugin_Continue;
}

public Action Timer_RetrySpawning(Handle hTimer, int iRound)
{
	if (gI_Round == iRound && gB_Round)
		SQL_LoadProps();	
}


/*===============================================================================================================================*/
/********************************************************* [COMMANDS] ************************************************************/
/*===============================================================================================================================*/
  

public Action CL_LAW(int client, char[] sCommand, int args)
{
	if (IsValidClient(client, false))
		SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") ^ 4);
	return Plugin_Handled;
}

public Action CL_Block(int client, char[] sCommand, int args) 
{
	return Plugin_Handled;
}

public Action Cmd_MurderInfo(int client, int args)
{
	if (IsValidClient(client))
	{
		PrintToChat(client, "%s Check your console for the information.", TAG);
		PrintToConsole(client, "\n\n*************************[Murder]*****************************\n");		
		PrintToConsole(client,
		"Author: LenHard\
		\nVersion: %s\
		\nContact: steamcommunity.com/id/TheOfficalLenHard\
		\n\nA gamemode of deception and murder, based off of Murder in the Dark. \
		One person is a murderer with a knife, who is trying to secretly kill off the other players. \
		The other players must use their wits to find out who it is and kill them first. \
		Unfortunately, they only have the one gun between them.", VERSION);
		PrintToConsole(client, "\n***************************************************************\n");		
	}		
	return Plugin_Handled;
}

public Action Cmd_Voice(int client, int args)
{
	if (IsValidClient(client))
	{
		if (IsPlayerAlive(client))
			DisplayRadioMenu(client);
		else 
			PrintToChat(client, "%s You must be alive to use the voice commands!", TAG);
	}
	return Plugin_Handled;
}

public Action Cmd_PropsMenu(int client, int args)
{
	if (IsValidClient(client))
		DisplayPropsMenu(client, false);
	return Plugin_Handled;
}

public Action Cmd_SpawnMenu(int client, int args)
{
	if (IsValidClient(client))
		DisplaySpawnMenu(client, false);
	return Plugin_Handled;
}

public Action Cmd_DeleteMenu(int client, int args)
{
	if (IsValidClient(client))
		DisplayDeleteMenu(client, false);
	return Plugin_Handled;
}


/*===============================================================================================================================*/
/********************************************************* [ADMINMENU] ***********************************************************/
/*===============================================================================================================================*/


public void OnAdminMenuReady(Handle hMenu)
{
	if (gB_AdminMenu)
	{
		TopMenu hTopMenu = TopMenu.FromHandle(hMenu);
	
		if (hTopMenu != gT_TopMenu)
		{
			gT_TopMenu = hTopMenu;
			
			TopMenuObject hCommands = gT_TopMenu.AddCategory("Murder Commands", CategoryHandler);
			
			if (hCommands != INVALID_TOPMENUOBJECT)
			{
				gT_TopMenu.AddItem("sm_addprops", AdminMenu_AddProps, hCommands, "sm_rcon", ADMFLAG_RCON);
				gT_TopMenu.AddItem("sm_spawnprops", AdminMenu_SpawnProps, hCommands, "sm_rcon", ADMFLAG_RCON);
				gT_TopMenu.AddItem("sm_deleteprops", AdminMenu_DeleteProps, hCommands, "sm_rcon", ADMFLAG_RCON);
			}
		}
	}
}

public void CategoryHandler(TopMenu hTopMenu, TopMenuAction hAction, TopMenuObject hObject, int client, char[] sBuffer, int iMaxlength)
{
	switch (hAction)
	{
		case TopMenuAction_DisplayTitle: FormatEx(sBuffer, iMaxlength, "Murder Commands:");
		case TopMenuAction_DisplayOption: FormatEx(sBuffer, iMaxlength, "Murder Commands");
	}
}

public int AdminMenu_AddProps(TopMenu hTopMenu, TopMenuAction hAction, TopMenuObject hObject, int client, char[] sBuffer, int iMaxlength)
{
	switch (hAction)
	{
		case TopMenuAction_DisplayOption: FormatEx(sBuffer, iMaxlength, "Add Props");
		case TopMenuAction_SelectOption: DisplayPropsMenu(client, true);
	}
}

public int AdminMenu_SpawnProps(TopMenu hTopMenu, TopMenuAction hAction, TopMenuObject hObject, int client, char[] sBuffer, int iMaxlength)
{
	switch (hAction)
	{
		case TopMenuAction_DisplayOption: FormatEx(sBuffer, iMaxlength, "Spawn Props");
		case TopMenuAction_SelectOption: DisplaySpawnMenu(client, true);
	}
}

public int AdminMenu_DeleteProps(TopMenu hTopMenu, TopMenuAction hAction, TopMenuObject hObject, int client, char[] sBuffer, int iMaxlength)
{
	switch (hAction)
	{
		case TopMenuAction_DisplayOption: FormatEx(sBuffer, iMaxlength, "Delete Props");
		case TopMenuAction_SelectOption: DisplayDeleteMenu(client, true);
	}
}


/*===============================================================================================================================*/
/********************************************************* [MENUS] ***************************************************************/
/*===============================================================================================================================*/


void DisplayPropsMenu(int client, bool bBackButton)
{
	char[] sModels = new char[128];
	char[] sModelPath = new char[PLATFORM_MAX_PATH];
	char[] sBuffer = new char[350];
	
	Menu hMenu = new Menu(Menu_Props);
	hMenu.SetTitle("Add Props\n ");
	
	for (int i = 0; i < gA_ModelName.Length; ++i)
	{
		gA_ModelName.GetString(i, sModels, 128);
		gA_ModelPath.GetString(i, sModelPath, PLATFORM_MAX_PATH);
		FormatEx(sBuffer, 350, "%s;%s", sModels, sModelPath);
		hMenu.AddItem(sBuffer, sModels);	
	}
	
	if (hMenu.ItemCount == 0)
	{
		PrintToChat(client, "%s The Prop menu is empty!", TAG);
		delete hMenu;	
	}
	else
	{
		hMenu.ExitBackButton = bBackButton;
		hMenu.Display(client, MENU_TIME_FOREVER);
	}
}

public int Menu_Props(Menu hMenu, MenuAction hAction, int client, int iParam)
{	
	switch (hAction)
	{
		case MenuAction_Select:
		{
			if (IsValidClient(client))
			{
				char[] sModel = new char[PLATFORM_MAX_PATH];
				hMenu.GetItem(iParam, sModel, PLATFORM_MAX_PATH);
				DisplaySetsMenu(client, sModel);
			}
		}
		case MenuAction_Cancel: if (iParam == MenuCancel_ExitBack && gT_TopMenu != null && IsValidClient(client)) gT_TopMenu.Display(client, TopMenuPosition_LastCategory);
		case MenuAction_End: delete hMenu;
	}
}

void DisplaySetsMenu(int client, char[] sModel)
{
	Menu hMenu = new Menu(Menu_Sets);
	hMenu.SetTitle("Prop Set\n ");
	hMenu.AddItem(sModel, "Set #0");
	hMenu.AddItem(sModel, "Set #1");
	hMenu.AddItem(sModel, "Set #2");
	hMenu.AddItem(sModel, "Set #3");
	hMenu.AddItem(sModel, "Set #4");
	hMenu.AddItem(sModel, "Set #5");
	hMenu.ExitBackButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Sets(Menu hMenu, MenuAction hAction, int client, int iParam)
{
	switch (hAction)
	{
		case MenuAction_Select:
		{			
			if (IsValidClient(client, false))
			{
				char[] sInfo = new char[350];
				hMenu.GetItem(iParam, sInfo, 350);		
				
				char[][] sBuffer = new char[2][350];
				ExplodeString(sInfo, ";", sBuffer, 2, 350);
				
				float fAngles[3], fOrigin[3]; 
				GetClientAbsAngles(client, fAngles);
				SpawnProp(client, sBuffer[0], sBuffer[1], fAngles, fOrigin, iParam);
			}
		}
		case MenuAction_Cancel: if (iParam == MenuCancel_ExitBack && IsValidClient(client)) DisplayPropsMenu(client, true);
		case MenuAction_End: delete hMenu;
	}
}

void DisplaySpawnMenu(int client, bool bBackButton)
{		
	Menu hMenu = new Menu(Menu_SpawnMenu);
	hMenu.SetTitle("Props Spawner\n ");
	hMenu.AddItem("", "Set #0");
	hMenu.AddItem("", "Set #1");
	hMenu.AddItem("", "Set #2");
	hMenu.AddItem("", "Set #3");
	hMenu.AddItem("", "Set #4");
	hMenu.AddItem("", "Set #5");
	hMenu.ExitBackButton = bBackButton;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_SpawnMenu(Menu hMenu, MenuAction hAction, int client, int iParam)
{	
	switch (hAction)
	{
		case MenuAction_Select: 
		{
			if (IsValidClient(client))
			{
				char[] sMap = new char[100];
				GetCurrentMap(sMap, 100);
				
				char[] sQuery = new char[200];
				FormatEx(sQuery, 200, "SELECT * FROM `Murder` WHERE `Map` = \"%s\" AND `Set` = %i;", sMap, iParam);
				gD_Database.Query(SQL_Spawn_Callback, sQuery, GetClientUserId(client));
			}
		}
		case MenuAction_Cancel: if (iParam == MenuCancel_ExitBack && gT_TopMenu != null && IsValidClient(client)) gT_TopMenu.Display(client, TopMenuPosition_LastCategory);
		case MenuAction_End: delete hMenu;
	}
}

public int Menu_SpawnCallback(Menu hMenu, MenuAction hAction, int client, int iParam)
{	
	switch (hAction)
	{
		case MenuAction_Select: 
		{
			if (IsValidClient(client, false))
			{
				char[] sInfo = new char[350];
				hMenu.GetItem(iParam, sInfo, 350);		
				
				char[][] sBuffer = new char[8][350];
				ExplodeString(sInfo, ";", sBuffer, 8, 350);
				
				int iSet = StringToInt(sBuffer[1]);
				float fAngles[3], fOrigin[3]; 
				fOrigin[0] = StringToFloat(sBuffer[4]);
				fOrigin[1] = StringToFloat(sBuffer[5]);
				fOrigin[2] = StringToFloat(sBuffer[6]);
				fAngles[1] = StringToFloat(sBuffer[7]);
				SpawnProp(0, sBuffer[2], sBuffer[3], fAngles, fOrigin, iSet, StringToInt(sBuffer[0]));
				
				PrintToChat(client, "%s The Prop \x04'%s'\x01 in Set \x04%i\x01 has spawned!", TAG, sBuffer[2], iSet);
				
				char[] sMap = new char[100];
				GetCurrentMap(sMap, 100);
				
				char[] sQuery = new char[200];
				FormatEx(sQuery, 200, "SELECT * FROM `Murder` WHERE `Map` = \"%s\" AND `Set` = %i;", sMap, iSet);
				gD_Database.Query(SQL_Spawn_Callback, sQuery, GetClientUserId(client));
			}
		}
		case MenuAction_Cancel: if (iParam == MenuCancel_ExitBack && IsValidClient(client)) DisplaySpawnMenu(client, true);
		case MenuAction_End: delete hMenu;
	}
}

void DisplayDeleteMenu(int client, bool bBackButton)
{	
	gB_Delete[client] = true;
	Menu hMenu = new Menu(Menu_DeleteMenu);
	hMenu.SetTitle("Props Deletion\nAim at a Prop & Press E to delete it!\nThere is no going back!\n ");
	hMenu.AddItem("", "Stop Deleting");
	hMenu.ExitBackButton = bBackButton;
	hMenu.ExitButton = false;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_DeleteMenu(Menu hMenu, MenuAction hAction, int client, int iParam)
{	
	switch (hAction)
	{
		case MenuAction_Select:
		{
			if (IsValidClient(client)) 
			{
				gB_Delete[client] = false;
				PrintToChat(client, "%s You have ended the deletion process.", TAG);
			}
		}
		case MenuAction_Cancel: 
		{
			if (IsValidClient(client))
			{
				gB_Delete[client] = false;
				PrintToChat(client, "%s The deletion process has ended.", TAG);
				
				if (iParam == MenuCancel_ExitBack && gT_TopMenu != null) 
					gT_TopMenu.Display(client, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End: delete hMenu;
	}
}

void DisplayRadioMenu(int client)
{
	char[] sName = new char[128];
	char[] sPath = new char[PLATFORM_MAX_PATH];
	
	Menu hMenu = new Menu(Menu_Radio);
	hMenu.SetTitle("[Murder] Voice Commands\n ");
	
	for (int i = 0; i < gA_RadioName.Length; ++i)
	{
		gA_RadioName.GetString(i, sName, 128);
		gA_RadioPath.GetString(i, sPath, PLATFORM_MAX_PATH);
		hMenu.AddItem(sPath, sName);	
	}
	
	if (hMenu.ItemCount == 0)
	{
		PrintToChat(client, "%s The Voice Menu is empty.", TAG);
		delete hMenu;
	}
	else hMenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Radio(Menu hMenu, MenuAction hAction, int client, int iParam)
{	
	switch (hAction)
	{
		case MenuAction_Select: 
		{
			if (IsValidClient(client, false))
			{
				if (gB_Allow)
				{
					float fGameTime = GetGameTime();
					
					if (gF_RadioDelay[client] <= fGameTime)
					{
						char[] sInfo = new char[PLATFORM_MAX_PATH]; 
						hMenu.GetItem(iParam, sInfo, PLATFORM_MAX_PATH);
						EmitSoundToAllAny(sInfo, client);
						gF_RadioDelay[client] = fGameTime + gCV_Radio_Delay.FloatValue;
					}
					else PrintToChat(client, "%s Wait \x04%.02f\x01 seconds before accessing the voice commands!", TAG, gF_RadioDelay[client] - fGameTime);
				}
				else PrintToChat(client, "%s You can't use the voice commands before the game starts!", TAG);
			}
		}
		case MenuAction_End: delete hMenu;
	}
}

public int Menu_RoundData(Menu hMenu, MenuAction hAction, int client, int iParam)
{	
	if (hAction == MenuAction_End && hMenu != null)
		delete hMenu;
}


/*===============================================================================================================================*/
/********************************************************* [SQL] *****************************************************************/
/*===============================================================================================================================*/


void SQL_LoadDatabase()
{
	if (gD_Database != null)
		delete gD_Database;
	
	char[] sError = new char[255];
	
	if (!(gD_Database = SQL_Connect("Murder", true, sError, 255)))
		SetFailState(sError);
	
	gD_Database.SetCharset("utf8mb4");
	gD_Database.Query(SQL_Error, "CREATE TABLE IF NOT EXISTS `Murder` (`ID` int(20) NOT NULL AUTO_INCREMENT, `Set` int(3) NOT NULL, `Map` VARCHAR(100) NOT NULL, `Name` VARCHAR(50) NOT NULL, `Model` VARCHAR(256) NOT NULL, `X` FLOAT NOT NULL, `Y` FLOAT NOT NULL, `Z` FLOAT NOT NULL, `Angle` FLOAT NOT NULL, PRIMARY KEY (`ID`)) AUTO_INCREMENT=1", 1);
}

void SQL_LoadProps()
{	
	if (gD_Database != null)
	{
		char[] sMap = new char[150];
		GetCurrentMap(sMap, 150);
		
		int Set = GetRandomInt(0, 5);
		
		char[] sQuery = new char[200];
		FormatEx(sQuery, 200, "SELECT * FROM `Murder` WHERE `Map` = \"%s\" AND `Set` = %i;", sMap, Set);
		gD_Database.Query(SQL_LoadProps_Callback, sQuery, Set);
	}
	else 
	{
		LogError("The Database turned null! Reconnecting...");
		SQL_LoadDatabase();
	}
}

public void SQL_LoadProps_Callback(Database db, DBResultSet Results, char[] sError, int iData)
{
	if (Results == null || Results.RowCount == 0)
	{
		CreateTimer(1.0, Timer_RetrySpawning, gI_Round, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}
	
	char[] sModel = new char[PLATFORM_MAX_PATH];
	char[] sName = new char[50];
	float fOrigin[3], fAngles[3];
	
	while (Results.FetchRow())
	{
		Results.FetchString(3, sName, 50);
		Results.FetchString(4, sModel, PLATFORM_MAX_PATH);
		fOrigin[0] = Results.FetchFloat(5);
		fOrigin[1] = Results.FetchFloat(6);
		fOrigin[2] = Results.FetchFloat(7);
		fAngles[1] = Results.FetchFloat(8);
		SpawnProp(0, sName, sModel, fAngles, fOrigin, Results.FetchInt(1), Results.FetchInt(0));
	}
}

void SQL_SaveProps(int Set, char[] sName, char[] Model, float fAngles, float fOrigin[3])
{
	if (gD_Database != null)
	{
		char[] sMap = new char[PLATFORM_MAX_PATH];
		GetCurrentMap(sMap, PLATFORM_MAX_PATH);
		
		char[] sQuery = new char[400]; 	
		FormatEx(sQuery, 400, "INSERT INTO `Murder` (`Set`, `Map`, `Name`, `Model`, `X`, `Y`, `Z`, `Angle`) VALUES (%i, \"%s\", \"%s\", \"%s\", %f, %f, %f, %f);", Set, sMap, sName, Model, fOrigin[0], fOrigin[1], fOrigin[2], fAngles);
		gD_Database.Query(SQL_Error, sQuery);
	}
	else 
	{
		LogError("The Database turned null! Reconnecting...");
		SQL_LoadDatabase();
	}
}

void SQL_DeleteProp(int ID)
{	
	if (gD_Database != null)
	{
		char[] sMap = new char[PLATFORM_MAX_PATH];
		GetCurrentMap(sMap, PLATFORM_MAX_PATH);
		
		char[] sQuery = new char[200];
		FormatEx(sQuery, 200, "DELETE FROM `Murder` WHERE `Map` = \"%s\" AND `ID` = %i;", sMap, ID);
		gD_Database.Query(SQL_Error, sQuery);
	}
	else 
	{
		LogError("The Database turned null! Reconnecting...");
		SQL_LoadDatabase();
	}
}

public void SQL_Spawn_Callback(Database db, DBResultSet Results, char[] sError, int iUser)
{
	int client = GetClientOfUserId(iUser);
	
	if (IsValidClient(client))
	{
		if (Results == null)
		{
			PrintToChat(client, "%s \x04Error: \x01%s", TAG, sError);
			ThrowError(sError);
		}
		else if (Results.RowCount == 0)
		{
			PrintToChat(client, "%s There are no Props in this set!", TAG);
			DisplaySpawnMenu(client, true);
		}
		else
		{
			char[] sBuffer = new char[350];
			char[] sName = new char[50];
			char[] sModel = new char[PLATFORM_MAX_PATH];
			
			Menu hMenu = new Menu(Menu_SpawnCallback);
			hMenu.SetTitle("Props available\n ");
			
			while (Results.FetchRow())
			{
				Results.FetchString(3, sName, 50);
				Results.FetchString(4, sModel, PLATFORM_MAX_PATH);
				FormatEx(sBuffer, 350, "%i;%i;%s;%s;%f;%f;%f;%f", Results.FetchInt(0), Results.FetchInt(1), sName, sModel, Results.FetchFloat(5), Results.FetchFloat(6), Results.FetchFloat(7), Results.FetchFloat(8));
				hMenu.AddItem(sBuffer, sName);
			}
			hMenu.ExitBackButton = true;
			hMenu.Display(client, MENU_TIME_FOREVER);
		}
	}
}

public void SQL_Error(Database db, DBResultSet Results, char[] sError, int iData) 
{
	if (Results == null) ThrowError(sError);
}


/*===============================================================================================================================*/
/********************************************************* [CALLBACKS] ***********************************************************/
/*===============================================================================================================================*/


void SpawnProp(int client, char[] sName, char[] sModel, float fAngles[3], float fOrigin[3], int Set = -1, int ID = -1)
{
	bool bValidClient = false;
	
	if (IsValidClient(client, false))
	{
		bValidClient = true;
		
		float fCOrigin[3]; GetClientEyePosition(client, fCOrigin);
		float fCAngles[3]; GetClientEyeAngles(client, fCAngles);

		Handle hTraceRay = TR_TraceRayFilterEx(fCOrigin, fCAngles, MASK_PLAYERSOLID, RayType_Infinite, FilterPlayers);

		if (TR_DidHit(hTraceRay)) TR_GetEndPosition(fOrigin, hTraceRay);
		delete hTraceRay;
	}
	
	int iEnt = CreateEntityByName("prop_physics_override");
	
	if (IsValidEntity(iEnt))
	{
		DispatchKeyValue(iEnt, "Model", sModel);
		
		if (DispatchSpawn(iEnt))
		{
			TeleportEntity(iEnt, fOrigin, fAngles, NULL_VECTOR);

			int iGlow = CreateEntityByName("prop_dynamic_glow");
			
			if (IsValidEntity(iGlow))
			{
				DispatchKeyValue(iGlow, "Model", sModel);
				DispatchKeyValue(iGlow, "disablereceiveshadows", "1");
				DispatchKeyValue(iGlow, "disableshadows", "1");
				DispatchKeyValue(iGlow, "solid", "0");
				DispatchKeyValue(iGlow, "spawnflags", "256");
				
				if (DispatchSpawn(iGlow))
				{
					SetEntProp(iGlow, Prop_Send, "m_CollisionGroup", 11);
					SetEntProp(iGlow, Prop_Send, "m_bShouldGlow", true, true);
					SetEntProp(iGlow, Prop_Send, "m_nGlowStyle", 3);
					SetEntPropFloat(iGlow, Prop_Send, "m_flGlowMaxDist", 300.0);
					TeleportEntity(iGlow, fOrigin, fAngles, NULL_VECTOR);
					
					SetVariantColor({50, 255, 50, 255});
					AcceptEntityInput(iGlow, "SetGlowColor");
					
					SetVariantString("!activator");
					AcceptEntityInput(iGlow, "SetParent", iEnt);
				}
			}	
		}
		
		++gI_ValidProps;
		gI_Prop[gI_ValidProps] = iEnt;
		gI_PropID[gI_ValidProps] = ID;
	}
	
	if (bValidClient)
	{
		PrintToChat(client, "%s You added the prop '\x04%s\x01' in set \x04%i\x01.", TAG, sName, Set);
		SQL_SaveProps(Set, sName, sModel, fAngles[1], fOrigin);
		Cmd_PropsMenu(client, 0);
	}
}

void GetClientColor(int client, int iColor[4], bool bColorName = false, bool bSymbol = false, char sColor[] = "", char[] sName = "")
{
	if (StrContains(gS_ColoredName[client], "800080") != -1)
	{ 
		if (bColorName)
		{
			if (bSymbol)
				FormatEx(sColor,  20, "\x03");
			else
				FormatEx(sColor, 20, "Purple");
		}
		else
		{			
			iColor[0] = 128;
			iColor[1] = 0;
			iColor[2] = 128;
		}
		
		strcopy(sName, MAX_NAME_LENGTH, gS_ColoredName[client]);
		ReplaceString(sName, MAX_NAME_LENGTH, "<font color='#800080'>", "");
	}
	else if (StrContains(gS_ColoredName[client], "FFFF00") != -1)
	{ 
		if (bColorName)
		{
			if (bSymbol)
				FormatEx(sColor, 20, "\x09");
			else
				FormatEx(sColor, 20, "Yellow");
		}
		else
		{
			iColor[0] = 255;
			iColor[1] = 255;
			iColor[2] = 0;
		}
		
		strcopy(sName, MAX_NAME_LENGTH, gS_ColoredName[client]);
		ReplaceString(sName, MAX_NAME_LENGTH, "<font color='#FFFF00'>", "");
	}
	else if (StrContains(gS_ColoredName[client], "FF00FF") != -1)
	{ 
		if (bColorName)
		{
			if (bSymbol)
				FormatEx(sColor, 20, "\x0E");
			else
				FormatEx(sColor, 20, "Pink");
		}
		else
		{
			iColor[0] = 255;
			iColor[1] = 0;
			iColor[2] = 255;
		}
		
		strcopy(sName, MAX_NAME_LENGTH, gS_ColoredName[client]);
		ReplaceString(sName, MAX_NAME_LENGTH, "<font color='#FF00FF'>", "");
	}
	else if (StrContains(gS_ColoredName[client], "00FF00") != -1)
	{ 
		if (bColorName)
		{
			if (bSymbol)
				FormatEx(sColor, 20, "\x04");
			else
				FormatEx(sColor, 20, "Green");
		}
		else
		{
			iColor[0] = 0;
			iColor[1] = 255;
			iColor[2] = 0;
		}
		
		strcopy(sName, MAX_NAME_LENGTH, gS_ColoredName[client]);
		ReplaceString(sName, MAX_NAME_LENGTH, "<font color='#00FF00'>", "");
	}
	else if (StrContains(gS_ColoredName[client], "FF0000") != -1)
	{ 
		if (bColorName)
		{
			if (bSymbol)
				FormatEx(sColor, 20, "\x02");
			else
				FormatEx(sColor, 20, "Red");
		}
		else
		{
			iColor[0] = 255;
			iColor[1] = 0;
			iColor[2] = 0;
		}
		
		strcopy(sName, MAX_NAME_LENGTH, gS_ColoredName[client]);
		ReplaceString(sName, MAX_NAME_LENGTH, "<font color='#FF0000'>", "");
	}
	else if (StrContains(gS_ColoredName[client], "0000FF") != -1)
	{ 
		if (bColorName)
		{
			if (bSymbol)
				FormatEx(sColor, 20, "\x0C");
			else
				FormatEx(sColor, 20, "Blue");
		}
		else
		{
			iColor[0] = 70;
			iColor[1] = 70;
			iColor[2] = 221;
		}
		
		strcopy(sName, MAX_NAME_LENGTH, gS_ColoredName[client]);
		ReplaceString(sName, MAX_NAME_LENGTH, "<font color='#0000FF'>", "");
	}
	else if (StrContains(gS_ColoredName[client], "A7DE35") != -1)
	{ 
		if (bColorName)
		{
			if (bSymbol)
				FormatEx(sColor, 20, "\x06");
			else
				FormatEx(sColor, 20, "Olive");
		}
		else
		{
			iColor[0] = 167;
			iColor[1] = 222;
			iColor[2] = 53;
		}
		
		strcopy(sName, MAX_NAME_LENGTH, gS_ColoredName[client]);
		ReplaceString(sName, MAX_NAME_LENGTH, "<font color='#A7DE35'>", "");
	}
	else if (StrContains(gS_ColoredName[client], "E36E27") != -1)
	{ 
		if (bColorName)
		{
			if (bSymbol)
				FormatEx(sColor, 20, "\x10");
			else
				FormatEx(sColor, 20, "Orange");
		}
		else
		{
			iColor[0] = 227;
			iColor[1] = 110;
			iColor[2] = 39;
		}
		
		strcopy(sName, MAX_NAME_LENGTH, gS_ColoredName[client]);
		ReplaceString(sName, MAX_NAME_LENGTH, "<font color='#E36E27'>", "");
	}
	else if (StrContains(gS_ColoredName[client], "DC381F") != -1)
	{ 
		if (bColorName)
		{
			if (bSymbol)
				FormatEx(sColor, 20, "\x07");
			else
				FormatEx(sColor, 20, "Brown");
		}
		else
		{
			iColor[0] = 220;
			iColor[1] = 56;
			iColor[2] = 31;
		}
		
		strcopy(sName, MAX_NAME_LENGTH, gS_ColoredName[client]);
		ReplaceString(sName, MAX_NAME_LENGTH, "<font color='#DC381F'>", "");
	}
	iColor[3] = 255;
}

int GetRandomPlayer()
{
	int iClients[MAXPLAYERS + 1] = {-1, ...};
	int iClientCount = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && i != gI_Murderer && i != gI_Detective)
		{
			iClients[iClientCount] = i;
			iClientCount++;
		}
	}	
	
	if (iClientCount != 0)
		return iClients[GetRandomInt(0, iClientCount-1)];
	else
		return -1;
}

void LoadModelFile()
{
	gA_ModelName = new ArrayList(128);
	gA_ModelPath = new ArrayList(128);
	
	gA_ModelName.Clear();
	gA_ModelPath.Clear();
	
	KeyValues kv = new KeyValues("Props");
	
	char[] sPath = new char[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/Murder/Props.cfg");
	kv.ImportFromFile(sPath);
	
	if (kv.GotoFirstSubKey())
	{
		do
		{
			char[] sName = new char[128];
			char[] sModel = new char[PLATFORM_MAX_PATH];
			
			kv.GetSectionName(sName, 128);
			kv.GetString("model", sModel, PLATFORM_MAX_PATH);
			
			gA_ModelName.PushString(sName);
			gA_ModelPath.PushString(sModel);
			
			AddFileToDownloadsTable(sModel);
			PrecacheModel(sModel);
		}
		while (kv.GotoNextKey());
		kv.Rewind();
	}	
	delete kv;
}

void LoadRadioFile()
{
	gA_RadioName = new ArrayList(32);
	gA_RadioPath = new ArrayList(128);
	
	gA_RadioName.Clear();
	gA_RadioPath.Clear();
	
	KeyValues kv = new KeyValues("Radio");

	char[] sPath = new char[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/Murder/Radio.cfg");
	kv.ImportFromFile(sPath);
	
	if (kv.GotoFirstSubKey())
	{
		do
		{
			char[] sName = new char[128];
			
			kv.GetSectionName(sName, 128);
			kv.GetString("sound", sPath, PLATFORM_MAX_PATH);
			AddFileToDownloadsTable(sPath);
			
			if (StrContains(sPath, "sound/") != -1)
				ReplaceString(sPath, PLATFORM_MAX_PATH, "sound/", "");
			
			gA_RadioName.PushString(sName);
			gA_RadioPath.PushString(sPath);
			
			PrecacheSoundAny(sPath);
		}
		while (kv.GotoNextKey());
		kv.GoBack();
	}	
	delete kv;
}

bool ValidGrab(int client)
{
	int iObject = gI_GrabEntity[client];
	
	if (IsValidEntity(iObject) && IsValidEdict(iObject))
		return true;
	return false;
}

int GetObject(int client, bool hitSelf=true)
{
	int iEntity = -1;

	if (IsClientInGame(client))
	{
		if (ValidGrab(client))
		{
			iEntity = EntRefToEntIndex(gI_GrabEntity[client]);
			return (iEntity);
		}

		iEntity = TraceToEntity(client);

		if (IsValidEntity(iEntity) && IsValidEdict(iEntity))
		{
			char[] sName = new char[64];
			GetEdictClassname(iEntity, sName, 64);
			
			if (StrEqual(sName, "worldspawn"))
			{
				if (hitSelf)
					iEntity = client;
				else
					iEntity = -1;
			}
		}
		else iEntity = -1;
	}
	return iEntity;
}

int ReplacePhysicsEntity(int iEntity)
{
	float fOrigin[3], fAngle[3];
	char[] sModel = new char[128];
	
	GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModel, 128);
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigin);
	GetEntPropVector(iEntity, Prop_Send, "m_angRotation", fAngle);
	AcceptEntityInput(iEntity, "Wake");
	AcceptEntityInput(iEntity, "EnableMotion");
	AcceptEntityInput(iEntity, "EnableDamageForces");
	DispatchKeyValue(iEntity, "physdamagescale", "0.0");

	TeleportEntity(iEntity, fOrigin, fAngle, NULL_VECTOR);
	SetEntityMoveType(iEntity, MOVETYPE_VPHYSICS);
	
	return iEntity;
}

int TraceToEntity(int client)
{
	float fEyePos[3], fEyeAngle[3];
	GetClientEyePosition(client, fEyePos);
	GetClientEyeAngles(client, fEyeAngle);

	TR_TraceRayFilter(fEyePos, fEyeAngle, MASK_PLAYERSOLID, RayType_Infinite, Trace_Callback, client);

	if (TR_DidHit(null))
		return (TR_GetEntityIndex(null));
	return -1;
}

void ResetKnifeTimer()
{
	if (gH_KnifeTimer != null)
	{
		KillTimer(gH_KnifeTimer);
		gH_KnifeTimer = null;
	}	
}

void DoubleJump(int client) // Credits: darkranger & paegus
{
	int iFlags = GetEntityFlags(client);
	int iButtons = GetClientButtons(client);
	
	if (gI_LastFlags[client] & FL_ONGROUND)
	{
		if (!(iFlags & FL_ONGROUND) && !(gI_LastButtons[client] & IN_JUMP) && iButtons & IN_JUMP)
			++gI_Jumps[client];
	}
	else if (iFlags & FL_ONGROUND) {
		gI_Jumps[client] = 0;
	}
	else if (!(gI_LastButtons[client] & IN_JUMP) && iButtons & IN_JUMP)
	{
		if (1 <= gI_Jumps[client] <= gCV_DoubleJump_Max.IntValue)
		{
			++gI_Jumps[client];
			
			float fVel[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel);
			fVel[2] = gCV_DoubleJump_Height.FloatValue;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
		}
	}
	
	gI_LastFlags[client] = iFlags;
	gI_LastButtons[client] = iButtons;
}

public bool Trace_Callback(int entity, int mask, any data)
{
	return (data != entity);
}

public bool FilterPlayers(int iEntity, any aContentsMask) 
{
	if (0 < iEntity <= MaxClients)
		return false;
	return true;
}