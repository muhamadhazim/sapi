#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// 1. Deklarasi penunjuk fungsi untuk menyimpan alamat memori asli
static void (*orig_addObject)(id, SEL, id);

// 2. Fungsi C murni sebagai pengganti logika Apple
static void my_addObject(id self, SEL _cmd, id object) {
    if (object == nil) {
        // Hentikan eksekusi jika objek kosong, selamatkan aplikasi dari crash
        return; 
    }
    // Teruskan eksekusi ke alamat fungsi asli jika objek valid
    orig_addObject(self, _cmd, object);
}

// 3. Konstruktor inisialisasi memori
__attribute__((constructor))
static void bypass_init() {
    // Cari alamat metode addObject: pada kelas internal __NSSetM
    Method m = class_getInstanceMethod(NSClassFromString(@"__NSSetM"), @selector(addObject:));
    
    if (m != NULL) {
        // Ekstrak dan simpan alamat aslinya ke dalam variabel
        orig_addObject = (void *)method_getImplementation(m);
        // Timpa metode di RAM dengan alamat fungsi buatan kita
        method_setImplementation(m, (IMP)my_addObject);
    }
}
