#include <a_samp>
#include <FileFunctions>

forward DrazvioSmokeExit();
main() {}

public OnGameModeInit()
{
    // Simulate the Stage 10 account-snapshot publication sequence.
    new File:f = fopen("DZ_CI_ACCOUNT.ini", io_write);
    if(!f) { print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: initial account"); SetTimer("DrazvioSmokeExit",200,false); return 1; }
    fwrite(f, "Money=12");
    fclose(f);
    f = fopen("DZ_CI_ACCOUNT.savenew", io_write);
    if(!f) { print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: staged account"); SetTimer("DrazvioSmokeExit",200,false); return 1; }
    fwrite(f, "Money=99");
    fclose(f);
    if(!fileMove("DZ_CI_ACCOUNT.ini", "DZ_CI_ACCOUNT.swapold"))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: backup move");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    if(!fileMove("DZ_CI_ACCOUNT.savenew", "DZ_CI_ACCOUNT.ini"))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: staged publish");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    if(fileMove("DZ_CI_ACCOUNT.swapold","DZ_CI_ACCOUNT.ini"))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: destination overwrite");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    new File:live = fileOpen("DZ_CI_ACCOUNT.ini", io_Read);
    if(!live)
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: account fileOpen");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    new line[64];
    if(!fileRead(live,line,sizeof(line)) || strfind(line,"Money=99")!=0 ||
       !fileSeek(live,0,seek_Start))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: account read/seek");
        fileClose(live);
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    fileClose(live);
    if(!fileRemove("DZ_CI_ACCOUNT.swapold") || !fileRemove("DZ_CI_ACCOUNT.ini"))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: account cleanup");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    new File:logfile = fileOpen("server_log.txt", io_Read);
    if(!logfile)
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: log read");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    fileClose(logfile);
    if(fileOpen("server_log.txt",io_Write))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: log write permitted");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    print("DRAZVIO_FILEFUNCTIONS_SMOKE_PASS");
    SetTimer("DrazvioSmokeExit",200,false);
    return 1;
}

public DrazvioSmokeExit()
{
    SendRconCommand("exit");
    return 1;
}
