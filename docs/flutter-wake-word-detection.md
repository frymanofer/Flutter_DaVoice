# [Flutter Wake Word Detection And Keyword Spotting](https://davoice.io/integration-guides-wake-word/flutter)

This repository is relevant for developers searching for:

- [Flutter wake word](https://davoice.io/integration-guides-wake-word/flutter)
- [Flutter wake word detection](https://davoice.io/integration-guides-wake-word/flutter)
- Flutter keyword spotting
- Flutter hotword detection
- Flutter trigger word

The example app demonstrates [wake-word detection](https://davoice.io/wake-word) as part of a complete on-device voice flow. After the wake phrase is detected, the app can pause detection, move into [speaker verification](https://davoice.io/speaker-recognition) or speech to text, and later return to listening mode.

That orchestration is important because wake word detection alone is rarely enough for a production voice product. Real apps need clean transitions between:

- always-listening detection
- speaker verification
- active speech recognition
- TTS playback

For the full implementation, see:

- [Main README](../README.md)
- [Example App](../example/lib/main.dart)
- [Wake Word Generator](../WakeWordGenerator.md)

