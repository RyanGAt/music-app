# SoundScroll for iOS

SoundScroll is a native SwiftUI listening experience: swipe through a full-screen feed of
curated music moments and the soundtrack follows the card currently on screen.

This repository intentionally contains no web client, accounts, backend, or social features.
Its small bundled catalogue and audio files make the entire experience available offline.

## Requirements

- Xcode 16 or later
- iOS 17 or later

## Run

1. Open `SoundScroll.xcodeproj` in Xcode.
2. Select the **SoundScroll** scheme and an iPhone simulator or device.
3. Build and run. Audio starts after tapping **Start listening**, in line with iOS media rules.

## Interaction

- Swipe vertically to move one track at a time.
- Tap the central play/pause button to control the visible track.
- Drag the progress bar to seek within the featured moment.
- Use the speaker control to mute or restore audio.

## Architecture

- `SoundScroll/App` owns application entry and audio-session lifecycle.
- `SoundScroll/Features/Feed` contains the paging interface and track presentation.
- `SoundScroll/Audio` wraps `AVAudioPlayer`, seeking, and crossfades.
- `SoundScroll/Models` and `SoundScroll/Resources` provide an offline catalogue.

There are no external package dependencies or network services.
