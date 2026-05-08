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

// 1. Menambal akses file App Group yang hilang
@implementation NSFileManager (AppGroupFix)
- (NSURL *)lc_containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    NSURL *originalURL = [self lc_containerURLForSecurityApplicationGroupIdentifier:groupIdentifier];
    
    // Jika sistem menolak akses dan memberikan nil, kita manipulasi dengan URL valid
    if (originalURL == nil) {
        NSString *dummyPath = [NSString stringWithFormat:@"/private/var/mobile/Containers/Data/Application/dummy/Groups/%@", groupIdentifier];
        return [NSURL fileURLWithPath:dummyPath];
    }
    return originalURL;
}
@end

// 2. Menambal akses preferensi penyimpanan App Group
@implementation NSUserDefaults (AppGroupFix)
- (instancetype)lc_initWithSuiteName:(NSString *)suitename {
    instancetype defaults = [self lc_initWithSuiteName:suitename];
    
    // Jika gagal membuat suite penyimpanan khusus, paksa kembali ke penyimpanan standar
    if (defaults == nil) {
        return [self lc_initWithSuiteName:nil];
    }
    return defaults;
}
@end

__attribute__((constructor))
static void init_appgroup_bypass() {
    swizzleMethod([NSFileManager class], @selector(containerURLForSecurityApplicationGroupIdentifier:), @selector(lc_containerURLForSecurityApplicationGroupIdentifier:));
    swizzleMethod([NSUserDefaults class], @selector(initWithSuiteName:), @selector(lc_initWithSuiteName:));
}
