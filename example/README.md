# Flutter DaVoice Example

The main project README lives at:

[`../README.md`](../README.md)

This `example/` directory contains the runnable Flutter app.

## Android compatibility

The example has `minSdk = 23` and keeps its current `compileSdk`. The
supported API 23 device ABI is `arm64-v8a`.

On API 23–32, STT uses the system recognizer's normal microphone input. Custom
PCM injection/AEC and the inline STT SpeakerID gate are disabled because the
required Android audio-source extras were introduced in API 33. API 33 and
newer retain the existing custom-audio and inline-gate behavior.

Wakeword, standalone SpeakerID, TTS, and TTS2 use API-23-built ARM64 native
libraries. The complete app does not support `armeabi-v7a`, `x86`, or
`x86_64`, because the native TTS dependencies are only available for ARM64.
See [ANDROID_COMPATIBILITY.md](ANDROID_COMPATIBILITY.md) for the package and
runtime contract.
