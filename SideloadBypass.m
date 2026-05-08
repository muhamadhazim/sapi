#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void swizzleMethod(Class cls, SEL origSel, SEL newSel) {
    Method origMethod = class_getInstanceMethod(cls, origSel);
    Method newMethod = class_getInstanceMethod(cls, newSel);
    if (!origMethod || !newMethod) return;

    if (class_addMethod(cls, origSel, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(cls, newSel, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

@implementation NSBundle (ShopeeFix)

// 1. Paksa Bundle ID agar selalu terlihat asli di mata sistem keamanan aplikasi
- (NSString *)lc_bundleIdentifier {
    return @"com.shopeepay.id"; 
}

// 2. Berikan URL receipt palsu agar aplikasi tidak mendapatkan nilai 'nil' yang memicu crash NSSetM
- (NSURL *)lc_appStoreReceiptURL {
    return [NSURL fileURLWithPath:@"/private/var/mobile/Containers/Data/Application/dummy/StoreKit/receipt"];
}

@end

__attribute__((constructor))
static void init_bypass() {
    // Kita hanya melakukan swizzling pada NSBundle. 
    // Ini aman dan tidak akan menyebabkan layar hitam di LiveContainer.
    swizzleMethod([NSBundle class], @selector(bundleIdentifier), @selector(lc_bundleIdentifier));
    swizzleMethod([NSBundle class], @selector(appStoreReceiptURL), @selector(lc_appStoreReceiptURL));
}
