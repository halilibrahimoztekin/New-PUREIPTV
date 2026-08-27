#!/bin/bash
set -e

SIMULATOR_NAME="iPhone 17"
BUNDLE_ID="com.oztech.PureIPTV"
PROJECT_DIR="/Users/ibrahimoztekin/Desktop/Projeler/New-PureIPTV/PureIPTV"

echo "📱 Booting Simulator ($SIMULATOR_NAME)..."
xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true

echo "🔨 Building app for Simulator..."
cd "$PROJECT_DIR"
xcodebuild build -project PureIPTV.xcodeproj -scheme PureIPTV -destination "name=$SIMULATOR_NAME" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/PureIPTV_build

APP_PATH=$(find "/tmp/PureIPTV_build/Build/Products/" -name "*.app" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: App not found after build!"
    exit 1
fi

echo "📲 Installing app to Simulator..."
xcrun simctl install "$SIMULATOR_NAME" "$APP_PATH"

echo "🚀 Launching app..."
xcrun simctl launch "$SIMULATOR_NAME" "$BUNDLE_ID"

echo "✅ Done!"
