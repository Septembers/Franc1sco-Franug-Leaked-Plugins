/*
	Franug Knives

	Copyright (C) 2017 Francisco 'Franc1sco' García

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>
#include <weapons>
#include <givenameditem>
#undef REQUIRE_PLUGIN
#include <fpvm_interface>

#pragma semicolon 1

#define MAX_KNIVES 50 //Not sure how many knives will eventually be in the game until its death.

#define DATA "4.0 private version"

enum KnifeList{
	String:Name[64],
	KnifeID,
	String:flag[24]
};

ArrayList KnivesArray;
char path_knives[PLATFORM_MAX_PATH];
knives[MAX_KNIVES][KnifeList];
int knifeCount = 0;
int g_team[MAXPLAYERS + 1];


public Plugin myinfo = {
	name = "SM CS:GO Franug Knives",
	author = "Franc1sco franug",
	description = "",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
};

int knife_ct[MAXPLAYERS+1];
int knife_t[MAXPLAYERS+1];

Handle c_knife_ct, c_knife_t;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Franug_GetKnife", Native_GetKnife);
	MarkNativeAsOptional("FPVMI_GetClientViewModel");
	return APLRes_Success;
}

public Native_GetKnife(Handle:plugin, params)
{
	int client = GetNativeCell(1);
	int knife;
	if(GetClientTeam(client) == CS_TEAM_CT)
		knife = knife_ct[client];
	else
		knife = knife_t[client];
	
	if (knife < 0 || knife > (MAX_KNIVES - 1))return -1;
	
	return knives[knife][KnifeID];
}

public void OnPluginStart() {
	
	c_knife_ct = RegClientCookie("hknife_ct", "", CookieAccess_Private);
	c_knife_t = RegClientCookie("hknife_t", "", CookieAccess_Private);
	
	RegConsoleCmd("sm_knife", command_knives);
	RegConsoleCmd("sm_vknife", DID);
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && AreClientCookiesCached(i)) {
			OnClientCookiesCached(i);
		}
	}
	KnivesArray = new ArrayList(64);
	loadKnives();
}

public Action command_knives(int clientId, int args) {
	if(!CommandExists("sm_ck"))
	{
		FakeClientCommand(clientId, "sm_vknife");
		return Plugin_Handled;
	}
	
	Menu menu = CreateMenu(DIDMenuHandler_knives);
	menu.SetTitle("Franug knives %s", DATA);
	

	menu.AddItem("sm_vknife", "Valve knives");
	menu.AddItem("sm_ck", "Custom knives");
	
	SetMenuExitButton(menu, true);
	
	menu.Display(clientId, 0);
	
	return Plugin_Handled;
	
}

public int DIDMenuHandler_knives(Menu menu, MenuAction action, int client, int itemNum) {
	switch(action){
		case MenuAction_Select:{
			
			char info[32];
		
			menu.GetItem(itemNum, info, sizeof(info));

			FakeClientCommand(client, info);
		}
		case MenuAction_End: delete menu;
	}
}

public Action:DID(clientId, args) 
{
	new Handle:menu = CreateMenu(DIDMenuHandler);
	SetMenuTitle(menu, "Choose a category");
	AddMenuItem(menu, "ct", "Select counter-terrorist knife");
	AddMenuItem(menu, "tt", "Select terrorist knife");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, clientId, 0);
	
	return Plugin_Handled;
}

public DIDMenuHandler(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32];
		
		GetMenuItem(menu, itemNum, info, sizeof(info));

		if ( strcmp(info,"ct") == 0 ) 
		{     
			loadKnifeMenu(client, -1);
			g_team[client] = CS_TEAM_CT;
		}
	   
		else if ( strcmp(info,"tt") == 0 ) 
		{
			loadKnifeMenu(client, -1);
			g_team[client] = CS_TEAM_T;
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public void loadKnifeMenu(int clientId, int menuPosition) 
{
	
	Menu menu = CreateMenu(DIDMenuHandler_h);
	menu.SetTitle("Franug Knife %s\nChoose you knife.", DATA);
	
	int knife;
	if(g_team[clientId] == CS_TEAM_CT)
		knife = knife_ct[clientId];
	else
		knife = knife_t[clientId];
		
	char item[4], item2[124];
	for (int i = 0; i < knifeCount; ++i) {
		Format(item, 4, "%i", i);
		if(knife == i)
		{
			Format(item2, 124, "%s (Current knife)", knives[i][Name]);
			menu.AddItem(item, item2, ITEMDRAW_DISABLED);
		}
		else if(!HasFlag(clientId,knives[i][flag]))
		{
			Format(item2, 124, "%s (Vip knife)", knives[i][Name]);
			menu.AddItem(item, item2, ITEMDRAW_DISABLED);
		}
		else
			menu.AddItem(item, knives[i][Name], ITEMDRAW_DEFAULT);
	}
	
	SetMenuExitButton(menu, true);
	
	if(menuPosition == -1){
		menu.Display(clientId, 0);
	} else menu.DisplayAt(clientId, menuPosition, 0);
	
}

public int DIDMenuHandler_h(Menu menu, MenuAction action, int client, int itemNum) {
	switch(action){
		case MenuAction_Select:{
			char info[32];
		
			menu.GetItem(itemNum, info, sizeof(info));

			if(g_team[client] == CS_TEAM_T)
			{
				knife_t[client] = StringToInt(info);
		
				char cookie[8];
				IntToString(knife_t[client], cookie, 8);
			
				SetClientCookie(client, c_knife_t, cookie);
		
				if (knife_t[client] < 0 || knife_t[client] > (MAX_KNIVES - 1))knife_t[client] = 0;
			
				GiveNamedItem_GiveKnife(client, knives[knife_t[client]][KnifeID]);
		
				loadKnifeMenu(client, GetMenuSelectionPosition());
			}
			if(g_team[client] == CS_TEAM_CT)
			{
				knife_ct[client] = StringToInt(info);
		
				char cookie[8];
				IntToString(knife_ct[client], cookie, 8);
			
				SetClientCookie(client, c_knife_ct, cookie);
		
				if (knife_ct[client] < 0 || knife_ct[client] > (MAX_KNIVES - 1))knife_ct[client] = 0;
			
				GiveNamedItem_GiveKnife(client, knives[knife_ct[client]][KnifeID]);
		
				loadKnifeMenu(client, GetMenuSelectionPosition());
			}
		}
		case MenuAction_End: delete menu;
	}
}

public OnGiveNamedItemEx(int client, const char[] Classname)
{
	
	if(GiveNamedItemEx.IsClassnameKnife(Classname))
	{
		int knife;
		if(GetClientTeam(client) == CS_TEAM_CT)
			knife = knife_ct[client];
		else
			knife = knife_t[client];
			
		if (knife < 0 || knife > (MAX_KNIVES - 1))return;
		
		if ((GetFeatureStatus(FeatureType_Native, "FPVMI_GetClientViewModel") == FeatureStatus_Available) && FPVMI_GetClientViewModel(client, "weapon_knife") != -1) return;
		
		if(knives[knife][KnifeID] > -1) GiveNamedItemEx.ItemDefinition = knives[knife][KnifeID];
	}
}

public void OnClientCookiesCached(int client) {
	char value[16];
	GetClientCookie(client, c_knife_ct, value, sizeof(value));
	if(strlen(value) > 0) knife_ct[client] = StringToInt(value);
	else knife_ct[client] = 0;
	

	GetClientCookie(client, c_knife_t, value, sizeof(value));
	if(strlen(value) > 0) knife_t[client] = StringToInt(value);
	else knife_t[client] = 0;
}

public void loadKnives() {
	BuildPath(Path_SM, path_knives, sizeof(path_knives), "configs/csgo_knives.cfg");
	KeyValues kv = new KeyValues("Knives");
	knifeCount = 0;
	ClearArray(KnivesArray);
	
	kv.ImportFromFile(path_knives);
	
	if (!kv.GotoFirstSubKey()){
		SetFailState("Knives Config not found: %s. Please install the cfg file in the addons/sourcemod/configs", path_knives);
		delete kv;
	}
	do {
		kv.GetSectionName(knives[knifeCount][Name], 64);
		knives[knifeCount][KnifeID] = kv.GetNum("KnifeID", 0);
		KvGetString(kv, "flag", knives[knifeCount][flag], 24, "public");
		PushArrayString(KnivesArray, knives[knifeCount][Name]);
		knifeCount++;
	} while (kv.GotoNextKey());
	
	delete kv;
	for (int i=knifeCount; i<MAX_KNIVES; ++i) {
		knives[i][KnifeID] = -1;
	}
}


bool:HasFlag(client, String:flags[])
{
	if(StrEqual(flags, "public")) return true;
	
	if (GetUserFlagBits(client) & ADMFLAG_ROOT)
	{
		return true;
	}

	new iFlags = ReadFlagString(flags);

	if ((GetUserFlagBits(client) & iFlags) == iFlags)
	{
		return true;
	}

	return false;
}  