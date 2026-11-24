# DaVoice: AI Car Voice Agent: how-to (Flutter)

> **For** developers who run this example, change it, or add its voice features to their own Flutter app. Paths are relative to
> `example_car_agent/`. Packages: `flutter_wake_word` 0.0.55, `flutter_davoice` 0.0.20, `flutter_davoice_llm` 0.0.17. Last update:
> 2026-11-22. The React Native twin of this app has the same guide (`ReactNative_DaVoice/example_car_agent/englishHowTo.md`).

The app is a car voice assistant that runs entirely on the phone: **wake word → (optional) speaker verification → speech to text
(STT) → the DaVoice Automotive Agent (a 0.6B model on the phone) → an action on a simulated car → text to speech (TTS)**. Nothing
you say leaves the phone. The car is simulated.

- **Part A** — use the app and change it.
- **Part B** — add each capability to **your own** Flutter app, with code you can copy.

| Package | What for |
|---|---|
| `flutter_wake_word` | wake word, speaker verification (enrollment and live checking), the audio routing config |
| `flutter_davoice` | STT and TTS (`FlutterDavoice`), voices, voice cloning, which speaker said each sentence |
| `flutter_davoice_llm` | the on-device model and agent (only for the car agent itself; Part B does not need it) |

---

# Part A — Use and change this app

## A1. Run it

```bash
cd example_car_agent
flutter pub get
flutter run                    # a phone: Android arm64 or iPhone
flutter test                   # unit tests, including the conversation flows shared with the other apps
```

Your DaVoice license goes in `licensekey.txt` (see `licensekey.example.txt`; ask info@davoice.io). Models and hint lists are
Flutter assets (`pubspec.yaml`): changing them needs a rebuild.

## A2. What it does

1. **Language** → its voice downloads the first time. 2. **Voice.** 3. **Speaker verification**: record a voice signature
(5 sentences), use the saved one, or skip. 4. **Say the wake word** ("Hey Coach" in this build). 5. **The car screen.** With the
default settings every request starts with the wake word; the line at the bottom says what to do ("Say “Hey Coach” before each
request" / "Listening… say your request").

## A3. Settings (the gear)

The same settings as the React Native app (see its guide, A3): take turns or interrupt, wake word or just talk, end of speech,
listen window after the wake word, **follow-up only after a question**, pre-fetch, wake word as a stop word (default off), and on the
car screen the model and Local confidence. Changes are a draft until **Save**.

## A4. Common changes

| To change | Where |
|---|---|
| The wake word | `_wakewordModel`, `_wakewordThreshold` in `lib/main.dart`; the model in `assets/models/` and in `pubspec.yaml` assets. Add its sound-alikes to `_soundsLike` in `lib/conversation/conversation_controller.dart`. |
| Conversation defaults | `defaultConversationSettings` in `lib/conversation/conversation_settings.dart` |
| Words STT should prefer | `assets/stt_bias_conf/words_flattened.txt` (one phrase per line, ending with a comma) |
| Audio routing (iOS route, ducking, echo cancellation) | `_defaultAudioRoutingConfig` in `lib/main.dart` |
| Speaker verification | `_svOnboardingSampleCount`, `_svDecisionThreshold` in `lib/main.dart`; sentences in `lib/speaker_verification/enrollment_sentences.dart` |
| What the car does and says | `lib/car/car_tools.dart` (keep `assets/car/carToolDefinitions.h3d.json` as is: the model was trained with it) |

## A5. Where the code is

| Part | Files |
|---|---|
| Start-up, wake word, speech, the turn | `lib/main.dart` (`_initializeSpeechAndWakeWord`, `_initializeSpeech`, `_listenToSpeechEvents`, `_handleWakeWord`) |
| Speaker verification | `lib/main.dart` (`_runSpeakerVerificationOnboarding`, `_applySpeakerVerificationChoice`), `lib/speaker_verification/` |
| **Conversation modes** (who listens when) | `lib/conversation/` (`conversation_controller.dart` and `conversation_settings.dart` are plain Dart) |
| Screens | `lib/redesign/` |
| The agent, the model, the car | `lib/agent/`, `lib/local_llm/`, `lib/car/` |

---

# Part B — Add these capabilities to your own Flutter app

## B0. Setup (once)

**1. Packages** (`pubspec.yaml`): `flutter_wake_word`, `flutter_davoice`, `path_provider`, `permission_handler`.

**2. Permissions.** Android: `RECORD_AUDIO` (ask at run time with `permission_handler` before starting anything). iOS
`Info.plist`: `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`; for background listening also
`UIBackgroundModes` → `audio`.

**3. Model files** as Flutter assets (`pubspec.yaml` → `flutter: assets:`): the wake-word model, `sv.dm` (speaker verification),
your TTS voice model, and `assets/stt_bias_conf/` (hint words). You refer to them by their asset path, e.g.
`'assets/models/hey_davoice_model_28_06042026.dm'`. A downloaded file works the same way with its file path.

**4. Licenses.** One for the wake word (`setKeywordDetectionLicense`), one for speech (`setLicense`). Ask info@davoice.io.

### The rules that make it work

1. **Pauses are gentle; the microphone keeps running.** Use only `pauseSpeechRecognition()` / `unPauseSpeechRecognition(-1,
   preFetchMs: …)` and the wake word's `pauseDetection(stopMic: false)` / `unPauseDetection()`. Never stop or cancel the recognizer
   to end a turn.
2. **One listener decides at a time.** STT listening → wake word paused (unless it is the stop word, B5). Wake word listening → STT
   paused.
3. **`pauseDetection(stopMic: true)` (Android) only to hand the microphone to another recorder** (speaker-verification enrollment,
   voice-clone recording); `unPauseDetection()` afterwards.
4. **The routing config first**, on both engines, before creating the wake word and before `initAll`.
5. **Start-up order:** wake word created, started → paused → `initAll` → STT paused → wake word unpaused.
6. **Pre-fetch only after the wake word** (2000 ms), then **strip the wake phrase** (B5). After a reply, a tap or a stop word:
   pre-fetch 0.
7. **Ignore speech that is not the user's turn**: while waiting for the wake word, thinking, or speaking (unless interrupting).
8. **Speaker verification is switched on and off live** (`addSpeaker` / `setSpeakers([])`), no restart.

## B1. Wake word

```dart
import 'package:flutter_wake_word/flutter_wake_word.dart';

const wakeId = 'wakeword';
const wakeModel = 'assets/models/hey_davoice_model_28_06042026.dm';

Future<KeyWordFlutterPC> createWakeWord(AudioRoutingConfig routing, void Function(String phrase) onWakeWord) async {
  await setWakewordAudioRoutingConfig(routing);                            // rule 4
  final ww = createKeyWordFlutterPCInstance(wakeId);
  await ww.createInstanceMulti(wakeId, [wakeModel], const [0.999], const [3], const [1000]);
  ww.onKeywordDetectionEvent().listen((e) => onWakeWord('${e['phrase'] ?? e['model'] ?? ''}'));
  if (!await ww.setKeywordDetectionLicense(wakewordLicense)) throw StateError('wake word license');
  if (!await ww.startKeywordDetection(wakeId, 0.999)) throw StateError('wake word did not start');
  return ww;
}
```

- Pause / resume: `await ww.pauseDetection(stopMic: false)` / `await ww.unPauseDetection()`.
- Sensitivity: threshold (higher = fewer false triggers) and buffer count; this app uses 0.999 / 3.
- Shut down: `await ww.stopKeywordDetection(wakeId); await ww.destroyInstance();` and cancel the subscription.
- The routing config: copy `_defaultAudioRoutingConfig` from `lib/main.dart` (`AudioRoutingConfig`, typed).

## B2. Speaker-verification onboarding

The user reads a few sentences; the result is an **enrollment JSON** saved to a file you enroll later (B4).

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_wake_word/flutter_wake_word.dart';
import 'package:path_provider/path_provider.dart';

Future<String> recordVoiceSignature({int samples = 5, void Function(int collected)? onProgress}) async {
  final file = File('${(await getApplicationDocumentsDirectory()).path}/sv_enrollment.json');
  final ctrl = await createSpeakerVerificationMicController('svMic');
  final done = Completer<void>();
  var collected = 0;
  final progress = StreamController<int>.broadcast();
  final subs = [
    onSpeakerVerificationOnboardingProgress((e) {
      if (e['controllerId'] != 'svMic') return;
      collected = (e['collected'] as num?)?.toInt() ?? collected;
      onProgress?.call(collected);
      progress.add(collected);
    }),
    onSpeakerVerificationOnboardingDone((e) {
      if (e['controllerId'] == 'svMic' && !done.isCompleted) done.complete();
    }),
    onSpeakerVerificationError((e) {
      if (e['controllerId'] == 'svMic' && !done.isCompleted) done.completeError(StateError('${e['error']}'));
    }),
  ];
  try {
    await ctrl.create({
      'modelPath': 'assets/models/sv.dm',
      'options': {'decisionThreshold': Platform.isAndroid ? 0.34 : 0.35, 'tailSeconds': 2.0, 'frameSize': 1280,
                  'maxTailSeconds': 3.0, 'cmn': true, 'expectedLayoutBDT': false},
    });
    await ctrl.beginOnboarding('davoice', samples, reset: true, savePath: file.path);
    for (var i = 0; i < samples && !done.isCompleted; i++) {
      // show sentence i, then wait for that sample (up to 60 s: people read slowly)
      final before = collected;
      final next = progress.stream.firstWhere((c) => c > before);
      await ctrl.getNextEmbeddingFromMic();          // iOS: returns when the sample is taken
      await Future.any([next, done.future]).timeout(const Duration(seconds: 60));
    }
    await done.future.timeout(const Duration(seconds: 30));
    if (!await file.exists()) throw StateError('the voice signature was not saved');
    return file.path;
  } finally {
    for (final s in subs) {
      await s.cancel();
    }
    await progress.close();
    await ctrl.destroy();      // always: an open controller keeps recording and fights the wake word and STT
  }
}
```

The full version, with the iOS and Android differences, is `_runSpeakerVerificationOnboarding` in `lib/main.dart`.

**Around the recording:** STT paused, and the wake word hands over the microphone:

```dart
await speech.pauseSpeechRecognition();
await ww.pauseDetection(stopMic: Platform.isAndroid);
try {
  enrollmentPath = await recordVoiceSignature(onProgress: showProgress);
} catch (_) {
  // show the choice again with a notice ("Try again in a quiet place, or skip"), never "restart the app"
} finally {
  await ww.unPauseDetection();
}
```

## B3. STT and TTS

```dart
import 'package:flutter_davoice/flutter_davoice.dart';

final speech = FlutterDavoice();

Future<void> startSpeech(KeyWordFlutterPC ww, AudioRoutingConfig routing) async {
  await speech.setAudioRoutingConfig(routing.toJson());                  // rule 4
  if (!await speech.setLicense(speechLicense)) throw StateError('speech license');
  await ww.pauseDetection(stopMic: false);
  await speech.initAll(DavoiceInitAllOptions(locale: 'en-US', model: 'assets/models/<your voice model>.dm'));
  await speech.pauseSpeechRecognition();       // STT starts paused; the wake word decides when it opens
  await ww.unPauseDetection();
}
```

**Listen:** `await speech.unPauseSpeechRecognition(-1, preFetchMs: preFetchMs, timeoutMs: 2500);` then
`speech.onSpeechPartialResults.listen((e) => onHeard(e.value.isEmpty ? '' : e.value.first))` (and `onSpeechResults`). When the user
stopped talking: `await speech.pauseSpeechRecognition();`.

- **End of speech** is yours: restart a timer on every result; when it runs out (2 s) the request is complete.
- **Android** delivers segments: merge them (`mergeTranscript` in `lib/flow/transcript.dart`); ignore results for ~400 ms after an
  unpause.
- **Hint words:** `assets/stt_bias_conf/words_flattened.txt`. Put your wake phrase there.

**Speak:**

```dart
await speech.changeVoice('Rich');                          // one of speech.getAllVoices()
speech.onFinishedSpeaking.listen((_) { /* everything queued was spoken: the next turn (B5) */ });
await speech.speak('I opened the driver window.', speed: 1.0);   // sentences queue up
await speech.stopSpeaking();                               // stop now
```

## B4. Speaker verification with STT and the wake word

```dart
const owner = 'owner';
await ww.addSpeaker(owner, enrollmentPath);       // the wake word answers only this voice
await speech.addSpeaker(owner, enrollmentPath);   // STT results say who spoke
// off:
await ww.setSpeakers(const []);
await speech.setSpeakers(const []);
```

Every STT result has `speakerIds` / `speakerId` (while verification is on). Collect them per request and check before a sensitive
action (`lib/speaker_verification/current_speaker.dart`: `noteSpeechResult`, `ownerMayAct`).

## B5. A complete voice-to-voice flow

**Copy** `lib/conversation/conversation_controller.dart`, `barge_in.dart`, `conversation_settings.dart` (and, for the UI,
`conversation_settings_panel.dart`, `conversation_store.dart`). The controller is plain Dart and runs the same test cases as the
React Native and Android apps (`test/fixtures/conversation_*.json`).

| Phase | STT | Wake word | Leaves the phase when |
|---|---|---|---|
| **asleep** (wake-word mode) | paused | listening | the wake word → listening (pre-fetch 2 s) |
| **listening** | listening | paused | silence after speech → busy; nothing said → asleep |
| **busy** | paused (interrupt mode: open under the voice) | paused (stop word: listening while it speaks) | the reply was spoken → a question: listening; otherwise asleep |

```dart
const wakePhrase = 'Hey DaVoice';
var settings = defaultConversationSettings;
var transcript = '';
var spoken = '';
var fromWakeWord = false;
var ignoreUntil = DateTime(0);
Timer? silence;

late final conversation = ConversationController(
  ConversationCommands(
    openMic: (preFetchMs, why) async {
      transcript = '';
      ignoreUntil = DateTime.now().add(const Duration(milliseconds: 400));
      await speech.unPauseSpeechRecognition(-1, preFetchMs: preFetchMs, timeoutMs: 2500);
    },
    closeMic: (why) async {
      silence?.cancel();
      transcript = '';
      await speech.pauseSpeechRecognition();                     // gentle (rule 1)
    },
    armWakeWord: (why) async => ww.unPauseDetection(),
    disarmWakeWord: (why) async => ww.pauseDetection(stopMic: false),
    stopReply: (why) async { cancelYourAgent(); await speech.stopSpeaking(); },
    onPhase: (phase) => showLine(conversationHint(phase, wakePhrase, settings.wakeWord)),
  ),
  settings,
);

Future<void> startConversation() async {        // the conversation screen opens
  if (!settings.wakeWord) await speech.unPauseSpeechRecognition(-1, preFetchMs: 0, timeoutMs: 2500);
  conversation.enter();                         // wake-word mode: asleep (the wake word that opened the screen is not a request)
}

void onWakeWord(String phrase) {                // B1
  fromWakeWord = true;
  conversation.wakeWord();
}

void onHeard(String text) {                     // B3 results
  text = text.trim();
  if (text.isEmpty) return;
  if (Platform.isAndroid && DateTime.now().isBefore(ignoreUntil)) return;
  if (conversation.phase == ConversationPhase.asleep || conversation.phase == ConversationPhase.off) return;   // rule 7
  if (conversation.phase == ConversationPhase.busy && !conversation.heardWhileBusy(text, spoken)) return;
  conversation.userSpeech();
  transcript = Platform.isAndroid ? mergeTranscript(transcript, text) : text;
  silence?.cancel();
  silence = Timer(Duration(milliseconds: settings.endOfSpeechMs), endOfRequest);
}

Future<void> endOfRequest() async {
  var text = transcript.trim();
  if (fromWakeWord && settings.wakeWord) {
    text = dropWakePhrase(text, wakePhrase);
    if (text.isEmpty) return;                   // only the wake phrase so far: wait for the request
  }
  fromWakeWord = false;
  transcript = '';
  await speech.pauseSpeechRecognition();
  conversation.turnStarted();
  spoken = '';
  final reply = await yourAgent(text);          // your model, server or rules
  conversation.replySpeaking();
  spoken = reply;
  await speech.speak(reply);
}

// once: after the voice finished, a question → listening; otherwise → asleep
void listenForReplyEnd() => speech.onFinishedSpeaking.listen((_) => conversation.replyFinished(spoken));

void applySettings(ConversationSettings next) {   // Save in the settings
  settings = next;
  conversation.update(next);
}
```

- **The wake phrase** (`dropWakePhrase`): "Hey DaVoice, open the window" → "open the window"; also "Hey the voice …", "The voice,
  …", "DaVoice, …", the phrase twice; only the phrase → `''` (wait). For your wake phrase, add its sound-alikes to `_soundsLike`.
  Strip it also from text you show while the user talks.
- **After the reply:** wake-word mode reopens STT only after a question (`isQuestion`: ends with "?"); just talk reopens after every
  reply.
- **Stop word** (`wakeWordMode.stopWord`): the wake word listens while the agent speaks and stops it. **Interrupt** (`interrupt`):
  STT stays open under the voice; `routingConfigForConversation(routing, settings)` turns on echo cancellation (iOS); Android:
  `speech.setAECEnabled(true)` where supported (experimental).
- **Leaving the screen:** `conversation.leave()`.

### Checklist

- [ ] Routing config set on both engines first; start-up order as in B3.
- [ ] Only gentle pauses.
- [ ] Wake-word mode starts asleep; the screen says "Say “…” before each request".
- [ ] Pre-fetch only after the wake word; the wake phrase is stripped.
- [ ] Nothing heard while asleep or busy reaches your agent (unless interrupting).
- [ ] After a reply: a question → listening; otherwise → the wake word.
- [ ] Enrollment hands over the microphone and always destroys its controller; speaker verification is switched on live.

### Troubleshooting

| Symptom | Cause |
|---|---|
| It answers without the wake word | STT opened when the screen opened, or a result while asleep was not ignored, or the recognizer was stopped instead of paused. |
| The request starts with the wake phrase | The turn was not marked as opened by the wake word, or the phrase's sound-alikes are missing. |
| The agent answers its own voice | Interrupting without echo cancellation, or pre-fetch > 0 after a reply. |
| Voice signature: no sample | The wake word still holds the microphone (`pauseDetection(stopMic: true)` on Android), or a noisy room. |
