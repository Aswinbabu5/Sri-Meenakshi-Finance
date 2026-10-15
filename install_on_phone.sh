#!/bin/bash
export PATH="/opt/homebrew/bin:$HOME/Library/Android/sdk/platform-tools:$PATH"

APK_PATH="/Users/ashwin/Desktop/loan_management_system/Sri_Meenakshi_Finance_Release.apk"
if [ ! -f "$APK_PATH" ]; then
  APK_PATH="/Users/ashwin/Desktop/loan_management_system/mobile_loan_app/build/app/outputs/flutter-apk/app-release.apk"
fi

echo "=========================================================="
echo "Sri Meenakshi Finance - Android Auto-Installer"
echo "Target APK: $APK_PATH"
echo "=========================================================="
echo "Checking for connected Android phone..."

for i in {1..30}; do
  DEVICE=$(adb devices | grep -w "device" | awk '{print $1}' | head -n 1)
  if [ -n "$DEVICE" ]; then
    echo "Found authorized Android device: $DEVICE"
    echo "Installing application onto $DEVICE..."
    adb -s "$DEVICE" install -r "$APK_PATH"
    echo "Launching Sri Meenakshi Finance on device..."
    adb -s "$DEVICE" shell monkey -p com.example.mobile_loan_app -c android.intent.category.LAUNCHER 1
    echo "SUCCESS: App installed and launched on your phone!"
    exit 0
  fi

  UNAUTH=$(adb devices | grep -w "unauthorized" | awk '{print $1}' | head -n 1)
  if [ -n "$UNAUTH" ]; then
    echo "Device detected ($UNAUTH) but UNPAIRED/UNAUTHORIZED."
    echo "Please look at your phone screen and tap 'Allow USB debugging' (or 'Always allow')."
  fi

  sleep 3
done

echo "Device not yet authorized after 90 seconds. Please ensure USB debugging is enabled."
exit 1
