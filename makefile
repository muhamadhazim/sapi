CC = clang
ARCH = arm64
SDK = $(shell xcrun --sdk iphoneos --show-sdk-path)
MIN_VERSION = 15.0

FRAMEWORKS = -framework Foundation -framework UIKit

OUT = SideloadBypass.dylib
SRC = SideloadBypass.m fishhook.c

all: $(OUT)

$(OUT): $(SRC)
	$(CC) -arch $(ARCH) \
		-shared \
		-fmodules \
		-fobjc-arc \
		-isysroot $(SDK) \
		-miphoneos-version-min=$(MIN_VERSION) \
		$(FRAMEWORKS) \
		-o $(OUT) $(SRC)

clean:
	rm -f $(OUT)
