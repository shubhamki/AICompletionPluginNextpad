// Isolated settings harness: no user editor, documents or configuration are opened.
#import <Cocoa/Cocoa.h>
#include "NppPluginInterfaceMac.h"
#include "Scintilla.h"
#include <dlfcn.h>
#include <cstring>
#include <iostream>

static NSString *configurationDirectory;
static intptr_t Send(NppHandle, uint32_t message, uintptr_t capacity, intptr_t output) {
    if (message == NPPM_GETPLUGINSCONFIGDIR && output && capacity) {
        strlcpy((char *)output, configurationDirectory.fileSystemRepresentation, capacity);
        return 1;
    }
    return 0;
}
int main(int argc, char **argv) { @autoreleasepool {
    NSString *libraryPath;
    if (argc == 3) {
        libraryPath = [NSString stringWithUTF8String:argv[1]];
        configurationDirectory = [NSString stringWithUTF8String:argv[2]];
    } else if (argc == 1) {
        NSString *build = [NSBundle.mainBundle.bundlePath stringByDeletingLastPathComponent];
        libraryPath = [build stringByAppendingPathComponent:@"WritingAssistant/WritingAssistant.dylib"];
        configurationDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    } else return 2;
    [NSFileManager.defaultManager createDirectoryAtPath:configurationDirectory
        withIntermediateDirectories:YES attributes:nil error:nil];
    NSApplication *app = NSApplication.sharedApplication;
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    [app finishLaunching];
    void *library = dlopen(libraryPath.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
    if (!library) { std::cerr << dlerror() << '\n'; return 1; }
    auto info = (PFUNCSETINFO)dlsym(library, "setInfo");
    auto items = (PFUNCGETFUNCSARRAY)dlsym(library, "getFuncsArray");
    if (!info || !items) return 1;
    info({1, 2, 3, Send});
    int count = 0; FuncItem *commands = items(&count);
    if (count != 7) return 1;
    [app activateIgnoringOtherApps:YES];
    commands[5]._pFunc();
    return 0;
} }
