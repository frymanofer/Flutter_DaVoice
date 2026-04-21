# Flutter Wake Word Generator By DaVoice

By [DaVoice.io](https://davoice.io)

Welcome to the Flutter wake word guide for DaVoice custom keyword detection.

## Create Your Custom Wake Word

Below are the steps needed to generate and integrate a custom wake word into this Flutter repository:

- Create a wake word model:
  Contact `info@davoice.io` with the list of desired custom wake words.

  DaVoice will provide corresponding model files, typically an `.onnx` file per wake phrase.

  For example, a wake word phrase like `hey sky` will usually correspond to `hey_sky.onnx`.

- Add the wake word to Flutter assets:
  Copy the generated `.onnx` model into [`example/assets/models/`](./example/assets/models/).

- Add the wake word to Android:
  Copy the same `.onnx` model into [`example/android/app/src/main/assets/`](./example/android/app/src/main/assets/).

- Add the wake word to iOS:
  Copy the same `.onnx` model somewhere under `example/ios/` and make sure it is added to the Xcode project with copy enabled if needed.

- Update the Flutter code:
  Change the wake word model returned by `_wakewordModel` in [`example/lib/main.dart`](./example/lib/main.dart).

Current example:

```dart
String get _wakewordModel {
  return Platform.isAndroid
      ? 'hey_coach_model_28_22012026b.onnx'
      : 'hey_coach_model_28_22012026b.onnx';
}
```

Example after switching to `hey_sky.onnx`:

```dart
String get _wakewordModel {
  return Platform.isAndroid ? 'hey_sky.onnx' : 'hey_sky.onnx';
}
```

- Last step:
  Rebuild the Flutter project.

## About This Project

This repository demonstrates a full Flutter voice pipeline, not only a wake-word feature. A wake word is the phrase that activates the app, similar to `Hey Siri` or `OK Google`.

It can then continue into more advanced voice flows such as:

- speaker verification
- speech to text
- AI chat
- text to speech

That layered approach is important for production voice experiences because wake word detection is usually just the first step in a longer voice interaction.

## Related Links

- [Main README](./README.md)
- [Flutter Wake Word Detection Doc](./docs/flutter-wake-word-detection.md)
- [DaVoice Wake Word Page](https://davoice.io/wake-word)
- [Flutter Wake Word Integration Guide](https://davoice.io/integration-guides-wake-word/flutter)

## Contact

For custom wake words, model generation, licensing, or integration support, contact `info@davoice.io`.
