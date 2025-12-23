#!/bin/bash
set -e

APP_NAME="AppleIntelligenceServer"
SCHEME="AppleIntelligenceServer"
CONFIG="Release"
DERIVED_DATA_PATH="build"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Keep build caches inside the repo to avoid sandbox write errors.
export SWIFT_MODULE_CACHE_PATH="$ROOT_DIR/.build/swift-module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
export SWIFTPM_PACKAGE_CACHE_PATH="$ROOT_DIR/.build/swiftpm-package-cache"
mkdir -p "$SWIFT_MODULE_CACHE_PATH" "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_PACKAGE_CACHE_PATH"

echo "Building $APP_NAME..."

# Build using xcodebuild (requires generated project or Swift PM integration)
# Since we have Package.swift, we can use swift build or generate xcodeproj
# But for a .app bundle with SwiftUI, we generally want xcodebuild.

# 1. Generate xcodeproj if needed (optional with modern xcodebuild but good for consistency)
# swift package generate-xcodeproj

# 2. Build
# Note: creating a proper .app from swift package executable requires some manual work or using xcodebuild with a defined target.
# Since we setup Package.swift as executable, the output is a binary. 
# We need to wrap it in a .app structure for "open -gj" to work nicely as a bundled app.

pushd apps/AppleIntelligenceServer
swift build -c release --arch arm64
popd

BIN_PATH="apps/AppleIntelligenceServer/.build/arm64-apple-macosx/release/AppleIntelligenceServer"
APP_BUNDLE="packages/@apple-intelligence-js-sdk/darwin-arm64/AppleIntelligenceServer.app"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AppleIntelligenceServer</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.AppleIntelligenceServer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AppleIntelligenceServer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "App bundle created at $APP_BUNDLE"
