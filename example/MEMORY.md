# Flutter example memory

## 2026-10-06 — committed RN example parity audit

Fetched the React Native remote, confirmed local `HEAD` and `origin/main` both
resolve to `9dc9dc6fdd6af524ec309da1ec3e183490a7f37f` with zero divergence, and
exported that ref to a separate temporary directory. The RN checkout is dirty,
including Local LLM work and dependency changes, so no behavior or manifest was
read from those working files for this audit.

The latest pushed commit only changes `WakewordAEC.duringTTS` from true to false.
Flutter already matched the committed false/false AEC setting. The committed RN
example declares `react-native-davoice 1.0.102` and
`react-native-wakeword 1.1.154`, and still has four modes. Its active Gemini
configuration is non-streaming `gemini-3.1-flash-lite-preview`, Google search,
temperature 0.7, 512 output tokens, thinking budget 256, four-second request
spacing, 30-second rate-limit cooldown, and a two-second speech silence timeout;
Flutter matches those values and behavior.

Compared both Git/LFS pointers and materialized bytes for Rich, Hanna, Ariana,
shared TTS2, hey-coach and SV models. They match. Sound effects and logo pointers
also match. Voice selection, speeds, wakeword thresholds, SV sample/decision
settings, routing entries, narration, mode labels and descriptions match. The
Flutter temporary license matches the single committed RN license value; only a
boolean comparison was logged and the value was not copied into these notes.

Found and fixed two example-state differences. Flutter initialized its selected
mode as Full AI Chat even though the first prompt later reset it to Combined;
committed RN initializes both state and ref as Combined. Flutter also passed
`stopMic=true` on Android through its shared wakeword pause helper, while every
active committed RN startup, enrollment and detection-capture pause passes
false. Flutter now initializes Combined and passes false on both platforms.
No wrapper or native code change was needed. Local LLM remains excluded.

## 2026-10-01 — API 23 native lint follow-up

The full Android TTS build exposed 13 API-24 lint errors after lowering minSdk.
Replaced `ConcurrentHashMap.newKeySet()` with an API-23-compatible concurrent
map-backed set and stopped calling Java `Optional` in both legacy TTS and TTS2
ONNX result handling. This preserves behavior without core-library desugaring
or a lint baseline. Native `./build.sh` now passes all 91 tasks, including
debug/release compilation, lint and unit tests. Copied the rebuilt AAR and
checksums into `FlutterPubDavoicePrivate`; SHA-256 is
`dc5a7d557aa18536c82f5e2c89de9739a04ab4c2779c2f03b789c9dd132c072f`.

## 2026-09-30 — Android API 23 implementation

Lowered the example and `flutter_davoice` declarations to API 23 without
changing compileSdk. Native STT now routes API 23–32 through the normal
`SpeechRecognizer` microphone and keeps custom PCM/AEC plus inline STT
SpeakerID on API 33+. Added a pure routing policy test and an authoritative
guard at the custom-audio boundary.

Rebuilt legacy TTS and TTS2 JNI for ARM64 API 23. Rebuilt the same ARM Compute
38.0 source commit and acceleration configuration for API 23. The first ONNX
package used 1.24.1; inspection of the prior binary identified its exact 1.24.0
build commit (`1442fe00d9169e89ec4a52bd699952810244ba6b`), so the final package
was rebuilt from that commit. It still links ARM Compute and ARM Compute Graph,
preserving the existing engine version and accelerated architecture on API 29+
while lowering its native platform floor.

Published the local compatibility contract: the full product supports
`arm64-v8a`. Proprietary TTS inputs are unavailable for 32-bit ARM and x86_64.
The wakeword x86 development slice remains in its AAR at API 27 but is outside
the full product/API-23 contract. No pub package was published.

Validation so far: TTS release tests/build, wakeword release build, speech
Flutter analysis/tests, wakeword Flutter tests, and example analysis/tests
pass. Wakeword analysis has 27 pre-existing public-member documentation infos.
The current Flutter test plugin declares API 24; a debug-only manifest override
keeps that test runner from raising the application floor. An ARM64 debug APK
and split ARM64 release APK build pass. The final release APK declares minSdk
23, compile/target SDK 36, and contains only ARM64 native libraries. Its TTS,
TTS2, ONNX Runtime and ARM Compute files identify API 23, while
`libc++_shared.so` identifies API 21; all have 16 KB ELF load alignment.
Physical API 23/API 33 device tests remain.

## 2026-09-30 — restart handoff persisted

Created `RESTART_HANDOFF.md` and made it the first file named by `AGENTS.md`.
It records the corrected native binary floors, API-23 feasibility decisions,
feature limitations, safe implementation order, dirty-worktree preservation and
validation boundary. Added the API-23 execution track to `ALIGNMENT_PLAN.md` and
linked the handoff from `CHATGPT_CONTEXT.md`. Documentation only; no runtime,
manifest, native binary or package publication change occurred.

## 2026-09-30 — Android API-level audit from customer report

Audited `android_version_issues.md`, the Flutter app/plugins, packaged AAR
manifests and metadata, native wakeword/SpeakerID variants, and the combined
STT/TTS/TTS2 source. The example and flutter_davoice wrapper hardcode minSdk 29,
but the actual wakeword and TTS artifacts declare 23 and 26 respectively. Thus
API 29 is currently a wrapper policy rather than a demonstrated engine floor.

Confirmed the customer's STT failure mechanism still exists in the current
source and pub 0.0.5 AAR: `useCustomAlways=true`, and public `startSpeech()` calls
private `startListening()` directly, bypassing the newer API-aware
`startListeningForMode()` helper. This can select Android-13 custom PCM injection
on API 29–32. Basic STT should use the ordinary recognizer there. The integrated
STT speaker gate intentionally remains API 33+ because it consumes that custom
PCM stream; its underlying SpeakerVerificationSTT inference is not intrinsically
API 33. Wakeword-side speaker verification owns AudioRecord and has no equivalent
API-33 dependency. Legacy TTS and TTS2 share the API-26 AAR; inspected TTS2 code
adds no higher Android framework requirement. Full breakdown and recommended
compatibility contract are appended to `android_version_issues.md`. No native or
wrapper behavior was changed in this investigation.

## 2026-09-30 — latest RN wrapper refresh

Re-audited the live TTSNPM 1.0.395 and WakeWordRNNPM 1.1.156 working trees plus
the current RN example (installed speech 1.0.102, wakeword 1.1.154). Flutter
wakeword's iOS `setTTSActive` was still a no-op; it now
balances `AudioSessionAndDuckingManager.beginWakeWordDuringTTS()` and
`endWakeWordDuringTTS()` and returns the native applied result through Dart.
Flutter iOS standalone `initTTS` now resolves local models off the method-channel
thread and downloads HTTP(S) models using an ephemeral URLSession with RN's
8-second request and 15-second resource timeouts before background engine init.
Added the missing `clearAudioRoutingConfig()` contract (real iOS clear, Android
no-op like RN) and an adapted `sttListenerDiag()` for Flutter's single
EventChannel. RN's multiple-emitter mode fields do not apply to Flutter.

The RN example also added a fifth Local AI Chat mode through the separate
`react-native-davoice-llm` / TTSLLM package. That is a new product/package track,
not a TTSNPM or WakeWordRNNPM API, so no LLM API was added to these two Flutter
wrappers in this refresh. Existing native binaries were not copied or published.

Validation: wakeword 5 tests and speech 16 tests passed; speech analysis is
clean; wakeword analysis reports only the same 27 public-doc info notices. The
example's 8 tests, Android debug APK, and iOS simulator debug build passed using
the local package overrides. Physical-device behavior remains to be checked.

## 2026-09-28 — align Flutter wrappers with current RN bridge changes

Implemented the wrapper gaps found in the September 22 audit without replacing
native frameworks/AARs. Speech pause now uses a bounded 500 ms native wait and
Dart backstop. Unpause defaults to 500 ms, respects an explicit longer timeout,
and returns the native `{ok, reason, elapsedMs}` readiness verdict. Microphone
pause/unpause use bounded iOS native waits. Added read-only iOS
`sttHealthSnapshot` diagnostics.

The iOS speech bridge now drops callbacks from an obsolete STT instance, clears
its reference before destruction, removes the delegate during teardown, and
performs deinit cleanup on the main thread. License setup no longer constructs
STT on either platform; Android uses the process-global LicenseManager. Android model loading
runs on a serial background executor and handles standalone-TTS to full-init
transition cleanup. The wakeword wrapper now exposes Android `setTTSActive`;
iOS treats it as a no-op because playback coordination is native there. The
current RN example does not call this API, so the Flutter app does not duplicate
native playback-state signaling.

Matched the RN logging defaults as well: routine iOS speaker-verification and
audio-routing payload logs plus Android wakeword model/enrollment logs are off by
default. Actual bridge errors remain visible. This also removes the active
Android log site that printed the license value.

Validation: speech package 15 tests passed; wakeword package 5 tests passed.
Flutter speech analysis passed. Wakeword analysis has only its 27 pre-existing
public-member documentation infos. Example 8 tests passed. Android debug APK and
iOS simulator debug builds passed with the local wrapper overrides. Native
binaries were not copied or published in this pass.

## 2026-09-22 — wrapper-only audit (no implementation changes)

Compared local TTSNPM/WakeWordRNNPM working trees with Flutter wrappers, excluding
native frameworks/AARs. Exact September-16 source snapshots were not retained;
RN git HEADs remain August 1 and changes are uncommitted. Therefore current gaps
are confirmed, but cannot date every gap to after the previous alignment.

Current gaps: Speech pause/unpause now has 500ms bounded handling in RN (Android
JS callback backstop; iOS async calls). Flutter pause has no timeout argument or
Dart backstop; unpause still defaults to 2500ms. RN exposes iOS sttHealthSnapshot,
absent from Flutter. RN iOS bridge rejects events from obsolete STT instances and
centralizes clear-before-destroy teardown/main-queue enforcement; Flutter event
handler has no instance identity guard and clears STT after destroySpeech.
RN Android model initialization uses a single-thread executor; Flutter still calls
initTTS synchronously in the method handler. RN Android licensing stores the key
without constructing STT; Flutter setLicense calls ensureSTT. RN further guards
standalone-TTS to full-init lifecycle. Wakeword RN exposes Android setTTSActive,
absent from Flutter. No usage of healthSnapshot/setTTSActive found in current RN
example App.tsx/src; do not automatically duplicate native playback coordination.
Prior changeVoice/audio-routing/AEC schema work already covers those RN changes.
RN-specific JS bridge routing fixes cannot be mechanically ported to Flutter's
single-plugin architecture. No binaries updated or library code changed in audit.

## 2026-09-16 — match RN per-voice models and Rich default

Read live src/tts/index.ts and App.tsx: DEFAULT_TTS_VOICE=Rich and
useTTS2Only=false. Flutter now defaults to Rich model_ex2_rich.dm (0.95),
Hanna uses model_ex_hanna_light_davoice_ph.dm (0.90), Ariana uses
model_ex_ariana_fast_davoice_phoneme.dm (0.88). All assets copied/verified
against RN SHA-256. Rich hash:
84b005e493fd75470fc9d213d3ce7c99c430abb5321af4056356ebdb4d9112e5.
Named changeVoice applies only to ex2; legacy voices reload via existing initAll
path. Default narration identifies Rich; removed obsolete quality selector.
Expanded widget flow to exercise default Rich plus each alternative model load,
asserting no legacy changeVoice call. Native smoke now loads each distinct model.
Validation: all three phone-sized widget flows pass, covering Rich/Hanna/Ariana
model selection and all four app modes. Test isolation clears cached assets and
resets the speech channel instance between cases. No wrapper/native changes
needed; no device launch or publication performed. New model audio on device
remains unverified.

## 2026-09-16 — align screen layout with React Native

Compared live RN App.tsx prompt/mode/speech layout and styles. Unified Flutter
prompt, speech and typed-TTS screens around a centered max-width 420 card,
24px corner radius, consistent padding and rounded logo panel. Removed repeated
voice narration and default license editor from voice selection; manual license
entry/retry is shown only after setup failure. Four-option picker now has the
RN direct choices without redundant Continue or repeated narration. Active
speech uses stable Speaker/Status/Current sentence blocks, avoiding repeated
transcript output. Typed TTS has a full-width Speak action and paired Clear/Back.
Widget flow now runs at 390x844 logical pixels to check phone layout constraints.
Physical-device visual review remains pending; no new device runner launched.

## 2026-09-16 — clean detected wake-word label

Matched RN cleanDetectedWakeWord: strip the model token and all following words
from normalized detection labels, instead of matching one dated filename. Both
onscreen detection text and narration use the cleaned phrase (Hey Coach). Handles
filename/path and already space-separated native labels.

## 2026-09-16 — investigate four-option wait from xcode.log

Read user-provided example/xcode.log. Native narration player #9 drains normally
and releases its completion callback (around line 9886). STT later unpauses,
recognizes Hey Coach, and player #10 speaks it successfully. No permanent hang
or failed license appears in that sequence. Logs lack Dart mode-selection timing,
so cannot attribute the user's long wait to a specific call. Asked whether the
wait was before options appeared or after selecting one, and which option.

Found and corrected misleading active STT/combined heading (previously still
said Say the wake word despite paused wakeword). Continue now uses the same
mode-switch guard as option taps, preventing concurrent entry calls; it displays
Opening while pending. Mode entry only allowed from picker. Added elapsed timing
for narration and mode entry. Known hey-coach model filename now displays/speaks
Hey Coach instead of model/version suffix. These are concrete UI fixes, not proof
that the reported delay is resolved. Existing all-four-mode widget test passes.
No native code changes or device launch; normal Xcode app target retained.

## 2026-09-16 — working license restored and Xcode target corrected

User authorized using the working active RN App.tsx license. Copied that value
into licensekey.txt and verified speech/wakeword source values match, without
printing credentials. Supersedes the literal expired license-file copy below.
User log confirms integration smoke failed at setLicense before initialization;
its subsequent no_tts error came from unconditional teardown stopSpeaking.
Teardown now stops only after successful TTS initialization and uses finally
blocks to ensure remaining engine/detector cleanup is attempted.
Generated iOS configuration retained the integration test target from our runner.
Regenerated with flutter build ios --config-only --debug --target lib/main.dart
so manual Xcode launches return to the actual app. No device launch attempted
during this fix; native validation with the restored license remains pending.

## 2026-09-16 — full app pass and iOS debugging follow-up

Implemented all four mode transitions, stop/back cancellation and stale callback
protection, transcript coalescing, and current RN non-streaming Gemini request
spacing/cooldown/history. Speech wrapper queues now respect native stop completion.
Copied and selected RN hey-coach and SV .dm assets; aligned SV thresholds. iOS
wakeword bridge resolves Flutter asset paths and surfaces initialization failures.
Local sibling overrides now live in tracked pubspec.yaml, not the ignored override
file. All 23 non-signature files per XCFramework and Maven POMs match RN wrappers.

Validation: six app tests and thirteen speech tests passed; four wakeword tests
passed in the prior pass. Android debug, iOS simulator and signed iOS device builds
passed. Samsung native shared-model/three-voice smoke passed using the active RN
App.tsx license. Later, at the user's request, copied RN licensekey.txt exactly.
That file expires 2026-05-31 21:00 UTC; active RN App.tsx instead uses a license
expiring 2026-10-31 22:00 UTC. Subsequent Android and iPhone smoke tests fail license
validation before inference. Added SV loading check has therefore not run to
completion. Keep the requested file copy until this discrepancy is resolved.

User reported FlutterDartVMServicePublisher permission denial and signal 9.
Built debug Runner.app Info.plist already contains _dartVmService._tcp and Flutter's
Local Network usage description. Device Local Network permission needs enabling;
adding duplicate source plist keys is not justified. Signal 9 cause is unproven.
Stopped the old automated flutter drive runner (PID 99978), which had kept retrying
wireless launches and could interfere with manual Xcode debugging. Confirmed exited.
Do not launch another competing device runner while the user debugs manually.
Physical wakeword, SV enrollment, music/Bluetooth routing and all-mode audio remain
unverified. No native inference sources changed and no packages published.

## 2026-09-30 — API 23 feasibility correction

Inspected `.note.android.ident` in the actual ARM64 shared objects. This corrects
the earlier manifest-only assessment: current wakeword and SpeakerID packages
bundle ONNX Runtime built for API 27 and ARM Compute/Graph built for API 29, even
where the AAR manifest declares API 23 or 26. Older SpeakerID Genie,
PlatformValidator and calculator binaries identify API 21. TTS and TTS2 JNI
binaries identify API 26. These packages must not be relabeled API 23 without
rebuilding or replacing every higher-floor native dependency.

Source-level feasibility: wakeword and standalone SpeakerID can target API 23
after native dependency work; basic STT can target it after its API-aware route
is used; TTS and TTS2 appear portable after API-23 JNI/inference rebuilds. The
current Android SpeechRecognizer design cannot provide custom PCM injection/AEC
or the pre-recognition inline SpeakerID gate below API 33. An owned PCM-capable
ASR engine or changed post-capture verification flow is required for those
features. Updated `android_version_issues.md`; no runtime code or binaries changed.

## 2026-09-15 — continued with startup narration and SV handoff

Compared RN `App.tsx` startup bootstrap, `speakStartupNarration`,
`handleSkipNarration`, selected-voice reload and enrollment restart. This exposed
an app sequencing gap, not an additional missing native API: existing init,
changeVoice, pause, stopSpeaking, destroy and detector restart calls suffice.

Implemented preparation screen and bootstrap before the voice picker; RN-based
intro/confirmation/final wakeword prompts; persistent Skip Narration; strict pause
and resume errors; Android stopMic=true parity. Added a small narration controller
that waits for native stop completion and does not call stop during model loading.
Existing speech facade resolves its speak waiter before stop finishes, so this
ordering is necessary. SV skip keeps the model; active enrollment reloads speech
and restarts the same detector. Retry cancels the prior subscription and cleans
up the prior detector; late callbacks check mounted. Existing user model/voice
changes remain preserved.

Tests: three narration tests cover skip during loading, stop-completion race,
disposal and synthesis failure. The widget test exercises pending initialization,
skip, Hanna-to-Rich selection, SV skip and final wakeword resume; asserts exactly
one model init and one detector creation. All four example tests pass. Analyze
reports no issues. Android debug APK rebuild passed (39.6 s); iOS simulator
rebuild passed (42.3 s). No physical-device installation or runtime test occurred. Native inference
source and package bridges were unchanged in this continuation.


## 2026-09-15 — app-first implementation (user-directed order)

User requested starting from the example and working backwards through missing
APIs into RN wrappers and Flutter packages. Reordered the plan accordingly and
added `API_PARITY.md`. No native inference source or binaries changed this pass.
Preserved existing sibling wrapper edits and binaries.

Implemented:
- Example selects shared ex2, named voices, RN speeds, and hides legacy quality
  controls. Voice selection awaits initialization and errors on -1. The app's
  speech helper re-applies voice only when necessary.
- Example supplies current RN routing JSON before wakeword/speech initialization.
- Added speech `changeVoice` and `setAudioRoutingConfig` across Dart/platform/channel
  and Swift/Kotlin. Android speech routing is deliberately a no-op, matching RN;
  Android wakeword now parses JSON and refreshes existing detectors instead of
  returning notImplemented. Extended typed routing and native wire-contract tests.
- Local pubspec overrides resolve sibling wrappers; lockfile updated by pub get.
- Fixed first-wakeword mode-picker Type to TTS path incorrectly entering combined.

Evidence: RN `App.tsx`, `src/tts/index.ts`, `src/wakeword/index.ts`,
TTSNPM `speech/index.ts`, `ios/SpeechBridge/SpeechBridge.m`, Android TTS bridge,
WakeWordRNNPM Android `KeyWordRNBridge.java`, and packaged Swift interfaces.
RN and Flutter both invert speed at the public speech layer; preserved this.

## 2026-10-01 — public Flutter package releases

Published the aligned wrappers to pub.dev:

- `flutter_davoice 0.0.6`, source commit
  `b6a6f36f0bbbf8ee5b77f7a1a386b8f8f6566d70`
- `flutter_wake_word 0.0.45`, source commit
  `59181aed96c0771be17b4a6e486d770786085d1c`

Both commits are on their private GitHub `main` branches; the pub.dev package
archives themselves are public. Before upload, speech
passed analysis and 16 tests; wakeword passed analysis and 5 tests. Both publish
dry-runs completed with zero warnings. Pub.dev accepted each upload and its API
reported these versions as latest. The example now resolves 0.0.6/0.0.45 as
hosted pub.dev dependencies with no local path overrides. Analyzer and all eight
example tests passed against the downloaded packages. The user explicitly
confirmed that `example/licensekey.txt` is a temporary demo license intended for
the public repository. Keep it committed, while avoiding unnecessary copies of
its value in notes, logs, or responses.

Validation: initial Android debug APK and iOS simulator app builds passed with
local wrappers. Speech package: 12 tests passed; wakeword package: 4 tests passed;
example chooser test passed. Final checks after the mode-branch fix are recorded
below. Final checks also passed: analyze (no issues), example test, Android debug
APK rebuild (24.2 s), iOS simulator rebuild (29.5 s), and diff whitespace checks
across all three repositories. iOS plugin symlinks and Dart package roots point
to the intended sibling repositories. `pubspec_overrides.yaml` is ignored by the
existing repository rules and is local-only.
No app launched or installed on a physical device; inference, music routing
and barge-in remain unverified. Startup narration/skip and full flow parity remain
open; do not interpret this pass as complete RN parity.


## 2026-09-15 — initial alignment investigation

Created persistent context, plan and `AGENTS.md` at the user's request. Read RN
context/memory and migration notes, native wakeword context/memory, TTS package
notes and recent native ex2 documentation; checked live app and bridge code.

### Existing work preserved

Before this session, `lib/main.dart` was modified (169 insertions / 32 deletions)
and four legacy phoneme `.dm` assets were untracked. The app already includes
Hanna and four modes. No existing app code or wrapper/native code was changed.
Copied `assets/models/model_ex2_rich_hanna_ariana.dm` from the canonical RN example
and verified identical SHA-256. It is bundled by the existing assets directory
declaration but is not yet the selected runtime model.

### Findings that supersede older notes

- Actual RN manifest/installed versions: davoice 1.0.71, wakeword 1.1.145.
  TTSNPM has the alternate package name davoice-tts, version 1.0.378.
- Flutter resolves hosted 0.0.5/0.0.44 plugins, not sibling working trees.
- Sibling Flutter primary native binaries match RN wrappers; bridge/schema
  updates and dependency wiring remain necessary.
- `changeVoice` is absent in the Flutter Dart API and plugin handlers, while
  RN/native supports it on iOS and Android. Current RN uses the shared ex2 model.
- Current RN startup narration does pause wakeword. July's blanket continuous
  detection experiment does not describe current code.
- Historical notes' artifact hashes differ from today's files. Hash equality
  between wrappers does not establish which source fixes a binary contains.

### SHA-256 baseline: equal in Flutter and corresponding RN sibling wrappers

| Artifact | SHA-256 |
|---|---|
| Wakeword iOS device executable | `0c031deac9e1ccbe7f90a9c03411c35dea8a7f0e8ba61d8e4efe5b12f7001028` |
| Wakeword iOS simulator executable | `2faaa7daf01b349d070dc5d98dac7e875412b1668afb5bdb800d6ef53cd3dc48` |
| Wakeword Maven AAR | `1c4029d5e9cac0fb74f3c0b32b106d460dfa8f9aa1cfd372adc9ba279bacb8b8` |
| TTS iOS device executable | `9637d3a28dd4aad1a5748cccfcc014a16b081fa3db87641d93cb9d6a029262dc` |
| TTS iOS simulator executable | `b53294d465ec2aba3238c4241070d3d50d7577064adce71f88d28b2478f93a48` |
| TTS Maven AAR | `50b73734176e70dbdeac3f154c34e0c98d4053437c48c29ad93b70a5bdbc3860` |

Maven paths are `android/libs/com/davoice/{keyworddetection,tts}/1.0.0/`.
Frameworks are `ios/KeyWordDetection.xcframework` in the Flutter wakeword wrapper,
`ios/KeyWordRNBridge/KeyWordDetection.xcframework` in RN; `ios/Frameworks/` in
Flutter TTS and `ios/TTSRNBridge/` in RN TTS. This comparison covers framework
executables, not a full resource/header audit. RN `android/src/main/libs/` AARs
differ from the Maven copies and must not be substituted without resolution checks.

### Validation and next step

Performed read-only source/manifest/resolved-path inspection, SHA-256 comparisons,
and model-copy verification. No Flutter build, inference, device run, or functional
parity claim. Next: local dependency overrides and full bridge/packaging inventory,
then implement named voice switching and select ex2. Keep native-source changes
outside routine alignment; record concrete blockers if one is discovered.

## 2026-10-05 — latest RN parity recheck

Fetched current remote refs without modifying the RN working trees. The RN app
remote remains `9dc9dc6`; TTSNPM is `15610ca` with live version 1.0.401 and
WakeWordRNNPM is `efb04e9` with live version 1.1.160. The dirty RN example
working tree declares react-native-davoice 1.0.103 and react-native-wakeword
1.1.156. Its October 4 uncommitted App.tsx work adds Local AI Chat through the
separate TTSLLM package.

RN speech's newly committed declarations and bounded transition behavior were
already in Flutter 0.0.6. RN wakeword added app-wide `AEC.mode`; added Flutter
`AECMode`/`AECConfig` serialization and coverage. Changed the example's legacy
WakewordAEC during-TTS value from true to false to match live RN false/false.

Live artifact SHA-256 values, identical between corresponding RN and Flutter
wrappers: TTS AAR `70bdedbefb1a71c491a565f98d9a90d030c99a90ed4e642884317fce493a4c82`,
TTS iOS device executable `ccac2a2e615a66d62e404741be15cf4aa1e2b363aec6287bb90d4e0033f832c0`,
wake AAR `86a023a1650c063ef2a2ce92918aaf01414a9ecd94118ae829e99e0a0bc5daf5`,
and wake iOS device executable `39339990666efb1aec8122cdd6dd8e5672f81de10f23fb7438d19273823c1048`.
The TTS Flutter checksum sidecars described the old AAR; copied the matching RN
sidecars and confirmed both Maven directories and both full XCFramework trees
are identical.

Both refreshed AAR manifests declare minSdk 23. ARM64 ELF Android ident values:
TTS/TTS2 JNI 23; wake ARM Compute/Graph and ONNX 23; libc++ 21. Validation:
wake analysis plus 5 tests, speech analysis plus 16 tests, example analysis plus
8 tests, Android debug APK with local wrappers, and iOS simulator app with local
wrappers all passed. Restored the public example to hosted 0.0.6/0.0.45 after
the build. No physical-device runtime test was performed.

Published the rechecked artifacts as `flutter_davoice 0.0.7` from commit
`5ad9c07` and `flutter_wake_word 0.0.46` from commit `863068b`, with matching
annotated tags. Both publish dry-runs had zero warnings and both pub.dev uploads
succeeded. The public example now targets these hosted versions.

## 2026-10-06 — Android pause bridge and TTS2 regex startup fixes

Reproduced the photographed `MissingPluginException` on the connected Samsung
SM-G781B. Dart called wakeword `pauseDetection`, while Android in published
0.0.46 explicitly returned `notImplemented`. Added Android forwarding for
`pauseDetection(stopMic)` and `unPauseDetection()`, validated it on-device, and
published/pushed `flutter_wake_word 0.0.47` (commit `4e544f1`).

That exposed the next native failure. TTS2 model/session loading succeeded, but
warm-up constructed `TTSPreprocessingEnglish`, whose `(?U)` regex flag is not
accepted by Android's ICU-backed `Pattern`. Replaced English uses with explicit
Unicode boundaries and made Portuguese use `(?U)` only on engines that accept
it. Preserved the original TTS2 initialization exception for diagnostics.
All 80 native tests, Android lint, and release AAR assembly passed. Rebuilt the
AAR, regenerated MD5/SHA1 sidecars, then pushed and published
`flutter_davoice 0.0.8` (commit `5466018`). The Samsung reached startup
narration without either exception. Example dependencies are now 0.0.8/0.0.47
with no path override. Added `android:largeHeap="true"` to match RN because the
loaded TTS2 process is memory-heavy; testing proved it was not the regex fix.

## 2026-10-07 — wake-word device root cause and repair

The Samsung reached the final wake screen with Flutter 0.0.47 but did not
detect speech. The native detector and license initialized, the model bytes
matched RN, and Android showed an active unsilenced wake AudioRecord. Stopping
the paused STT recorder did not repair detection and was reverted.

The app lifecycle was then matched to committed RN exactly: the start helper
stops before starting; wake is paused before `Speech.initAll`; speech is paused;
the same wake instance is resumed immediately afterward and remains active
through narration. Widget coverage now verifies speech pause precedes wake
resume. This removed Flutter's extra narration pauses and final stop/restart.

A controlled acoustic comparison found the decisive binary difference. The
installed RN APK detected the same phrase with three scores above 0.999. Its
ONNX Runtime, JNI, ARM Compute and Graph hashes match
`WakeWordRNNPM/android/src/main/libs/MyLibrary-release.aar`, not the newer
Maven AAR copied into Flutter during the API-23 work. Flutter's rebuild logged
that XNNPACK was unsupported and produced no prediction logs. Replacing the
Flutter AAR with the proven RN AAR restored detection; the user spoke “Hey
Coach” and confirmed it worked.

Released and pushed `flutter_wake_word 0.0.48` from commit `44f738a`, tag
`v0.0.48`. Analysis, five wrapper tests, publish dry-run and pub.dev upload
passed. This hotfix restores current-device behavior and invalidates the prior
claim that the API-23 ONNX rebuild preserved API 29+ behavior. A separate or
corrected API-23 wake runtime still needs physical inference validation.
