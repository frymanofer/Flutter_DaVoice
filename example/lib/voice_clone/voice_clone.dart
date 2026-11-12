// Voice cloning: turn a short recording (microphone or an audio file) into a
// voice the TTS model can speak with. The RN example's src/tts/voiceClone.ts.
//
// speech.createVoiceClone(audio, '<clonedVoicesPath>/<Name>.emd', voiceEmbedder)
// writes <Name>.emd; speech.setExternalVoicesPath(clonedVoicesPath) makes every
// .emd in the folder a selectable voice (speech.changeVoice(name)), after the
// voices bundled in the model.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_davoice/flutter_davoice.dart';
import 'package:path_provider/path_provider.dart';

import '../flow/app_language.dart';
import '../flow/rn_tables.g.dart';
import '../tts/language_packs.dart';

/// Voice encoder for createVoiceClone: turns a recording (wav/mp3/m4a/...)
/// into a `<name>.emd` voice for the app language's model (a voice fits only its own language's model).
/// Built in (a Flutter asset) or a downloaded language pack's file (lib/tts/language_packs.dart); English if neither.
String get voiceEmbedder => languageFile(currentAppLanguage, 'embedder') ?? languageFile('en', 'embedder')!;

/// How long to record: about 10 seconds of natural speech gives a good voice.
const recommendedRecordingSeconds = 10;
const maxRecordingSeconds = 30;

/// Voice volume (speech.createVoiceClone's `volume`), in percent: 100% keeps
/// the recording's loudness, 120% makes the voice 20% louder (volume 1.2), 80%
/// 20% quieter (0.8). The clone screen steps it by [voiceVolumeStep].
const defaultVoiceVolumePercent = 100;
const minVoiceVolumePercent = 50;
const maxVoiceVolumePercent = 200;
const voiceVolumeStep = 10;

/// A text to read aloud while recording (about 10 seconds).
String get voiceCloneReadingText => voiceCloneReadingTexts[currentAppLanguage] ?? voiceCloneReadingTexts['en']!;

/// The cloned voices folder of the app's language: new voices are saved here,
/// and the app looks here for cloned voices. One path for both. A voice is made
/// with the language's encoder, so each language has its own folder. Change it
/// to keep voices elsewhere.
Future<String> clonedVoicesPath() async {
  final base = '${(await getApplicationDocumentsDirectory()).path}/cloned_voices';
  return currentAppLanguage == 'en' ? base : '${base}_${currentAppLanguage.replaceAll('-', '_').toLowerCase()}';
}

/// The microphone recording, before it becomes a voice (replaced each time).
Future<String> _recordingPath() async =>
    '${(await getTemporaryDirectory()).path}/voice_clone_recording.wav';

// The app's own native code (android/.../VoiceRecorder.kt,
// ios/Runner/VoiceRecorder.swift): microphone recording and the file picker.
const _recorder = MethodChannel('davoice_example/voice_recorder');

class VoiceRecordingStatus {
  const VoiceRecordingStatus(this.recording, this.seconds, this.peak);

  final bool recording;
  final double seconds;

  /// 0..1
  final double peak;
}

class VoiceAudioFile {
  const VoiceAudioFile(this.path, this.name);

  final String path;
  final String name;
}

/// Makes the cloned voices in the cloned voices folder selectable. Call after
/// every speech.initAll() (a reload forgets the folder). Returns their names.
Future<List<String>> loadClonedVoices(FlutterDavoice speech) async {
  try {
    final folder = await clonedVoicesPath();
    await Directory(folder).create(recursive: true);
    final names = await speech.setExternalVoicesPath(folder);
    debugPrint('[VoiceClone] cloned voices: $names');
    return names;
  } catch (error) {
    debugPrint('[VoiceClone] loading cloned voices failed: $error');
    return const <String>[];
  }
}

/// Why [name] can't be a new voice's name, or null when it can. The name is
/// the file name: letters, digits, spaces and dashes; no "_" (that marks a
/// style of a voice, e.g. Kate_whisper); not a bundled voice (the bundled one
/// would win).
String? voiceNameProblem(String name, List<String> bundledVoices) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Enter a name for the new voice.';
  if (trimmed.length > 30) return 'Use at most 30 characters.';
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 -]*$').hasMatch(trimmed)) {
    return 'Use letters, digits, spaces and dashes only, starting with a letter or digit.';
  }
  if (bundledVoices.any((voice) => voice.toLowerCase() == trimmed.toLowerCase())) {
    return '"$trimmed" is a built-in voice. Pick another name.';
  }
  return null;
}

Future<void> startVoiceRecording() async {
  final path = await _recordingPath();
  try {
    await File(path).delete();
  } catch (_) {}
  await _recorder.invokeMethod<String>('start', {'path': path});
}

Future<VoiceRecordingStatus> getVoiceRecordingStatus() async {
  final map = await _recorder.invokeMapMethod<String, dynamic>('status') ?? const {};
  return VoiceRecordingStatus(
    map['recording'] == true,
    (map['seconds'] as num?)?.toDouble() ?? 0,
    (map['peak'] as num?)?.toDouble() ?? 0,
  );
}

/// Stops the microphone recording; returns the WAV file and its length.
Future<({String path, double seconds})> stopVoiceRecording() async {
  final map = await _recorder.invokeMapMethod<String, dynamic>('stop') ?? const {};
  return (path: '${map['path'] ?? ''}', seconds: (map['seconds'] as num?)?.toDouble() ?? 0);
}

Future<void> cancelVoiceRecording() async {
  try {
    await _recorder.invokeMethod<void>('cancel');
  } catch (_) {
    // nothing was recording
  }
}

/// Lets the user pick an audio file (wav, mp3, m4a, ...). Returns a local copy
/// the TTS library can read, or null when the user cancels.
Future<VoiceAudioFile?> pickVoiceAudioFile() async {
  final map = await _recorder.invokeMapMethod<String, dynamic>('pickAudioFile');
  if (map == null) return null;
  return VoiceAudioFile('${map['path']}', '${map['name']}');
}

/// Creates the voice [name] from [audioPath], saved in the cloned voices folder.
/// [volume]: 1 keeps the recording's loudness, 1.2 is 20% louder, 0.8 20% quieter.
Future<VoiceCloneResult> createClonedVoice(FlutterDavoice speech, String audioPath, String name,
    {double volume = 1}) async {
  final folder = await clonedVoicesPath();
  await Directory(folder).create(recursive: true);
  // Same name (voice names ignore case): the new voice replaces the old one.
  final fileName = '${name.trim()}.emd'.toLowerCase();
  await for (final item in Directory(folder).list()) {
    if (item is File && item.uri.pathSegments.last.toLowerCase() == fileName) await item.delete();
  }
  // Make sure the folder is the library's external voices folder, so the new
  // voice is selectable right away.
  await speech.setExternalVoicesPath(folder);
  final result =
      await speech.createVoiceClone(audioPath, '$folder/${name.trim()}.emd', voiceEmbedder, volume: volume);
  debugPrint('[VoiceClone] created "${result.voice}" (volume $volume)');
  return result;
}

/// Deletes the cloned voice [name] (its .emd and its styles, `<name>_<style>.emd`)
/// from the cloned voices folder. Returns the cloned voices that remain.
Future<List<String>> deleteClonedVoice(FlutterDavoice speech, String name) async {
  final voice = name.trim().toLowerCase();
  final folder = Directory(await clonedVoicesPath());
  if (await folder.exists()) {
    await for (final item in folder.list()) {
      final file = item.uri.pathSegments.last.toLowerCase();
      if (item is File && (file == '$voice.emd' || (file.startsWith('${voice}_') && file.endsWith('.emd')))) {
        await item.delete();
      }
    }
  }
  debugPrint('[VoiceClone] deleted "$name"');
  return loadClonedVoices(speech);
}
