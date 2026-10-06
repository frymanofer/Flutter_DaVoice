# Restart handoff

Updated: 2026-10-06. This is the shortest authoritative starting point after an
editor/session restart. Read the linked detailed files before changing behavior.

2026-10-06 committed-only RN audit: fetched the RN remote and compared Flutter
against an exported `origin/main` snapshot at `9dc9dc6`, which is identical to
the RN checkout's `HEAD`. All dirty RN working-tree files, including Local LLM,
were excluded. The pushed app still has four modes and package declarations
`react-native-davoice 1.0.102` / `react-native-wakeword 1.1.154`. Flutter's
models, assets, voices/speeds, routing/AEC, Gemini policy, SV settings, narration,
and four mode flows match. Corrected two older state/lifecycle differences:
Flutter now initializes the selected mode as Combined and every wakeword pause
uses `stopMic=false`, matching each active RN pause call. No Flutter wrapper or
native binary change was required.

2026-10-05 RN recheck: Flutter now includes the RN wrapper's typed app-wide
`AEC.mode` contract and the example matches RN's active legacy AEC false/false
policy. The live Flutter native artifacts exactly match the current RN wrapper
artifacts; stale TTS AAR checksum sidecars were corrected. Both AAR manifests
and required ARM64 objects remain API 23-compatible. Wrapper tests, example
tests, Android debug build, and iOS simulator build pass. The dirty RN working
tree's fifth Local AI Chat mode still belongs to a separate TTSLLM migration.

2026-10-01 follow-up: the full TTS build found API-24 collection/Optional calls.
They were replaced with API-23-safe equivalents without desugaring or lint
suppression. Native `./build.sh` now passes, and the rebuilt Flutter speech AAR
SHA-256 is
`dc5a7d557aa18536c82f5e2c89de9739a04ab4c2779c2f03b789c9dd132c072f`.

## Active objective

Keep the Flutter example and its two sibling Flutter packages aligned with the
current React Native example and wrappers. The active work implements Android
API 23 support while preserving the API 33+ STT path and the existing accelerated
wakeword architecture.

## API 23 implementation

- The example and `FlutterPubDavoicePrivate` now declare API 23. The current
  Flutter tool tries to migrate literal API 23 values to its API 24 default, so
  the example uses a named `davoiceMinSdk = 23` value.
- TTS `libtts-jni.so` and TTS2 `libttsv2-jni.so` were rebuilt for ARM64 API
  23; their containing AAR also declares API 23.
- Wakeword/SpeakerID ARM Compute was rebuilt from the exact prior source commit
  and acceleration configuration for ARM64 API 23.
- The first ONNX rebuild used upstream 1.24.1. The original binary revealed its
  exact build commit, `1442fe00d9169e89ec4a52bd699952810244ba6b`, reporting
  1.24.0. The final API-23 build now uses that exact commit, still directly
  links ARM Compute/Graph, and preserves the prior engine version and ACL
  architecture on API 29+.
- Basic STT uses ordinary recognizer-owned microphone input on API 23–32.
  `startSpeech()` now goes through the version-aware dispatcher, and the
  custom-audio boundary independently enforces the same policy.
- Custom PCM injection/AEC and the current inline pre-recognition STT SpeakerID
  gate remain API 33+.
- The complete supported ABI is `arm64-v8a`. Required TTS static libraries do
  not exist for `armeabi-v7a`, x86 or `x86_64`; do not advertise them.
- The wake AAR retains its existing x86 development slice at API 27, outside the
  full product/API-23 support contract.

Full reasoning and the per-subsystem matrix are in
`android_version_issues.md`, especially “API 23 feasibility by subsystem.”

## Current version declarations and validation

- Example app: `minSdk = 23`.
- `FlutterPubDavoicePrivate`: `minSdk = 23`, `compileSdk = 36`.
- `flutter_wake_word_lib`: wrapper `minSdk = 21`; embedded AAR manifest API 23.
- Combined TTS/STT/TTS2 AAR manifest and ARM64 JNI: API 23.
- `compileSdk`, `targetSdk`, Java 17 and NDK versions are build/policy concerns;
  they do not themselves establish the oldest supported phone.
- TTS native unit tests/release assembly, wakeword release assembly, speech
  Flutter analysis/tests, wakeword Flutter tests, and example analysis/tests
  pass.
- Current Flutter `integration_test` declares API 24. The debug manifest
  overrides that test-only library so the app can build with API 23; production
  code does not depend on it.
- Final ARM64 debug and split release APK builds pass. The release APK declares
  minSdk 23, compile/target SDK 36, contains only ARM64 native libraries, and
  preserves ONNX 1.24.0 plus ACL linkage. All relevant native files have API-23
  or lower notes and 16 KB load alignment.
- Physical API 23/API 33 device behavior remains untested. Do not publish
  packages without an explicit publishing request.

## Existing alignment state to preserve

- Rich is default and uses `model_ex2_rich.dm`; Hanna and Ariana use their legacy
  `model_ex_*` files and do not call named `changeVoice`.
- The working RN App.tsx license was restored to the Flutter example. Never copy
  its value into context, logs or responses.
- UI, startup narration, wakeword text, model choices, bridges and wrapper parity
  are described in `CHATGPT_CONTEXT.md` and `MEMORY.md`.
- Recheck each repository's live status before editing. Do not reset, clean,
  mass-copy binaries, or overwrite files based only on filenames.
- The API-23 pass changes runtime routing, manifests, native sources and local
  package AARs. It has not published any package.

## Validation boundary

Earlier alignment passes passed Flutter tests, analysis, Android debug builds and
iOS simulator builds as recorded in `MEMORY.md`. This API-23 pass has built an
API-23 ARM64 debug APK, but no API-23 physical-device runtime test has occurred.
