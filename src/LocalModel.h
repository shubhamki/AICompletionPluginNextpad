#import <Foundation/Foundation.h>

// Accepts loopback IPs and localhost; localhost is canonicalized before transport.
BOOL WAValidEndpoint(NSString *endpoint);
BOOL WAValidRequestEndpoint(NSString *endpoint);
NSURL *WALocalRequestURL(NSString *endpoint);
BOOL WASettingFlag(id value, BOOL fallback);
NSString *WAValidateModels(NSData *data, NSArray<NSString *> *models);
NSArray<NSString *> *WAParseModels(NSData *data, NSString **error);
NSString *WAExtractReply(NSData *data, NSString **error);
NSDictionary *WARequestBody(NSString *model, NSString *instruction, NSString *text);

@interface WALocalModel : NSObject <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
@property(nonatomic, copy) void (^completion)(NSString *, NSString *);
@property(nonatomic, copy) NSArray<NSString *> *availableModels;
- (void)listEndpoint:(NSString *)endpoint completion:(void (^)(NSArray<NSString *> *models, NSString *error))completion;
- (void)requestEndpoint:(NSString *)endpoint body:(NSDictionary *)body
             completion:(void (^)(NSString *reply, NSString *error))completion;
- (void)requestEndpoint:(NSString *)endpoint model:(NSString *)model
            instruction:(NSString *)instruction text:(NSString *)text
             completion:(void (^)(NSString *reply, NSString *error))completion;
- (void)cancel;
- (void)checkEndpoint:(NSString *)endpoint models:(NSArray<NSString *> *)models
           completion:(void (^)(NSString *error))completion;
@end
