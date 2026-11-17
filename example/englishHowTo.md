# How-to: the DaVoice example app (Flutter)

> For developers who run, test or copy parts of this Flutter example (`Flutter_DaVoice/example/`). Last update: 2026-11-17,
> `flutter_davoice_llm` 0.0.14 (the agent core with Local confidence), `flutter_davoice` 0.0.19, `flutter_wake_word` 0.0.55.
> File paths are relative to `example/`. A Brazilian Portuguese version is in `portugueseHowTo.md`.
>
> The app is the Flutter version of DaVoice's React Native example: the same screens, the same agent packs, car tools,
> on-device models, pre-warmed states and language files.

> **Status: test models, still in training.** The car demo's on-device model ("DaVoice Automotive Agent 0.6B", checkpoint
> `g3c_it3639`, the default since 2026-11-17) is **a test model, not a finished product**. On a sealed set of 128 new
> sentences it never saw (run once, Brazilian Portuguese and English):
> - **86%** of the car commands (92 of 107) ended in exactly the right action;
> - **2 of 128** turns ran a wrong action, with **no opposite action** ("open" for "close") and **no unsupported action**;
>   background speech and fragments were never acted on;
> - 6 complete commands were answered with "say it again" instead of acting.
>
> Every car action is **simulated** (the car card) and checked before it runs (2.2). The **Local confidence** setting (2.3) can
> send uncertain commands to a remote agent instead. This example does not control a real vehicle.

The app shows a voice assistant that runs on the device: wake word, speaker verification, speech recognition (STT), speech
synthesis (TTS) with voice cloning, and two on-device AI demos with tools:
- **Car demo:** a simulated Volkswagen car (windows, doors, locks, climate, seats, navigation, radio, ...);
- **Calories demo:** a calorie tracker with personal memory.

Packages (`pubspec.yaml`):

| Package | What for |
|---|---|
| `flutter_wake_word` | wake word + speaker verification |
| `flutter_davoice` | STT + TTS, voice cloning, speaker filter on STT |
| `flutter_davoice_llm` (0.0.14) | the on-device model, `DavoiceAgent` (a whole assistant turn), tools, call checks, Local confidence |
| `path_provider`, `crypto`, `permission_handler` | files and downloads (checked by sha256), microphone permission |

---

## 1. Using the app

### 1.1 Run it

```bash
cd Flutter_DaVoice/example
flutter pub get
cd ios && pod install && cd ..      # iOS only
flutter run                         # a connected phone; or: flutter build apk / flutter build ios
```

- Requirements: Flutter 3.47 or newer (Dart 3.12). Android `minSdk` 23 (`android/app/build.gradle.kts`).
- The app installs as `com.davoice.flutter_davoice_example`.
- **License:** `licensekey.txt` (bundled) holds a temporary DaVoice key; the license field in the app replaces it. In your own app,
  use your own key (info@davoice.io).
- **Optional keys** (Gemini for the Full AI Chat mode, web search, USDA food lookup, a remote MCP server): `config/local.config.ts`
  (git-ignored). Without it the app uses the committed template `config/local.config.example.ts`; the car demo needs none of them.
- Logs: `flutter logs`, or on Android `adb logcat | grep -E "flutter|DavoiceChat"` (`DavoiceChat` = the agent's own log: every
  model output, check and reply). The same log is written to `davoice_chat.log` in the app's documents folder.

### 1.2 Startup flow

1. **Language.** English, Português do Brasil, Português de Portugal, German, Greek, Spanish, French, Italian, Dutch, Danish or
   Swedish. **English and Brazilian Portuguese are built into the app**; any other language is downloaded the first time it is
   chosen (its button shows "⬇ N MB"; a download screen shows the progress, with Retry and Back). The language sets the STT locale,
   the voices, the language the agent replies in and the agent pack (`assets/agent*/` or `assets/agent*/pt-BR/`).
2. **Microphone permission.** Accept.
3. **Spoken introduction** (narration, `lib/flow/narration.dart` and `lib/flow/startup_narration.dart`). **Skip Narration** skips it.
4. **Voice.** Pick a built-in voice, a voice you cloned earlier, or clone a new one (`lib/voice_clone/voice_clone.dart`).
5. **Speaker verification** (1.3): create a voice signature, use the saved one, or skip.
6. **Wake word.** Say **"Hey Coach"** (`assets/models/hey_coach_model_28_22012026b.dm`, the same in every language). This app has
   no button that replaces the spoken wake word.
7. **Choose Mode:**

| Mode | What it does |
|---|---|
| **Local AI · Car demo** | STT → on-device Automotive Agent → TTS, with the simulated car |
| **Local AI · Calories demo** | STT → on-device Personal Agent → TTS, with the calorie tracker and memory |
| Full AI Chat | STT → Gemini (cloud) → TTS; needs `GEMINI_API_KEY` |
| Combined STT + TTS | you speak and hear the text back |
| STT Only | shows the transcript only |
| Type to TTS | you type and the app speaks |

8. **A local demo's loading screen:** download (the model, and for the car demo its pre-warmed state, one progress bar), load,
   warm-up, with the seconds of each step and Retry / Back on an error. At "Ready" the chat screen opens.

### 1.3 Speaker verification

The app records a **voice signature** of the owner (5 natural sentences, in a quiet room) and enrolls it in the wake word **and**
in STT, so the wake word only fires for the enrolled voice and every STT result says who spoke. With a signature, the door tools
(`open_door`, `unlock_car`, scope `"door_locks"`) only run for the verified owner (`lib/speaker_verification/current_speaker.dart`);
with verification skipped they run (it is a demo).

### 1.4 What to say (car demo)

- **Windows:** "open the windows", "close the rear right window" / "abre os vidros", "fecha o vidro do carona", "abaixa os vidros
  de trás".
- **Climate:** "set the temperature to 22", "two degrees warmer" / "coloca o ar em vinte e dois", "vinte graus pro carona",
  "coloca 20 pro motorista e 23 pro passageiro", "ventilador no três", "liga o desembaçador".
- **Seats:** "turn on my seat heating" / "liga o aquecimento do banco do motorista".
- **Doors and locks:** "lock the car", "close the doors" / "tranca o carro", "abre a porta traseira esquerda".
- **Media and navigation:** "tune to 98.5 FM", "take me to Campinas" / "sintoniza noventa e oito ponto cinco", "quanto tempo falta?".
- **Two commands at once:** "fecha os vidros e tranca o carro". **Undo:** "undo" / "desfaz".
- **Follow-ups:** after "open the driver's window": "now the passenger one" / "agora o do carona", "fecha ele".
- **Incomplete:** "open a window" → "Which window?".
- **Not a car command** ("tell me about Brazil"): handed to the remote assistant. This example has none set up
  (`localLlmLayer2 = 'none'` in `lib/local_llm/model_config.dart`), so the app says so.

---

## 2. The car demo

### 2.1 Models and the chat screen

- **Models** (`lib/local_llm/model_config.dart`): the car demo's default is **DaVoice Automotive Agent 0.6B**
  (`localLlmDavoiceAutomotiveG3c`, checkpoint `g3c_it3639`, 382 MB, checked by sha256), with a pre-warmed state for English or
  Brazilian Portuguese (about 430 MB), so the first start skips the about-30-second warm-up. The older Automotive models (`r8d_it150`,
  `r4b_it100`) were removed. The calories demo uses the Personal Agent `ft7f2_it900`. **Change** opens the model picker;
  only one model is loaded at a time.
- **Chat screen:** the car card (state and last actions), **You said**, **Reply**, **Model · Change**, **Local confidence ·
  Change** (car demo), **Reset Chat**, **Back** (to the mode choice).

### 2.2 How a turn works

1. **Scope.** Only straightforward car commands reach the model; general questions go to the remote assistant, garbled speech is
   asked again, car functions without a tool are declined, background speech is ignored (`scope` in the model entry).
2. **The model** writes a tool call with the car's tools in its prompt (`assets/car/carToolDefinitions.h3d.json`, the wording it
   was trained with).
3. **Local confidence** (if on, 2.3): a call the model is not sure enough of never runs.
4. **Checks:** every call is compared with the user's own words before it runs (wrong object, on/off and open/close flips, zones,
   numbers never said, values out of range); a wrong-tool call gets one more try without that tool, otherwise the user is asked.
   Settings: `callGuards: 'correct'`, `guardRetry: true`, `maxOperations: 2`, `undo: true` in the model entry.
5. **The car** (`lib/car/car_tools.dart`) runs the action on the simulated car and says what it did; "desfaz" / "undo" restores
   the previous state (`lib/car/car_undo.dart`).

### 2.3 Local confidence

**Local confidence · Change** cycles Off (default) → 0.80 → 0.90 → 0.95. The value is stored in `local_confidence.json` next to the
model registry (`LocalLlmModelStore.localConfidence`) and sent to the agent before the next turn (`configure({'confidence':
{'min': value}})` in `lib/local_llm/local_llm_service.dart`; the calories demo always sends 0).

A tool call whose probability (the product of the probabilities of the tokens the model picked) is below the value **never runs**.
The request goes to the remote assistant (reason `low-confidence`); with none set up, `lib/agent/remote_assistant.dart` answers
**"For this command I need a remote agent."** / **"Para esse comando eu preciso de um agente remoto."**

Measured with `g3c_it3639` on commands it was never trained on:

| Setting | Wrong actions removed | Valid commands sent to the remote agent |
|---|---|---|
| Off (default) | 0% | 0% |
| 0.80 | about 40% | about 13% |
| 0.90 | about two thirds | about 20% |
| 0.95 | about 70% | about 27% |

It does not reach zero on its own (some wrong calls are made with high confidence). It does not change the prompt, so the
pre-warmed states stay valid.

### 2.4 What is downloaded

| What | Where | When |
|---|---|---|
| Wake word, speaker verification (`sv.dm`), voice files of English and Brazilian Portuguese | in the app (`assets/models/`) | always |
| Voice model + voice-cloning encoder of every other language (136–170 MB each) | R2 `language-packs/<file>` → app documents | when the language is chosen |
| On-device models (GGUF, 382 MB each) | R2 `agent-llm/<file>` → app documents `local_llm/models/` | when a demo first opens |
| The car model's pre-warmed state, English or pt-BR (about 430 MB) | R2 `agent-llm/prewarm/<file>` → next to the model | with the model |

R2 = DaVoice's Cloudflare R2 (`https://pub-27f94b1602c647ab95a601086cf52820.r2.dev`); every file is checked by sha256.
Languages: `assets/language_packs.json` (`bundled` = the languages inside the app; `lib/tts/language_packs.dart` downloads the
others). Models and states: `lib/local_llm/model_config.dart` (`url`, `sizeBytes`, `sha256`, `prebuiltStates`).

---

## 3. Where the code is

| Part | Files |
|---|---|
| Screens and flow (language, narration, voice, speaker verification, wake word, modes) | `lib/main.dart`, `lib/flow/` |
| On-device model: list, download, picker, loading, warm-up, turns | `lib/local_llm/` |
| The agent, its packs and the remote answer | `lib/agent/local_agent.dart`, `lib/agent/agent_pack.dart`, `lib/agent/remote_assistant.dart`, `assets/agent/`, `assets/agent_automotive/` |
| The simulated car (tools, state, card, undo, positions) | `lib/car/`, `assets/car/` |
| Calories demo | `lib/calories/` |
| Voices, styles, cloning, language packs | `lib/tts/`, `lib/voice_clone/` |
| Speaker verification state | `lib/speaker_verification/current_speaker.dart` |

Tests: `flutter test` (unit and widget tests in `test/`: car tools, undo, language packs, the model list, narration, the
transcript) and `integration_test/` on a device.

## Quick test checklist

1. Run the app (1.1); choose **Português do Brasil**. Also try a language that isn't built in (e.g. French): the download screen
   shows progress, and the app continues only when the download is complete.
2. Pick a voice; create the voice signature (5 sentences); say **"Hey Coach"**; choose **Local AI · Car demo**.
3. The first time the model and its pre-warmed state download (about 810 MB); then "Ready" comes in about a second.
4. "abre os vidros" → all windows open; "fecha eles" → closed; "desfaz" → back. Check the car card and that the spoken sentence
   matches what happened.
5. "abre um vidro" → the agent asks which one.
6. **Local confidence** → 0.90; uncertain commands are not run and the app says it needs a remote agent; clear ones still run.
7. A different voice must **not** wake the assistant nor unlock the car.
