# iOS Zypper Voice

This repository now contains an iOS voice keyboard inspired by the Ubuntu Go app in `zypper-voice/`.

Goal: switch to the custom keyboard, tap the microphone, speak, and have transcript text inserted at the current cursor in apps like Messages, Notes, etc.

## Project Layout

- `zypper-voice/`: existing Ubuntu/Linux Go implementation.
- `project.yml`: XcodeGen project definition for iOS.
- `ios/App/`: host iOS app (permission setup + onboarding).
- `ios/Keyboard/`: custom keyboard extension with speech transcription.

## iOS Architecture

- Host app (`ZypperVoice`)
  - Requests `Speech Recognition` and `Microphone` permissions.
  - Shows setup steps to enable the custom keyboard in iOS Settings.
- Keyboard extension (`ZypperVoiceKeyboard`)
  - UI keys: `globe`, `mic`, `delete`, `space`, `return`.
  - Tap mic to start recording, tap again to stop.
  - Uses `AVAudioEngine + SFSpeechRecognizer` for live transcription.
  - Inserts incremental transcript updates into `textDocumentProxy` at cursor.

## Requirements

- macOS with Xcode 15+ (or newer).
- Apple ID signed into Xcode for personal signing.
- iPhone with Developer Mode enabled (iOS 16+).
- `xcodegen` for generating the `.xcodeproj` from `project.yml`.

Install XcodeGen:

```bash
brew install xcodegen
```

## Build The iOS Project

From repo root:

```bash
xcodegen generate
open IOSZypperVoice.xcodeproj
```

In Xcode:

1. Select the `ZypperVoice` project.
2. For both targets (`ZypperVoice` and `ZypperVoiceKeyboard`), set:
   - `Signing & Capabilities` -> Team: your personal Apple team.
   - Unique bundle identifiers (example):
     - `com.yourname.zyppervoice`
     - `com.yourname.zyppervoice.keyboard`
3. Build once (`Product -> Build`).

Optional CLI build:

```bash
xcodebuild -project IOSZypperVoice.xcodeproj -scheme ZypperVoice -configuration Debug -destination 'generic/platform=iOS' build
```

## Deploy To Your Own iPhone

1. Connect iPhone to Mac (USB, first time only).
2. On iPhone:
   - Trust the computer.
   - Enable Developer Mode:
     - `Settings -> Privacy & Security -> Developer Mode`.
3. In Xcode:
   - `Window -> Devices and Simulators`.
   - Select your iPhone.
   - Enable `Connect via network` (wireless deployment).
4. In Xcode target selector, choose your iPhone.
5. Run `ZypperVoice` (`Product -> Run`).

After first successful USB run, you can usually deploy wirelessly when phone and Mac are on the same network.

## Enable The Keyboard

On iPhone:

1. Open the installed `ZypperVoice` app and tap `Grant Permissions`.
2. Go to `Settings -> General -> Keyboard -> Keyboards -> Add New Keyboard...`.
3. Add `Zypper Voice`.
4. Tap `Zypper Voice` in keyboard list and enable `Allow Full Access`.

## Use It

1. Open any text input app (Messages, Notes, Mail, etc.).
2. Press the globe key until `Zypper Voice` keyboard appears.
3. Tap mic to start recording.
4. Speak.
5. Tap mic again to stop and finalize transcript.
6. Text appears where your cursor is active.

## Troubleshooting

- Mic button shows permission error:
  - Re-open host app and grant Speech + Microphone permissions.
  - Check `Settings -> Privacy & Security -> Microphone` and `Speech Recognition`.
- Keyboard not shown:
  - Re-check iOS keyboard settings and ensure `Zypper Voice` is added.
- Voice input unstable in keyboard extension:
  - Confirm `Allow Full Access` is enabled.
  - Try again in a standard text field (Messages/Notes).

## Notes

- This iOS implementation is native Swift (`Speech` + `AVFoundation`) and does not run the Go binary on-device.
- The Linux Go app remains unchanged in `zypper-voice/`.
