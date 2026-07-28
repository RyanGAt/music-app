# SoundScroll for iOS

SoundScroll is a native SwiftUI listening experience: swipe through a full-screen feed of
curated music moments and the soundtrack follows the card currently on screen.

This repository intentionally contains no web client, accounts, backend, or social features.
It discovers playable previews through the Apple Music catalogue and keeps likes and listening
history privately on-device with SwiftData.

## Requirements

- Xcode 16 or later
- iOS 17 or later

## Run

1. Open `SoundScroll.xcodeproj` in Xcode.
2. Select the **SoundScroll** scheme and an iPhone simulator or device.
3. In Signing & Capabilities, choose a development team with MusicKit enabled for the app ID.
4. Build and run. Audio starts after tapping **Start listening**, in line with iOS media rules.

## Interaction

- Swipe vertically to move one track at a time.
- Tap the central play/pause button to control the visible track.
- Drag the progress bar to seek within the featured moment.
- Use the speaker control to mute or restore audio.
- Tap the heart to save a song locally, then find it in the **Likes** tab.
- Open a full track with its Apple Music or Spotify destination button.

## Architecture

- `SoundScroll/App` owns application entry and audio-session lifecycle.
- `SoundScroll/Features/Feed` contains the paging interface and track presentation.
- `SoundScroll/Catalog` searches MusicKit and maps Apple Music preview assets into the feed.
- `SoundScroll/Audio` uses `AVPlayer` for remote preview streaming and seeking.
- `SoundScroll/Persistence` stores likes and recent listening history with SwiftData.
- Bundled tracks are compiled only as a `DEBUG` fallback when the catalogue is unavailable.

There are no external package dependencies, accounts, or application backend.
