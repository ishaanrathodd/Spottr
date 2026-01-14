#!/bin/bash

APP_NAME="Spottr"
SOURCE_APP_PATH="/Users/ishaanrathod/Library/Developer/Xcode/DerivedData/FolderWatcher-fszkihsbmhkaeoblxxbflalvuode/Build/Products/Release/FolderWatcher.app"
DMG_NAME="Spottr.dmg"
STAGING_DIR="./dmg_staging"

# Check if Release build exists
if [ ! -d "$SOURCE_APP_PATH" ]; then
    echo "Error: Release build not found at $SOURCE_APP_PATH"
    echo "Please run the Production Build step first."
    exit 1
fi

echo "Preparing staging area..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy App
cp -R "$SOURCE_APP_PATH" "$STAGING_DIR/$APP_NAME.app"

# Create Applications shortcut
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating DMG..."
# Remove old DMG if exists
rm -f "$DMG_NAME"

# Create the DMG using hdiutil
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"

# Cleanup
rm -rf "$STAGING_DIR"

echo "-----------------------------------"
echo "DMG Created: $DMG_NAME"
echo "You can now distribute this file."
echo "-----------------------------------"
