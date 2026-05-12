#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-v8}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-Build/DerivedData}"
BINARY_PATH="${BINARY_PATH:-$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/BetterCastReceiverIOS}"
PLIST_PATH="${PLIST_PATH:-Sources/BetterCastReceiverIOS/Info.plist}"
ICON_PATH="${ICON_PATH:-Sources/BetterCastReceiverIOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png}"
OUTPUT_IPA="${OUTPUT_IPA:-YC-Cast-Receiver-iOS-${VERSION}.ipa}"
PACKAGE_DIR="${PACKAGE_DIR:-ios_packaging}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-YC Cast.app}"
EXECUTABLE_NAME="BetterCastReceiverIOS"

echo "=================================="
echo "  YC Cast iOS IPA Packager $VERSION"
echo "=================================="

if [ ! -f "$BINARY_PATH" ]; then
    echo "Binary not found at: $BINARY_PATH"
    echo "Build the receiver first, for example:"
    echo "xcodebuild -project BetterCastIOS.xcodeproj -scheme BetterCastReceiverIOS -configuration $CONFIGURATION -destination 'generic/platform=iOS' -derivedDataPath $DERIVED_DATA_PATH build"
    exit 1
fi

if [ ! -f "$PLIST_PATH" ]; then
    echo "Info.plist not found at: $PLIST_PATH"
    exit 1
fi

echo "Cleaning old packaging..."
rm -rf "$PACKAGE_DIR" "$OUTPUT_IPA"

APP_DIR="$PACKAGE_DIR/Payload/$APP_BUNDLE_NAME"
mkdir -p "$APP_DIR/Frameworks"

echo "Copying app files..."
cp "$BINARY_PATH" "$APP_DIR/$EXECUTABLE_NAME"
cp "$PLIST_PATH" "$APP_DIR/Info.plist"
chmod +x "$APP_DIR/$EXECUTABLE_NAME"

if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$APP_DIR/AppIcon.png"
else
    echo "Icon not found at $ICON_PATH; continuing without a loose icon file."
fi

SWIFT_LIB_PATH="${SWIFT_LIB_PATH:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.0/iphoneos}"
if [ -d "$SWIFT_LIB_PATH" ]; then
    echo "Bundling available Swift runtime libraries..."
    COPIED_COUNT=0
    for lib in libswiftCore.dylib libswiftFoundation.dylib libswiftNetwork.dylib libswiftDispatch.dylib libswiftObjectiveC.dylib libswiftDarwin.dylib libswiftCoreMedia.dylib libswiftCoreFoundation.dylib libswiftAVFoundation.dylib libswiftVideoToolbox.dylib libswiftUIKit.dylib libswiftCoreImage.dylib libswiftCoreGraphics.dylib libswiftCoreAudio.dylib libswiftMetal.dylib libswiftQuartzCore.dylib libswiftos.dylib libswiftsimd.dylib; do
        if [ -f "$SWIFT_LIB_PATH/$lib" ]; then
            cp "$SWIFT_LIB_PATH/$lib" "$APP_DIR/Frameworks/"
            COPIED_COUNT=$((COPIED_COUNT + 1))
        fi
    done
    echo "Copied $COPIED_COUNT Swift runtime libraries."
else
    echo "Swift runtime folder not found; skipping runtime library copy."
fi

echo "Creating IPA archive..."
(
    cd "$PACKAGE_DIR"
    zip -r -q "../$OUTPUT_IPA" Payload
)

rm -rf "$PACKAGE_DIR"

IPA_SIZE=$(du -h "$OUTPUT_IPA" | cut -f1)
echo ""
echo "Done: $OUTPUT_IPA ($IPA_SIZE)"
echo ""
echo "Install with Xcode, Apple Configurator, or another sideloading tool that you trust."
