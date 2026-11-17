// DRAZVIO native ABI and filesystem self-test. Runs with disposable files only.
#define WIN32_LEAN_AND_MEAN
#define HAVE_STDINT_H 1
#include <windows.h>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <direct.h>
#include "plugincommon.h"
#include "amx/amx.h"

static cell memory[4096]={0};
static const AMX_NATIVE_INFO *native_list=nullptr;
static int AMXAPI fake_addr(AMX *,cell addr,cell **dst) {
    if(addr<0||addr>=4096) return 1;
    *dst=&memory[addr]; return 0;
}
static int AMXAPI fake_len(const cell *p,int *len) {
    int n=0; while(n<4095&&p[n]) ++n;
    if(n==4095) return 1;
    *len=n; return 0;
}
static int AMXAPI fake_get(char *dst,const cell *src,int,size_t size) {
    if(!size) return 1;
    size_t i=0;
    while(i+1<size&&src[i]) { dst[i]=static_cast<char>(src[i]); ++i; }
    dst[i]='\0'; return 0;
}
static int AMXAPI fake_set(cell *dst,const char *src,int,int,size_t count) {
    size_t i=0;
    if(!count) return 1;
    while(i+1<count&&src[i]) {dst[i]=static_cast<unsigned char>(src[i]);++i;}
    dst[i]=0; return 0;
}
static int AMXAPI fake_register(AMX *, const AMX_NATIVE_INFO *list,int) {
    native_list=list; return 0;
}
static void setstr(int address,const char *text) {
    int i=0; while(text[i]&&i<255) {memory[address+i]=static_cast<unsigned char>(text[i]);++i;}
    memory[address+i]=0;
}
static bool file_exists(const char *path) {
    FILE *f=nullptr; if(fopen_s(&f,path,"rb")||!f) return false;
    fclose(f); return true;
}
static AMX_NATIVE find_native(const char *name) {
    if(!native_list) return nullptr;
    for(auto p=native_list;p->name;++p) if(!strcmp(p->name,name)) return p->func;
    return nullptr;
}
int main(int argc,char **argv) {
    if(argc!=2) return 2;
    HMODULE dll=LoadLibraryA(argv[1]);
    if(!dll) {puts("FAIL: LoadLibrary"); return 3;}
    auto load=reinterpret_cast<bool (__stdcall *)(void **)>(GetProcAddress(dll,"Load"));
    auto unload=reinterpret_cast<void (__stdcall *)()>(GetProcAddress(dll,"Unload"));
    auto supports=reinterpret_cast<unsigned int (__stdcall *)()>(GetProcAddress(dll,"Supports"));
    auto amxload=reinterpret_cast<int (__stdcall *)(AMX *)>(GetProcAddress(dll,"AmxLoad"));
    auto amxunload=reinterpret_cast<int (__stdcall *)(AMX *)>(GetProcAddress(dll,"AmxUnload"));
    if(!load||!unload||!supports||!amxload||!amxunload) {puts("FAIL: exports");return 4;}
    if((supports()&SUPPORTS_AMX_NATIVES)==0) return 5;
    void *apiTable[50]={0};
    apiTable[PLUGIN_AMX_EXPORT_GetAddr]=reinterpret_cast<void *>(&fake_addr);
    apiTable[PLUGIN_AMX_EXPORT_StrLen]=reinterpret_cast<void *>(&fake_len);
    apiTable[PLUGIN_AMX_EXPORT_GetString]=reinterpret_cast<void *>(&fake_get);
    apiTable[PLUGIN_AMX_EXPORT_SetString]=reinterpret_cast<void *>(&fake_set);
    apiTable[PLUGIN_AMX_EXPORT_Register]=reinterpret_cast<void *>(&fake_register);
    void *data[32]={0};
    data[PLUGIN_DATA_AMX_EXPORTS]=apiTable;
    AMX fakeAMX={};
    if(!load(data)||amxload(&fakeAMX)!=0) {puts("FAIL: plugin registration");return 6;}
    for(const char *name:{"fileMove","fileRemove","fileOpen","fileClose","fileRead","fileSeek"}) {
        if(!find_native(name)) {printf("FAIL: native %s\n",name);return 7;}
    }
    _mkdir("scriptfiles");
    _mkdir("scriptfiles/players");
    const char *from="scriptfiles/players/DZ_CI_TEST.savenew";
    const char *to="scriptfiles/players/DZ_CI_TEST.ini";
    const char *log="scriptfiles/players/DZ_CI_TEST.log";
    if(file_exists(from)||file_exists(to)||file_exists(log)) {puts("FAIL: test paths occupied");return 8;}
    FILE *f=nullptr;
    if(fopen_s(&f,from,"wb")||!f) return 9;
    fputs("Money=45\n",f); fclose(f);
    setstr(16,"players/DZ_CI_TEST.savenew");
    setstr(256,"players/DZ_CI_TEST.ini");
    cell moveArgs[]={2*sizeof(cell),16,256};
    auto move=find_native("fileMove");
    if(move(&fakeAMX,moveArgs)!=1||!file_exists(to)||file_exists(from)) {puts("FAIL: fileMove");return 10;}
    if(fopen_s(&f,from,"wb")||!f) return 11;
    fputs("Money=999\n",f);fclose(f);
    if(move(&fakeAMX,moveArgs)!=0) {puts("FAIL: fileMove overwrote destination");return 12;}
    setstr(512,"players/../server.cfg");
    cell badArgs[]={2*sizeof(cell),512,256};
    if(move(&fakeAMX,badArgs)!=0) {puts("FAIL: traversal accepted");return 13;}
    cell removeArgs[]={sizeof(cell),16};
    if(find_native("fileRemove")(&fakeAMX,removeArgs)!=1||file_exists(from)) return 14;
    setstr(512,"players/DZ_CI_TEST.log");
    if(fopen_s(&f,log,"wb")||!f) return 15;
    fputs("TEST_LINE\n",f); fclose(f);
    cell openArgs[]={2*sizeof(cell),512,0};
    cell handle=find_native("fileOpen")(&fakeAMX,openArgs);
    if(!handle) {puts("FAIL: fileOpen");return 16;}
    cell readArgs[]={3*sizeof(cell),handle,1024,32};
    if(find_native("fileRead")(&fakeAMX,readArgs)!=1||memory[1024]!='T') {
        puts("FAIL: fileRead");return 17;
    }
    cell seekArgs[]={3*sizeof(cell),handle,0,0};
    if(find_native("fileSeek")(&fakeAMX,seekArgs)!=1) return 18;
    cell closeArgs[]={sizeof(cell),handle};
    if(find_native("fileClose")(&fakeAMX,closeArgs)!=1) return 19;
    if(find_native("fileRemove")(&fakeAMX,closeArgs)!=0) {puts("FAIL: invalid fileRemove");return 20;}
    setstr(16,"players/DZ_CI_TEST.ini");
    setstr(256,"players/DZ_CI_TEST.log");
    if(find_native("fileRemove")(&fakeAMX,removeArgs)!=1) return 21;
    cell deleteLog[]={sizeof(cell),256};
    if(find_native("fileRemove")(&fakeAMX,deleteLog)!=1) return 22;
    // Reject reserved Win32 devices, normalized-away suffixes and log writes.
    setstr(768,"players/NUL.ini");
    cell badOpen[]={2*sizeof(cell),768,1};
    if(find_native("fileOpen")(&fakeAMX,badOpen)!=0) {puts("FAIL: NUL device accepted");return 23;}
    setstr(768,"players/COM1.txt");
    if(find_native("fileOpen")(&fakeAMX,badOpen)!=0) {puts("FAIL: COM1 device accepted");return 24;}
    setstr(768,"players/unsafe.");
    if(find_native("fileOpen")(&fakeAMX,badOpen)!=0) {puts("FAIL: trailing dot accepted");return 25;}
    setstr(768,"server_log.txt");
    if(find_native("fileOpen")(&fakeAMX,badOpen)!=0) {puts("FAIL: server_log write accepted");return 26;}
    setstr(768,"players/DZ_CI_HANDLE_LEAK.log");
    const char *leak="scriptfiles/players/DZ_CI_HANDLE_LEAK.log";
    if(file_exists(leak)) {puts("FAIL: leaked handle test file occupied");return 27;}
    cell leaked=find_native("fileOpen")(&fakeAMX,badOpen);
    if(leaked==0) {puts("FAIL: cannot open temporary handle");return 28;}
    amxunload(&fakeAMX);
    cell closeLeaked[]={sizeof(cell),leaked};
    if(find_native("fileClose")(&fakeAMX,closeLeaked)!=0) {puts("FAIL: leaked handle survived AMX unload");return 29;}
    if(!DeleteFileA(leak)) {puts("FAIL: leaked handle still locks file");return 30;}
    unload();FreeLibrary(dll);

    puts("PASS: exports, filesystem, reserved names, log read-only and AMX handle cleanup");
    return 0;
}
