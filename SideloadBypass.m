#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import "fishhook.h"

// ==========================================
// 1. Swizzling Objective-C Runtime
// ==========================================
static void swizzleMethod(Class cls, SEL origSel, SEL newSel) {
    Method origMethod = class_getInstanceMethod(cls, origSel);
    Method newMethod = class_getInstanceMethod(cls, newSel);
    BOOL didAddMethod = class_addMethod(cls, origSel, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
    if (didAddMethod) {
        class_replaceMethod(cls, newSel, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

// Menambal Null Pointer Exception bawaan ShopeePay
@implementation NSMutableSet (CrashFix)
- (void)safe_addObject:(id)object {
    if (object == nil) {
        return; 
    }
    [self safe_addObject:object];
}
@end

// Memalsukan Data Sandboxing Apple
@implementation NSBundle (ReceiptFix)
- (NSURL *)safe_appStoreReceiptURL {
    NSURL *url = [self safe_appStoreReceiptURL];
    if (url == nil) {
        return [NSURL fileURLWithPath:@"/StoreKit/sandboxReceipt"];
    }
    return url;
}

- (NSString *)safe_bundleIdentifier {
    NSString *originalID = [self safe_bundleIdentifier];
    if ([originalID containsString:@"livecontainer"] || [originalID containsString:@"sidestore"]) {
        return @"com.shopee.id"; 
    }
    return originalID;
}
@end

@implementation NSFileManager (SideloadBypass)
- (BOOL)safe_fileExistsAtPath:(NSString *)path {
    if ([path containsString:@"embedded.mobileprovision"]) {
        return NO;
    }
    return [self safe_fileExistsAtPath:path];
}
@end

// ==========================================
// 2. Fishhook C-API (Hanya untuk DYLD Memory Scanner)
// ==========================================
static const char * (*orig_dyld_get_image_name)(uint32_t image_index);

const char * my_dyld_get_image_name(uint32_t image_index) {
    const char * name = orig_dyld_get_image_name(image_index);
    // Menyembunyikan nama dylib kita dari pemindai memori Shopee
    if (name != NULL && (strstr(name, "LiveContainer") || strstr(name, "SideloadBypass"))) {
        return "/usr/lib/libSystem.B.dylib";
    }
    return name;
}

// ==========================================
// 3. Konstruktor Inisialisasi
// ==========================================
__attribute__((constructor))
static void bypass_init() {
    swizzleMethod(NSClassFromString(@"__NSSetM"), @selector(addObject:), @selector(safe_addObject:));
    swizzleMethod([NSBundle class], @selector(appStoreReceiptURL), @selector(safe_appStoreReceiptURL));
    swizzleMethod([NSBundle class], @selector(bundleIdentifier), @selector(safe_bundleIdentifier));
    swizzleMethod([NSFileManager class], @selector(fileExistsAtPath:), @selector(safe_fileExistsAtPath:));
    
    struct rebinding rebindings[] = {
        {"_dyld_get_image_name", my_dyld_get_image_name, (void *)&orig_dyld_get_image_name}
    };
    rebind_symbols(rebindings, 1);
}
