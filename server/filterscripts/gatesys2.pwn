//==============================================================================
//                            Основные настройки
//==============================================================================

#define MOD77INS 2 //режим управления воротами:
//                 //MOD77INS 1 - командой-паролем (может управлять любой игрок из любого места карты).
//                 //MOD77INS 2 - командой /gate (может управлять только игрок из соответствующей
//                 //             банды, и находясь вблизи ворот своей банды).

//   ВНИМАНИЕ !!! после изменения настроек ОБЯЗАТЕЛЬНО откомпилировать !!!
//==============================================================================
#if (MOD77INS < 1)
	#undef MOD77INS
	#define MOD77INS 1
#endif
#if (MOD77INS > 2)
	#undef MOD77INS
	#define MOD77INS 2
#endif

#include <a_samp>
#include <streamer>

#undef MAX_PLAYERS
#define MAX_PLAYERS 101 //максимум игроков на сервере + 1 (если 50 игроков, то пишем 51 !!!)

#if (MAX_PLAYERS > 501)
	#undef MAX_PLAYERS
	#define MAX_PLAYERS 501
#endif

#define MAX_GATE 13 //число ворот на сервере (ОБЯЗАТЕЛЬНО - ТОЧНОЕ КОЛИЧЕСТВО !!!) (2)
#define MAX_MOVE 13 //число "перемещаемых" объектов (ОБЯЗАТЕЛЬНО - ТОЧНОЕ КОЛИЧЕСТВО !!!) (3)
#define G_SPEED 2.00 //скорость перемещения ворот
/*
--------------------------------------------------------------------------------
Правила певевода стандартных объектов в динамические:

Стандартные объекты:
CreateObject(971, -250.89, 1510.65, 78.17,   0.00, 0.00, 180.00);
CreateObject(971, -269.57, 1510.95, 78.17,   0.00, 0.00, 0.00);
CreateObject(971, -278.45, 1510.98, 78.17,   0.00, 0.00, 0.00);

Динамические объекты:
CreateDynamicObject(971, -250.89, 1510.65, 78.17,   0.00, 0.00, 180.00, -1, -1, -1, 500);
CreateDynamicObject(971, -269.57, 1510.95, 78.17,   0.00, 0.00, 0.00, -1, -1, -1, 500);
CreateDynamicObject(971, -278.45, 1510.98, 78.17,   0.00, 0.00, 0.00, -1, -1, -1, 500);

Перемещение динамических объектов:
MoveDynamicObject(idobject[0], -250.89, 1510.65, 81.67, G_SPEED, -90.00, 0.00, 180.00);
MoveDynamicObject(idobject[1], -269.57, 1510.95, 70.60, G_SPEED);//пример перемещения объекта БЕЗ поворотов по осям X, Y, и Z
MoveDynamicObject(idobject[2], -278.45, 1510.98, 70.60, G_SPEED);//пример перемещения объекта БЕЗ поворотов по осям X, Y, и Z

	idobject[0] - ID перемещаемого объекта
	-250.89, 1510.65, 78.17 - координаты, В которые нужно переместить объект
	G_SPEED - скорость перемещения объекта
	-90.00, 0.00, 180.00 - углы поворотов по осям X, Y, и Z соответственно,
	НА которые нужно повернуть перемещаемый объект

	Внимание !!! Данный скрипт тестировался со stramer-плагином v2.7.2 !!!
	При использовании stramer-плагина более ранних версий - возможен
	скачкообразный, либо неверный поворот по осям X, Y, и Z в функции
	перемещения динамического объекта (MoveDynamicObject) !!!
	В таком случае используйте MoveDynamicObject БЕЗ задания углов поворотов
	по осям X, Y, и Z... Пример:

Перемещение динамических объектов для более ранних версий stramer-плагина:
MoveDynamicObject(idobject[0], -240.38, 1510.78, 86.17, G_SPEED);
MoveDynamicObject(idobject[1], -269.57, 1510.95, 70.60, G_SPEED);
MoveDynamicObject(idobject[2], -278.45, 1510.98, 70.60, G_SPEED);

--------------------------------------------------------------------------------
*/
forward timobj();

new statgate[MAX_GATE];
new idobject[MAX_MOVE];
new idgang[MAX_GATE];
new Float:CorX[MAX_GATE];
new Float:CorY[MAX_GATE];
new Float:CorZ[MAX_GATE];
new namegate[MAX_GATE][128];
new Text3D:GateLabel[MAX_GATE];

public OnFilterScriptInit()
{
	print("\n-------------------------");
	print("    GateSys загружена");
	print("-------------------------\n");
	for(new i = 0; i < MAX_PLAYERS; i++)
	{
		SetPVarInt(i, "CComAc6", 0);
	}

	for(new i = 0; i < MAX_GATE; i++)//присваиваем всем воротам статус "закрыто"
	{
		statgate[i] = 0;
	}
	SetTimer("timobj", 300, 0);
	new string[256];

	CorX[0] = 1791.5514;//координаты 3D-текста названия банды для ворот-1 
	CorY[0] = -1300.1964;
	CorZ[0] = 119.2558;

	CorX[1] = -2068.9878;//координаты 3D-текста названия банды для ворот-2, , 
	CorY[1] = -2140.4287;
	CorZ[1] = 297.0078;
	
	CorX[2] = 1948.9338;//координаты 3D-текста названия банды для ворот-3
	CorY[2] = 2407.9412;
	CorZ[2] = 11.5370;

	CorX[4] = 1013.197082;//координаты 3D-текста названия банды для ворот-5
	CorY[4] = 2457.990;
	CorZ[4] = 12.2;

	CorX[5] = 807.7497;//координаты 3D-текста названия банды для ворот-6
	CorY[5] = -1348.8375;
	CorZ[5] = 15.2015;

	CorX[6] = 1534.4993;//координаты 3D-текста названия банды для ворот-7
	CorY[6] = 2773.1279;
	CorZ[6] = 12.2015;

	CorX[7] = 1417.9531;//координаты 3D-текста названия банды для ворот-8 
	CorY[7] = 2817.2993;
	CorZ[7] = 12.4786;

	CorX[8] = 1811.6017;//координаты 3D-текста названия банды для ворот-9
	CorY[8] = -1883.8499;
	CorZ[8] = 15.1142;
	
	CorX[9] = 1793.6798;//координаты 3D-текста названия банды для ворот-10
	CorY[9] = -1296.8867;
	CorZ[9] = 14.1675;
	
	CorX[10] = 1782.7676;//координаты 3D-текста названия банды для ворот-11
	CorY[10] = -1298.7368;
	CorZ[10] = 14.0724;
	
	CorX[11] = -2430.3293;//координаты 3D-текста названия банды для ворот-12   
	CorY[11] = 503.1187;
	CorZ[11] = 31.6309; 
	
	CorX[12] = 1030.7196;//координаты 3D-текста названия банды для ворот-13 
	CorY[12] = -367.4314;
	CorZ[12] = 75.7091;
	
#if (MOD77INS == 2)//режим управления командой /gate
	idgang[0] = 1;//ID банды для ворот-1
	format(namegate[0], 128, "");//название банды для ворот-1
	format(string, sizeof(string), "", namegate[0]);
	GateLabel[0] = Create3DTextLabel(string, 0xFF0000FF, CorX[0], CorY[0], CorZ[0], 25, 0, 0);//подписываем ворота-1

	idgang[1] = 4;//ID банды для ворот-2
	format(namegate[1], 128, "{FF0000}VI{00FF00}P{0000FF}RRDS");//название банды для ворот-2
	format(string, sizeof(string), "ПРОДАЁТСЯ: %s\n{00FF00}управление воротами - /gate", namegate[1]);
	GateLabel[1] = Create3DTextLabel(string, 0x00FF00FF, CorX[1], CorY[1], CorZ[1], 25, 0, 0);//подписываем ворота-2
	
	idgang[2] = 13;//ID банды для ворот-3
	format(namegate[2], 128, "{FF0000}Подробности узнавать у vk.com/hed_sport");//название банды для ворот-3
	format(string, sizeof(string), "ПРОДАЁТСЯ: %s\n{00FF00}управление воротами - /gate", namegate[2]);
	GateLabel[2] = Create3DTextLabel(string, 0x00FF00FF, CorX[2], CorY[2], CorZ[2], 25, 0, 0);//подписываем ворота-3
	
	idgang[4] = 158;//ID банды для ворот-5
	format(namegate[4], 128, "{FF0000}Подробности узнавать у vk.com/hed_sport");//название банды для ворот-5
	format(string, sizeof(string), "ПРОДАЁТСЯ: %s\n{00FF00}управление воротами - /gate", namegate[4]);
	GateLabel[4] = Create3DTextLabel(string, 0x00FF00FF, CorX[4], CorY[4], CorZ[4], 25, 0, 0);//подписываем ворота-5
	
	idgang[5] = 231;//ID банды для ворот-6
	format(namegate[5], 128, "{FFFFFF}Подробности узнавать у vk.com/hed_sport");//название банды для ворот-6
	format(string, sizeof(string), "{FF0000}ПРОДАЁТСЯ: %s\n{00FF00}управление воротами - /gate", namegate[5]);
	GateLabel[5] = Create3DTextLabel(string, 0x00FF00FF, CorX[5], CorY[5], CorZ[5], 25, 0, 0);//подписываем ворота-6
	
	idgang[6] = 436;//ID банды для ворот-7
	format(namegate[6], 128, "{FF0000}Подробности узнавать у vk.com/hed_sport");//название банды для ворот-7
	format(string, sizeof(string), "{FF0000}ПРОДАЁТСЯ: %s\n{00FF00}управление воротами - /gate", namegate[6]);
	GateLabel[6] = Create3DTextLabel(string, 0x00FF00FF, CorX[6], CorY[6], CorZ[6], 25, 0, 0);//подписываем ворота-7
	
	idgang[7] = 436;//ID банды для ворот-8
	format(namegate[7], 128, "{FF0000}Подробности узнавать у vk.com/hed_sport");//название банды для ворот-8
	format(string, sizeof(string), "{FF0000}ПРОДАЁТСЯ: %s\n{00FF00}управление воротами - /gate", namegate[7]);
	GateLabel[7] = Create3DTextLabel(string, 0x00FF00FF, CorX[7], CorY[7], CorZ[7], 25, 0, 0);//подписываем ворота-8

	idgang[8] = 52;//ID банды для ворот-9
	format(namegate[8], 128, "{FFFFFF}Подробности узнавать у vk.com/hed_sport");//название банды для ворот-9
	format(string, sizeof(string), "{FF0000}ПРОДАЁТСЯ: %s\n{00FF00}управление воротами - /gate", namegate[8]);
	GateLabel[8] = Create3DTextLabel(string, 0x00FF00FF, CorX[8], CorY[8], CorZ[8], 25, 0, 0);//подписываем ворота-9
	
	idgang[9] = 1;//ID банды для ворот-10
	format(namegate[9], 128, "");//название банды для ворот-10
	format(string, sizeof(string), "", namegate[9]);
	GateLabel[9] = Create3DTextLabel(string, 0xFF0000FF, CorX[9], CorY[9], CorZ[9], 25, 0, 0);//подписываем ворота-10
	
	idgang[10] = 1;//ID банды для ворот-11
	format(namegate[10], 128, "");//название банды для ворот-11
	format(string, sizeof(string), "", namegate[10]);
	GateLabel[10] = Create3DTextLabel(string, 0xFF0000FF, CorX[10], CorY[10], CorZ[10], 25, 0, 0);//подписываем ворота-11
	
	idgang[11] = 326;//ID банды для ворот-12
	format(namegate[11], 128, "{FF0000}Подробности узнавать у vk.com/hed_sport");//название банды для ворот-12
	format(string, sizeof(string), "{FF0000}ПРОДАЁТСЯ: %s\n{00FF00}управление воротами - /gate", namegate[11]);
	GateLabel[11] = Create3DTextLabel(string, 0x00FF00FF, CorX[11], CorY[11], CorZ[11], 25, 0, 0);//подписываем ворота-12
	
	idgang[12] = 169;//ID банды для ворот-13  Ярик внутр
	format(namegate[12], 128, "");//название банды для ворот-13
	format(string, sizeof(string), "", namegate[12]);
	GateLabel[12] = Create3DTextLabel(string, 0x00FF00FF, CorX[12], CorY[12], CorZ[12], 25, 0, 0);//подписываем ворота-13

#endif ///////// 
 	return 1;
}

public timobj()
{

	idobject[0] = CreateDynamicObject(1555, 1791.5714, -1300.1964, 119.2558, 0.0000, 0.0000,  76.9200, -1, -1, -1, 500);//ворота-1 в закрытом состоянии

	idobject[1] = CreateDynamicObject(19912, -2068.9878, -2140.4287, 297.0078,   0.00, 0.00, 141.6000, -1, -1, -1, 500);//ворота-2 в закрытом состоянии
	
	idobject[2] = CreateDynamicObject(19912, 1948.9338, 2407.9412, 11.5370,   0.00, 0.00, 0.00, -1, -1, -1, 500);//ворота-3 в закрытом состоянии
	
	idobject[3] =

	idobject[4] = CreateDynamicObject(19912, 1013.197082, 2457.990, 12.5,   0.0000, 0.0000, 0.0000, -1, -1, -1, 500);//ворота-5 в закрытом состоянии
	
	idobject[5] = CreateDynamicObject(19912, 807.7497, -1348.8375, 15.2015,   0.0000, 0.0000, 90.0000, -1, -1, -1, 500);//ворота-6 в закрытом состоянии

	idobject[6] = CreateDynamicObject(980, 1534.4993, 2773.1279, 12.3820,   0.0000, 0.0000, 90.0000, -1, -1, -1, 500);//ворота-7 в закрытом состоянии

	idobject[7] = CreateDynamicObject(980, 1417.9531, 2817.2993, 12.4786,   180.0000, -360.0000, 90.0000, -1, -1, -1, 500);//ворота-8 в закрытом состоянии

	idobject[8] = CreateDynamicObject(19912, 1811.6017, -1883.8499, 15.1142,   0.0000, 0.0000, 90.0000, -1, -1, -1, 500);//ворота-9 в закрытом состояни
	
	idobject[9] = CreateDynamicObject(17951, 1793.6798, -1296.8867, 14.1675,   0.0000, 0.0000, 90.0000, -1, -1, -1, 500);//ворота-10 в закрытом
	
	idobject[10] = CreateDynamicObject(17951, 1782.7676, -1298.7368, 14.0724,   0.0000, 0.0000, 0.0000, -1, -1, -1, 500);//ворота-11 в закрытом

	idobject[11] = CreateDynamicObject(19912, -2430.3293, 503.1187, 31.6309,   0.0000, 0.0000, 22.8600, -1, -1, -1, 500);//ворота-12 в закрытом

	idobject[12] = CreateDynamicObject(19912, 1030.7196, -367.4314, 75.7091,  0.0000, 0.0000, 365.6999, -1, -1, -1, 500);//ворота-13 в закрытом

	return 1;
}

public OnFilterScriptExit()
{
	for(new i = 0; i < MAX_PLAYERS; i++)
	{
		if(IsPlayerConnected(i))
		{
			DeletePVar(i, "CComAc6");
		}
	}
 	for(new i = 0; i < MAX_MOVE; i++)
	{
		DestroyDynamicObject(idobject[i]);//убираем все объекты
	}
 	for(new i = 0; i < MAX_GATE; i++)
	{
		Delete3DTextLabel(GateLabel[i]);//убираем все надписи (3D-тексты)
	}
	return 1;
}

public OnPlayerConnect(playerid)
{
	SetPVarInt(playerid, "CComAc6", 0);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	DeletePVar(playerid, "CComAc6");
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	SetPVarInt(playerid, "CComAc6", GetPVarInt(playerid, "CComAc6") + 1);
	new string[256];
    new pname[MAX_PLAYER_NAME];
	GetPlayerName(playerid,pname,sizeof(pname));
	new aa333[64];//доработка для использования Русских ников
	format(aa333, sizeof(aa333), "%s", pname);//доработка для использования Русских ников

#if (MOD77INS == 2)//режим управления командой /gate
    if(!strcmp(cmdtext, "/gate", true))//команда /gate
    {
		new per1 = 0;
		new per2 = -600;
		while(per1 < MAX_GATE)
		{
//			if(GetPVarInt(playerid, "PlGng") == idgang[per1] &&
//			IsPlayerInRangeOfPoint(playerid, 15.0, CorX[per1], CorY[per1], CorZ[per1]))//управление воротами ТОЛЬКО игроками из банды
			if((GetPVarInt(playerid, "PlGng") == idgang[per1] || IsPlayerAdmin(playerid)) &&
			IsPlayerInRangeOfPoint(playerid, 10.0, CorX[per1], CorY[per1], CorZ[per1]))//управление воротами игроками из банды И RCON-админом
        	{
				per2 = per1;
				break;
			}
			per1++;
		}
        if(per2 == -600)
        {
			SendClientMessage(playerid, 0xFF0000FF, "Это не Ваши ворота, или ворота слишком далеко !");
			return 1;
        }
		if(statgate[per2] == 0)//если ворота закрыты, то:
		{
			if(GetPVarInt(playerid, "PlGng") != idgang[per2] && IsPlayerAdmin(playerid))
			{
				printf("[gatesys] RCON %s [%d] открыл ворота базы %s", aa333, playerid, namegate[per2]);//выводим сообщение в лог сервера (доработка для использования Русских ников)
//				printf("[gatesys] %s [%d] открыл ворота базы %s", pname, playerid, namegate[per2]);//выводим сообщение в лог сервера
			}
			else
			{
				printf("[gatesys] %s [%d] открыл ворота базы %s", aa333, playerid, namegate[per2]);//выводим сообщение в лог сервера (доработка для использования Русских ников)
//				printf("[gatesys] %s [%d] открыл ворота базы %s", pname, playerid, namegate[per2]);//выводим сообщение в лог сервера
			}
		}
		else//иначе:
		{
			if(GetPVarInt(playerid, "PlGng") != idgang[per2] && IsPlayerAdmin(playerid))
			{
				printf("[gatesys] RCON %s [%d] закрыл ворота базы %s", aa333, playerid, namegate[per2]);//выводим сообщение в лог сервера (доработка для использования Русских ников)
//				printf("[gatesys] %s [%d] закрыл ворота базы %s", pname, playerid, namegate[per2]);//выводим сообщение в лог сервера
			}
			else
			{
				printf("[gatesys] %s [%d] закрыл ворота базы %s", aa333, playerid, namegate[per2]);//выводим сообщение в лог сервера (доработка для использования Русских ников)
//				printf("[gatesys] %s [%d] закрыл ворота базы %s", pname, playerid, namegate[per2]);//выводим сообщение в лог сервера
			}
		}
		if(per2 == 0)//управление воротами-1
        {
        	if(statgate[0] == 0)//открываем, если ворота-1 закрыты
        	{
				format(string, sizeof(string), "Вы открыли ворота базы %s", namegate[0]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[0]);//убираем надпись с ворот-1
				MoveDynamicObject(idobject[0], 1791.5714, -1300.1964, 119.2558, G_SPEED, 0.00, 0.00, 176.9999);//перемещение объекта ворота-1
				statgate[0] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-1 открыты
        	{
				format(string, sizeof(string), "Вы закрыли ворота базы %s", namegate[0]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "", namegate[0]);
				GateLabel[0] = Create3DTextLabel(string, 0x00FF00FF, CorX[0], CorY[0], CorZ[0], 25, 0, 0);//подписываем ворота-1
				MoveDynamicObject(idobject[0], 1791.5714, -1300.1964, 119.2558, G_SPEED, 0.00, 0.00, 76.9200);//перемещение объекта ворота-1 в координаты создания
				statgate[0] = 0;//изменяем статус на "закрыто"
        	}
        	return 1;
		}
    	if(per2 == 1)//управление воротами-2
    	{
        	if(statgate[1] == 0)//открываем, если ворота-2 закрыты
        	{
				format(string, sizeof(string), "Вы открыли ворота базы %s", namegate[1]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[1]);//убираем надпись с ворот-2
				MoveDynamicObject(idobject[1], -2068.9878, -2140.4287, 302.5286, G_SPEED);//перемещение объекта ворота-2
				statgate[1] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-2 открыты
        	{
				format(string, sizeof(string), "Вы закрыли ворота базы %s", namegate[1]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "База банды: %s\n{00FF00}управление воротами - /gate", namegate[1]);
				GateLabel[1] = Create3DTextLabel(string, 0x00FF00FF, CorX[1], CorY[1], CorZ[1], 25, 0, 0);//подписываем ворота-2
				MoveDynamicObject(idobject[1], -2068.9878, -2140.4287, 297.0078, G_SPEED, 0.0000, 0.0000, 141.6000);//перемещение объекта ворота-2 в координаты создания
				statgate[1] = 0;//изменяем статус на "закрыто"
        	}
        	return 1;
		}
    	if(per2 == 2)//управление воротами-3
    	{
        	if(statgate[2] == 0)//открываем, если ворота-3 закрыты
        	{
				format(string, sizeof(string), "Вы открыли ворота базы %s", namegate[2]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[2]);//убираем надпись с ворот-3
				MoveDynamicObject(idobject[2], 1948.9338, 2407.9412, 6.8906, G_SPEED);//перемещение объекта ворота-3
				statgate[2] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-3 открыты
        	{
				format(string, sizeof(string), "Вы закрыли ворота базы %s", namegate[2]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "База банды: %s\n{00FF00}управление воротами - /gate", namegate[2]);
				GateLabel[2] = Create3DTextLabel(string, 0x00FF00FF, CorX[2], CorY[2], CorZ[2], 25, 0, 0);//подписываем ворота-3
				MoveDynamicObject(idobject[2], 1948.9338, 2407.9412, 11.5370, G_SPEED);//перемещение объекта ворота-3 в координаты создания
				statgate[2] = 0;//изменяем статус на "закрыто"
        	}
        	return 1;
		}
 		if(per2 == 4)//управление воротами-5
    	{
        	if(statgate[4] == 0)//открываем, если ворота-5 закрыты
        	{
				format(string, sizeof(string), "Вы открыли ворота базы %s", namegate[4]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[4]);//убираем надпись с ворот-5
				MoveDynamicObject(idobject[4], 1013.197082, 2457.990, 17.5, G_SPEED);//перемещение объекта ворота-5
				statgate[4] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-5 открыты
        	{
				format(string, sizeof(string), "Вы закрыли ворота базы %s", namegate[4]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "База банды: %s\n{00FF00}управление воротами - /gate", namegate[4]);
				GateLabel[4] = Create3DTextLabel(string, 0x00FF00FF, CorX[4], CorY[4], CorZ[4], 25, 0, 0);//подписываем ворота-5
				MoveDynamicObject(idobject[4], 1013.197082, 2457.990, 12.5, G_SPEED);//перемещение объекта ворота-5 в координаты создания
				statgate[4] = 0;//изменяем статус на "закрыто"
        	}
        	return 1;
		}

 		if(per2 == 5)//управление воротами-6
    	{
        	if(statgate[5] == 0)//открываем, если ворота-6 закрыты
        	{
				format(string, sizeof(string), "Вы открыли ворота базы %s", namegate[5]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[5]);//убираем надпись с ворот-6
				MoveDynamicObject(idobject[5], 807.7497, -1348.8375, 18.7628, G_SPEED);//перемещение объекта ворота-6
				statgate[5] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-6 открыты
        	{
				format(string, sizeof(string), "Вы закрыли ворота базы %s", namegate[5]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "База банды: %s\n{00FF00}управление воротами - /gate", namegate[5]);
				GateLabel[5] = Create3DTextLabel(string, 0x00FF00FF, CorX[5], CorY[5], CorZ[5], 25, 0, 0);//подписываем ворота-6
				MoveDynamicObject(idobject[5], 807.7497, -1348.8375, 15.2015, G_SPEED);//перемещение объекта ворота-6 в координаты создания
				statgate[5] = 0;//изменяем статус на "закрыто"
        	}
        	return 1;
		}

 		if(per2 == 6)//управление воротами-7
    	{
        	if(statgate[6] == 0)//открываем, если ворота-7 закрыты
        	{
				format(string, sizeof(string), "Вы открыли ворота базы %s", namegate[6]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[6]);//убираем надпись с ворот-7
				MoveDynamicObject(idobject[6], 1534.4993, 2773.1279, 6.5167, G_SPEED);//перемещение объекта ворота-7
				statgate[6] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-7 открыты
        	{
				format(string, sizeof(string), "Вы закрыли ворота базы %s", namegate[6]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "База банды: %s\n{00FF00}управление воротами - /gate", namegate[6]);
				GateLabel[6] = Create3DTextLabel(string, 0x00FF00FF, CorX[6], CorY[6], CorZ[6], 25, 0, 0);//подписываем ворота-7
				MoveDynamicObject(idobject[6], 1534.4993, 2773.1279, 12.3820, G_SPEED);//перемещение объекта ворота-7 в координаты создания
				statgate[6] = 0;//изменяем статус на "закрыто"
        	}
        	return 1;
		}

 		if(per2 == 7)//управление воротами-8
    	{
        	if(statgate[7] == 0)//открываем, если ворота-8 закрыты
        	{
				format(string, sizeof(string), "Вы открыли ворота базы %s", namegate[7]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[7]);//убираем надпись с ворот-8
				MoveDynamicObject(idobject[7], 1417.9531, 2817.2993, 6.8272, G_SPEED);//перемещение объекта ворота-8
				statgate[7] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-8 открыты
        	{
				format(string, sizeof(string), "Вы закрыли ворота базы %s", namegate[7]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "База банды: %s\n{00FF00}управление воротами - /gate", namegate[7]);
				GateLabel[7] = Create3DTextLabel(string, 0x00FF00FF, CorX[7], CorY[7], CorZ[7], 25, 0, 0);//подписываем ворота-8
				MoveDynamicObject(idobject[7], 1417.9531, 2817.2993, 12.4786, G_SPEED);//перемещение объекта ворота-8 в координаты создания
				statgate[7] = 0;//изменяем статус на "закрыто"
        	}
        	return 1;
		}

 		if(per2 == 8)//управление воротами-9
    	{
        	if(statgate[8] == 0)//открываем, если ворота-9 закрыты
        	{
				format(string, sizeof(string), "Вы открыли ворота базы %s", namegate[8]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[8]);//убираем надпись с ворот-9
				MoveDynamicObject(idobject[8], 1811.6517, -1883.8694, 9.46377, G_SPEED);//перемещение объекта ворота-9
				statgate[8] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-9 открыты
        	{
				format(string, sizeof(string), "Вы закрыли ворота базы %s", namegate[8]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "База банды: %s\n{00FF00}управление воротами - /gate", namegate[8]);
				GateLabel[8] = Create3DTextLabel(string, 0x00FF00FF, CorX[8], CorY[8], CorZ[8], 25, 0, 0);//подписываем ворота-9
				MoveDynamicObject(idobject[8], 1811.6017, -1883.8499, 15.1142, G_SPEED);//перемещение объекта ворота-9 в координаты создания
				statgate[8] = 0;//изменяем статус на "закрыто"
        	}
        	return 1;
		}

		if(per2 == 9)//управление воротами-10
        {
        	if(statgate[9] == 0)//открываем, если ворота-10 закрыты
        	{
				format(string, sizeof(string), "Вы открыли ворота базы %s", namegate[9]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[9]);//убираем надпись с ворот-10
				MoveDynamicObject(idobject[9], 1793.6798, -1296.8867, 17.7260, G_SPEED, 0.00, 0.00, 90.0000);//перемещение объекта ворота-1
				statgate[9] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-10 открыты
        	{
				format(string, sizeof(string), "Вы закрыли ворота базы %s", namegate[9]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "", namegate[9]);
				GateLabel[9] = Create3DTextLabel(string, 0x00FF00FF, CorX[9], CorY[9], CorZ[9], 25, 0, 0);//подписываем ворота-10
				MoveDynamicObject(idobject[9], 1793.6798, -1296.8867, 14.1675, G_SPEED, 0.00, 0.00, 90.0000);//перемещение объекта ворота-1 в координаты создания
				statgate[9] = 0;//изменяем статус на "закрыто"
        	}
        	return 1;
		}

		if(per2 == 10)//управление воротами-11
        {
        	if(statgate[10] == 0)//открываем, если ворота-11 закрыты
        	{
				format(string, sizeof(string), "Вы открыли ворота базы %s", namegate[10]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[10]);//убираем надпись с ворот-11
				MoveDynamicObject(idobject[10], 1782.7769, -1298.7368, 17.6346, G_SPEED, 0.00, 0.00, 0.0000);//перемещение объекта ворота-1
				statgate[10] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-11 открыты
        	{
				format(string, sizeof(string), "Вы закрыли ворота базы %s", namegate[10]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "", namegate[10]);
				GateLabel[10] = Create3DTextLabel(string, 0x00FF00FF, CorX[10], CorY[10], CorZ[10], 25, 0, 0);//подписываем ворота-11
				MoveDynamicObject(idobject[10], 1782.7676, -1298.7368, 14.0724, G_SPEED, 0.00, 0.00, 0.0000);//перемещение объекта ворота-1 в координаты создания
				statgate[10] = 0;//изменяем статус на "закрыто"
        	}
        	return 1;
		}

		if(per2 == 11)//управление воротами-12
        {
        	if(statgate[11] == 0)//открываем, если ворота-12 закрыты
        	{
				format(string, sizeof(string), "Вы открыли ворота базы %s", namegate[11]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[11]);//убираем надпись с ворот-12
				MoveDynamicObject(idobject[11], -2430.3293, 503.1187, 24.078125, G_SPEED, 0.0000, 0.0000, 22.8600);//перемещение объекта ворота-1
				statgate[11] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-12 открыты
        	{
				format(string, sizeof(string), "Вы закрыли ворота базы %s", namegate[11]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "База банды: %s\n{00FF00}управление воротами - /gate", namegate[11]);
				GateLabel[11] = Create3DTextLabel(string, 0x00FF00FF, CorX[11], CorY[11], CorZ[11], 25, 0, 0);//подписываем ворота-12
				MoveDynamicObject(idobject[11], -2430.3293, 503.1187, 31.6309, G_SPEED, 0.0000, 0.0000, 22.8600);//перемещение объекта ворота-1 в координаты создания
				statgate[11] = 0;//изменяем статус на "закрыто"
        	}
        	return 1;
		}

		if(per2 == 12)//управление воротами-13 Ярик внутр
        {
        	if(statgate[12] == 0)//открываем, если ворота-13 закрыты
        	{
				format(string, sizeof(string), "", namegate[12]);
				SendClientMessage(playerid, 0x00FF00FF, string);
				Delete3DTextLabel(GateLabel[12]);//убираем надпись с ворот-12
				MoveDynamicObject(idobject[12], 1030.7196, -367.4314, 67.7091, G_SPEED, 0.0000, 0.0000, 365.6999);//перемещение объекта ворота-1
				statgate[12] = 1;//изменяем статус на "открыто"
        	}
        	else//закрываем, если ворота-13 открыты
        	{
				format(string, sizeof(string), "", namegate[12]);
				SendClientMessage(playerid, 0xFF0000FF, string);
				format(string, sizeof(string), "", namegate[12]);
				GateLabel[12] = Create3DTextLabel(string, 0x00FF00FF, CorX[12], CorY[12], CorZ[12], 25, 0, 0);//подписываем ворота-13
				MoveDynamicObject(idobject[12], 1030.7196, -367.4314, 75.7091, G_SPEED, 0.0000, 0.0000, 365.6999);//перемещение объекта ворота-1 в координаты создания
				statgate[12] = 0;//изменяем статус на "закрыто"
        	}
        	return 1; 
		}

    }
#endif 
	return 0;
}

