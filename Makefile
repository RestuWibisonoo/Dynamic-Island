# Makefile untuk Dynamic Island macOS

APP_NAME = DynamicIsland
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS
RESOURCES = $(CONTENTS)/Resources
BUNDLE_ID = com.restuwibisono.DynamicIsland

.PHONY: all build test run bundle clean

all: build

build:
	@echo "🔨 Mengompilasi $(APP_NAME)..."
	swift build -c release

test:
	@echo "🧪 Menjalankan Unit Tests..."
	swift run TestRunner

run:
	@echo "🚀 Menjalankan $(APP_NAME)..."
	swift run DynamicIsland

bundle: build
	@echo "📦 Membuat macOS App Bundle ($(APP_BUNDLE))..."
	@mkdir -p $(MACOS) $(RESOURCES)
	@cp $(BUILD_DIR)/$(APP_NAME) $(MACOS)/$(APP_NAME)
	@echo '<?xml version="1.0" encoding="UTF-8"?>\
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\
<plist version="1.0">\
<dict>\
    <key>CFBundleExecutable</key>\
    <string>$(APP_NAME)</string>\
    <key>CFBundleIdentifier</key>\
    <string>$(BUNDLE_ID)</string>\
    <key>CFBundleName</key>\
    <string>$(APP_NAME)</string>\
    <key>CFBundlePackageType</key>\
    <string>APPL</string>\
    <key>CFBundleShortVersionString</key>\
    <string>1.0.0</string>\
    <key>CFBundleVersion</key>\
    <string>1</string>\
    <key>LSUIElement</key>\
    <true/>\
    <key>NSHighResolutionCapable</key>\
    <true/>\
</dict>\
</plist>' > $(CONTENTS)/Info.plist
	@echo "✅ App bundle siap: $(APP_BUNDLE)"

clean:
	@echo "🧹 Membersihkan build..."
	swift package clean
	rm -rf $(APP_BUNDLE)
