#!/bin/bash

set -e

APP_NAME="ScreenLingo"
APP_BUNDLE="${APP_NAME}.app"
VERSION="1.0.0"

echo "🔨 Building ${APP_NAME}..."

# Clean previous build
rm -rf "$APP_BUNDLE"
rm -rf AppIcon.appiconset
rm -f AppIcon.icns

# Build release version
swift build -c release

echo "📦 Creating app bundle..."

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary (rename to app name)
cp .build/release/OverlayTranslator "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

# Copy Info.plist and update executable name
sed "s/OverlayTranslator/${APP_NAME}/g" Info.plist > "$APP_BUNDLE/Contents/Info.plist"

# Copy entitlements
if [ -f "OverlayTranslator.entitlements" ]; then
    cp OverlayTranslator.entitlements "$APP_BUNDLE/Contents/Resources/"
fi

# Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Generate app icon
echo "🎨 Generating app icon..."
if [ -f "generate-icon.swift" ]; then
    swift generate-icon.swift 2>/dev/null || true
    
    # Try to create icns (may fail on some systems)
    if command -v iconutil &> /dev/null && [ -d "AppIcon.appiconset" ]; then
        iconutil -c icns AppIcon.appiconset -o AppIcon.icns 2>/dev/null || true
    fi
    
    # Install icon
    if [ -f "AppIcon.icns" ]; then
        cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/"
        echo "   ✓ App icon (icns) installed"
    elif [ -d "AppIcon.appiconset" ]; then
        # Copy the iconset directly - Finder can use this
        cp -r AppIcon.appiconset "$APP_BUNDLE/Contents/Resources/AppIcon.iconset"
        # Also copy largest PNG as fallback
        cp AppIcon.appiconset/icon_512x512@2x.png "$APP_BUNDLE/Contents/Resources/AppIcon.png" 2>/dev/null || true
        echo "   ✓ App icon (iconset) installed"
    fi
    
    # Update Info.plist to reference icon
    if ! grep -q "CFBundleIconFile" "$APP_BUNDLE/Contents/Info.plist"; then
        sed -i '' 's|</dict>|<key>CFBundleIconFile</key><string>AppIcon</string></dict>|' "$APP_BUNDLE/Contents/Info.plist"
    fi
    
    # Cleanup source files (keep in bundle)
    rm -rf AppIcon.appiconset
    rm -f AppIcon.icns AppIcon.png
fi

echo ""
echo "✅ App bundle created: $APP_BUNDLE"
echo ""
echo "🚀 To run:"
echo "   open \"$APP_BUNDLE\""
echo ""
echo "📁 To install:"
echo "   mv \"$APP_BUNDLE\" /Applications/"
echo ""
echo "⚠️  First run - grant permissions:"
echo "   • Accessibility (keyboard shortcuts)"
echo "   • Screen Recording (window capture)"
echo ""

# Optionally open the app
read -p "Open app now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$APP_BUNDLE"
fi
