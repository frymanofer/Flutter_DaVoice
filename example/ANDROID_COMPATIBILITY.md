# Android compatibility contract

Updated: 2026-09-30

## Platform versions

- The example and `flutter_davoice` declare `minSdk = 23`.
- Keep `compileSdk` current. It selects compile-time APIs and does not set the
  oldest supported phone.
- The wakeword AAR and the ARM64 TTS/STT/TTS2 AAR declare API 23.

## Runtime feature matrix

| Feature | API 23–32 | API 33+ |
|---|---|---|
| Wakeword | Supported | Supported |
| Standalone wakeword SpeakerID | Supported | Supported |
| Basic STT | System recognizer-owned microphone | Supported |
| Custom PCM STT / AEC | Unavailable | Supported |
| Inline STT SpeakerID gate | Unavailable | Supported |
| TTS and TTS2 | Supported | Supported |

The API boundary is enforced inside the native STT implementation. Below API
33, all STT starts use the ordinary `SpeechRecognizer` path, even if custom
audio or a speaker gate was requested. API 33 and newer retain the existing
custom PCM/AEC and inline speaker-gate path.

## ABI contract

The complete example supports `arm64-v8a`.

- TTS/TTS2 proprietary static dependencies are available only for ARM64.
- The wakeword ARM64 ONNX Runtime and ARM Compute stack is built for API 23.
- The wakeword AAR retains an existing x86 development slice with a native API
  27 floor. It is not supported by this full example.
- `armeabi-v7a` and `x86_64` are not shipped.

Adding an ABI name to Gradle cannot create support when its native libraries are
absent. A future 32-bit ARM or x86_64 contract requires matching builds of every
native dependency and device testing.

## Validation boundary

The native libraries, AAR manifests, package declarations, unit tests, and
ARM64 Flutter APK are checked as part of this migration. A physical API 23
device run remains required before making production device claims.
