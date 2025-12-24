#!/bin/bash

# Configuration
ENTITLEMENTS="Entitlements.plist"
BUILD_DIR=".build/release"
EXECUTABLE="AppleIntelligenceServer"
BINARY_PATH="$BUILD_DIR/$EXECUTABLE"

echo "🔨 Building release..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "🔐 Signing binary with entitlements..."
# Use ad-hoc signing (-) with the entitlements file
codesign --entitlements "$ENTITLEMENTS" --force --sign - "$BINARY_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Signing failed"
    exit 1
fi

echo "✅ Build and sign complete!"
echo "🚀 Running server..."

# Pass all arguments to the server
$BINARY_PATH $@
