# Flutter / React Native alignment plan

Created: 2026-09-15. Status: first app-driven alignment pass implemented and compiled.

## 1. Baseline and persistence

- [x] Inspect reference memories, live app configuration and wrapper APIs.
- [x] Preserve existing Flutter voice/mode edits and legacy model assets.
- [x] Create context, memory and ongoing maintenance instructions.
- [x] Copy shared ex2 model and verify source/destination SHA-256.
- [x] Compare sibling wrapper primary framework binaries and Maven AARs.

## Working order (user direction, 2026-09-15)

Start at the example, compare its behavior with the RN app, write the required
Flutter calls, identify missing APIs, trace each through the RN wrapper, then
implement that API in the Flutter package and validate the integrated app.
Package audits support an identified app requirement; they are not the starting
point. See `API_PARITY.md` for the first app-driven comparison.

## 2. First app-driven implementation

- [x] Select shared ex2 for Hanna/Rich/Ariana and apply named voice after init and
  before speech; skip redundant switches. Treat -1 as a visible selection failure.
- [x] Match ex2 speeds (Rich 0.95, Hanna/Ariana 1.0), hide quality selection for
  ex2 as RN does, retain the explicit legacy model branch.
- [x] Put the complete current RN routing policy in the example.
- [x] Trace and implement missing `changeVoice` through Dart and both bridges.
- [x] Trace and implement direct speech `setAudioRoutingConfig`: iOS stores JSON,
  Android no-op matches RN. Implement Android wakeword config parsing/refresh.
- [x] Expand typed wakeword config for HD/fallback, playback/STT ducking, AEC and
  during-TTS sensitivity; add wire-contract regression tests.
- [x] Publish the aligned wrappers and make the public example resolve them from
  pub.dev without machine-specific sibling path overrides.
- [x] Fix type-to-TTS selection after the first wakeword entering combined mode.
- [ ] Validate real ex2 inference, named-voice audio, switching and failure handling
  on both physical platforms. Compilation and mocked channels do not prove these.

## 3. Continue from app behavior

- [x] Align startup order and spoken narration/skip controls with current RN.
  Bootstrap precedes narration/voice/SV; skip remembers loading-time intent and
  awaits native stop during speech. SV skip reuses engines, enrollment reloads
  speech and restarts the same detector with enrollment.
- [ ] Verify startup narration and enrolled-SV reload on physical devices.
- [ ] Compare repeat-turn and barge-in policy using explicit app states, not blanket
  pause removal. Test cancellation and late callbacks at every transition.
- [x] Align wakeword model packaging with RN `.dm` and iOS asset resolution.
- [ ] Finish method/event comparison for SV, STT and AI streaming modes.
- [ ] For each newly exposed gap, trace the RN bridge contract, implement the
  smallest Flutter equivalent, and validate that app flow before broadening scope.
- [ ] Audit remaining framework resources, podspec/POM/native dependencies and
  source-fix provenance only as needed for these requirements or build failures.

## 4. Audio routing and flow fixes

- [x] Extend typed routing/serialization with RN's current HD input, ordered
  fallback, playback/finish and delayed-unduck policy; `WakewordAEC` regular=false,
  duringTTS=true; `wakeWordDuringTTS` threshold=0.9, buffer_cnt=1.
- [x] Pass the same complete JSON to wakeword and speech before initialization;
  confirm both native bridges forward every supported field.
- [ ] Compare current startup/narration skip, stop promises, queued callbacks,
  playback tail, voice changes, wakeword resume, STT and mode transitions.
  Preserve purposeful startup pauses and allow barge-in where the current RN flow
  permits it. Prevent late callbacks from resurrecting stopped or disposed work.
- [x] Check bundled wakeword/SV asset mappings and thresholds against RN.
- [ ] Verify SV create/reuse/skip and speech reload. RN notes describe a stale
  enrollment race: avoid enabling SV merely because a saved path exists.
- [ ] Finish behavior comparison for all four modes, transcript timing, streaming
  AI responses and narration text policy. Existing UI presence is not proof of parity.

## 5. Validation and completion

- [x] Flutter analyze and relevant existing tests; focused new bridge/serialization
  and lifecycle regression tests where behavior changed.
- [x] Android debug build and iOS simulator compile with resolved wrappers.
- [ ] iOS device compile and physical runtime validation.
- [ ] Physical Android and iPhone: cold/warm startup, each voice/mode, enrollment
  skip/reuse, rapid switching, narration skip, stop/barge-in, repeated turns,
  background/foreground, Bluetooth connect/disconnect, speaker and headset routes.
- [ ] Play music concurrently: verify actual route and audible duck/recovery;
  test low and high TTS volume. Record capture recovery and completion after drain.
- [ ] Record binary identities, test results and unresolved native/device defects.
  Update context/memory after each milestone. No package publishing or native
  distribution scripts are needed to complete the local migration.

## Current device follow-up

- [x] Restore active RN App.tsx license and normal Xcode lib/main.dart target.
- [x] Read iPhone xcode.log: narration completion, STT and echo TTS observed.
- [x] Fix misleading active mode title and concurrent Continue entry path;
  add elapsed transition logs. All-four-mode widget test passes.
- [ ] Locate/reproduce user-reported long four-option wait; existing log does not
  identify the delayed Dart operation. Do not treat UI fixes as verified resolution.

- [x] Align prompt/mode/speech/TTS card hierarchy and remove duplicate text.
- [ ] Review updated UI visually on physical iPhone.

## Wrapper refresh (2026-09-28)

- [x] Add bounded pause/unpause and native readiness result parity.
- [x] Add iOS STT health snapshot and stale-instance callback protection.
- [x] Move Android TTS initialization off the method-channel thread and align
  process-global licensing plus standalone/full initialization cleanup.
- [x] Expose Android wakeword `setTTSActive` without duplicating native state in
  the example app.
- [x] Pass wrapper tests, example tests, Android debug build and iOS simulator build.
- [ ] Refresh native binaries separately and repeat physical-device validation.

## Wrapper refresh (2026-09-30)

- [x] Match RN iOS wakeword during-TTS begin/end behavior and expose its applied result.
- [x] Move standalone iOS TTS model resolution off the method-channel thread and
  use RN's bounded remote download timeouts.
- [x] Add routing reset and Flutter-adapted listener diagnostics from the latest
  RN speech facade.
- [x] Pass wrapper tests, example tests, Android debug build and iOS simulator build.
- [ ] Scope the new RN Local AI Chat/TTSLLM work as a separate Flutter package
  and example-app migration if that fifth mode is required.

## Current RN voice update

- [x] Rich default and dedicated ex2 model; Hanna/Ariana legacy ex models.
- [x] Match voice speeds and restrict named voice selection to ex2.
- [x] Verify all three model assets against RN; update app and smoke tests.
- [ ] Confirm audible output for the new model combination on device.

## Android API 23 compatibility track (implemented 2026-09-30)

- [x] Separate compileSdk, targetSdk, manifest minSdk, feature gates and native
  binary build floors.
- [x] Inspect current TTS/TTS2, ONNX Runtime, ARM Compute and older SpeakerID
  native build notes; record the corrected subsystem matrix.
- [x] Fix STT public dispatch and enforce ordinary SpeechRecognizer capture below
  API 33 regardless of `useCustomAlways`.
- [x] Define the compatibility contract: custom PCM/AEC and inline STT SpeakerID
  remain API 33+ unless STT is redesigned around a PCM-capable ASR engine.
- [x] Produce API-23 TTS/TTS2 JNI, ONNX Runtime and ARM Compute dependencies
  while retaining the existing ARM64 ACL acceleration architecture.
- [x] Keep API 23 SpeakerID in the main wakeword AAR on the rebuilt inference
  stack; older standalone experimental SpeakerID repositories are not released.
- [x] Define the supported full-product ABI as `arm64-v8a`; required TTS
  dependencies do not currently exist for `armeabi-v7a` or `x86_64`.
- [x] Audit packaged AARs and lower wrapper/example minSdk declarations.
- [x] Build the API-23 ARM64 example APK and run host/unit validation.
- [ ] Test the supported feature matrix on physical API 23/26/29/32/33/current
  devices before publishing.
