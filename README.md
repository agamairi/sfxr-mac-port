# sfxr macOS Port

A native macOS port of the classic sfxr sound effect generator by DrPetter.

## Overview

This is a complete macOS application port of sfxr, featuring:
- Native Cocoa/AppKit UI
- Core Audio playback
- All original sound generation features
- Preset generators (Pickup/Coin, Laser, Explosion, etc.)
- WAV export functionality
- Load/Save sound parameters (.sfs files)
- Universal binary support (Intel + Apple Silicon)

## Building the Project

### Prerequisites
- macOS 10.13 or later
- Xcode 14.0 or later
- Command Line Tools for Xcode

### Build Steps

#### Option 1: Using Xcode (Recommended)

1. Open the Terminal and navigate to the sfxr-macos directory
2. Generate the Xcode project:
   ```bash
   ./generate_xcode_project.sh
   ```
3. Open the generated project:
   ```bash
   open sfxr.xcodeproj
   ```
4. In Xcode, select your development team in the project settings (Signing & Capabilities)
5. Build and run (⌘R)

#### Option 2: Command Line Build

```bash
cd sfxr-macos
./build.sh
```

This will create the app bundle in `build/Release/sfxr.app`

### Running the App

After building, you can:
- Run directly from Xcode
- Open the app bundle from Finder
- Copy to /Applications for permanent installation

## Project Structure

```
sfxr-macos/
├── main.m                  # Application entry point
├── Info.plist             # App bundle configuration
├── AppDelegate.h/m        # Application delegate
├── SoundGenerator.h/mm    # C++ audio synthesis engine
├── MainViewController.h/mm # UI controller
├── MainMenu.xib           # Interface Builder UI definition
└── Assets.xcassets/       # App icons and resources
```

## Features

### Sound Generation Presets
- **Pickup/Coin**: Classic item collection sound
- **Laser/Shoot**: Sci-fi weapon sounds
- **Explosion**: Various explosion effects
- **Powerup**: Positive enhancement sounds
- **Hit/Hurt**: Damage and impact sounds
- **Jump**: Character jump sounds
- **Blip/Select**: UI interaction sounds

### Parameters
- Wave type (Square, Sawtooth, Sine, Noise)
- Envelope (Attack, Sustain, Decay, Punch)
- Frequency controls (Start, Min, Slide, Delta Slide)
- Vibrato (Depth, Speed, Delay)
- Arpeggiation (Change Amount/Speed)
- Filters (Low-pass and High-pass with resonance)
- Phaser effect
- Repeat speed

### File Operations
- Load/Save: .sfs format (original sfxr format)
- Export: .wav files (8/16 bit, 22050/44100 Hz)

## Usage

1. Click one of the generator buttons on the left to create a preset sound
2. Adjust sliders to fine-tune the sound
3. Press Space or the Play button to hear your sound
4. Right-click any slider to reset it to zero
5. Use Randomize for completely random sounds
6. Use Mutate to create variations of the current sound
7. Save your sounds to .sfs files for later use
8. Export to .wav when you're ready to use in your project

## Keyboard Shortcuts

- **Space/Enter**: Play current sound
- **⌘O**: Load sound
- **⌘S**: Save sound
- **⌘E**: Export WAV

## License

This port maintains the original MIT license from the sfxr project.

Original sfxr: Copyright © 2007 Tomas Pettersson
macOS Port: 2026

## Credits

- Original sfxr by DrPetter (Tomas Pettersson)
- macOS port development

## Troubleshooting

### Build Errors
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`
- Check that your Xcode is up to date
- Verify the project file paths are correct

### Audio Issues
- Check system sound settings
- Ensure no other audio software is conflicting
- Try adjusting the master volume slider

### Code Signing
- You need to select a development team in Xcode's signing settings
- For distribution, you'll need a Developer ID certificate

## Future Enhancements

Potential improvements for future versions:
- Visual waveform display
- More preset categories
- Undo/redo functionality
- Export to additional audio formats
- Drag & drop .sfs files support
