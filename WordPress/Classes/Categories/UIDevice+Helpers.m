#import "UIDevice+Helpers.h"

static NSString * const WordPressIdentifierDefaultsKey = @"WordPressIdentifier";

@implementation UIDevice (Helpers)

- (NSString *)wordPressUserAgent
{
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *userAgent = [NSString stringWithFormat:@"wp-iphone/%@ (%@ %@, %@) Mobile",
                           appVersion,
                           self.systemName,
                           self.systemVersion,
                           self.model];
    
    return userAgent;
}

- (NSString *)wordPressIdentifier
{
    NSString *uuid;
    if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)]) {
        uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    } else {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        uuid = [defaults objectForKey:WordPressIdentifierDefaultsKey];
        if (!uuid) {
            uuid = [self generateUUID];
            [defaults setObject:uuid forKey:WordPressIdentifierDefaultsKey];
            [defaults synchronize];
        }
    }
    return uuid;
}

- (NSString *)generateUUID
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return (__bridge_transfer NSString *)string;
}

@end
