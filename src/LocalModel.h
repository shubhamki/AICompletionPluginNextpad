#import <Foundation/Foundation.h>

// Deliberately accepts only literal loopback hosts, with no redirects or proxies.
BOOL WAValidEndpoint(NSString *endpoint);
BOOL WAValidRequestEndpoint(NSString *endpoint);
NSString *WAExtractReply(NSData *data, NSString **error);
NSDictionary *WARequestBody(NSString *model, NSString *instruction, NSString *text);

@interface WALocalModel : NSObject <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
@property(nonatomic, copy) void (^completion)(NSString *, NSString *);
- (void)requestEndpoint:(NSString *)endpoint body:(NSDictionary *)body
             completion:(void (^)(NSString *reply, NSString *error))completion;
- (void)requestEndpoint:(NSString *)endpoint model:(NSString *)model
            instruction:(NSString *)instruction text:(NSString *)text
             completion:(void (^)(NSString *reply, NSString *error))completion;
- (void)cancel;
@end
