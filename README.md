# iOS Zypper Voice

This repository contains an iOS custom keyboard inspired by the Ubuntu Go app in `zypper-voice/`.

Goal: switch to the custom keyboard, tap the microphone, speak, and have transcript text inserted at the current cursor in apps like Messages, Notes, etc.

## Project Layout

- `zypper-voice/`: existing Ubuntu/Linux Go implementation.
- `project.yml`: XcodeGen project definition for iOS.
- `ios/App/`: host iOS app (permission setup + onboarding).
- `ios/Keyboard/`: custom keyboard extension with OpenAI transcription.

## iOS Architecture

- Host app (`ZypperVoice`)
  - Requests `Microphone` permission.
  - Shows setup steps for OpenAI and keyboard enablement.
- Keyboard extension (`ZypperVoiceKeyboard`)
  - UI keys: `globe`, `mic`, `delete`, `space`, `return`.
  - Tap mic to start recording, tap again to stop.
  - Sends audio to OpenAI `/audio/transcriptions`.
  - Uses the same editor-prompt and punctuation postprocessing workflow used by `zypper-voice`.
  - Supports English, Spanish, or bilingual mode (default bilingual).

## Requirements

- macOS with Xcode 15+ (or newer).
- Apple ID signed into Xcode for signing.
- iPhone with Developer Mode enabled (iOS 16+).
- `xcodegen` for generating the `.xcodeproj` from `project.yml`.
- OpenAI API key.

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

1. Select the `IOSZypperVoice` project.
2. For both targets (`ZypperVoice` and `ZypperVoiceKeyboard`), set:
   - `Signing & Capabilities` -> Team: your Apple team.
   - Unique bundle identifiers (example):
     - `com.yourname.zyppervoice`
     - `com.yourname.zyppervoice.keyboard`
3. Configure OpenAI for the keyboard target:
   - Select target `ZypperVoiceKeyboard` -> `Info`.
   - Set `ZypperOpenAIAPIKey` to your OpenAI API key.
   - Optional:
     - `ZypperOpenAILanguage`: `en`, `es`, or empty string for bilingual fallback.
     - `ZypperOpenAIModel`: defaults to `gpt-4o-mini-transcribe`.
     - `ZypperOpenAIPrompt`: leave empty to use the built-in editor prompt workflow.
4. Build once (`Product -> Build`).

Optional CLI build:

```bash
xcodebuild -project IOSZypperVoice.xcodeproj -scheme ZypperVoice -configuration Debug -destination 'generic/platform=iOS' build
```

## Deploy To Your iPhone

1. Connect iPhone to Mac (USB first run).
2. On iPhone:
   - Trust the computer.
   - Enable Developer Mode (`Settings -> Privacy & Security -> Developer Mode`).
3. In Xcode:
   - `Window -> Devices and Simulators`.
   - Select your iPhone.
   - Enable `Connect via network` (optional after first run).
4. In Xcode target selector, choose your iPhone.
5. Run `ZypperVoice` (`Product -> Run`).

## Enable The Keyboard

On iPhone:

1. Open installed `ZypperVoice` and tap `Grant Permissions`.
2. Go to `Settings -> General -> Keyboard -> Keyboards -> Add New Keyboard...`.
3. Add `Zypper Voice`.
4. Tap `Zypper Voice` in keyboard list and enable `Allow Full Access`.

## Use It

1. Open any text input app (Messages, Notes, Mail, etc.).
2. Press the globe key until `Zypper Voice` keyboard appears.
3. Tap mic to start recording.
4. Speak in English or Spanish.
5. Tap mic again to stop.
6. The keyboard transcribes via OpenAI and inserts text at cursor.

## Troubleshooting

- `Set ZypperOpenAIAPIKey in Keyboard Info.plist`:
  - Configure `ZypperOpenAIAPIKey` under target `ZypperVoiceKeyboard` -> `Info`.
- Transcription fails immediately:
  - Confirm `Allow Full Access` is enabled for the keyboard.
  - Confirm internet access on the iPhone.
  - Verify API key and model value.
- Keyboard not shown:
  - Re-check iOS keyboard settings and ensure `Zypper Voice` is added.
- App install says developer not trusted:
  - iPhone `Settings -> General -> VPN & Device Management -> Developer App -> Trust`.

## Notes

- This iOS implementation is native Swift (`AVFoundation` + OpenAI HTTP API) and does not run the Go binary on-device.
- The Linux Go app remains unchanged in `zypper-voice/`.
