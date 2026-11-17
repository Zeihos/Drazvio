// Experimental Win32 FileFunctions compatibility plugin for DRAZVIO.
// Implements only the six natives used by mod05. Not yet runtime-verified.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdio>
#include <cstdint>
#include <string>
#include <unordered_set>
#include <vector>
#include "plugincommon.h"
#define HAVE_STDINT_H 1
#include "amx/amx.h"

static void **g_amx = nullptr;
static std::unordered_set<FILE *> g_files;
template <typename T> static T api(int index) {
    return reinterpret_cast<T>(g_amx[index]);
}
static bool count(cell *p, int n) { return p && p[0] / sizeof(cell) >= n; }
static bool pawn_read(AMX *amx, cell arg, std::string &out) {
    if (!g_amx) return false;
    cell *ptr = nullptr;
    if (api<int (AMXAPI *)(AMX *, cell, cell **)>(PLUGIN_AMX_EXPORT_GetAddr)(amx,arg,&ptr) || !ptr) return false;
    int n = 0;
    if (api<int (AMXAPI *)(const cell *, int *)>(PLUGIN_AMX_EXPORT_StrLen)(ptr,&n) || n < 0 || n > 4095) return false;
    std::vector<char> buffer(static_cast<size_t>(n)+1, 0);
    if (api<int (AMXAPI *)(char *, const cell *, int, size_t)>(PLUGIN_AMX_EXPORT_GetString)(buffer.data(),ptr,0,buffer.size())) return false;
    out = buffer.data();
    return true;
}
static bool pawn_write(AMX *amx, cell arg, const char *text, size_t maxlen) {
    cell *ptr = nullptr;
    if (api<int (AMXAPI *)(AMX *, cell, cell **)>(PLUGIN_AMX_EXPORT_GetAddr)(amx,arg,&ptr) || !ptr) return false;
    return api<int (AMXAPI *)(cell *, const char *, int, int, size_t)>(PLUGIN_AMX_EXPORT_SetString)(
        ptr,text,0,0,maxlen) == 0;
}
// Inputs are scriptfiles-relative exactly as the native Pawn file API expects.
// Refuse absolute paths, drive paths and .. components.
static bool file_path(std::string raw, std::string &result) {
    if (raw.empty() || raw.size() > 240 || raw[0] == '\\' || raw[0] == '/' ||
        raw.find(':') != std::string::npos) return false;
    for (char &c: raw) if (c == '\\') c = '/';
    size_t start=0;
    for (;;) {
        size_t end=raw.find('/',start);
        std::string part=raw.substr(start,end==std::string::npos?end:end-start);
        if (part.empty() || part=="." || part=="..") return false;
        if (end==std::string::npos) break;
        start=end+1;
    }
    result="scriptfiles/"+raw;
    return true;
}
static FILE *get_handle(cell value) {
    FILE *f=reinterpret_cast<FILE *>(static_cast<uintptr_t>(static_cast<uint32_t>(value)));
    return g_files.count(f)?f:nullptr;
}
static cell AMX_NATIVE_CALL n_move(AMX *amx, cell *p) {
    if (!count(p,2)) return 0;
    std::string a,b,src,dst;
    if (!pawn_read(amx,p[1],a)||!pawn_read(amx,p[2],b)||
        !file_path(a,src)||!file_path(b,dst)) return 0;
    // Never overwrite an existing account, and ask Windows to flush metadata.
    return MoveFileExA(src.c_str(),dst.c_str(),MOVEFILE_WRITE_THROUGH)?1:0;
}
static cell AMX_NATIVE_CALL n_remove(AMX *amx, cell *p) {
    if (!count(p,1)) return 0;
    std::string a,path;
    if (!pawn_read(amx,p[1],a)||!file_path(a,path)) return 0;
    return DeleteFileA(path.c_str())?1:0;
}
static cell AMX_NATIVE_CALL n_open(AMX *amx, cell *p) {
    if (!count(p,2)||p[2]<0||p[2]>=6) return 0;
    std::string a,path;
    if (!pawn_read(amx,p[1],a)) return 0;
    if (a=="server_log.txt") path=a;
    else if (!file_path(a,path)) return 0;
    const char *modes[]={"rb","wb","ab","r+b","w+b","a+b"};
    FILE *f=nullptr;
    if (fopen_s(&f,path.c_str(),modes[p[2]])!=0||!f) return 0;
    g_files.insert(f);
    return static_cast<cell>(reinterpret_cast<uintptr_t>(f));
}
static cell AMX_NATIVE_CALL n_close(AMX *, cell *p) {
    if (!count(p,1)) return 0;
    FILE *f=get_handle(p[1]);
    if (!f) return 0;
    g_files.erase(f);
    return fclose(f)==0?1:0;
}
static cell AMX_NATIVE_CALL n_read(AMX *amx, cell *p) {
    if (!count(p,3)||p[3]<2||p[3]>4096) return 0;
    FILE *f=get_handle(p[1]);
    if (!f) return 0;
    std::vector<char> b(static_cast<size_t>(p[3]),0);
    if (!fgets(b.data(),static_cast<int>(b.size()),f)) return 0;
    return pawn_write(amx,p[2],b.data(),b.size())?1:0;
}
static cell AMX_NATIVE_CALL n_seek(AMX *, cell *p) {
    if (!count(p,3)||p[3]<0||p[3]>2) return 0;
    FILE *f=get_handle(p[1]);
    if (!f) return 0;
    const int origins[]={SEEK_SET,SEEK_CUR,SEEK_END};
    return fseek(f,static_cast<long>(p[2]),origins[p[3]])==0?1:0;
}
static AMX_NATIVE_INFO natives[]={
    {"fileMove",n_move},{"fileRemove",n_remove},
    {"fileOpen",n_open},{"fileClose",n_close},
    {"fileRead",n_read},{"fileSeek",n_seek},
    {nullptr,nullptr}
};
extern "C" unsigned int __stdcall Supports() { return SUPPORTS_VERSION|SUPPORTS_AMX_NATIVES; }
extern "C" bool __stdcall Load(void **data) {
    if (!data||!data[PLUGIN_DATA_AMX_EXPORTS]) return false;
    g_amx=reinterpret_cast<void **>(data[PLUGIN_DATA_AMX_EXPORTS]);
    return true;
}
extern "C" void __stdcall Unload() {
    for (FILE *f: g_files) fclose(f);
    g_files.clear();
}
extern "C" int __stdcall AmxLoad(AMX *amx) {
    if (!amx||!g_amx) return 1;
    return api<int (AMXAPI *)(AMX *, const AMX_NATIVE_INFO *, int)>(
        PLUGIN_AMX_EXPORT_Register)(amx,natives,-1);
}
extern "C" int __stdcall AmxUnload(AMX *) { return 0; }
