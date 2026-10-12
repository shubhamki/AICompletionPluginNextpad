#import "LocalModel.h"

BOOL WAValidEndpoint(NSString *endpoint) {
    return WAValidRequestEndpoint(endpoint) && [[[NSURLComponents componentsWithString:endpoint] path] isEqual:@"/v1/chat/completions"];
}
BOOL WAValidRequestEndpoint(NSString *endpoint) {
    NSURLComponents *url = [NSURLComponents componentsWithString:endpoint];
    NSSet *hosts = [NSSet setWithArray:@[@"localhost", @"127.0.0.1", @"[::1]", @"::1"]];
    return url && [hosts containsObject:url.host.lowercaseString] &&
        ([@"http" isEqual:url.scheme] || [@"https" isEqual:url.scheme]) &&
        !url.user && !url.password && !url.query && !url.fragment &&
        (!url.port || (url.port.integerValue > 0 && url.port.integerValue <= 65535)) &&
        [@[@"/v1/chat/completions", @"/api/generate"] containsObject:url.path] && url.URL != nil;
}

NSDictionary *WARequestBody(NSString *model, NSString *instruction, NSString *text) {
    return @{@"model": model, @"stream": @NO, @"temperature": @0.3, @"max_tokens": @2048,
        @"messages": @[@{@"role": @"system", @"content": instruction},
                       @{@"role": @"user", @"content": text}]};
}

NSString *WAExtractReply(NSData *data, NSString **error) {
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class]) { *error = @"The local server returned invalid JSON."; return nil; }
    if (json[@"response"]) {
        if (![json[@"response"] isKindOfClass:NSString.class] || ![json[@"done"] isEqual:@YES] || ![json[@"done_reason"] isEqual:@"stop"]) {
            *error = @"The code model returned an incomplete response."; return nil;
        }
        // Reuse the same empty-text, NUL and reasoning validation below.
        json = @{@"choices":@[@{@"message":@{@"content":json[@"response"]}, @"finish_reason":@"stop"}]};
    }
    id choices = json[@"choices"];
    id first = [choices isKindOfClass:NSArray.class] && [choices count] ? choices[0] : nil;
    id message = [first isKindOfClass:NSDictionary.class] ? first[@"message"] : nil;
    id content = [message isKindOfClass:NSDictionary.class] ? message[@"content"] : nil;
    if (![content isKindOfClass:NSString.class]) { *error = @"The local server returned no suggestion."; return nil; }
    if (![first[@"finish_reason"] isEqual:@"stop"]) {
        *error = @"The model did not finish its reply. Try a shorter selection or another model."; return nil;
    }
    NSString *reply = content;
    // Some local reasoning models put private scratch text in content.
    while (YES) {
        NSRange open = [reply rangeOfString:@"<think>"];
        if (open.location == NSNotFound) break;
        NSRange close = [reply rangeOfString:@"</think>" options:0 range:NSMakeRange(NSMaxRange(open), reply.length - NSMaxRange(open))];
        if (close.location == NSNotFound) { *error = @"The model returned unfinished reasoning instead of a suggestion."; return nil; }
        reply = [reply stringByReplacingCharactersInRange:NSMakeRange(open.location, NSMaxRange(close) - open.location) withString:@""];
        // Remove separator newlines left by the reasoning block, preserving ordinary prose whitespace.
        while ([reply hasPrefix:@"\n"]) reply = [reply substringFromIndex:1];
    }
    unichar nul = 0;
    if ([reply rangeOfString:[NSString stringWithCharacters:&nul length:1]].location != NSNotFound ||
        ![reply stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) {
        *error = @"The model returned empty or invalid text."; return nil;
    }
    return reply;
}

@implementation WALocalModel {
    NSURLSession *_session;
    NSURLSessionDataTask *_task;
    NSMutableData *_data;
    NSString *_failure;
}
- (void)requestEndpoint:(NSString *)endpoint model:(NSString *)model instruction:(NSString *)instruction
                  text:(NSString *)text completion:(void (^)(NSString *, NSString *))completion {
    [self requestEndpoint:endpoint body:WARequestBody(model, instruction, text) completion:completion];
}
- (void)requestEndpoint:(NSString *)endpoint body:(NSDictionary *)body completion:(void (^)(NSString *, NSString *))completion {
    [self cancel];
    if (!WAValidRequestEndpoint(endpoint)) { completion(nil, @"Use a supported local loopback endpoint."); return; }
    self.completion = completion;
    _data = [NSMutableData data]; _failure = nil;
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.connectionProxyDictionary = @{};
    config.HTTPCookieStorage = nil; config.URLCredentialStorage = nil; config.URLCache = nil;
    config.timeoutIntervalForRequest = 120; config.timeoutIntervalForResource = 120;
    _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpoint]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    _task = [_session dataTaskWithRequest:request]; [_task resume];
}
- (void)cancel {
    self.completion = nil;
    [_task cancel]; [_session invalidateAndCancel];
    _task = nil; _session = nil; _data = nil;
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
    completionHandler:(void (^)(NSURLRequest *))completionHandler {
    if (session == _session) _failure = @"Redirects are disabled. Set the local server's direct URL in Settings.";
    completionHandler(nil);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task
    didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if (session != _session) { completionHandler(NSURLSessionResponseCancel); return; }
    NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
    if (status != 200) _failure = [NSString stringWithFormat:@"Local server returned HTTP %ld. Check the model name and server settings.", (long)status];
    if (response.expectedContentLength > 1024 * 1024) _failure = @"The local server's reply exceeded 1 MB.";
    completionHandler(_failure ? NSURLSessionResponseCancel : NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if (session != _session) return;
    if (_data.length + data.length > 1024 * 1024) { _failure = @"The local server's reply exceeded 1 MB."; [task cancel]; return; }
    [_data appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (session != _session) return;
    NSString *failure = _failure;
    if (error && !failure) failure = @"Could not reach the local model. Start Ollama or LM Studio's local server, load a model, then try again.";
    NSString *reply = failure ? nil : WAExtractReply(_data, &failure);
    void (^done)(NSString *, NSString *) = self.completion;
    self.completion = nil;
    [_session finishTasksAndInvalidate]; _session = nil; _task = nil; _data = nil;
    if (done) done(reply, failure);
}
@end
