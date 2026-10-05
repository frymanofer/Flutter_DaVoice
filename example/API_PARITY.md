> Current voice configuration (supersedes shared-model notes below): Rich is
> default, uses model_ex2_rich.dm at 0.95 with changeVoice. Hanna uses
> model_ex_hanna_light_davoice_ph.dm at 0.90; Ariana uses
> model_ex_ariana_fast_davoice_phoneme.dm at 0.88. Legacy models do not call
> changeVoice. Switching models reinitializes speech; no new wrapper API needed.

# App-driven API parity

Updated 2026-10-05. Start with `ReactNative_DaVoice/example/App.tsx` and its
active `src/` modules, then follow missing contracts into package wrappers.
This is a first-pass inventory, not a declaration of complete behavioral parity.

| App requirement | RN contract / reference | Flutter result |
|---|---|---|
| Voice models, Hanna/Rich/Ariana | `src/tts/index.ts`, `App.tsx: applySelectedTTSVoice` | Rich uses `model_ex2_rich.dm` plus `changeVoice`; Hanna/Ariana use their legacy `model_ex_*` files; quality hidden; matching speeds |
| Named voice selection | `TTSNPM/speech/index.ts: changeVoice`; iOS SpeechBridge and Android DaVoiceTTSBridge | Added facade/platform/channel and both native handlers; await conditioning; 0 success, -1 fallback/unavailable |
| Speech routing before init | `Speech.setAudioRoutingConfig`; iOS `DaVoiceAudioRoutingConfig.setAudioRoutingConfigJSONString` | Added map API; iOS stores JSON; Android no-op as in RN |
| Reset direct speech routing | `Speech.clearAudioRoutingConfig` | Added facade/channel; iOS clears native override, Android no-op as in RN |
| Wakeword routing on Android | `WakeWordRNNPM/.../KeyWordRNBridge.java: setAudioRoutingConfig` | Replaced notImplemented with native setFromJson and detector refresh |
| HD/fallback and ducking preferences | `src/wakeword/index.ts: defaultAudioRoutingConfig` | Typed Flutter extensions preserve native key casing and omitted partial fields; app policy matches RN |
| App-wide AEC / during-TTS sensitivity | RN `AEC.mode`, legacy `WakewordAEC`, and `wakeWordDuringTTS` | Added typed `AECConfig` with exact key/value serialization; legacy config retained; active example matches RN false/false setting |
| Initialization/license/disposal | `initAll`, `setLicense`, `destroyAll` | Existing APIs; startup now bootstraps first, retries replace prior detector/listener, SV skip avoids reload; native late-init/disposal remains a device validation concern |
| STT task control | `start`, `pauseSpeechRecognition`, `unPauseSpeechRecognition`, `stop`, `cancel`, `isRecognizing` | Existing facade methods; distinguish task pause from microphone pause |
| Bounded STT transitions | RN 500 ms pause backstop and unpause readiness result | Flutter uses bounded waits and returns `{ok, reason, elapsedMs}` when available |
| STT diagnostics | RN iOS `sttHealthSnapshot` | Added nullable Flutter API and iOS route/engine snapshot |
| Listener diagnostics | RN JS `sttListenerDiag` inspects emitter switching | Added Flutter-adapted map for its single EventChannel; RN emitter modes do not apply |
| Android TTS initialization | RN serial background executor and TTS-only/full-init cleanup | Flutter Android bridge now matches these lifecycle guarantees |
| Wakeword TTS state | RN Android detector state; iOS shared `begin/endWakeWordDuringTTS` | Added Flutter API on both platforms; returns whether native state was applied; current example does not call it |
| Standalone iOS remote TTS model | RN `initTTS` resolves asynchronously with 8s/15s URLSession timeouts | Flutter iOS now matches without blocking the method channel |
| Local AI Chat | Separate RN `react-native-davoice-llm` / TTSLLM package | Separate future Flutter package/app migration; no API belongs in these speech/wakeword wrappers |
| Speech events and playback | RN callbacks, `speak`, `stopSpeaking`, `playWav` | Existing Flutter streams/completion handling; full cancellation/late-event parity remains open |
| SV create/reuse/skip | RN onboarding/verification modules | Existing Flutter flows; saved candidate vs active enrollment already separate; full comparison pending |
| Type-to-TTS mode | RN appflow mode selection | Fixed Flutter's first-wakeword selection falling through into combined mode |
| Startup narration and skip | RN bootstraps then narrates/presents choices; waits for native stop | Implemented bootstrap → intro → voice → SV → wakeword; loading-time skip and native-stop wait covered by tests |
| Wakeword asset | RN bundled hey-coach `.dm` | Flutter bundles and selects the same `.dm`; UI reports “Hey Coach” |

## Validation boundaries

Package channel/serialization tests, app chooser test, Android debug build and
iOS simulator build pass. These demonstrate wiring and compilation, not audible
voice identity, actual HD routes, useful AEC or physical barge-in. Use the device
matrix in `ALIGNMENT_PLAN.md` for those checks.
