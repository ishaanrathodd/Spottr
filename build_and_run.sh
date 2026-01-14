#!/bin/bash

# Build the project
echo "Building FolderWatcher..."
xcodebuild -project FolderWatcher.xcodeproj -scheme FolderWatcher build

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "Build succeeded."
    
    # Path where Xcode builds the app (Source)
    # Note: adjusting this to match the specific DerivedData path seen in logs or use a generic find if needed. 
    # For now, aiming for the specific path since it was stable in previous logs.
    APP_SOURCE="/Users/ishaanrathod/Library/Developer/Xcode/DerivedData/FolderWatcher-fszkihsbmhkaeoblxxbflalvuode/Build/Products/Debug/Spottr.app"
    
    # Define stable install path (Destination)
    INSTALL_PATH="$HOME/Applications/Spottr.app"
    
    # Ensure ~/Applications exists
    mkdir -p "$HOME/Applications"
    
    # Remove old version if present
    rm -rf "$INSTALL_PATH"
    
    # Copy new build to stable path
    echo "Installing to $INSTALL_PATH..."
    cp -R "$APP_SOURCE" "$INSTALL_PATH"
    
    # Kill existing instance if running
    pkill -f "Spottr" || true
    pkill -f "FolderWatcher" || true
    
    # Launch the app from the stable path
    echo "Launching from stable path..."
    open "$INSTALL_PATH"
    
    echo "App launched! Checks Console logs for 'com.ishaanrathod.Spottr'."
else
    echo "Build failed."
    exit 1
fi
