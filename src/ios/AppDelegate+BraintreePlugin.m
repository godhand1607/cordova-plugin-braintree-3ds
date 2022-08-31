#import "AppDelegate+BraintreePlugin.h"
#import <objc/runtime.h>
#import <Braintree/BTAppContextSwitcher.h>

@implementation AppDelegate(BraintreePlugin)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        Class class = [self class];

        SEL originalSelector = @selector(application:didFinishLaunchingWithOptions:);
        SEL swizzledSelector = @selector(BraintreePlugin_application:didFinishLaunchingWithOptions:);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (BOOL) BraintreePlugin_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"AppDelegate(BraintreePlugin):didFinishLaunchingWithOptions");
    [BTAppContextSwitcher setReturnURLScheme:[self getUrlScheme]];
    return [self BraintreePlugin_application:application didFinishLaunchingWithOptions:launchOptions];
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    NSLog(@"AppDelegate(BraintreePlugin):application");
    if ([url.scheme localizedCaseInsensitiveCompare:[self getUrlScheme]] == NSOrderedSame) {
        return [BTAppContextSwitcher handleOpenURL:url];
    }
    return NO;
}

- (NSString*) getUrlScheme {
    return [NSString stringWithFormat:@"%@.braintree", [[NSBundle mainBundle] bundleIdentifier]];
}

@end
