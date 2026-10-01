Here is what I got from Claude on the issue I encountered, I didn't dig too much into the library or use cases so I can't validate it for current POC, but the fix it made worked for now. Also it seems to be the same with sample app when I run on Android.

## Implementation update — 2026-09-30

The migration described in the audit below has now been implemented:

- the example and `flutter_davoice` use `minSdk = 23`;
- API 23–32 always uses ordinary `SpeechRecognizer` microphone input;
- API 33+ keeps custom PCM/AEC and inline STT SpeakerID;
- TTS, TTS2, ONNX Runtime, and ARM Compute ARM64 binaries were rebuilt for API
  23 and repackaged;
- the supported full-product ABI is `arm64-v8a`.

The older audit text remains below as the evidence and pre-change diagnosis.
Its statements about the “current” API 26/27/29 binaries describe the replaced
artifacts. The current contract is in
[ANDROID_COMPATIBILITY.md](ANDROID_COMPATIBILITY.md).

Versions
- flutter_davoice 0.0.5 (pub.dev), bundled com.davoice:tts:1.0.0 (tts-1.0.0.aar)
- flutter_wake_word 0.0.44
- Device: Xiaomi MI 8 Lite, Android 10 (API 29), MIUI; Google speech services as the recognizer

Summary
On Android 12 and below, FlutterDavoice.start() / startWithSVOnboardingJson() return successfully, but the recognizer never produces any results: no onSpeechStart, onSpeechPartialResults or onSpeechResults, and no errors. On the same device with a one-byte change to STT's constructor (see below), recognition works immediately.

Steps to reproduce
1. Set a valid license (setLicense), then call FlutterDavoice.start('en-US') with no enrollment, on an API 29–32 device.
2. Speak.
3. No speech events arrive. Logcat shows:
I/STT: [SV] startSpeech: onboarding=OFF api=29
I/STT: startListening(): api=29 speakerGateEnabled=false useCustomAlways=true
(nothing further until destroySpeech)

Root cause (from com.davoice.stt.STT in tts-1.0.0.aar)
- The STT constructor hardcodes the field useCustomAlways = true (bytecode aload_0; iconst_1; putfield #129). No API changes it.
- startListening() selects the route like this:
if (!useCustomAlways && SDK_INT < 33)            startListeningNoAEC(...)
else if (!useCustomAlways && !speakerGateEnabled) startListeningNoAEC(...)
else                                              // CustomAudioSource route
- With useCustomAlways == true, the custom route is always taken. CustomAudioSource.attachToIntent feeds audio to the recognizer via RecognizerIntent.EXTRA_AUDIO_SOURCE (a ParcelFileDescriptor pipe), plus EXTRA_AUDIO_SOURCE_ENCODING, _SAMPLING_RATE and _CHANNEL_COUNT. These extras were added in API 33. Below that, SpeechRecognizer ignores them and never reads the pipe, so it hears nothing.
- initSpeakerGateFromOnboarding already guards the speaker gate with SDK_INT < 33 → setSpeakerGateDisabled(). useCustomAlways has no equivalent guard.

Verification (A/B, same app build, only the AAR differs)

┌─────────────────────────────────────┬─────────────────────────────────────────────────────┬────────────────────────────────────────┐
│                 AAR                 │                         Log                         │                 Result                 │
├─────────────────────────────────────┼─────────────────────────────────────────────────────┼────────────────────────────────────────┤
│ Stock 1.0.0                         │ startListening(): api=29 … useCustomAlways=true     │ Zero speech results across two         │
│                                     │                                                     │ sessions                               │
├─────────────────────────────────────┼─────────────────────────────────────────────────────┼────────────────────────────────────────┤
│ Constant flipped to false           │ useCustomAlways=false, startListeningNoAEC():       │ Partial results from the first word    │
│ (iconst_0)                          │ api=29                                              │                                        │
└─────────────────────────────────────┴─────────────────────────────────────────────────────┴────────────────────────────────────────┘

Suggested fix
Don't take the custom route where it can't work:
useCustomAlways = Build.VERSION.SDK_INT >= 33
Alternatively, make it a constructor parameter or plugin option. A setter exposed through flutter_davoice would also work, since apps may want route 2 even on API 33+.

Current workaround
We ship a bytecode-patched tts-1.0.0.aar (constructor constant true → false). On API 33+ this keeps the custom route when Voice ID (the speaker gate) is on, but without Voice ID it loses your echo cancellation. That's why a version-aware default upstream would be better than our patch.

Related (lower priority)
1. EXTRA_PREFER_OFFLINE is also hardcoded true in STT. On devices without an offline language pack, this can plausibly fail with SpeechRecognizer error 13 instead of falling back to online recognition. We haven't isolated this one.
2. Speaker verification below Android 13: because of the above, the Voice ID gate is unavailable before API 33. An Android implementation of verifySpeakerWavStreaming, which iOS already has, would let apps verify a recorded utterance themselves on any API level.
3. iOS: flutter_davoice.podspec links Libraries/lib{ucd,phonemes}.a, which are device-only (arm64, platform IOS). So Simulator builds fail to link, even though the package already ships Frameworks/lib{ucd,phonemes}.xcframework with Simulator slices.

Hope that is helpful to some extent? If I can help to debug it further let me know.

---

## Local repository audit — 2026-09-30

### Three Android version numbers that must be kept separate

1. `compileSdk` selects which Android APIs can be referenced while compiling. It
   does not prevent installation on an older phone. The Flutter speech plugin's
   `compileSdk = 36` is therefore a build-tool requirement, not an Android 16
   device requirement.
2. `targetSdk` opts the application into newer Android behavior and Play policy.
   It does not set the oldest supported device.
3. `minSdk` is the installation floor. The highest `minSdk` from the app and all
   merged libraries wins.

There is also a fourth concept: a feature can be restricted at runtime even when
the package installs. STT's Android-13 custom audio injection is such a feature.

### What currently raises the Flutter example

| Layer | Declared/effective minimum | Finding |
|---|---:|---|
| Flutter example app | API 29 | Hardcoded in `example/android/app/build.gradle.kts`. |
| `flutter_davoice` plugin | API 29 | Hardcoded in `FlutterPubDavoicePrivate/android/build.gradle.kts`; this alone forces every consuming Flutter app to API 29. |
| Packaged TTS/STT/TTS2 AAR | API 26 | The AAR manifest declares 26, and both locally built JNI engines (`libtts-jni.so` and `libttsv2-jni.so`) identify API 26 as their native build floor. |
| `flutter_wake_word` plugin | API 21 | The bundled wakeword AAR raises its effective floor to API 23. |
| Packaged wakeword/Speaker Verification AAR | Manifest API 23; bundled ARM64 inference binaries up to API 29 | ONNX Runtime identifies API 27, while `libarm_compute.so` and `libarm_compute_graph.so` identify API 29. The manifest understates the current native payload's supported floor. |

The example's API-29 setting is higher than the TTS package needs, but it happens
to match the highest native build floor found in the current wakeword package.
The combined TTS/STT/TTS2 artifact currently has a native API-26 floor. Full
STT-integrated speaker gating remains an API-33 feature for a separate reason
explained below.

### Wakeword

- Repository: `AndroidLibraryCode`.
- Gradle and the packaged AAR declare API 23.
- The detector owns its microphone with `AudioRecord`; it does not depend on
  Android 13's `RecognizerIntent.EXTRA_AUDIO_SOURCE` pipe.
- Newer foreground-service and audio-routing behavior is guarded with
  `SDK_INT` checks. Those paths do not raise `minSdk`.
- The bundled AAR includes only selected CPU ABIs. ABI availability is a device
  compatibility issue, but it is independent of the Android API level.
- The native payload does not match the API-23 manifest: its ONNX Runtime files
  were built for API 27 and its ARM Compute files were built for API 29.

Conclusion: the Java/Kotlin wakeword design can target API 23, but the current
ARM64 artifact cannot honestly be supported there. It must receive API-23 builds
of every required native inference library, or an API-23 variant must omit the
higher-floor acceleration libraries. Merely lowering manifests is unsafe.

### SpeakerID / Speaker Verification in the wakeword repository

- Current `AndroidLibraryCode` contains `SpeakerVerification.java` inside the
  same API-23 wakeword AAR. ONNX inference and PCM feature extraction do not use
  an Android-13-only API.
- Its microphone controller uses the wakeword library's own `AudioRecord`, so
  enrollment and verification are not inherently tied to API 33.
- The older `AndroidLibraryCodeWithSpeakerID` and
  `AndroidLibraryCodeKWWithSpeakerID` projects build AARs with API 26. Their
  source manifests still say API 29, but the generated AAR manifests say API 26;
  this inconsistency should be cleaned up.
- `SpeakerIdStorage.exportToDownloads()` uses MediaStore on API 29+ and has a
  legacy external-storage branch below 29. That guarded convenience export does
  not require the entire SpeakerID engine to have `minSdk 29`.

The older standalone native payloads show the same mixed floors: Genie,
PlatformValidator and calculator identify API 21; ONNX Runtime identifies API
27; ARM Compute identifies API 29. Therefore their API-26 AAR declarations also
understate part of their native payload.

Conclusion: the SpeakerID algorithm and microphone flow can target API 23, but
none of the current ARM64 packages containing the API-27/API-29 inference files
can do so as shipped. Neither requires API 33 for inference. A CPU-only API-23
ONNX build is the simplest compatibility route; retaining the current hardware
acceleration requires rebuilding or replacing its native dependencies.

### STT

- Repository: `DavoiceTTSAndroidPrivate`, packaged together with TTS.
- Basic Android `SpeechRecognizer` operation can use the normal recognizer-owned
  microphone below API 33.
- Custom PCM injection uses `RecognizerIntent.EXTRA_AUDIO_SOURCE` and related
  encoding/sample-rate/channel extras. `CustomAudioSource` is correctly marked
  `@RequiresApi(33)`. This path is needed for the current AEC and inline
  STT-speaker-gate design.
- The current source and AAR contain `startListeningForMode()`, which chooses the
  ordinary recognizer below API 33. However, the public `startSpeech()` path
  still calls private `startListening()` directly instead of this helper.
- `useCustomAlways` is still initialized to `true`. Private `startListening()`
  only falls back below API 33 when `useCustomAlways` is false. This reproduces
  the customer's diagnosis: API 29–32 enters a path designed for API 33 and gets
  no microphone data.
- The robust fix is to make the API guard unconditional at the custom-path
  boundary and route `startSpeech()` through `startListeningForMode()`. A
  version-aware `useCustomAlways = SDK_INT >= 33` default is also appropriate,
  but the boundary should still protect callers independently of that flag.
- `EXTRA_PREFER_OFFLINE = true` does not raise `minSdk`; it can cause a separate
  recognizer-availability failure when the language pack is absent. It should be
  configurable or have an online fallback.

Expected behavior after the routing fix:

| Android API | Basic STT | Custom PCM/AEC | Inline STT SpeakerID gate |
|---:|---|---|---|
| 26–32 | Supported through ordinary `SpeechRecognizer` input | Unavailable | Unavailable in the current inline design |
| 33+ | Supported | Supported | Supported |

### SpeakerID / Speaker Verification in the STT repository

- `SpeakerVerificationSTT.java` performs ONNX/PCM inference and does not itself
  require API 33.
- `STT.initSpeakerGateFromOnboarding()` deliberately disables the gate below API
  33 because the current gate consumes PCM from `CustomAudioSource` before audio
  reaches `SpeechRecognizer`.
- This is an integration limitation rather than a model/inference limitation.
  A standalone `verifySpeakerWav`/streaming PCM API could run the same verifier
  on older versions, but it would not provide the current pre-recognizer gate
  unless the app/library owns capture and recognition differently.

Conclusion: the STT-integrated live gate needs API 33 today; the underlying
SpeakerID inference does not.

### Legacy TTS

- Repository: `DavoiceTTSAndroidPrivate`; packaged in the same AAR as STT/TTS2.
- The generated AAR declares API 26. Playback uses `MediaPlayer`, `AudioTrack`,
  and `AudioFocusRequest`. Calls introduced in API 29, 31, and 32 are guarded.
- Java 17, Kotlin, AGP, NDK, and `compileSdk` settings affect the customer's build
  environment. They do not by themselves set the phone's minimum Android API.

Conclusion: the current legacy-TTS floor is API 26 in both its AAR declaration
and JNI build metadata. Its source appears portable to API 23, but it requires a
native rebuild with API 23 as the platform plus device validation. No inspected
TTS logic explains API 29 or 33 as an installation requirement.

### New TTS2

- TTS2 lives under `com.davoice.tts.ttsv2` in the same API-26 AAR.
- Its own logic is file/archive parsing, SentencePiece tokenization, ONNX Runtime
  inference, JNI, streaming buffers, and resampling. It contains no Android
  framework API-level branches.
- Playback is shared with `DaVoiceTTS`, whose newer calls are version guarded.
- TTS2 therefore inherits API 26 from the containing AAR, and its JNI binary was
  also built for API 26. It does not introduce an API-29 or API-33 framework
  requirement, but it needs an API-23 JNI rebuild to support API 23.

### Recommended compatibility contract

1. Do not advertise API 23 for the current binaries. Their embedded build floors
   are API 26 for TTS/TTS2, API 27 for ONNX Runtime, and API 29 for ARM Compute.
2. Produce an API-23 native dependency set before lowering the Flutter wrappers
   and example. Validate the final packaged AAR rather than only source builds.
3. Fix STT routing so every API below 33 unconditionally uses
   `startListeningNoAEC()`; add API 29/30/31/32 regression coverage.
4. Document custom-audio AEC and inline STT SpeakerID as API 33+ features rather
   than raising the whole package minimum.
5. Make offline-only recognition a caller option or retry without it after the
   relevant recognizer error.
6. Align source manifests, Gradle `minSdk`, generated AAR manifests, and wrapper
   declarations so the advertised floor is unambiguous.

### API 23 feasibility by subsystem

| Subsystem | Can support API 23? | What must change / what cannot be preserved |
|---|---|---|
| Wakeword | Yes, after native dependency work | Rebuild/replace ONNX Runtime (currently API 27) and ARM Compute/Graph (currently API 29) for API 23, or make an API-23 CPU-only package. Verify `AudioRecord`, AEC, foreground service behavior and real devices. The current AAR cannot be relabeled as API 23. |
| SpeakerID in the wakeword repo | Yes, after the same native work | The verifier and owned-microphone flow do not need API 33. It inherits the wakeword AAR's higher-floor inference binaries. Splitting it into a lean CPU-only API-23 artifact would reduce the dependency problem. |
| Older standalone SpeakerID repos | Conditionally | Java/storage logic can be adapted to API 23, and the proprietary Genie/calculator files identify API 21. Their ONNX files identify API 27 and ARM Compute files API 29. API 23 depends on having rebuildable/replacement versions of those files; if a required proprietary prebuilt has no API-23 build or source, that accelerated configuration cannot support API 23. |
| Basic STT | Yes | Route API 23–32 unconditionally through normal `SpeechRecognizer` microphone capture. Fix `startSpeech()` to use the API-aware helper and make the custom-path guard authoritative. Package it with API-23-compatible native dependencies, or split STT from the combined TTS AAR. Expect recognizer/service differences across old OEM devices. |
| Custom PCM STT/AEC | No, with the current Android `SpeechRecognizer` architecture | `RecognizerIntent.EXTRA_AUDIO_SOURCE` and its format extras arrive at API 33. API 23 cannot feed the library's processed PCM into the platform recognizer through that route. Preserving this feature requires a different recognizer that accepts PCM, such as an owned on-device or remote ASR engine. |
| Inline STT SpeakerID gate | No, with the current pre-recognition design | The gate consumes the same custom PCM stream before it reaches `SpeechRecognizer`, so the existing behavior requires API 33. API 23 could verify a separately recorded utterance after capture, but that changes timing and semantics; an owned PCM-capable ASR engine could restore an inline gate. |
| Legacy TTS | Yes, likely | Rebuild `libtts-jni.so` for API 23 (current build floor 26), use API-23-compatible inference dependencies, keep the existing guarded fallbacks for newer audio APIs, and validate playback/focus on API-23 devices. |
| TTS2 | Yes, likely | Rebuild `libttsv2-jni.so` and SentencePiece/native dependencies for API 23 (current floor 26), pair them with API-23 ONNX Runtime, and test memory, model extraction, synthesis and playback on old devices. |

The full product can install and provide wakeword, standalone SpeakerID, basic
STT, TTS and TTS2 on API 23 only after the native packages are rebuilt and the
wrappers are lowered. Exact feature parity is not possible on API 23 while STT
depends on Android's platform `SpeechRecognizer`: custom PCM/AEC and the current
inline STT SpeakerID gate must be disabled there or redesigned.

The current Android artifacts also provide ARM64 and x86 selectively, with no
complete `armeabi-v7a`/`x86_64` set. This does not change `minSdk`, but it matters
for API-23-era hardware: many such devices are 32-bit ARM. An API-23 claim needs
an explicit ABI support contract and physical tests for every shipped ABI.
