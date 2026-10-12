#import <Foundation/Foundation.h>
#include "EditorBridge.hpp"
#import "LocalModel.h"
#import "SuggestionText.h"
#import "CodeCompletion.h"
#include <cassert>
#include <iostream>

static std::string text = "She go to school yesterday.";
static intptr_t caret = text.size(), anchor = 0, bufferID = 44, documentID = 55;
static int view = 0, selections = 1, selectionMode = SC_SEL_STREAM, page = SC_CP_UTF8;
static bool readOnly = false;
static int eol = SC_EOL_LF;
static size_t targetStart, targetEnd;
static int undoStarts = 0, undoEnds = 0;
static intptr_t Send(uintptr_t h, uint32_t m, uintptr_t w, intptr_t l) {
    if (h == 1) {
        if (m == NPPM_GETCURRENTSCINTILLA) { *(int *)l = view; return 1; }
        if (m == NPPM_GETCURRENTBUFFERID) return bufferID;
        return 0;
    }
    assert(h == (view == 0 ? 2 : 3));
    switch (m) {
        case SCI_GETREADONLY: return readOnly;
        case SCI_GETEOLMODE: return eol;
        case SCI_GETCODEPAGE: return page;
        case SCI_GETSELECTIONS: return selections;
        case SCI_GETSELECTIONMODE: return selectionMode;
        case SCI_GETLENGTH: return text.size();
        case SCI_GETCURRENTPOS: return caret;
        case SCI_GETANCHOR: return anchor;
        case SCI_GETDOCPOINTER: return documentID;
        case SCI_GETTEXT: assert(w == text.size() + 1); memcpy((void *)l, text.c_str(), w); return text.size();
        case SCI_BEGINUNDOACTION: ++undoStarts; break;
        case SCI_ENDUNDOACTION: ++undoEnds; break;
        case SCI_SETTARGETSTART: targetStart = w; break;
        case SCI_SETTARGETEND: targetEnd = w; break;
        case SCI_REPLACETARGET: text.replace(targetStart, targetEnd - targetStart, (const char *)l, w); return w;
        case SCI_SETSEL: anchor = w; caret = l; break;
    }
    return 0;
}
static int checks = 0;
#define CHECK(x) do { ++checks; if (!(x)) { std::cerr << "FAILED line " << __LINE__ << ": " << #x << "\n"; return 1; } } while(0)
int main(int argc, char **argv) { @autoreleasepool {
    wa::EditorBridge ed; ed.host = {1, 2, 3, Send}; wa::Snapshot s; std::string error;
    CHECK(ed.capture(wa::Action::Grammar, s, error));
    CHECK(s.context == text && ed.matches(s));
    CHECK(!ed.capture(wa::Action::Continue, s, error));
    CHECK(ed.capture(wa::Action::Grammar, s, error));
    ++ed.revision; CHECK(!ed.matches(s)); --ed.revision;
    ++bufferID; CHECK(!ed.matches(s)); --bufferID;
    ++documentID; CHECK(!ed.matches(s)); --documentID;
    --caret; CHECK(!ed.matches(s)); ++caret;
    ++anchor; CHECK(!ed.matches(s)); --anchor;
    view = 1; CHECK(!ed.matches(s)); view = 0;
    text[0] = 's'; CHECK(!ed.matches(s)); text[0] = 'S';
    text += '!'; CHECK(!ed.matches(s)); text.pop_back();
    readOnly = true; CHECK(!ed.apply(s, "oops")); readOnly = false;
    CHECK(!ed.apply(s, std::string("a\0b", 3)));
    std::string original = text;
    text = std::string("a\0b", 3); caret = anchor = text.size();
    CHECK(!ed.capture(wa::Action::Continue, s, error));
    text = original; caret = text.size(); anchor = 0;
    CHECK(ed.capture(wa::Action::Grammar, s, error));
    CHECK(ed.apply(s, "She went to school yesterday."));
    CHECK(text == "She went to school yesterday." && undoStarts == 1 && undoEnds == 1);
    CHECK(!ed.apply(s, "duplicate"));
    text = "Café 🌍 नमस्ते"; caret = text.size(); anchor = caret;
    CHECK(ed.capture(wa::Action::Continue, s, error));
    CHECK(s.context == text && ed.apply(s, " — hello"));
    CHECK(text == "Café 🌍 नमस्ते — hello");
    CHECK(!ed.capture(wa::Action::Rewrite, s, error));
    view = 1; anchor = 0; caret = text.size();
    CHECK(ed.capture(wa::Action::Rewrite, s, error)); CHECK(s.view == 3);
    selections = 2; CHECK(!ed.capture(wa::Action::Rewrite, s, error)); selections = 1;
    selectionMode = SC_SEL_RECTANGLE; CHECK(!ed.capture(wa::Action::Rewrite, s, error)); selectionMode = SC_SEL_STREAM;
    page = 0; CHECK(!ed.capture(wa::Action::Rewrite, s, error)); page = SC_CP_UTF8;
    text = std::string(8200, 'a') + "🌍" + std::string(8189, 'b'); caret = anchor = text.size();
    CHECK(ed.capture(wa::Action::Continue, s, error));
    CHECK([[NSString alloc] initWithBytes:s.context.data() length:s.context.size() encoding:NSUTF8StringEncoding] != nil);
    CHECK(s.context.size() <= 8192);
    text = std::string(32769, 'a'); anchor = 0; caret = text.size();
    CHECK(!ed.capture(wa::Action::Rewrite, s, error));
    text = std::string(2 * 1024 * 1024 + 1, 'a'); caret = anchor = text.size();
    CHECK(!ed.capture(wa::Action::Continue, s, error));
    for (NSString *url in @[@"http://127.0.0.1:11434/v1/chat/completions", @"http://localhost:1234/v1/chat/completions", @"http://[::1]:1234/v1/chat/completions"]) CHECK(WAValidEndpoint(url));
    for (NSString *url in @[@"https://example.com/v1/chat/completions", @"http://127.0.0.1.evil.test/v1/chat/completions", @"file:///v1/chat/completions", @"http://user@localhost/v1/chat/completions", @"http://localhost/v1/chat/completions?key=x", @"http://localhost/api/generate", @"http://localhost:99999/v1/chat/completions"]) CHECK(!WAValidEndpoint(url));
    NSString *err = nil;
    NSData *(^data)(id) = ^NSData *(id obj) { return [NSJSONSerialization dataWithJSONObject:obj options:NSJSONWritingFragmentsAllowed error:nil]; };
    CHECK([WAExtractReply(data(@{@"choices": @[@{@"message": @{@"content": @" hello"}, @"finish_reason": @"stop"}]}), &err) isEqual:@" hello"]);
    CHECK([WAExtractReply(data(@{@"choices": @[@{@"message": @{@"content": @"<think>secret</think>\n\nFixed."}, @"finish_reason": @"stop"}]}), &err) isEqual:@"Fixed."]);
    for (id bad in @[@[], @{}, @{@"choices": @"bad"}, @{@"choices": @[@42]}, @{@"choices": @[@{@"message": @{@"content": @42}}]}, @{@"choices": @[@{@"message": @{@"content": @"unfinished"}, @"finish_reason": @"length"}]}, @{@"choices": @[@{@"message": @{@"content": @"<think>incomplete"}, @"finish_reason": @"stop"}]}]) CHECK(WAExtractReply(data(bad), &err) == nil);
    CHECK(WAExtractReply([@"not json" dataUsingEncoding:NSUTF8StringEncoding], &err) == nil);
    NSDictionary *body = WARequestBody(@"local-model", @"Fix grammar", @"She go.");
    CHECK([body[@"model"] isEqual:@"local-model"] && [body[@"stream"] isEqual:@NO]);
    CHECK([body[@"messages"][1][@"content"] isEqual:@"She go."]);
    std::cout << checks << " core checks passed\n";
    CHECK([WANormalizeSuggestion(@"The best way is through practice.", @"The best way is ") isEqual:@"through practice."]);
    CHECK([WANormalizeSuggestion(@"through practice.", @"The best way is") isEqual:@" through practice."]);
    CHECK([WANormalizeSuggestion(@"again", @"Try ") isEqual:@"again"]);
    CHECK([WANormalizeSuggestion(@", then test.", @"Write") isEqual:@", then test."]);
    CHECK(WANormalizeSuggestion(@"same text", @"same text") == nil);
    CHECK([WANormalizeSuggestion(@"世界", @"你好 ") isEqual:@"世界"]);
    CHECK(WANormalizeSuggestion(@" \n", @"context") == nil);
    std::cout << "Suggestion echo and whitespace checks passed\n";
    s = {}; s.context = "def add(a, b):\n    return a + "; s.suffix = "\n";
    CHECK([WACodeLanguage(s) isEqual:@"Python"]);
    CHECK([WANormalizeCode(@"b", s, YES) isEqual:@"b"]);
    CHECK([WANormalizeCode(@"b\n\ndef unwanted():", s, YES) isEqual:@"b"]);
    s.context = "std::str"; s.suffix = " value;";
    CHECK([WANormalizeCode(@"ing", s, YES) isEqual:@"ing"]);
    CHECK([WACodeLanguage(s) isEqual:@"C++"]);
    s.context = "Console.WriteLine("; s.suffix = ");";
    CHECK([WANormalizeCode(@"\"ready\");", s, YES) isEqual:@"\"ready\""]);
    s.suffix = "";
    CHECK([WANormalizeCode(@"    return 1;", s, YES) isEqual:@"    return 1;"]);
    CHECK([WANormalizeCode(@"```cpp\n    return 1;\n```", s, YES) isEqual:@"    return 1;"]);
    CHECK(WANormalizeCode(@"<|fim_suffix|>", s, YES) == nil);
    CHECK(WANormalizeCode(@"```broken", s, YES) == nil);
    s.eolMode = SC_EOL_CRLF;
    CHECK([WANormalizeCode(@"    a();\n    b();", s, NO) isEqual:@"    a();\r\n    b();"]);
    s.language = "C#";
    CHECK([WACodeLanguage(s) isEqual:@"C#"]);
    NSDictionary *fim = WACodeRequest(@"nextpad-coder:0.5b", s, YES);
    CHECK([fim[@"raw"] isEqual:@YES] && [fim[@"stream"] isEqual:@NO]);
    CHECK([fim[@"prompt"] containsString:@"<|fim_suffix|>"] && [fim[@"options"][@"num_predict"] isEqual:@96]);
    NSDictionary *chat = WACodeRequest(@"local", s, NO);
    CHECK([WACodePrompt(s) containsString:@"</PREFIX>\n<CURSOR>\n<SUFFIX>\n"]);
    CHECK([chat[@"temperature"] isEqual:@0.1] && [chat[@"max_tokens"] isEqual:@128]);
    CHECK([WAFIMEndpoint(@"http://127.0.0.1:11434/v1/chat/completions", @"nextpad-coder:0.5b") isEqual:@"http://127.0.0.1:11434/api/generate"]);
    CHECK(WAFIMEndpoint(@"http://127.0.0.1:1234/v1/chat/completions", @"nextpad-coder:0.5b") == nil);
    CHECK(WAFIMEndpoint(@"http://127.0.0.1:11434/v1/chat/completions", @"qwen2.5:0.5b") == nil);
    CHECK([WAFIMEndpoint(@"http://127.0.0.1:11434/v1/chat/completions", @"nextpad-complete:0.5b") isEqual:@"http://127.0.0.1:11434/api/generate"]);
    CHECK(WAValidRequestEndpoint(@"http://127.0.0.1:11434/api/generate"));
    CHECK(!WAValidEndpoint(@"http://127.0.0.1:11434/api/generate"));
    CHECK(!WAValidRequestEndpoint(@"http://example.com/api/generate"));
    CHECK([WAExtractReply(data(@{@"response":@"b;", @"done":@YES, @"done_reason":@"stop"}), &err) isEqual:@"b;"]);
    CHECK(WAExtractReply(data(@{@"response":@"b;", @"done":@YES, @"done_reason":@"length"}), &err) == nil);
    CHECK(WAExtractReply(data(@{@"response":@42, @"done":@YES, @"done_reason":@"stop"}), &err) == nil);
    text = "def add(a, b):\n    return a + \n"; caret = anchor = text.size() - 1;
    CHECK(ed.capture(wa::Action::Continue, s, error));
    CHECK(s.suffix == "\n" && s.context == "def add(a, b):\n    return a + ");
    CHECK(ed.apply(s, "b")); CHECK(text == "def add(a, b):\n    return a + b\n");
    std::cout << "Code context, FIM request, whitespace, suffix overlap and native response checks passed (" << checks << " total)\n";
    if (argc > 2 && std::string(argv[1]) == "--http-tests") {
        NSString *endpoint = [NSString stringWithUTF8String:argv[2]];
        WALocalModel *client = [WALocalModel new];
        for (NSString *scenario in @[@"valid", @"invalid-json", @"http-error", @"redirect", @"oversized", @"truncated"]) {
            __block bool done = false;
            __block NSString *reply = nil, *failure = nil;
            [client requestEndpoint:endpoint model:scenario instruction:@"test" text:@"synthetic text"
                completion:^(NSString *r, NSString *e) { reply = r; failure = e; done = true; }];
            NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
            while (!done && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
            CHECK(done);
            if ([scenario isEqual:@"valid"]) CHECK([reply isEqual:@"Corrected text."] && !failure);
            else CHECK(!reply && failure.length > 0);
        }
        __block bool oldCalled = false, newCalled = false;
        [client requestEndpoint:endpoint model:@"slow" instruction:@"test" text:@"synthetic text"
            completion:^(NSString *, NSString *) { oldCalled = true; }];
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        [client cancel];
        [client requestEndpoint:endpoint model:@"valid" instruction:@"test" text:@"synthetic text"
            completion:^(NSString *reply, NSString *failure) { newCalled = [reply isEqual:@"Corrected text."] && !failure; }];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.2];
        while (deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        CHECK(!oldCalled && newCalled);
        [client cancel];
        NSURLComponents *nativeURL = [NSURLComponents componentsWithString:endpoint]; nativeURL.path = @"/api/generate";
        for (NSString *scenario in @[@"valid", @"truncated"]) {
            __block bool done = false, correct = false;
            [client requestEndpoint:nativeURL.string body:@{@"model":scenario, @"prompt":@"synthetic code", @"raw":@YES, @"stream":@NO}
                completion:^(NSString *reply, NSString *failure) {
                    correct = [scenario isEqual:@"valid"] ? ([reply isEqual:@"b;"] && !failure) : (!reply && failure.length);
                    done = true;
                }];
            NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
            while (!done && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
            CHECK(done && correct);
        }
        std::cout << "HTTP failure, redirect, reply size and cancellation checks passed\n";
    }
    if (argc > 1 && std::string(argv[1]) == "--live") {
        __block bool done = false, success = false;
        WALocalModel *client = [WALocalModel new];
        [client requestEndpoint:@"http://127.0.0.1:11434/v1/chat/completions" model:@"deepseek-r1:1.5b"
            instruction:@"Correct the grammar. Output only the corrected sentence without reasoning." text:@"She go to school yesterday."
            completion:^(NSString *reply, NSString *failure) {
                success = reply.length > 0 && !failure;
                fprintf(stdout, "Local model: %s\n", (reply ?: failure).UTF8String); done = true;
            }];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:125];
        while (!done && deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        [client cancel]; CHECK(done && success);
    }
    return 0;
} }
