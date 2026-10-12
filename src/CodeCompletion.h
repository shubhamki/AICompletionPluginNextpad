#import <Foundation/Foundation.h>
#include "EditorBridge.hpp"
NSString *WACodeLanguage(const wa::Snapshot &snapshot);
NSString *WACodePrompt(const wa::Snapshot &snapshot);
NSDictionary *WACodeRequest(NSString *model, const wa::Snapshot &snapshot, BOOL fim);
NSString *WANormalizeCode(NSString *reply, const wa::Snapshot &snapshot, BOOL inlineCompletion);
NSString *WAFIMEndpoint(NSString *chatEndpoint, NSString *model);
