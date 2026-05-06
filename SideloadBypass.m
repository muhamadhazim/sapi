#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <sys/stat.h>
#import <unistd.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import "fishhook.h"

// ==========================================
// 1. Objective-C Runtime Swizzling
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

// A. Mencegah Crash __NSSetM (Null Safety Patch)
// Menimpa fungsi bawaan Apple agar tidak crash saat menerima nilai nil dari ShopeePay
@implementation NSMutableSet (CrashFix)
- (void)safe_addObject:(id)object {
    if (object == nil) {
        return; // Hentikan eksekusi, cegah crash
    }
    [self safe_addObject:object];
}
@end

// B. Memalsukan URL Receipt App Store
@implementation NSBundle (ReceiptFix)
- (NSURL *)safe_appStoreReceiptURL {
    NSURL *url = [self safe_appStoreReceiptURL];
    if (url == nil) {
        // Berikan path dummy jika sistem mengembalikan nil
        return [NSURL fileURLWithPath:@"/StoreKit/sandboxReceipt"];
    }
    return url;
}

// C. Memalsukan Bundle ID
- (NSString *)safe_bundleIdentifier {
    NSString *originalID = [self safe_bundleIdentifier];
    if ([originalID containsString:@"livecontainer"] || [originalID containsString:@"sidestore"]) {
        return @"com.shopee.id"; 
    }
    return originalID;
}
@end

// D. Memblokir pencarian file Mobile Provisioning
@implementation NSFileManager (SideloadBypass)
- (BOOL)safe_fileExistsAtPath:(NSString *)path {
    if ([path containsString:@"embedded.mobileprovision"]) {
        return NO;
    }
    return [self safe_fileExistsAtPath:path];
}
@end

// ==========================================
// 2. Fishhook C-API (Bypass File System & DYLD)
// ==========================================
static int (*orig_stat)(const char *restrict path, struct stat *restrict buf);
static int (*orig_access)(const char *path, int amode);
static const char * (*orig_dyld_get_image_name)(uint32_t image_index);
static int (*orig_dladdr)(const void *addr, Dl_info *info);

int my_stat(const char *restrict path, struct stat *restrict buf) {
    if (path != NULL && strstr(path, "embedded.mobileprovision") != NULL) {
        return -1;
    }
    return orig_stat(path, buf);
}

int my_access(const char *path, int amode) {
    if (path != NULL && strstr(path, "embedded.mobileprovision") != NULL) {
        return -1; 
    }
    return orig_access(path, amode);
}

const char * my_dyld_get_image_name(uint32_t image_index) {
    const char * name = orig_dyld_get_image_name(image_index);
    if (name != NULL && (strstr(name, "LiveContainer") || strstr(name, "SideloadBypass"))) {
        return "/usr/lib/libSystem.B.dylib";
    }
    return name;
}

int my_dladdr(const void *addr, Dl_info *info) {
    int result = orig_dladdr(addr, info);
    if (result != 0 && info->dli_fname != NULL) {
        if (strstr(info->dli_fname, "LiveContainer") || strstr(info->dli_fname, "SideloadBypass")) {
            info->dli_fname = "/usr/lib/libSystem.B.dylib";
        }
    }
    return result;
}

// ==========================================
// 3. Konstruktor Inisialisasi
// ==========================================
__attribute__((constructor))
static void bypass_init() {
    // 1. Eksekusi patch NSSetM secara spesifik ke class cluster Apple
    swizzleMethod(NSClassFromString(@"__NSSetM"), @selector(addObject:), @selector(safe_addObject:));
    
    // 2. Eksekusi patch NSBundle & NSFileManager
    swizzleMethod([NSBundle class], @selector(appStoreReceiptURL), @selector(safe_appStoreReceiptURL));
    swizzleMethod([NSBundle class], @selector(bundleIdentifier), @selector(safe_bundleIdentifier));
    swizzleMethod([NSFileManager class], @selector(fileExistsAtPath:), @selector(safe_fileExistsAtPath:));
    
    // 3. Eksekusi Fishhook
    struct rebinding rebindings[] = {
        {"stat", my_stat, (void *)&orig_stat},
        {"access", my_access, (void *)&orig_access},
        {"_dyld_get_image_name", my_dyld_get_image_name, (void *)&orig_dyld_get_image_name},
        {"dladdr", my_dladdr, (void *)&orig_dladdr}
    };
    rebind_symbols(rebindings, 4);
}
