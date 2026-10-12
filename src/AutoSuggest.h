#import <Cocoa/Cocoa.h>
#include "EditorBridge.hpp"

@interface WAAutoSuggest : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic) BOOL connectionReady;
@property(nonatomic) BOOL coding;
@property(nonatomic, copy) NSString *endpoint;
@property(nonatomic, copy) NSString *model;
@property(nonatomic, copy) NSString *completionModel;
- (instancetype)initWithEditor:(wa::EditorBridge *)editor;
- (void)characterAdded;
- (void)checkContext;
- (void)cancel;
- (void)shutdown;
@end
