#import "SuggestionText.h"
NSString *WANormalizeSuggestion(NSString *reply, NSString *context) {
    NSString *result = [reply stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *trimmed = [context stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    // Local instruction models sometimes echo the complete prompt paragraph.
    // Strip exact echoes only; never fuzzy-delete text the model may have changed.
    if (trimmed.length && [result hasPrefix:trimmed]) result = [result substringFromIndex:trimmed.length];
    result = [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!result.length || result.length > 800) return nil;
    if (context.length && ![NSCharacterSet.whitespaceAndNewlineCharacterSet characterIsMember:[context characterAtIndex:context.length - 1]] &&
        [NSCharacterSet.alphanumericCharacterSet characterIsMember:[result characterAtIndex:0]])
        result = [@" " stringByAppendingString:result];
    return result;
}
