#include <a_samp>

#undef MAX_PLAYERS
#define MAX_PLAYERS 101 //максимум игроков на сервере + 1 (если 50 игроков, то пишем 51 !!!)

forward Reklama1();
forward Reklama2();
forward Reklama3();
forward Reklama4();
forward Reklama5();

new reklamatimer1;
new reklamatimer2;
new reklamatimer3;
new reklamatimer4;
new reklamatimer5;

public OnFilterScriptInit()
{
	reklamatimer2 = SetTimer("Reklama2",500000,1);
    reklamatimer3 = SetTimer("Reklama3",800000,1);
    reklamatimer4 = SetTimer("Reklama4",900000,1);
    reklamatimer5 = SetTimer("Reklama5",900000,1);
    reklamatimer1 = SetTimer("Reklama1",900000,1);
    return 1;
}

public OnFilterScriptExit()
{
	KillTimer(reklamatimer1);
	KillTimer(reklamatimer2);
	KillTimer(reklamatimer3);
	KillTimer(reklamatimer4);
	KillTimer(reklamatimer5);
    return 1;
}

public Reklama2()
{
	SendClientMessageToAll(0xFFFFFFFF,"{FF0000}[Платно]{FFFFFF}На сервере есть дополнительные телепорты /helptp");
	return 1;
}

public Reklama3()
{
	SendClientMessageToAll(0xFFFFFFFF,"{FF0000}[Помощь] {FFFFFF}Чтобы посмотреть Администрацию On-Line,введите: /admins");
	return 1;
}

public Reklama4()
{
	SendClientMessageToAll(0xFFFFFFFF,"{FF0000}[Администрация] {FFFFFF}На сервер читер или нарушитель? Пиши в /report [id] [причина]");
	return 1;
}

public Reklama5()
{
	SendClientMessageToAll(0xFFFFFFFF,"{FF0000}[Дома,гаражи] {FFFFFF}В Доме можно хранить оружие и деньги,а в гараже тюнингованное авто");
	return 1;
}

public Reklama1()
{
	SendClientMessageToAll(0xFFFFFFFF,"{FF0000}[Помощь] {FFFFFF}Чтобы посмотреть Вип Игроков On-Line,введите: /vips");
	return 1;
}
