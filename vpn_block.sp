#include <sourcemod>
#include <cURL>
#pragma semicolon 1

public Plugin   myinfo =
{
	name = "VPN Block",
	author = "Addicted / oaaron99",
	description = "Block VPNs using iphub.info API",
	version = "1.0.0",
	url = "https://steamcommunity.com/profiles/76561197962532156"
};

Database		g_dDB = null;
ConVar			g_hApiKey = null;
ConVar			g_hApiFilter = null;
bool			g_bConnected = false;

public void     OnPluginStart()
{
	DB_Connect();
	g_hApiKey = CreateConVar("sm_vpn_block_api_key", "", "API key from iphub.info (https://iphub.info/account)");
	g_hApiFilter = CreateConVar("sm_vpn_block_api_filter", "1", "IP type to block (0 - Residential/Unclassified IP (i.e. safe IP) | 1 - Non-residential IP (hosting provider, proxy, etc.) | 2 - Non-residential & residential IP (warning, may flag innocent people))", _, true, 0.0, true, 2.0);
	AutoExecConfig(true, "vpn_block");
}

public void		OnMapStart()
{
	DB_Connect();
}

public void		DB_Connect()
{
	if (g_dDB != null || g_bConnected)
	{
		return;
	}
	if (SQL_CheckConfig("vpn_block"))
	{
		Database.Connect(DB_OnDatabaseConnect, "vpn_block");
	}
	else
	{
		SetFailState("Can't find 'vpn_block' entry in sourcemod/configs/databases.cfg");
	}
}

public void		DB_OnDatabaseConnect(Database dDB, const char[] sError, any iData)
{
	if (dDB == null)
	{
		SetFailState("Failed to connect, SQL Error:  %s", sError);
		return;
	}
	g_dDB = dDB;
	g_bConnected = true;
	// TODO: Create Table
}

public void		OnClientPostAdminCheck(int iClient)
{
	char sIP[45]; // 45 is enough to store IPV6 (IDK if GetClientIP() returns IPV6)
	char sQuery[256];
	char sEscapedIP[(45 * 2) + 1];

	if (!IsValidClient(iClient))
	{
		return;
	}
	if (GetClientIP(iClient, sIP, sizeof(sIP)))
	{
		// TODO: Search DB, if IP doesn't exist in table then do API lookup and insert it
		if (g_dDB.Escape(sIP, sEscapedIP, sizeof(sEscapedIP)))
		{
			DataPack hQueryInfo = new DataPack();
			hQueryInfo.WriteCell(GetClientUserId(iClient));
			hQueryInfo.WriteString(sIP);
			hQueryInfo.Reset();

			Format(sQuery, sizeof(sQuery), "SELECT `type` FROM `ips` WHERE `ip` = \"%s\";", sEscapedIP);
			g_dDB.Query(DB_CheckIP, sQuery, _, DBPrio_High);
		}
		else
		{
			LogError("Failed to escape IP: %L", iClient);
		}
	}
	else
	{
		LogError("Failed to get IP: %L", iClient);
	}
}

public void		DB_CheckIP(Database dDB, DBResultSet dbResults, const char[] sError, DataPack hData)
{
	char	sIP[45]; // 45 is enough to store IPV6 (IDK if GetClientIP() returns IPV6)
	int		iClient;
	int		iType;

	if (g_dDB == null)
	{
		LogError("(DB_CheckIP) Invalid Database Connection");
		return;
	}
	if (dDB == null)
	{
		LogError("(DB_CheckIP) Query failed: %s", sError);
		return;
	}
	if (sError[0] != '\0')
	{
		LogError("(DB_CheckIP) Query failed: %s", sError);
		return;
	}
	iClient = GetClientOfUserId(hData.ReadCell());
	hData.ReadString(sIP, sizeof(sIP));
	if (!IsValidClient(iClient))
	{
		return;
	}
	if (dbResults.AffectedRows == 0) // No results for IP found. We need to query API and add to DB
	{
		// TODO: cURL query
	}
	else
	{
		dbResults.FetchRow();
		iType = dbResults.FetchInt(0);
		if (iType == g_hApiFilter.IntValue)
		{
			LogMessage("Kicked client: %L", iClient);
			KickClient(iClient, "VPN Block Active");
		}
	}
}

public OnComplete(Handle:hndl, CURLcode: code)
{
    CloseHandle(hndl);
}

stock bool IsValidClient(int iClient)
{
	if (iClient < 1 || iClient > MaxClients)
	{
		return false;
	}
	if (!IsClientInGame(iClient))
	{
		return false;
	}
	if (!IsClientConnected(iClient))
	{
		return false;
	}
	if (IsFakeClient(iClient))
	{
		return false;
	}
	if (IsClientSourceTV(iClient))
	{
		return false;
	}
	return true;
}
