#!/bin/bash
set -e

# Change directory to the Xcode workspace folder
cd "$(dirname "$0")/iGlance"

echo "=== Stopping any running instances of OpenGlance ==="
killall OpenGlance 2>/dev/null || true

echo "=== Building OpenGlance (Debug Configuration) ==="
xcodebuild -workspace OpenGlance.xcworkspace -scheme OpenGlance -configuration Debug -sdk macosx build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

echo "=== Locating built application ==="
BUILT_DIR=$(xcodebuild -workspace OpenGlance.xcworkspace -scheme OpenGlance -configuration Debug -showBuildSettings | grep -m 1 "BUILT_PRODUCTS_DIR = " | cut -d= -f2 | xargs)
APP_PATH="$BUILT_DIR/OpenGlance.app"

if [ -d "$APP_PATH" ]; then
    echo "=== Launching OpenGlance from: $APP_PATH ==="
    open "$APP_PATH"
    echo "=== OpenGlance started successfully! ==="
else
    echo "Error: Could not find compiled app at $APP_PATH"
    exit 1
fi
