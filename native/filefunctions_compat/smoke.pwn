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
    // Exercise the failure/rollback half of Stage 10 account publishing.
    // These are disposable scriptfiles, never real player accounts.
    new File:seed = fopen("DZ_CI_ROLLBACK.ini", io_write);
    if(!seed)
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: rollback seed");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    fwrite(seed, "Money=12");
    fclose(seed);
    new File:staging = fopen("DZ_CI_ROLLBACK.savenew", io_write);
    if(!staging)
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: rollback stage");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    fwrite(staging, "Money=99");
    fclose(staging);
    if(!fileMove("DZ_CI_ROLLBACK.ini", "DZ_CI_ROLLBACK.swapold"))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: rollback park");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    // An unexpected destination appeared before the stage could be published.
    new File:blocker = fopen("DZ_CI_ROLLBACK.ini", io_write);
    if(!blocker)
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: rollback collision");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    fwrite(blocker, "COLLISION");
    fclose(blocker);
    if(fileMove("DZ_CI_ROLLBACK.savenew", "DZ_CI_ROLLBACK.ini"))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: rollback overwrite accepted");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    if(!fexist("DZ_CI_ROLLBACK.savenew") ||
       !fileRemove("DZ_CI_ROLLBACK.ini") ||
       !fileMove("DZ_CI_ROLLBACK.swapold", "DZ_CI_ROLLBACK.ini"))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: rollback restoration");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    new File:restored = fileOpen("DZ_CI_ROLLBACK.ini", io_Read);
    new restoredLine[64];
    if(!restored)
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: rollback open");
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    if(!fileRead(restored, restoredLine, sizeof(restoredLine)) ||
       strfind(restoredLine, "Money=12") != 0)
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: restored balance mismatch");
        fileClose(restored);
        SetTimer("DrazvioSmokeExit",200,false); return 1;
    }
    fileClose(restored);
    if(!fileRemove("DZ_CI_ROLLBACK.ini") ||
       !fileRemove("DZ_CI_ROLLBACK.savenew"))
    {
        print("DRAZVIO_FILEFUNCTIONS_SMOKE_FAIL: rollback cleanup");
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
