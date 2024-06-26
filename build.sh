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

# Copy Info.plist
echo "Packaging application bundle..."
cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Ad-hoc codesign
echo "Ad-hoc code signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "=== Build Successful! ==="
echo "Application created at: ${APP_BUNDLE}"











































