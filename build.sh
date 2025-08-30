#!/bin/bash
set -e

APP_NAME="DilutionCryofreeSimulator"
BUILD_DIR="$(pwd)/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "=== Building ${APP_NAME} for macOS ==="

# Clean build directory
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Source files
SOURCES=(
    "src/main.m"
    "src/AppDelegate.m"
    "src/DRTheme.m"
    "src/DRPhysicsEngine.m"
    "src/DRCryostatScene.m"
    "src/DRControlPanelView.m"
    "src/DRGuideView.m"
    "src/DRInspectorView.m"
    "src/DRGraphView.m"
    "src/DRAudioSynthesizer.m"
)

# Compile binary
echo "Compiling Objective-C sources with clang..."
clang \
    -fobjc-arc \
    -O2 \
    -Wall \
    -mmacosx-version-min=12.0 \
    -framework Cocoa \
    -framework SceneKit \
    -framework QuartzCore \
    -framework AVFoundation \
    -framework AudioToolbox \
    "${SOURCES[@]}" \
    -o "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist and icon
echo "Packaging application bundle..."
cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Generate / copy AppIcon.icns
echo "Generating AppIcon PNGs into xcassets..."
clang -fobjc-arc -framework Cocoa -framework CoreGraphics \
    -o /tmp/gen_icon scripts/gen_icon.m
/tmp/gen_icon "Resources/AppIcon.xcassets/AppIcon.appiconset"

echo "Compiling AppIcon.xcassets with actool..."
xcrun actool \
    --output-format human-readable-text \
    --notices --warnings \
    --platform macosx \
    --minimum-deployment-target 12.0 \
    --target-device mac \
    --app-icon AppIcon \
    --output-partial-info-plist /tmp/actool-partial.plist \
    --compile "${RESOURCES_DIR}" \
    "Resources/AppIcon.xcassets"

# Ad-hoc codesign
echo "Ad-hoc code signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "=== Build Successful! ==="
echo "Application created at: ${APP_BUNDLE}"











































