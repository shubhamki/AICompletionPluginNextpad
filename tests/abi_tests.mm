#import <Foundation/Foundation.h>
#include "Scintilla.h"
#include "NppPluginInterfaceMac.h"
#include <dlfcn.h>
#include <cassert>
#include <cstring>
#include <iostream>
static intptr_t Send(uintptr_t, uint32_t, uintptr_t, intptr_t) { return 0; }
int main(int argc, char **argv) { @autoreleasepool {
    assert(argc == 2);
    void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!library) { std::cerr << dlerror() << "\n"; return 1; }
    auto name = (PFUNCGETNAME)dlsym(library, "getName");
    auto items = (PFUNCGETFUNCSARRAY)dlsym(library, "getFuncsArray");
    auto info = (PFUNCSETINFO)dlsym(library, "setInfo");
    auto notify = (PBENOTIFIED)dlsym(library, "beNotified");
    assert(name && items && info && notify && dlsym(library, "messageProc"));
    assert(strcmp(name(), "Writing Assistant") == 0);
    int count = 0; FuncItem *commands = items(&count);
    assert(count == 7 && commands);
    for (int i = 0; i < count; ++i) assert(commands[i]._pFunc && commands[i]._itemName[0]);
    info({1, 2, 3, Send});
    SCNotification notification{}; notification.nmhdr.code = NPPN_READY; notify(&notification);
    notification.nmhdr.code = NPPN_SHUTDOWN; notify(&notification);
    dlclose(library);
    std::cout << "Plugin ABI load, seven commands and shutdown passed\n";
    return 0;
} }
