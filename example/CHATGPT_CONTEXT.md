# Flutter example context

Last verified: 2026-09-30. Read `MEMORY.md` for evidence/history and
`ALIGNMENT_PLAN.md` for remaining work. Update these files throughout alignment.
For a fresh editor/session, start with `RESTART_HANDOFF.md`; it contains the
latest API-23 conclusions and safe continuation order.

## Objective and repository map

Align this example with the current main React Native example, including its
per-voice TTS models, named ex2 voice selection, fixes, and audio
lifecycle. Work now proceeds from example behavior backwards: compare RN app calls, expose
missing Flutter APIs, then trace RN wrappers and implement Flutter bridges.
Native inference changes are not expected. See `API_PARITY.md` for current gaps.

All paths below are relative to `/Volumes/T9/projects`:

| Role | Path |
|---|---|
| Flutter app | `Flutter_DaVoice/example`, chiefly `lib/main.dart` |
| Canonical RN app | `ReactNative_DaVoice/example`, `App.tsx` and `src/` |
| Flutter wakeword wrapper | `flutter_wake_word_lib` |
| Flutter speech/TTS wrapper | `FlutterPubDavoicePrivate` |
| RN wakeword wrapper | `WakeWordRNNPM` |
| RN speech/TTS wrapper | `TTSNPM` |
| Native wakeword iOS / Android | `KeywordDetectionIOSLibPrivate` / `AndroidLibraryCode` |
| Native speech/TTS iOS / Android | `DavoiceTTSPrivate` / `DavoiceTTSAndroidPrivate` |

The requested RN `chatGPTMemory.txt` exists at
`../../ReactNative_DaVoice/example/chatGPTMemory.txt` relative to this example.
The remote-model example and unused `AppSimpleUI.tsx` are not the parity target.
The canonical RN app now wires a fifth Local AI Chat mode through the separate
`react-native-davoice-llm` / `TTSLLM` package. Treat that as its own Flutter
package/app migration; it is not an API inside the speech or wakeword wrappers.

## Verified baseline

- Flutter declares the public hosted releases `flutter_davoice: 0.0.6` and
  `flutter_wake_word: 0.0.45`. The example has no local path overrides.
- RN manifest and installed packages now use `react-native-davoice: 1.0.102`
  and `react-native-wakeword: 1.1.154`. The live sibling wrapper manifests are
  newer working trees: TTSNPM 1.0.395 and WakeWordRNNPM 1.1.156.
  Older context files contain obsolete versions and packaging claims.
- Existing uncommitted Flutter changes already add Hanna, lite/heavy selection,
  and full AI chat, combined STT+TTS, STT-only, and type-to-TTS modes. Default
  voice is Rich. Preserve this work; do not restart from the July migration plan.
- Current RN `useTTS2Only=false` is matched by `_usesSharedTtsModel=false`.
  Rich is the default: `model_ex2_rich.dm`, speed 0.95, `changeVoice('Rich')`.
  Hanna: `model_ex_hanna_light_davoice_ph.dm`, speed 0.90, no changeVoice call.
  Ariana: `model_ex_ariana_fast_davoice_phoneme.dm`, speed 0.88, no changeVoice call.
  All three assets match RN SHA-256. The shared ex2 model remains an optional
  inactive branch. Lite/heavy selection is removed to match current RN choices.
- Selecting a different model destroys/reinitializes speech before narration;
  the named-voice cache resets on initialization. SV skip retains this model.
- Flutter now exposes `changeVoice` through Dart and both native bridges. It
  normalizes native fallback/missing support to -1, matching RN. The app treats
  failure as an error and caches only successful selection.
- The requested shared asset is now copied locally; `pubspec.yaml` already
  bundles `assets/models/`. The old shared model is no longer selected by default.
- Flutter's typed schema and example now include RN HD/fallback, playback/STT
  ducking, AEC and during-TTS sensitivity. The same JSON is supplied before init
  to both APIs. Speech routing stores a direct value on iOS and is a no-op on
  Android (matching RN); Android wakeword now applies config and refreshes detectors.
- Flutter now selects RN hey-coach and SV `.dm` assets. The iOS bridge resolves
  Flutter asset paths and reports native model initialization errors.

## Startup flow (implemented 2026-09-15)

The app opens on a preparation screen, awaits bundled license and permissions,
configures/starts/pauses wakeword, initializes speech and selects Rich, then
speaks the introduction before showing voice selection. Confirmation narrates
before the SV prompt. SV skip reuses the loaded selected model; enrollment reloads
speech and restarts the existing detector with enrollment. Final narration
finishes before wakeword resumes and app callbacks are armed.

`lib/flow/startup_narration.dart` coordinates persistent Skip Narration intent.
Skipping while loading never sends native stop; skipping a spoken line waits for
native stop even if Dart's speak waiter completes first. Pauses use stopMic=true
on Android and false on iOS, matching current RN startup/capture. Startup retries
cancel the previous event subscription and destroy the previous detector before
recreating it. Pause/resume failures surface instead of silently reporting ready.
Voice buttons are disabled during pending selection. Unit/widget tests cover
skip timing, disposal between narration lines, Rich startup and per-voice model reload, and SV skip to armed wakeword. Enrollment/device behavior is still untested.

## Binary and lifecycle boundaries

Both Flutter sibling packages' primary iOS device/simulator framework binaries
and Android Maven AARs match their corresponding RN wrapper artifacts by SHA-256
as of this inspection. This proves artifact equality, not native-source freshness,
full framework resource equality, or the identity of artifacts consumed by the
running Flutter app. See the memory hash table.

RN wrappers also contain different `android/src/main/libs/MyLibrary-release.aar`
copies; use Gradle/Maven resolution to identify consumed artifacts. Do not copy an
arbitrary AAR or assume filenames prove freshness. Check POMs, ONNX runtime,
tokenizer libraries, ABIs, iOS resources and podspec linkage before building.

The July continuous-wakeword experiment is historical: current RN code actively
pauses during startup narration and other guarded transitions. Port current
state/stop/resume behavior, not a blanket removal of pauses. Lite STT pause is
distinct from microphone teardown. Native playback owns temporary sensitivity,
AEC and ducking transitions; avoid duplicating those transitions in Dart.

Native notes document HD/Bluetooth fallback and Spotify regressions, and poor
loud-speaker Android AEC despite enabled status. Actual routing, audible music
recovery, capture frames and barge-in require physical-device checks. Historical
iOS ex2 initialization failure has diagnostics but no confirmed device diagnosis
in the reviewed notes; do not label it fixed based on simulator success or hashes.

## References to revisit

- RN `example/{chatGPTMemory.txt,ClaudeContext.md,ClaudeMemory.md}` and
  `Futter_migration.md` (historical, partly implemented).
- RN `App.tsx`, `src/{appflow.ts,initialization/index.ts,tts/index.ts,wakeword/index.ts}`,
  speaker-verification onboarding/verification and STT/AI-chat modules.
- `KeywordDetectionIOSLibPrivate/{CHATGPT_CONTEXT.md,MEMORY.md}`.
- `TTSNPM/{CHATGPT_CONTEXT.md,MEMORY.md}`, `speech/index.ts`, bridge sources.
- `DavoiceTTSPrivate/{CHATGPT_CONTEXT.md,MEMORY.md,TTSV2_CONTEXT.md}` and
  `DavoiceTTSAndroidPrivate/TTSV2_CONTEXT.md`.

Treat dated notes as investigation history and recheck live code/artifacts when
they disagree. Never include license keys, API keys, enrollment recordings, or
private container details in these documents.

## Current validation and blockers (2026-09-16)

All four modes now have guarded navigation/stop and late-callback handling; AI
uses current RN non-streaming policy, request spacing and cooldown. Six example
tests and thirteen speech wrapper tests passed. Signed iOS device build passed.
Samsung native ex2 voice smoke passed with the active RN App.tsx license. The
subsequent literal RN licensekey.txt copy is expired and latest device smoke tests
fail license validation; see MEMORY.md. iOS debug app already has Bonjour/local
network plist entries, but user device denied Local Network permission. The old
automated iOS runner has been stopped. Device audio/SV/routing validation remains
open. These findings supersede earlier partial-pass validation notes above.

Latest correction: user approved restoring the working active RN App.tsx license;
licensekey.txt now contains it. The expired-file blocker above is resolved in the
source asset, pending rebuild/runtime verification. Xcode generated configuration
is reset from integration_test/parity_smoke_test.dart to lib/main.dart. Smoke
teardown no longer stops TTS before successful initialization.

Latest device log: startup narration, STT resume and echo TTS complete on iPhone.
Reported delay around four-option selection remains unlocalized; see MEMORY.md.
Active STT/combined screens now identify the actual mode, Continue shares option
entry guard, and narration/mode-entry elapsed logs support the next reproduction.

UI now follows RN centered 420px rounded-card layout across prompts and active
modes. Mode buttons enter directly; voice picker omits repeated narration and
license editor. Manual license entry remains available on setup failure.

## Wrapper alignment update (2026-09-30)

Flutter speech now matches current RN wrapper behavior for bounded STT/microphone
pause handling, unpause readiness results, iOS health diagnostics and stale-STT
event teardown. Android licensing no longer creates STT, model initialization is
off the method-channel thread, and standalone TTS is released before full init.
Flutter wakeword exposes `setTTSActive` on both platforms. Android updates the
detector instance; iOS explicitly begins/ends the shared during-TTS profile and
returns whether begin succeeded. Standalone iOS `initTTS` resolves local models
off the channel thread and uses bounded URLSession downloads for remote models.
Speech also exposes RN's routing reset and adapted EventChannel diagnostics.
The current examples still do not call `setTTSActive`. See MEMORY.md for
validation. Native binary refresh and physical-device verification remain
separate work.

## Android compatibility boundary (2026-09-30)

Implementation now supersedes the audit paragraphs below. The example and
speech wrapper declare API 23. TTS/TTS2 JNI and the accelerated wakeword
ARM64 stack were rebuilt for API 23. API 23–32 uses recognizer-owned STT input;
custom PCM/AEC and the inline STT gate remain API 33+. The complete product ABI
contract is ARM64. See `ANDROID_COMPATIBILITY.md` and `RESTART_HANDOFF.md`.

The original ONNX binary reports 1.24.0 and build commit
`1442fe00d9169e89ec4a52bd699952810244ba6b`. Use that exact source commit for
the API-23 rebuild; do not replace current-device behavior with a generic CPU
runtime or a different ONNX release.

Historical pre-change audit: the Flutter example and speech wrapper hardcoded
minSdk 29. The
packaged wakeword and combined STT/TTS/TTS2 AARs declare API 23 and API 26, so
API 29 is not currently justified by their manifests. STT custom PCM injection
and its inline SpeakerID gate require API 33, but basic STT should fall back to
the recognizer-owned microphone on API 26–32. The current public startSpeech path
still bypasses its API-aware helper and can incorrectly enter the custom path;
see `android_version_issues.md` and MEMORY.md. Wakeword-side Speaker Verification
owns AudioRecord and has no equivalent API-33 restriction. No compatibility
settings or native behavior have yet been changed based on this audit.

Follow-up binary inspection supersedes the manifest-only interpretation above.
The wakeword AAR says API 23, but its ONNX Runtime binaries identify API 27 and
its ARM Compute/Graph binaries identify API 29. The combined speech AAR's TTS
and TTS2 JNI binaries identify API 26. The older SpeakerID projects contain the
same API-27 ONNX and API-29 ARM Compute files, although their Genie, platform
validator and calculator files identify API 21. API 23 therefore requires native
rebuilds/replacements before lowering wrapper manifests. Basic STT can use the
normal recognizer on API 23 after fixing its routing. Android platform
SpeechRecognizer cannot accept the library's custom PCM until API 33, so custom
AEC and the current inline STT SpeakerID gate cannot retain their existing design
on API 23. See `android_version_issues.md` for the subsystem matrix.

## Public Flutter releases (2026-10-01)

The aligned wrappers are published on pub.dev as `flutter_davoice 0.0.6` and
`flutter_wake_word 0.0.45`. Their release commits are pushed to each wrapper's
private GitHub `main` branch. The public package archives contain the reviewed
wrapper source and bundled binaries. The example resolves these versions directly
from pub.dev without sibling path overrides. Both packages passed analysis,
unit tests, and `flutter pub publish --dry-run` with zero warnings immediately
before publication. Pub.dev accepted both uploads and its package API reports
the new versions as latest.

The valid `example/licensekey.txt` is an intentionally public temporary demo
license. Commit it with the example so users can run the public app immediately.
Do not reproduce the license value in context files, logs, or responses.
