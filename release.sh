#!/bin/bash
set -e

# Change directory to the Xcode workspace folder
ROOT_DIR="$(dirname "$0")"
cd "$ROOT_DIR/iGlance"

echo "=== Building OpenGlance (Release Configuration) ==="
xcodebuild -workspace OpenGlance.xcworkspace -scheme OpenGlance -configuration Release -sdk macosx build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

echo "=== Locating built release application ==="
BUILT_DIR=$(xcodebuild -workspace OpenGlance.xcworkspace -scheme OpenGlance -configuration Release -showBuildSettings | grep -m 1 "BUILT_PRODUCTS_DIR = " | cut -d= -f2 | xargs)
APP_PATH="$BUILT_DIR/OpenGlance.app"

if [ -d "$APP_PATH" ]; then
    echo "=== Copying OpenGlance.app to project root ==="
    rm -rf "$ROOT_DIR/OpenGlance.app" "$ROOT_DIR/OpenGlance-Release.zip"
    cp -R "$APP_PATH" "$ROOT_DIR/"
    
    echo "=== Packaging Release Archive (OpenGlance-Release.zip) ==="
    cd "$ROOT_DIR"
    zip -r -y OpenGlance-Release.zip OpenGlance.app
    
    echo "=== Release package created successfully! ==="
    echo "Files available in root directory:"
    echo "  - OpenGlance.app (Folder)"
    echo "  - OpenGlance-Release.zip (Archive)"
else
    echo "Error: Could not find compiled app at $APP_PATH"
    exit 1
fi
