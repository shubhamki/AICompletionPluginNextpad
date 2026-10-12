#import "CodeCompletion.h"
#import "LocalModel.h"

static NSString *Text(const std::string &text) {
    return [[NSString alloc] initWithBytes:text.data() length:text.size() encoding:NSUTF8StringEncoding] ?: @"";
}
NSString *WACodeLanguage(const wa::Snapshot &s) {
    NSString *language = Text(s.language);
    if (language.length && ![@[@"normal text", @"normal text file", @"text", @"plain text"] containsObject:language.lowercaseString]) return language;
    NSString *source = [Text(s.context) stringByAppendingString:Text(s.suffix) ?: @""];
    if ([source containsString:@"using UnityEngine"] || [source containsString:@"using System"] || [source containsString:@"MonoBehaviour"]) return @"C#";
    if ([source containsString:@"def "] || [source containsString:@"import "]) return @"Python";
    if ([source containsString:@"#include"] || [source containsString:@"std::"]) return @"C++";
    if ([source containsString:@"function "] || [source containsString:@"const "] || [source containsString:@"=>"]) return @"JavaScript/TypeScript";
    if ([source containsString:@"void "] || [source containsString:@"int "]) return @"C-like language";
    return @"match the surrounding code";
}
NSString *WACodePrompt(const wa::Snapshot &s) {
    return [NSString stringWithFormat:@"Language: %@\nInsert only the missing code at <CURSOR>. Do not repeat the prefix or suffix. Preserve whitespace and indentation; finish partial identifiers without adding a space. Return one short code line, no markdown or explanation.\n<PREFIX>\n%@\n</PREFIX>\n<CURSOR>\n<SUFFIX>\n%@\n</SUFFIX>", WACodeLanguage(s), Text(s.context), Text(s.suffix)];
}
NSDictionary *WACodeRequest(NSString *model, const wa::Snapshot &s, BOOL fim) {
    if (fim) {
        NSString *prompt = [NSString stringWithFormat:@"<|fim_prefix|>%@<|fim_suffix|>%@<|fim_middle|>", Text(s.context), Text(s.suffix)];
        return @{@"model":model, @"prompt":prompt, @"raw":@YES, @"stream":@NO, @"keep_alive":@"10m",
            @"options":@{@"temperature":@0.1, @"top_p":@0.9, @"top_k":@20, @"repeat_penalty":@1.05,
                @"num_ctx":@4096, @"num_predict":@96,
                @"stop":@[@"\n", @"\r", @"<|fim_pad|>", @"<|endoftext|>", @"<|im_end|>", @"<|fim_prefix|>", @"<|fim_suffix|>", @"<|fim_middle|>"]}};
    }
    NSMutableDictionary *body = [WARequestBody(model, @"You are a code insertion engine. Return only the exact code to insert at the cursor, preserving identifiers and formatting.", WACodePrompt(s)) mutableCopy];
    body[@"temperature"] = @0.1; body[@"max_tokens"] = @128;
    return body;
}
NSString *WAFIMEndpoint(NSString *endpoint, NSString *model) {
    BOOL base = [model hasPrefix:@"qwen2.5-coder:"] && [model hasSuffix:@"-base"];
    if (!WAValidEndpoint(endpoint) || !(base || [model hasPrefix:@"nextpad-complete:"])) return nil;
    NSURLComponents *url = [NSURLComponents componentsWithString:endpoint];
    // Native FIM is Ollama-specific; other local endpoints use the chat fallback.
    if (url.port.integerValue != 11434) return nil;
    url.path = @"/api/generate";
    return url.string;
}
NSString *WANormalizeCode(NSString *reply, const wa::Snapshot &s, BOOL inlineCompletion) {
    NSString *code = reply;
    // Strip a complete markdown wrapper only. Never trim code indentation.
    if ([code hasPrefix:@"```"] && [[code stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet] hasSuffix:@"```"] ) {
        NSRange newline = [code rangeOfString:@"\n"];
        NSString *trimmed = [code stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
        if (newline.location == NSNotFound || trimmed.length < NSMaxRange(newline) + 3) return nil;
        code = [trimmed substringWithRange:NSMakeRange(NSMaxRange(newline), trimmed.length - NSMaxRange(newline) - 3)];
        if ([code hasSuffix:@"\n"]) code = [code substringToIndex:code.length - 1];
    }
    if ([code containsString:@"<|"] || [code containsString:@"<CURSOR>"] || [code containsString:@"```"] ) return nil;
    NSString *prefix = Text(s.context), *suffix = Text(s.suffix);
    if (inlineCompletion && prefix.length >= 8 && [code hasPrefix:prefix]) code = [code substringFromIndex:prefix.length];
    if (inlineCompletion) {
        // One line avoids spilling generated helpers into the existing document.
        NSRange newline = [code rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet];
        if (newline.location != NSNotFound) code = [code substringToIndex:newline.location];
        // Remove exact overlap with the existing same-line suffix, including ')' and ';'.
        NSString *suffixLine = [suffix componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet].firstObject;
        for (NSUInteger n = MIN(code.length, suffixLine.length); n > 0; --n) {
            if ([[code substringFromIndex:code.length - n] isEqual:[suffixLine substringToIndex:n]]) {
                code = [code substringToIndex:code.length - n]; break;
            }
        }
    }
    if (!code.length || (inlineCompletion && code.length > 800) || ![code stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) return nil;
    if (s.eolMode != SC_EOL_LF) {
        code = [[code stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
        code = [code stringByReplacingOccurrencesOfString:@"\n" withString:s.eolMode == SC_EOL_CRLF ? @"\r\n" : @"\r"];
    }
    return code;
}
