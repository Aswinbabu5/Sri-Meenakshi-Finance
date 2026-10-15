#!/bin/bash
export PATH="/opt/homebrew/bin:$PATH"

PROJECT_DIR="/Users/ashwin/Desktop/loan_management_system/mobile_loan_app"
IPA_PATH="/Users/ashwin/Desktop/loan_management_system/Sri_Meenakshi_Finance.ipa"

echo "=========================================================="
echo "Sri Meenakshi Finance - iPhone Deployment Helper"
echo "Target IPA: $IPA_PATH"
echo "=========================================================="

echo "Checking for connected iOS devices..."
cd "$PROJECT_DIR" || exit 1

# List connected physical devices (excluding macos and chrome)
DEVICES=$(flutter devices | grep -E "ios|iPhone" | grep -v "simulator")

if [ -z "$DEVICES" ]; then
  echo ""
  echo "⚠️  No physical iPhone detected via USB."
  echo ""
  echo "To install on your iPhone:"
  echo "1. Connect your iPhone to this Mac via USB cable."
  echo "2. On your iPhone, tap 'Trust This Computer' and enter your passcode."
  echo "3. If installing the IPA directly, you can use Sideloadly (free):"
  echo "   - Open Sideloadly (https://sideloadly.io)"
  echo "   - Drag & drop: $IPA_PATH"
  echo "   - Click 'Start' to install."
  echo ""
  echo "Alternatively, open the iOS workspace in Xcode to configure code signing:"
  echo "   open $PROJECT_DIR/ios/Runner.xcworkspace"
  exit 1
fi

echo "Found connected iOS device(s):"
echo "$DEVICES"
echo ""
echo "Attempting to build & run on your connected device..."
flutter run -d ios --release
