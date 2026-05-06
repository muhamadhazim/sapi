#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// Fungsi dasar penukar memori
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

// Fokus utama: Mencegah force close saat ShopeePay menerima variabel nil
@implementation NSMutableSet (CrashFix)
- (void)safe_addObject:(id)object {
    if (object == nil) {
        // Abaikan instruksi jika objek kosong, biarkan aplikasi tetap berjalan
        return; 
    }
    // Lanjutkan eksekusi normal jika objek valid
    [self safe_addObject:object];
}
@end

// Konstruktor berjalan saat aplikasi dimuat
__attribute__((constructor))
static void bypass_init() {
    // KITA HANYA MENGINJEKSI SATU FUNGSI INI
    // Tidak ada intervensi file system atau dyld yang bisa membentrok LiveContainer
    swizzleMethod(NSClassFromString(@"__NSSetM"), @selector(addObject:), @selector(safe_addObject:));
}
