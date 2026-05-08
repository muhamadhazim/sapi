#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import "fishhook.h"

// Fungsi dasar penukar metode
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

// 1. Memalsukan Identitas Perangkat Keras
@implementation UIDevice (SafeIDFV)
- (NSUUID *)lc_identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:@"31323D26-2BB4-459F-9C25-A5314364E47C"];
}
@end

// 2. Memalsukan Isi Papan Klip
@implementation UIPasteboard (SafePasteboard)
- (NSString *)lc_string {
    NSString *val = [self lc_string];
    if (val == nil) {
        return @"";
    }
    return val;
}
@end

// 3. Mencegat Permintaan Keychain C-API
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result);
OSStatus my_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = orig_SecItemCopyMatching(query, result);
    
    if (status != errSecSuccess && result != NULL) {
        NSDictionary *queryDict = (__bridge NSDictionary *)query;
        
        // PERBAIKAN: Menghapus tanda @ sebelum konversi pointer
        if ([queryDict[(__bridge id)kSecReturnData] boolValue]) {
            *result = CFBridgingRetain([@"SNNDummyToken" dataUsingEncoding:NSUTF8StringEncoding]);
        } else if ([queryDict[(__bridge id)kSecReturnAttributes] boolValue]) {
            *result = CFBridgingRetain(@{ (__bridge id)kSecValueData : [@"SNNDummyToken" dataUsingEncoding:NSUTF8StringEncoding] });
        } else {
            *result = CFBridgingRetain(@"SNNDummyReference");
        }
        
        return errSecSuccess; 
    }
    
    return status;
}

// 4. Konstruktor Inisialisasi
__attribute__((constructor))
static void init_shopee_environment_faker() {
    swizzleMethod([UIDevice class], @selector(identifierForVendor), @selector(lc_identifierForVendor));
    swizzleMethod([UIPasteboard class], @selector(string), @selector(lc_string));
    
    struct rebinding rebindings[] = {
        {"SecItemCopyMatching", my_SecItemCopyMatching, (void *)&orig_SecItemCopyMatching}
    };
    rebind_symbols(rebindings, 1);
}
