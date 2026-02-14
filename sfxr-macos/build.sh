#!/bin/bash

# Quick start script for building and running sfxr
# This creates a minimal working build for testing

set -e

echo "🔨 Quick Build for sfxr macOS"
echo "=============================="
echo ""

cd "$(dirname "$0")"

# Check if Xcode is available
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode Command Line Tools not found"
    echo "Please install with: xcode-select --install"
    exit 1
fi

# Create app bundle structure
echo "📦 Creating app bundle structure..."
mkdir -p "build/SFXR - macos.app/Contents/MacOS"
mkdir -p "build/SFXR - macos.app/Contents/Resources"

# Copy Info.plist
echo "📝 Copying Info.plist..."
cp Info.plist "build/SFXR - macos.app/Contents/"

# Copy resources (if any exist)
echo "🎨 Copying resources..."
if [ -f MainMenu.xib ]; then
    cp MainMenu.xib "build/SFXR - macos.app/Contents/Resources/" 2>/dev/null || true
fi
if [ -f sfxr.icns ]; then
    cp sfxr.icns "build/SFXR - macos.app/Contents/Resources/"
fi

echo "⚙️  Compiling source files..."

# Compile Objective-C files
clang -c main.m \
      -o build/main.o \
      -framework Cocoa \
      -fobjc-arc \
      -O2

clang -c AppDelegate.m \
      -o build/AppDelegate.o \
      -framework Cocoa \
      -fobjc-arc \
      -O2

clang -c WaveformView.m \
      -o build/WaveformView.o \
      -framework Cocoa \
      -fobjc-arc \
      -O2

# Compile Objective-C++ files  
clang++ -c SoundGenerator.mm \
      -o build/SoundGenerator.o \
      -framework Cocoa \
      -framework AVFoundation \
      -fobjc-arc \
      -O2 \
      -std=c++11 \
      -Wno-deprecated-declarations

clang++ -c MainViewController.mm \
      -o build/MainViewController.o \
      -framework Cocoa \
      -framework AVFoundation \
      -fobjc-arc \
      -O2 \
      -std=c++11 \
      -Wno-deprecated-declarations

# Link all object files
clang++ build/main.o \
      build/AppDelegate.o \
      build/SoundGenerator.o \
      build/WaveformView.o \
      build/MainViewController.o \
      -o "build/SFXR - macos.app/Contents/MacOS/sfxr" \
      -framework Cocoa \
      -framework AVFoundation \
      -framework AudioToolbox \
      -framework CoreAudio \
      -framework QuartzCore \
      -fobjc-arc

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📱 App bundle: build/SFXR - macos.app"
    echo ""
    echo "To run:"
    echo "  open \"build/SFXR - macos.app\""
    echo ""
    echo "To install:"
    echo "  cp -r \"build/SFXR - macos.app\" /Applications/"
    echo ""
else
    echo ""
    echo "❌ Build failed!"
    echo "Check the error messages above"
    exit 1
fi
