#!/bin/bash
set -e

echo "=== Packaging Pixy.app ==="

# 1. Build release executable
echo "Building Swift Release executable..."
swift build -c release

# 2. Generate icon set and convert to .icns
echo "Generating pixel art icon..."
swift generate_icon.swift
iconutil -c icns AppIcon.iconset -o AppIcon.icns

# 3. Create .app bundle directory structure
APP_DIR="Pixy.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 4. Copy files into bundle
cp .build/release/Pixy "$APP_DIR/Contents/MacOS/Pixy"
cp Info.plist "$APP_DIR/Contents/"
cp AppIcon.icns "$APP_DIR/Contents/Resources/"

echo "Successfully created $APP_DIR!"

# 5. Install to /Applications so user can access from Launchpad / Finder / Dock
DEST="/Applications/Pixy.app"
rm -rf "$DEST"
cp -R "$APP_DIR" "$DEST"
echo "Successfully installed Pixy to $DEST!"
