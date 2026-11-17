#include <a_samp>
#include <FileFunctions>

forward DrazvioSmokeExit();
main() {}

public OnGameModeInit()
{
    new File:f = fopen("DZ_CI_TEST.savenew", io_write);
    if(!f)
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: fopen");
        SetTimer("DrazvioSmokeExit", 200, false);
        return 1;
    }
    fwrite(f, "Money=42");
    fclose(f);
    if(!fileMove("DZ_CI_TEST.savenew", "DZ_CI_TEST.ini"))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: fileMove");
        SetTimer("DrazvioSmokeExit", 200, false);
        return 1;
    }
    if(!fexist("DZ_CI_TEST.ini"))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: destination");
        SetTimer("DrazvioSmokeExit", 200, false);
        return 1;
    }
    if(!fileRemove("DZ_CI_TEST.ini") || fexist("DZ_CI_TEST.ini"))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: fileRemove");
        SetTimer("DrazvioSmokeExit", 200, false);
        return 1;
    }
    new File:logfile = fileOpen("server_log.txt", io_Read);
    if(!logfile)
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: log fileOpen");
        SetTimer("DrazvioSmokeExit", 200, false);
        return 1;
    }
    fileClose(logfile);
    print("DRAZVIO_FILEFUNCTIONS_SMOKE_PASS");
    SetTimer("DrazvioSmokeExit", 200, false);
    return 1;
}

public DrazvioSmokeExit()
{
    SendRconCommand("exit");
    return 1;
}
