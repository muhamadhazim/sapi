#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// 1. Simpan penunjuk memori asli
static void (*orig_addObject)(id, SEL, id);

// 2. Fungsi intersepsi
static void my_addObject(id self, SEL _cmd, id object) {
    if (object == nil) {
        // Jangan hentikan eksekusi (yang memicu black screen).
        // Paksa masukkan objek string yang valid agar mesin keamanan tidak mendeteksi data yang hilang.
        orig_addObject(self, _cmd, @"SNN_Blind_Bypass_Data");
        return;
    }
    // Teruskan secara normal jika objek sudah valid
    orig_addObject(self, _cmd, object);
}

// 3. Inisialisasi Pemuat
__attribute__((constructor))
static void init_nsset_blind_bypass() {
    // Targetkan kelas internal Apple secara spesifik
    Class targetClass = NSClassFromString(@"__NSSetM");
    if (targetClass != nil) {
        Method m = class_getInstanceMethod(targetClass, @selector(addObject:));
        if (m != NULL) {
            // Ekstrak dan timpa Implementation Pointer (IMP) secara langsung tanpa Swizzling
            orig_addObject = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_addObject);
        }
    }
m
