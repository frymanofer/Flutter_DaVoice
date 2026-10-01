# Flutter DaVoice Example App

Standalone Flutter example app for the DaVoice voice stack.

DaVoice product pages:

- [DaVoice home](https://davoice.io/)
- [Wake word detection](https://davoice.io/wake-word)
- [Speaker recognition and speaker verification](https://davoice.io/speaker-recognition)
- [Documentation](https://davoice.io/docs)
- [Pricing](https://davoice.io/pricing)
- [Contact](https://davoice.io/contact-us)

This repo demonstrates how to combine:

- `flutter_davoice` for on-device TTS and speech recognition
- `flutter_wake_word` for wake word detection and speaker verification
- a simple Gemini-backed voice assistant flow for spoken replies

The runnable Flutter app lives in [`example/`](example/).

This repository shows how to build a full Flutter voice AI experience with DaVoice. Instead of stitching together unrelated mobile voice packages that often conflict around microphones, audio routing, speech sessions, interruptions, and iOS behavior, this example is built around a coordinated voice pipeline:

- [Speaker identification / speaker verification](https://davoice.io/speaker-recognition) with onboarding and real-time verification
- [Wake word / keyword spotting / hotword detection](https://davoice.io/wake-word) in an always-listening flow
- speech to text / real-time ASR
- on-device text to speech
- smooth audio transitions between listening, detection, recognition, and playback
- Flutter support for iOS and Android

For teams searching for Flutter wake word detection, Flutter speaker verification, Flutter speaker identification, Flutter speech to text, Flutter text to speech, or Flutter on-device voice AI, this repository is meant to show the full flow rather than one isolated feature.

By [DaVoice.io](https://davoice.io)

## Why This Repository Exists

Most mobile voice stacks start to break when you try to combine:

- wake word detection with live ASR
- speaker verification with speech recognition
- always-listening behavior with TTS playback
- iOS audio routing with Bluetooth, speaker, receiver, or car audio
- Flutter wrappers from different vendors that all want microphone ownership

This repository demonstrates a unified Flutter voice AI flow that avoids many of those integration problems, especially on iOS where microphone ownership, interruptions, ducking, output routing, and speech-session coordination often become the real challenge.

The example app shows how to:

- start from speaker onboarding, or reuse a saved speaker signature
- move into an always-listening wake word flow
- pause wake word detection at the right moment
- transition into speech recognition
- speak back using on-device TTS
- resume the voice pipeline cleanly

## What This Demo Does

The app walks through a real voice flow instead of showing isolated API calls.

It currently demonstrates:

- voice selection between `Ariana` and `Rich`
- quality selection between `Lite` and `Heavy`
- Davoice license loading from `licensekey.txt` or manual entry
- optional speaker verification onboarding
- reuse of a previously saved speaker signature
- live speaker verification before starting the full voice pipeline
- always-listening wake word detection with a bundled ONNX wake word model
- wake word pause/resume handling while STT or TTS is active
- manual TTS playground
- wake word -> intro speech -> speech echo flow
- full AI chat mode using STT input + Gemini response + TTS playback
- iOS audio routing configuration for wake word listening

Related DaVoice pages:

- Wake word and hotword detection: [davoice.io/wake-word](https://davoice.io/wake-word)
- Speaker recognition, speaker verification, and voice biometrics: [davoice.io/speaker-recognition](https://davoice.io/speaker-recognition)
- SDK docs and integration material: [davoice.io/docs](https://davoice.io/docs)
- Flutter wake word integration guide: [davoice.io/integration-guides-wake-word/flutter](https://davoice.io/integration-guides-wake-word/flutter)

Voice-isolated STT demo video:

- [Watch on YouTube](https://www.youtube.com/watch?v=uYpaCXAvjew&feature=youtu.be)

## Core Capabilities

### 1. [Flutter wake word detection](https://davoice.io/integration-guides-wake-word/flutter)

Use custom wake words and keyword spotting locally on the device. This is useful for hands-free experiences such as assistants, smart controls, in-car flows, accessibility use cases, healthcare workflows, industrial apps, and branded voice triggers.

Also known as:

- wake word detection
- keyword spotting
- hotword detection
- trigger word detection
- phrase spotting
- voice trigger

### 2. [Flutter speaker identification and speaker verification](https://davoice.io/speaker-recognition)

The example supports speaker onboarding and reuse of a saved speaker signature. You can choose to:

- skip speaker verification
- create a new speaker signature
- reuse a saved speaker signature
- redo onboarding and replace the old signature

That makes it possible to gate wake-word flows or speech-to-text flows by the onboarded speaker.

### 3. Flutter speech to text on device

After wake word detection, the app can transition into real-time speech recognition. The example demonstrates flow control between wake word and STT, including pausing detection to reduce conflicts and improve user experience.

This matters because in real products the hard part is not only speech recognition accuracy. The hard part is the orchestration between:

- microphone capture
- wake word state
- speaker verification state
- ASR start timing
- TTS playback
- re-entry into listening mode

### 4. Flutter text to speech on device

The example includes high-quality on-device TTS with multiple voice and model choices. It supports interactive voice flows where the app can speak, pause recognition, and then return to listening.

For teams searching for Flutter text to speech on device or offline TTS for Flutter, this repository shows how TTS fits into a complete mobile voice stack instead of existing as a disconnected feature.

## What Makes This Different

- Full voice pipeline: wake word, speaker verification, speech to text, Gemini-backed AI chat, and text to speech in one Flutter flow
- On-device voice stack: designed for privacy-sensitive and offline-first mobile experiences, with cloud LLM used only for the optional Gemini demo mode
- Cross-platform: iOS and Android
- Audio-session aware: built around the real behavior of mobile audio routing and interruptions
- Better flow control: the example intentionally pauses wake word detection before speech recognition and pauses STT before TTS playback
- Designed for real apps: not just a single isolated API demo

## App Flow

When you launch the demo:

1. Choose voice quality and speaker voice.
2. Enter a DaVoice license, or let the app load it from `example/licensekey.txt`.
3. Choose whether to create or reuse a speaker verification signature.
4. The app initializes wake word detection and the Davoice speech engine.
5. On the first wake word event, the app asks which area to test:
   - `Full AI Chat`
   - `Manual TTS Test`
6. In `Manual TTS Test`, you can type text and hear the selected voice.
7. In `Full AI Chat`, the app listens continuously, sends the final transcript to Gemini after a short silence, and speaks the reply back using the selected Davoice voice.

The implementation in [`example/lib/main.dart`](example/lib/main.dart) demonstrates a complete Flutter voice journey:

1. Request microphone permissions.
2. On iOS, request speech recognition permission.
3. Optionally onboard a speaker or reuse a saved speaker signature.
4. Start wake word detection.
5. Detect the wake phrase.
6. Pause detection so the app can transition cleanly.
7. Either move into manual TTS testing or a full AI chat flow.
8. In AI mode, run STT, send text to Gemini, and speak back the reply with on-device TTS.
9. Resume the listening experience.

It also includes:

- selectable TTS voices and quality modes
- saved speaker enrollment handling
- iOS audio-routing configuration hooks
- safe STT pause / TTS speak / STT resume sequencing
- friendly spoken fallback when Gemini returns an error

## Project Structure

- [`example/lib/main.dart`](example/lib/main.dart): full demo app and voice flow
- [`example/pubspec.yaml`](example/pubspec.yaml): Flutter dependencies and bundled assets
- [`example/assets/models/`](example/assets/models/): Davoice TTS, wake word, and speaker verification models
- [`example/licensekey.txt`](example/licensekey.txt): optional bundled DaVoice license
- [`example/local.config.ts`](example/local.config.ts): optional Gemini API key config
- [`example/README.md`](example/README.md): pointer to this main project README
- [`docs/flutter-speaker-identification.md`](docs/flutter-speaker-identification.md): focused speaker identification and verification page
- [`docs/flutter-wake-word-detection.md`](docs/flutter-wake-word-detection.md): focused wake word and keyword spotting page
- [`docs/flutter-speech-to-text.md`](docs/flutter-speech-to-text.md): focused speech to text page
- [`docs/flutter-text-to-speech.md`](docs/flutter-text-to-speech.md): focused text to speech page
- [`WakeWordGenerator.md`](WakeWordGenerator.md): Flutter-specific guide for custom wake word model integration

## Why This Matters For iOS

A lot of mobile voice packages appear to work in isolation but fail when combined on iOS. Common issues include:

- the microphone is already owned by another voice component
- text to speech interrupts recognition badly
- wake word and ASR compete for audio
- audio routing changes between speaker, earpiece, Bluetooth, and car audio
- apps behave differently after interruptions or route changes

This Flutter example is valuable because it tackles those integration edges in a single voice architecture, including iOS audio routing config for wake word behavior.

## Requirements

- Flutter SDK compatible with the app's Dart/Flutter setup
- Android `minSdk` 23+ on `arm64-v8a`
- iOS 13.0+
- microphone permission
- on iOS, speech recognition permission

On Android API 23–32, STT uses the system recognizer's microphone path. Custom
PCM/AEC and the inline STT SpeakerID gate are available on API 33 and newer.
The full Android stack currently supports ARM64; see the
[Android compatibility contract](example/ANDROID_COMPATIBILITY.md).

This app already includes the required platform permissions in:

- [`example/android/app/src/main/AndroidManifest.xml`](example/android/app/src/main/AndroidManifest.xml)
- [`example/ios/Runner/Info.plist`](example/ios/Runner/Info.plist)

## Setup

### 1. Install dependencies

```bash
./scripts/ensure-lfs.sh
cd example
flutter pub get
```

The `ensure-lfs` script is the Flutter repo equivalent of the React Native example's LFS bootstrap step. It verifies that Git LFS is installed and pulls the large model assets if the checkout currently contains LFS pointer files.

### 2. Add your DaVoice license

You can either:

- copy `example/licensekey.example.txt` to `example/licensekey.txt` and paste your key there
- or paste it into the app on startup

The app applies the same license to both `flutter_davoice` and `flutter_wake_word`.

### 3. Optional: add a Gemini API key

`Full AI Chat` mode expects `example/local.config.ts` to contain:

```ts
export const GEMINI_API_KEY = 'YOUR_GEMINI_API_KEY';
```

The safest setup is to copy `example/local.config.example.ts` to `example/local.config.ts` and keep the real file untracked.

If no Gemini API key is provided, the TTS and wake word parts of the demo still work, but the AI chat flow will fail when it tries to call Gemini.

### 4. Run the app

```bash
cd example
flutter run
```

If you enable Gemini-backed AI chat in the example app, avoid committing a real `GEMINI_API_KEY` into a public repository. For demos, prefer a local git-ignored config file instead of a hard-coded production key. For production, prefer a backend proxy or short-lived token flow instead of shipping a permanent key in the mobile client.

## Bundled Models

The example already includes model assets referenced by the app:

- Davoice TTS voice: `assets/models/model_ex_ariana_fast.dm`
- Davoice TTS voice: `assets/models/model_ex_rich_fast.dm`
- speaker verification model: `assets/models/speaker_model.dm`
- wake word model: `assets/models/hey_coach_model_28_22012026b.onnx`

The app currently uses the `Hey Coach` wake word model and saves speaker verification enrollment data to the app documents directory as `sv_enrollment.json`.

## Using A Custom Wake Word In This Flutter Example

The wake word side of this demo is based on a bundled ONNX model. To switch to a custom wake word for this Flutter repo:

1. Contact `info@davoice.io` with the wake word phrase you want to generate.
2. Add the generated `.onnx` model to [`example/assets/models/`](example/assets/models/).
3. Add the same ONNX file to Android native assets under [`example/android/app/src/main/assets/`](example/android/app/src/main/assets/).
4. Add the same ONNX file to the iOS app bundle under `example/ios/`, and make sure it is included by Xcode.
5. Update the wake word model name returned by `_wakewordModel` in [`example/lib/main.dart`](example/lib/main.dart).
6. Rebuild the Flutter app.

For example, if DaVoice generates `hey_sky.onnx`, update the app so `_wakewordModel` returns `hey_sky.onnx` instead of the current `hey_coach_model_28_22012026b.onnx`.

## Packages Used

Reference docs used while shaping this example README:

- `../FlutterPubDavoicePrivate/README.md`
- `../flutter_wake_word_lib/README.md`

Published packages used by this app:

- `flutter_davoice: ^0.0.6`
- `flutter_wake_word: ^0.0.45`

## Notes

- The app starts by requesting microphone permission, and on iOS also requests speech recognition permission.
- Speaker verification is optional. If you skip it, the app still initializes wake word and speech features.
- The first wake word opens a mode picker. Later wake word detections continue directly into the selected mode.
- During TTS playback, the app pauses STT and then resumes it after speaking to avoid self-transcription.
- In Full AI Chat mode, the LLM backend is Google Gemini, while the speech pipeline and spoken playback remain part of the Flutter DaVoice demo.

## Who This Is For

This repository is relevant if you are building:

- a Flutter voice assistant
- a hands-free mobile workflow
- an on-device AI assistant
- a voice-first accessibility flow
- a healthcare or enterprise voice workflow
- an in-car or field-service voice interface
- a branded app with a custom wake word
- a privacy-sensitive speech interface that should reduce cloud dependency

## SEO Summary

This repository is relevant for search intents such as:

- Flutter wake word
- Flutter wake word detection
- Flutter keyword spotting
- Flutter hotword detection
- Flutter trigger word
- Flutter speaker identification
- Flutter speaker verification
- Flutter speaker recognition
- Flutter speech to text
- Flutter offline speech to text
- Flutter ASR
- Flutter text to speech
- Flutter offline text to speech
- Flutter TTS
- Flutter on-device voice AI
- Flutter iOS Android voice AI

## Related Repositories

- DaVoice Flutter plugin: <https://github.com/frymanofer/FlutterPubDavoicePrivate>
- Wake word Flutter plugin: <https://github.com/frymanofer/flutter_wake_word_lib>

## Learn More

- DaVoice website: <https://davoice.io/>
- Documentation: <https://davoice.io/docs>
- Wake word product page: <https://davoice.io/wake-word>
- Speaker recognition product page: <https://davoice.io/speaker-recognition>
- Pricing: <https://davoice.io/pricing>
- Contact: <https://davoice.io/contact-us>
- Voice isolation with STT video: <https://www.youtube.com/watch?v=uYpaCXAvjew&feature=youtu.be>

## Contact

For licensing, custom wake words, speaker models, deployment help, or production integration support:

- Website: [https://davoice.io](https://davoice.io)
- Email: `info@davoice.io`
