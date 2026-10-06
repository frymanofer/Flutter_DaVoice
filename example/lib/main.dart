import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'flow/startup_narration.dart';
import 'flow/transcript.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_davoice/flutter_davoice.dart';
import 'package:flutter_wake_word/flutter_wake_word.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const DavoiceExampleApp());
}

const _speakerId = 0;
const _usesSharedTtsModel = false;
const _svOnboardingSampleCount = 5;
const _androidSvUiMatchThreshold = 0.34;
final _svDecisionThreshold = Platform.isAndroid ? 0.34 : 0.35;
const _svMatchHold = Duration(milliseconds: 750);
const _richSpeakerSpeed = 0.95;
const _hannaSpeakerSpeed = 1.0;
const _arianaSpeakerSpeed = 1.0;
const _wakewordInstanceId = 'multi_model_instance';
const _wakewordThreshold = 0.999;
const _wakewordBufferCount = 3;
const _wakewordMsBetweenCallbacks = 1000;
const _locale = 'en-US';
const _speechSilenceTimeout = Duration(milliseconds: 2000);
const _geminiModel = 'gemini-3.1-flash-lite-preview';
const _geminiSystemPrompt =
    'You are a helpful voice assistant inside a Flutter demo app. Reply conversationally, keep answers concise for spoken playback, and avoid markdown. For time-sensitive facts like current leaders, dates, news, prices, or recent events, answer cautiously and say when you may be unsure rather than asserting a stale fact.';
const _rnBackground = Color(0xff667eea);
const _rnCard = Color(0xeb070c1a);
const _rnGreen = Color(0xff34c759);
const _rnBlue = Color(0xff2e86de);
const _rnText = Color(0xffffffff);
const _rnMutedText = Color(0xb3ffffff);
const _rnSoftBorder = Color(0x24ffffff);
const _rnSoftFill = Color(0x14ffffff);
const _hdAudioOptions = [
  WakewordAudioOption.mixWithOthers,
  WakewordAudioOption.bluetoothHighQualityRecording,
  WakewordAudioOption.allowAirPlay,
];
const _speakerAudioOptions = [
  WakewordAudioOption.mixWithOthers,
  WakewordAudioOption.allowBluetoothA2DP,
  WakewordAudioOption.allowAirPlay,
  WakewordAudioOption.defaultToSpeaker,
];
const _hdRoute = RouteConfigEntry(
  category: WakewordAudioCategory.playAndRecord,
  mode: WakewordAudioMode.defaultMode,
  options: _hdAudioOptions,
  preferredInput: WakewordPreferredInput.bluetoothHighQualityMic,
  forceFallback: WakewordPreferredInput.none,
);
const _speakerRoute = RouteConfigEntry(
  category: WakewordAudioCategory.playAndRecord,
  mode: WakewordAudioMode.defaultMode,
  options: _speakerAudioOptions,
  preferredInput: WakewordPreferredInput.builtInMic,
);
const _defaultAudioRoutingConfig = AudioRoutingConfig(
  defaultRoute: RouteConfigEntry(
    category: WakewordAudioCategory.playAndRecord,
    mode: WakewordAudioMode.defaultMode,
    options: [..._hdAudioOptions, WakewordAudioOption.defaultToSpeaker],
    preferredInput: WakewordPreferredInput.bluetoothHighQualityMic,
    forceFallback: WakewordPreferredInput.none,
  ),
  carAudio: RouteConfigEntry(
    category: WakewordAudioCategory.playAndRecord,
    mode: WakewordAudioMode.defaultMode,
    options: [
      WakewordAudioOption.mixWithOthers,
      WakewordAudioOption.allowBluetooth,
      WakewordAudioOption.allowBluetoothA2DP,
      WakewordAudioOption.allowAirPlay,
      WakewordAudioOption.overrideMutedMicrophoneInterruption,
    ],
    preferredInput: WakewordPreferredInput.none,
  ),
  builtInReceiver: _speakerRoute,
  builtInSpeaker: _speakerRoute,
  bluetoothA2DP: _hdRoute,
  bluetoothHFP: _hdRoute,
  headphones: RouteConfigEntry(
    category: WakewordAudioCategory.playAndRecord,
    mode: WakewordAudioMode.defaultMode,
    options: [
      WakewordAudioOption.mixWithOthers,
      WakewordAudioOption.allowBluetoothA2DP,
      WakewordAudioOption.allowAirPlay,
    ],
    preferredInput: WakewordPreferredInput.builtInMic,
  ),
  whenPlayingAudio: PlaybackRoutingConfig(
    onPlay: AudioRoutingOverride(options: [WakewordAudioOption.duckOthers]),
    onFinishPlaying: AudioRoutingOverride(notifyOthers: true),
  ),
  sttDuckingConfig: STTDuckingConfig(
    onUnpause: AudioRoutingOverride(options: [WakewordAudioOption.duckOthers]),
    onPause: AudioRoutingOverride(notifyOthers: true),
  ),
  wakewordAEC: WakewordAECConfig(regular: false, duringTTS: false),
  wakeWordDuringTTS: WakeWordDuringTTSConfig(threshold: 0.9, bufferCount: 1),
);

enum _VoiceChoice { hanna, ariana, rich }

enum _AppModeChoice { fullAiChat, combined, sttOnly, typeToTts }

enum _Stage {
  preparing,
  voicePicker,
  svPrompt,
  svStatus,
  modePicker,
  ttsTest,
  home,
}

enum _SVStatusPhase { onboarding, verifying }

enum _SVStepResult { progress, done }

class _SVHeldScore {
  const _SVHeldScore(this.time, this.score);

  final DateTime time;
  final double score;
}

class DavoiceExampleApp extends StatelessWidget {
  const DavoiceExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Davoice Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _rnBackground,
          primary: _rnGreen,
          secondary: _rnBlue,
          surface: _rnCard,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: _rnBackground,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _rnSoftFill,
          hintStyle: _Styles.small,
          labelStyle: _Styles.small,
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _rnSoftBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _rnGreen),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        useMaterial3: true,
      ),
      home: const DavoiceExampleHome(),
    );
  }
}

class DavoiceExampleHome extends StatefulWidget {
  const DavoiceExampleHome({super.key});

  @override
  State<DavoiceExampleHome> createState() => _DavoiceExampleHomeState();
}

class _DavoiceExampleHomeState extends State<DavoiceExampleHome> {
  final _speech = FlutterDavoice();
  final _licenseController = TextEditingController();
  final _ttsController = TextEditingController(
    text:
        'Hello Guys, I am one of the coaches in the Lunafit app. I love helping people reach their fitness goals.',
  );

  KeyWordFlutterPC? _wakeword;
  StreamSubscription<Map<String, dynamic>>? _wakewordSubscription;
  SpeakerVerificationMicController? _svController;
  SpeakerVerificationMicController? _svVerifyController;
  StreamSubscription<Map<String, dynamic>>? _svVerifyResultSub;
  StreamSubscription<Map<String, dynamic>>? _svVerifyErrorSub;
  Timer? _svElapsedTimer;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  _Stage _stage = _Stage.preparing;
  final _narration = StartupNarration();
  String? _loadedTtsModel;
  _VoiceChoice _voiceChoice = _VoiceChoice.rich;
  _AppModeChoice _appModeChoice = _AppModeChoice.combined;
  String _message = 'Preparing voice demo...';
  bool _setupFailed = false;
  String _licenseSource = 'No license selected yet.';
  String? _geminiApiKey;
  String? _savedEnrollmentJson;
  String? _savedEnrollmentJsonPath;
  String? _enrollmentJsonPath;
  String? _pendingWakeWordForModeChoice;
  _SVStatusPhase _svStatusPhase = _SVStatusPhase.onboarding;
  bool _isBusy = false;
  int _busyEpoch = 0;
  bool _isFirstWakeWordCallback = true;
  bool _wakeWordArmed = false;
  bool _isHandlingWakeWord = false;
  bool _isManualTtsSpeaking = false;
  bool _isIntroSpeaking = false;
  bool _isTtsSpeaking = false;
  bool _speechEchoSessionActive = false;
  bool _isFullAIChatMode = false;
  bool _isAIChatLoading = false;
  bool _svStatusCanContinue = false;
  int _svCollected = 0;
  int _svTarget = _svOnboardingSampleCount;
  double? _lastSvScore;
  bool? _lastSvMatch;
  DateTime? _lastSvScoreAt;
  DateTime? _svMatchHoldUntil;
  final List<_SVHeldScore> _svHeldScores = [];
  String _svElapsed = 'N/A';
  String _currentSpeechSentence = '';
  String _introScript = '';
  String _aiChatResponse = '';
  String _lastTranscript = '';
  String _partialTranscript = '';
  String _lastWakeWord = 'Hey Coach';
  final List<Map<String, dynamic>> _geminiConversation = [];
  Timer? _speechSilenceTimer;
  int _speechUiEpoch = 0;
  bool _isSwitchingMode = false;
  bool _suppressSpeechResults = false;
  HttpClient? _activeGeminiClient;
  DateTime? _lastGeminiRequestAt;
  DateTime? _geminiBlockedUntil;
  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startDemo());
    });
    _loadGeminiApiKey();
    _listenToSpeechEvents();
  }

  @override
  void dispose() {
    _beginSpeechUiEpoch();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    unawaited(_wakewordSubscription?.cancel());
    _ttsController.dispose();
    _licenseController.dispose();
    _speechSilenceTimer?.cancel();
    unawaited(_wakeword?.stopKeywordDetection(_wakewordInstanceId));
    unawaited(_wakeword?.destroyInstance());
    unawaited(_svController?.destroy());
    unawaited(_stopSpeakerVerificationVerify());
    unawaited(_speech.destroyAll());
    super.dispose();
  }

  Future<void> _loadBundledLicense() async {
    try {
      final license = (await rootBundle.loadString('licensekey.txt')).trim();
      if (!mounted || license.isEmpty) return;
      setState(() {
        _licenseController.text = license;
        _licenseSource = 'Selected license: licensekey.txt';
      });
    } on FlutterError {
      if (!mounted) return;
      setState(() {
        _licenseSource = 'Selected license: manual entry';
      });
    }
  }

  Future<void> _loadGeminiApiKey() async {
    try {
      final config = await rootBundle.loadString('local.config.ts');
      final match = RegExp(
        r'''GEMINI_API_KEY\s*=\s*['"]([^'"]+)['"]''',
      ).firstMatch(config);
      final key = match?.group(1)?.trim();
      if (!mounted || key == null || key.isEmpty) return;
      setState(() => _geminiApiKey = key);
    } catch (error) {
      _log('Gemini config not loaded: $error');
    }
  }

  bool get _speechResultsAllowed =>
      mounted &&
      _stage == _Stage.home &&
      !_suppressSpeechResults &&
      !_isSwitchingMode &&
      (_isFullAIChatMode || _speechEchoSessionActive) &&
      !_isTtsSpeaking;

  void _listenToSpeechEvents() {
    _subscriptions.addAll([
      _speech.onSpeechStart.listen((_) {
        if (!mounted || !_speechEchoSessionActive) return;
      }),
      _speech.onSpeechEnd.listen((_) {
        if (!mounted) return;
      }),
      _speech.onSpeechPartialResults.listen((event) {
        if (!_speechResultsAllowed) return;
        final current = event.value.isEmpty ? '' : event.value.first.trim();
        if (current.isEmpty) return;

        if (_isFullAIChatMode) {
          if (_isAIChatLoading || _isTtsSpeaking) return;
          final merged = Platform.isAndroid
              ? mergeTranscript(_lastTranscript, current)
              : current;
          _scheduleAIChatTimeout();
          setState(() {
            _lastTranscript = merged;
            _partialTranscript = merged;
            _currentSpeechSentence = merged;
            _message = 'Listening...';
          });
          return;
        }

        if (_stage == _Stage.ttsTest || _stage == _Stage.modePicker) return;
        if (!_speechEchoSessionActive || _isTtsSpeaking) return;
        if (Platform.isIOS) {
          if (current == _lastTranscript) return;
          setState(() {
            _lastTranscript = current;
            _partialTranscript = current;
            _currentSpeechSentence = current;
            _message = 'Listening...';
          });
          return;
        }

        final merged = mergeTranscript(_lastTranscript, current);
        if (_appModeChoice != _AppModeChoice.sttOnly) {
          _scheduleSpeechEchoTimeout();
        }
        if (merged == _lastTranscript) return;
        setState(() {
          _lastTranscript = merged;
          _partialTranscript = merged;
          _currentSpeechSentence = merged;
          _message = 'Listening...';
        });
      }),
      _speech.onSpeechResults.listen((event) {
        if (!_speechResultsAllowed) return;
        final transcript = event.value.isEmpty ? '' : event.value.first.trim();
        if (transcript.isEmpty) return;

        if (_isFullAIChatMode) {
          if (_isAIChatLoading || _isTtsSpeaking) return;
          final merged = Platform.isAndroid
              ? mergeTranscript(_lastTranscript, transcript)
              : transcript;
          setState(() {
            _lastTranscript = merged;
            _partialTranscript = merged;
            _currentSpeechSentence = merged;
            _message = 'Listening...';
          });
          _scheduleAIChatTimeout();
          return;
        }

        if (_stage == _Stage.ttsTest || _stage == _Stage.modePicker) return;
        if (!_speechEchoSessionActive || _isTtsSpeaking) return;
        final merged = Platform.isAndroid
            ? mergeTranscript(_lastTranscript, transcript)
            : transcript;
        setState(() {
          _lastTranscript = merged;
          _partialTranscript = merged;
          _currentSpeechSentence = merged;
          _message = 'Listening...';
        });
        if (_appModeChoice != _AppModeChoice.sttOnly) {
          _scheduleSpeechEchoTimeout();
        }
      }),
      _speech.onSpeechError.listen((event) {
        if (!mounted) return;
        setState(() {
          _message = event.message ?? 'Speech recognition error.';
        });
      }),
      _speech.onFinishedSpeaking.listen((_) {
        if (mounted) {
          setState(() {
            _isManualTtsSpeaking = false;
            _isIntroSpeaking = false;
            _isTtsSpeaking = false;
          });
        }
      }),
    ]);
  }

  Future<bool> _applyDavoiceLicenseIfPresent() async {
    final license = _licenseController.text.trim();
    if (license.isEmpty) return true;
    return _speech.setLicense(license);
  }

  Future<bool> _applyWakewordLicenseIfPresent(KeyWordFlutterPC wakeword) async {
    final license = _licenseController.text.trim();
    if (license.isEmpty) return true;
    return wakeword.setKeywordDetectionLicense(license);
  }

  Future<void> _startDemo() async {
    _setupFailed = false;
    await _runBusy(() async {
      if (_licenseController.text.trim().isEmpty) await _loadBundledLicense();
      await _ensureMicPermission();
      if (Platform.isIOS) await _ensureSpeechRecognitionPermission();
      if (!mounted) return;
      await _initializeSpeechAndWakeWord(null);
      if (!mounted) return;
      await _speakStartupNarration([
        'Hey there, My name is $_voiceName. In this application we will use my cloned voice in order to showcase our voice AI agent capabilities.',
        "Don't worry. I will be your personal guide to walk you through this demonstration step by step.",
        'First, please choose which voice you want to use. You can stay with me, $_voiceName, or switch to $_otherVoiceNames.',
      ]);
      if (!mounted) return;
      setState(() {
        _stage = _Stage.voicePicker;
        _message = '';
      });
    });
  }

  Future<void> _skipNarration() async {
    final stop = _narration.skip(_speech.stopSpeaking);
    setState(() {});
    try {
      await stop;
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Could not stop narration: $error');
      }
    }
  }

  Future<void> _speakStartupNarration(List<String> lines) async {
    _wakeWordArmed = false;
    await _pauseWakeWordDetection();
    await _speech.pauseSpeechRecognition();
    await _applySelectedTtsVoice();
    if (!mounted) return;
    setState(() => _stage = _Stage.preparing);
    final narrationTimer = Stopwatch()..start();
    _log('Startup narration: beginning ${lines.length} lines');
    await _narration.speak(
      lines,
      isActive: () => mounted,
      speakLine: (line) async {
        if (!mounted) return;
        setState(() => _message = line);
        await _speech.speak(_applyTtsTextPolicy(line), speed: _speakerSpeed);
      },
    );
    _log(
      'Startup narration: completed after ${narrationTimer.elapsedMilliseconds}ms',
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _continueFromVoicePicker() async {
    await _runBusy(() async {
      if (_loadedTtsModel != _selectedTtsModel) {
        await _speech.destroyAll();
        await _initializeSpeech(null);
      }
      await _applySelectedTtsVoice();
      await _speakStartupNarration([
        _voiceChoice == _VoiceChoice.rich
            ? 'Awesome, Thanks for choosing to stay with me.'
            : 'Awesome, You chose $_voiceName.',
        'The next phase, is setting speaker verification. You can create a new speaker signature, use a saved one, or skip this step.',
      ]);
      await _loadSavedEnrollmentJson();
      if (!mounted) return;
      setState(() {
        _message = _savedEnrollmentJson == null
            ? 'Create a speaker signature, or skip this step.'
            : 'Saved speaker signature found. You can use it, create a new one, or skip speaker verification.';
        _stage = _Stage.svPrompt;
      });
    });
  }

  Future<void> _useSavedSpeakerVerification() async {
    final path = _savedEnrollmentJsonPath;
    final enrollmentJson = _savedEnrollmentJson;
    if (path == null ||
        path.isEmpty ||
        enrollmentJson == null ||
        enrollmentJson.isEmpty) {
      setState(() => _message = 'Saved speaker signature was not found.');
      return;
    }
    await _runBusy(() async {
      _enrollmentJsonPath = path;
      setState(() {
        _stage = _Stage.svStatus;
        _svStatusPhase = _SVStatusPhase.verifying;
        _svStatusCanContinue = false;
        _message = 'Verify Speaker Identification Now';
      });
      try {
        await _startSpeakerVerificationVerify(enrollmentJson);
      } catch (_) {
        await _stopSpeakerVerificationVerify();
        _enrollmentJsonPath = null;
        if (mounted) setState(() => _stage = _Stage.svPrompt);
        rethrow;
      }
    });
  }

  Future<void> _skipSpeakerVerification() async {
    _enrollmentJsonPath = null;
    await _finishSpeakerVerification();
  }

  Future<void> _runSpeakerVerificationOnboarding() async {
    await _runBusy(() async {
      await _ensureMicPermission();
      setState(() {
        _stage = _Stage.svStatus;
        _svStatusPhase = _SVStatusPhase.onboarding;
        _svStatusCanContinue = false;
        _svCollected = 0;
        _svTarget = _svOnboardingSampleCount;
        _lastSvScore = null;
        _lastSvMatch = null;
        _lastSvScoreAt = null;
        _svElapsed = 'N/A';
        _message = 'Speaker verification: preparing microphone controller...';
      });

      final controller = await createSpeakerVerificationMicController('svMic1');
      _svController = controller;

      final errorSub = onSpeakerVerificationError((event) {
        if (event['controllerId'] != 'svMic1' || !mounted) return;

        setState(() {
          _message = 'Speaker verification error: ${event['error'] ?? event}';
        });
      });
      final progressSub = onSpeakerVerificationOnboardingProgress((event) {
        if (event['controllerId'] != 'svMic1' || !mounted) return;

        setState(() {
          _svCollected = _readInt(event['collected'], _svCollected);
          _svTarget = _readInt(event['target'], _svTarget);
          _message = 'Collected $_svCollected/$_svTarget voice samples.';
        });
      });
      final doneCompleter = Completer<String>();
      // Native completion can fail before the sample loop reaches its final await.
      unawaited(
        doneCompleter.future.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        ),
      );
      final doneSub = onSpeakerVerificationOnboardingDone((event) {
        if (event['controllerId'] != 'svMic1') return;

        final json =
            event['enrollmentJson'] ?? event['enrollment'] ?? event['json'];
        if (json is String && json.length > 10) {
          if (!doneCompleter.isCompleted) doneCompleter.complete(json);
        } else if (!doneCompleter.isCompleted) {
          doneCompleter.completeError(
            StateError('Onboarding completed without enrollment JSON.'),
          );
        }
      });

      try {
        _log('SV create controller model=$_speakerModel');
        await controller.create({
          'modelPath': _speakerModel,
          'options': {
            'decisionThreshold': _svDecisionThreshold,
            'tailSeconds': 2.0,
            'frameSize': 1280,
            'maxTailSeconds': 3.0,
            'cmn': true,
            'expectedLayoutBDT': false,
          },
        });
        await controller.beginOnboarding(
          'davoice',
          _svOnboardingSampleCount,
          reset: true,
        );
        _log('SV beginOnboarding target=$_svOnboardingSampleCount');

        for (var index = 1; index <= _svOnboardingSampleCount; index += 1) {
          if (!mounted) return;
          setState(() {
            _message = 'Speak sample $index/$_svOnboardingSampleCount.';
          });
          final beforeCollected = _svCollected;
          _log(
            'SV getNextEmbeddingFromMic sample=$index before=$beforeCollected',
          );
          final _SVStepResult step;
          if (Platform.isIOS) {
            final nativeResult = await controller
                .getNextEmbeddingFromMic()
                .timeout(const Duration(seconds: 30));
            step = _handleSVStepPayload(
              nativeResult,
              beforeCollected,
              doneCompleter,
            );
          } else {
            final stepFuture = _waitForNextSVStep(
              'svMic1',
              beforeCollected,
              doneCompleter,
            );
            final results = await Future.wait<Object?>([
              controller.getNextEmbeddingFromMic(),
              stepFuture,
            ], eagerError: true);
            step = results[1] as _SVStepResult;
          }
          _log(
            'SV step result sample=$index result=$step collected=$_svCollected',
          );
          if (step == _SVStepResult.done) break;
        }

        setState(() => _message = 'Finalizing speaker profile...');
        final enrollmentJson = await doneCompleter.future.timeout(
          const Duration(seconds: 60),
        );
        await controller.setEnrollmentJson(enrollmentJson);
        await controller.destroy();
        _svController = null;
        final enrollmentJsonPath = await _writeEnrollmentJsonToFile(
          enrollmentJson,
        );

        setState(() {
          _savedEnrollmentJson = enrollmentJson;
          _savedEnrollmentJsonPath = enrollmentJsonPath;
          _enrollmentJsonPath = enrollmentJsonPath;
        });

        await _startSpeakerVerificationVerify(enrollmentJson);
      } catch (_) {
        await _stopSpeakerVerificationVerify();
        _enrollmentJsonPath = null;
        if (mounted) setState(() => _stage = _Stage.svPrompt);
        rethrow;
      } finally {
        if (identical(_svController, controller)) {
          _svController = null;
          await controller.destroy();
        }
        await errorSub.cancel();
        await progressSub.cancel();
        await doneSub.cancel();
      }
    });
  }

  Future<void> _continueAfterSpeakerVerification() async {
    await _stopSpeakerVerificationVerify();
    if (mounted) {
      setState(() {
        _svStatusCanContinue = false;
      });
    }
    await _finishSpeakerVerification();
  }

  Future<void> _startSpeakerVerificationVerify(String enrollmentJson) async {
    await _stopSpeakerVerificationVerify();
    final controllerId =
        'svVerifyMicFix_${DateTime.now().millisecondsSinceEpoch}';
    final controller = await createSpeakerVerificationMicController(
      controllerId,
    );
    _svVerifyController = controller;

    setState(() {
      _svStatusPhase = _SVStatusPhase.verifying;
      _svStatusCanContinue = false;
      _lastSvScore = null;
      _lastSvMatch = null;
      _lastSvScoreAt = null;
      _svMatchHoldUntil = null;
      _svHeldScores.clear();
      _svElapsed = 'N/A';
      _message = 'Verify Speaker Identification Now';
    });

    _svElapsedTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final scoreAt = _lastSvScoreAt;
      setState(() {
        if (scoreAt == null) {
          _svElapsed = 'N/A';
          return;
        }
        final elapsed = DateTime.now().difference(scoreAt);
        final seconds = elapsed.inMilliseconds / 1000;
        _svElapsed = seconds < 60
            ? '${seconds.toStringAsFixed(1)}s'
            : '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s';
      });
    });

    _svVerifyErrorSub = onSpeakerVerificationError((event) {
      if (event['controllerId'] != controllerId || !mounted) return;

      setState(() {
        _message = 'SV error: ${event['error'] ?? event}';
      });
    });

    _svVerifyResultSub = onSpeakerVerificationVerifyResult((event) {
      if (event['controllerId'] != controllerId || !mounted) return;

      final nativeScore =
          _readDouble(event['scoreBest']) ??
          _readDouble(event['bestScore']) ??
          _readDouble(event['score']);
      final nativeMatch = event['isMatch'] == true;
      final uiScore = _scoreForSVUI(nativeScore, nativeMatch);
      final uiMatch = _matchForSVUI(uiScore, nativeMatch);
      final displayScore = _displayScoreForSVUI(uiScore, nativeMatch);

      setState(() {
        _lastSvScore = displayScore;
        _lastSvMatch = uiMatch;
        _lastSvScoreAt = DateTime.now();
        _svStatusCanContinue = true;
        _message = 'Speaker Identification Match=${uiMatch ? 'YES' : 'NO'}';
      });
    });

    _log('SV verify create controller model=$_speakerModel');
    await controller.create({
      'modelPath': _speakerModel,
      'options': {
        'decisionThreshold': _svDecisionThreshold,
        'tailSeconds': 2.0,
        'frameSize': 1280,
        'maxTailSeconds': 3.0,
        'cmn': true,
        'expectedLayoutBDT': false,
      },
    });
    await controller.setEnrollmentJson(enrollmentJson);
    _log('SV verify startEndlessVerifyFromMic');
    await controller.startEndlessVerifyFromMic(
      hopSeconds: 0.25,
      stopOnMatch: false,
      resetState: true,
    );
  }

  Future<void> _initializeSpeechAndWakeWord(String? enrollmentJsonPath) async {
    await _ensureMicPermission();
    if (!mounted) return;
    _wakeWordArmed = false;
    await _wakewordSubscription?.cancel();
    _wakewordSubscription = null;
    final previous = _wakeword;
    if (previous != null) {
      await previous.stopKeywordDetection(_wakewordInstanceId);
      await previous.destroyInstance();
      _wakeword = null;
      await _speech.destroyAll();
      _loadedTtsModel = null;
    }
    if (!mounted) return;
    setState(() => _message = 'Initializing wake word...');
    _log('Initializing wake word instance $_wakewordInstanceId');
    await setWakewordAudioRoutingConfig(_defaultAudioRoutingConfig);
    await _speech.setAudioRoutingConfig(_defaultAudioRoutingConfig.toJson());
    final wakeword = createKeyWordFlutterPCInstance(_wakewordInstanceId);
    _wakeword = wakeword;
    _log(
      'createInstanceMulti model=$_wakewordModel threshold=$_wakewordThreshold buffer=$_wakewordBufferCount ms=$_wakewordMsBetweenCallbacks',
    );
    await wakeword.createInstanceMulti(
      _wakewordInstanceId,
      [_wakewordModel],
      const [_wakewordThreshold],
      const [_wakewordBufferCount],
      const [_wakewordMsBetweenCallbacks],
    );
    _log('createInstanceMulti completed');
    if (!mounted) {
      await wakeword.destroyInstance();
      return;
    }
    _wakewordSubscription = wakeword.onKeywordDetectionEvent().listen((event) {
      if (!mounted) return;
      final phrase = event['phrase']?.toString();
      final model = event['model']?.toString();
      unawaited(_handleWakeWord(phrase ?? model ?? _lastWakeWord));
    });

    _log('Applying wake-word license');
    final wakewordLicensed = await _applyWakewordLicenseIfPresent(wakeword);
    if (!wakewordLicensed) {
      throw StateError(
        'Wake-word license is not valid. Please contact info@davoice.io.',
      );
    }

    if (!mounted) return;
    _log('Applying Davoice license');
    final speechLicensed = await _applyDavoiceLicenseIfPresent();
    if (!speechLicensed) {
      throw StateError(
        'Davoice license is not valid. Please contact info@davoice.io.',
      );
    }

    if (!mounted) return;
    _log('Starting wake-word detection enrollmentJsonPath=$enrollmentJsonPath');
    final wakewordStarted = await wakeword.startKeywordDetection(
      _wakewordInstanceId,
      _wakewordThreshold,
      speakerVerificationEnrollmentJsonOrPath: enrollmentJsonPath,
    );
    if (!wakewordStarted) {
      throw StateError('Wake-word detection failed to start.');
    }
    if (!mounted) {
      await wakeword.stopKeywordDetection(_wakewordInstanceId);
      return;
    }
    _log('Wake-word detection started; pausing before Speech.initAll');
    await _pauseWakeWordDetection();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await _initializeSpeech(enrollmentJsonPath);
  }

  Future<void> _initializeSpeech(String? enrollmentJsonPath) async {
    if (!mounted) return;
    setState(() => _message = 'Initializing speech engine...');
    _appliedTtsVoice = null;
    await _speech.initAll(
      DavoiceInitAllOptions(
        locale: _locale,
        model: _selectedTtsModel,
        onboardingJsonPath: enrollmentJsonPath,
      ),
    );
    if (!mounted) {
      await _speech.destroyAll();
      return;
    }
    _loadedTtsModel = _selectedTtsModel;
    await _applySelectedTtsVoice();
    await _speech.pauseSpeechRecognition();
  }

  Future<void> _finishSpeakerVerification() async {
    await _runBusy(() async {
      final enrollment = _enrollmentJsonPath;
      if (enrollment != null) {
        await _speech.stopSpeaking();
        await _speech.destroyAll();
        await _initializeSpeech(enrollment);
        if (!mounted) return;
        final wakeword = _wakeword!;
        await wakeword.stopKeywordDetection(_wakewordInstanceId);
        final started = await wakeword.startKeywordDetection(
          _wakewordInstanceId,
          _wakewordThreshold,
          speakerVerificationEnrollmentJsonOrPath: enrollment,
        );
        if (!started) {
          throw StateError(
            'Wake-word detection with speaker verification failed to start.',
          );
        }
        await _pauseWakeWordDetection();
      }
      if (!mounted) return;
      await _speakStartupNarration([
        enrollment == null
            ? 'Speaker verification skipped.'
            : 'Speaker verification is ready!',
        'Now please say the wake word Hey Coach to continue.',
      ]);
      if (!mounted) return;
      await _unPauseWakeWordDetection();
      if (!mounted) return;
      setState(() {
        _wakeWordArmed = true;
        _stage = _Stage.home;
        _message = 'Say the wake word "Hey Coach" to continue.';
      });
    });
  }

  Future<void> _continueFromModePicker() async {
    final pendingWakeWord = _pendingWakeWordForModeChoice;
    _pendingWakeWordForModeChoice = null;
    if (pendingWakeWord != null) {
      try {
        await _continueAfterWakeWordModeChoice(pendingWakeWord);
      } finally {
        _isHandlingWakeWord = false;
      }
      return;
    }

    await _continueAfterWakeWordModeChoice(_lastWakeWord);
  }

  Future<void> _handleWakeWord(String rawWakeWord) async {
    if (_isBusy || _isHandlingWakeWord || !_wakeWordArmed) return;
    _wakeWordArmed = false;
    _isHandlingWakeWord = true;
    final isFirstCall = _isFirstWakeWordCallback;
    if (isFirstCall) {
      _isFirstWakeWordCallback = false;
    }

    try {
      await _pauseWakeWordDetection();
      await _captureWakeWordRecordingPaths();
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;
      final wakeWord = _formatWakeWord(rawWakeWord);
      setState(() {
        _lastWakeWord = wakeWord;
        _message = 'Wake word "$wakeWord" detected.';
        _stage = _Stage.home;
      });

      if (isFirstCall) {
        try {
          await _speech.pauseSpeechRecognition();
        } catch (_) {}
        await _speakStartupNarration([
          '$wakeWord detected.',
          'Now you can test the voice capabilities in four different ways. You can select a full AI Chat, or simply test Speech to Text and Text to Speech individually or a combination of both.',
        ]);
        if (!mounted) return;
        setState(() {
          _appModeChoice = _AppModeChoice.combined;
          _pendingWakeWordForModeChoice = wakeWord;
          _stage = _Stage.modePicker;
          _message =
              'Now you can choose from four options, a full AI Chat option, testing Speech to Text individually, testing Text to Speech individually, or a combination of both Speech to Text and Text to Speech.';
        });
        return;
      }

      await _continueAfterWakeWordModeChoice(wakeWord);
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Wake-word session failed: $error');
      }
      _isHandlingWakeWord = false;
    } finally {
      if (!isFirstCall) _isHandlingWakeWord = false;
    }
  }

  Future<void> _continueAfterWakeWordModeChoice(String wakeWord) async {
    _beginSpeechUiEpoch();
    _speechSilenceTimer?.cancel();
    _lastTranscript = '';
    _partialTranscript = '';
    _isAIChatLoading = false;
    _chatHistory.clear();
    _geminiConversation.clear();
    if (_appModeChoice == _AppModeChoice.typeToTts) {
      await _speech.pauseSpeechRecognition();
      if (!mounted) return;
      setState(() {
        _stage = _Stage.ttsTest;
        _speechEchoSessionActive = false;
        _isFullAIChatMode = false;
        _isIntroSpeaking = false;
        _isTtsSpeaking = false;
        _introScript = '';
        _currentSpeechSentence = '';
        _message = 'Type to TTS';
      });
      return;
    }
    if (_appModeChoice == _AppModeChoice.fullAiChat) {
      await _enterFullAIChatMode();
      return;
    }
    await _enterSttOnlyMode(wakeWord);
    if (mounted && _appModeChoice == _AppModeChoice.combined) {
      setState(
        () => _message = 'Combined STT + TTS is active. Start speaking.',
      );
    }
  }

  Future<void> _selectMode(_AppModeChoice mode) async {
    if (_isSwitchingMode || _stage != _Stage.modePicker) return;
    final timer = Stopwatch()..start();
    _log('Mode ${mode.name}: entering');
    setState(() {
      _isSwitchingMode = true;
      _appModeChoice = mode;
    });
    try {
      await _continueFromModePicker();
      _log('Mode ${mode.name}: ready after ${timer.elapsedMilliseconds}ms');
    } catch (error) {
      _log(
        'Mode ${mode.name}: failed after ${timer.elapsedMilliseconds}ms: $error',
      );
      if (mounted) setState(() => _message = 'Could not enter mode: $error');
    } finally {
      if (mounted) setState(() => _isSwitchingMode = false);
    }
  }

  Future<void> _goBackToModeSelection() async {
    if (_isSwitchingMode) return;
    _isSwitchingMode = true;
    _busyEpoch++;
    _beginSpeechUiEpoch();
    _speechSilenceTimer?.cancel();
    _speechEchoSessionActive = false;
    _isFullAIChatMode = false;
    _wakeWordArmed = false;
    _pendingWakeWordForModeChoice = null;
    _isHandlingWakeWord = false;
    _isAIChatLoading = false;
    try {
      await _speech.stopSpeaking();
      await _speech.pauseSpeechRecognition();
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _isTtsSpeaking = false;
        _isManualTtsSpeaking = false;
        _isIntroSpeaking = false;
        _lastTranscript = '';
        _partialTranscript = '';
        _currentSpeechSentence = '';
        _aiChatResponse = '';
        _introScript = '';
        _stage = _Stage.modePicker;
        _message = 'Choose what you want to test next.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Could not stop the session: $error');
      }
    } finally {
      _isSwitchingMode = false;
    }
  }

  Future<void> _stopPlayback() async {
    _busyEpoch++;
    final resume = _isFullAIChatMode || _speechEchoSessionActive;
    final epoch = _beginSpeechUiEpoch();
    await _speech.stopSpeaking();
    if (!_isSpeechUiEpochCurrent(epoch)) return;
    setState(() {
      _isTtsSpeaking = false;
      _isManualTtsSpeaking = false;
      _isAIChatLoading = false;
      _isBusy = false;
    });
    if (resume) await _resumeSpeechAfterTts();
  }

  void _showChatHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Chat History')),
            for (final message in _chatHistory)
              ListTile(
                title: Text(message['role'] == 'user' ? 'You' : 'Assistant'),
                subtitle: Text(message['text']!),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _enterSttOnlyMode(String wakeWord) async {
    _speechSilenceTimer?.cancel();
    setState(() {
      _stage = _Stage.home;
      _isFullAIChatMode = false;
      _speechEchoSessionActive = true;
      _isIntroSpeaking = false;
      _isTtsSpeaking = false;
      _introScript = '';
      _lastTranscript = '';
      _partialTranscript = '';
      _currentSpeechSentence = 'Listening...';
      _message = 'STT Only is active after "$wakeWord".';
    });
    await _resumeSpeechAfterTts(const Duration(milliseconds: 300));
  }

  Future<void> _enterFullAIChatMode() async {
    _speechSilenceTimer?.cancel();
    setState(() {
      _stage = _Stage.home;
      _speechEchoSessionActive = false;
      _isFullAIChatMode = true;
      _isIntroSpeaking = false;
      _isTtsSpeaking = false;
      _introScript = '';
      _message = 'Speak with Gemini.';
      _partialTranscript = 'Listening...';
      _currentSpeechSentence = 'Listening...';
      _aiChatResponse = '';
      _lastTranscript = '';
      _geminiConversation.clear();
    });
    await _speech.pauseSpeechRecognition();
    await _resumeSpeechAfterTts();
  }

  Future<void> _answerLikeVoiceAssistant(String transcript) async {
    final cleaned = transcript.trim();
    if (cleaned.isEmpty ||
        _isAIChatLoading ||
        !_isFullAIChatMode ||
        _stage != _Stage.home) {
      return;
    }
    final now = DateTime.now();
    if (_geminiBlockedUntil != null && now.isBefore(_geminiBlockedUntil!)) {
      setState(
        () => _message = 'Gemini is cooling down. Please try again shortly.',
      );
      return;
    }
    final epoch = _speechUiEpoch;
    _isAIChatLoading = true;
    _chatHistory.add({'role': 'user', 'text': cleaned});
    try {
      await _pauseSpeechForTts();
      if (!_isSpeechUiEpochCurrent(epoch)) return;
      setState(() {
        _currentSpeechSentence = 'Gemini is thinking...';
        _message = 'Sending transcript to Gemini...';
        _partialTranscript = '';
      });
      final previous = _lastGeminiRequestAt;
      if (previous != null) {
        final wait =
            const Duration(seconds: 4) - DateTime.now().difference(previous);
        if (!wait.isNegative) await Future<void>.delayed(wait);
      }
      if (!_isSpeechUiEpochCurrent(epoch)) return;
      _lastGeminiRequestAt = DateTime.now();
      final reply = await _generateGeminiReply(cleaned, epoch);
      if (!_isSpeechUiEpochCurrent(epoch)) return;
      _chatHistory.add({'role': 'model', 'text': reply});
      setState(() {
        _aiChatResponse = reply;
        _currentSpeechSentence = 'Gemini: $reply';
        _message = 'Speaking Gemini reply...';
        _lastTranscript = '';
      });
      await _speakWhileSpeechPaused(
        reply,
        speakerId: _speakerId,
        speed: _speakerSpeed,
      );
    } catch (error) {
      if (!_isSpeechUiEpochCurrent(epoch)) return;
      final raw = error.toString().toLowerCase();
      if (raw.contains('429') ||
          raw.contains('quota') ||
          raw.contains('rate limit')) {
        _geminiBlockedUntil = DateTime.now().add(const Duration(seconds: 30));
      }
      final friendlyReply = _friendlyGeminiErrorMessage(error);
      _chatHistory.add({'role': 'model', 'text': friendlyReply});
      setState(() {
        _aiChatResponse = friendlyReply;
        _currentSpeechSentence = friendlyReply;
        _message = 'Gemini is unavailable.';
      });
      try {
        await _speakWhileSpeechPaused(
          friendlyReply,
          speakerId: _speakerId,
          speed: _speakerSpeed,
        );
      } catch (_) {
        // Keep the actionable error visible if status narration also fails.
      }
    } finally {
      if (_isSpeechUiEpochCurrent(epoch)) {
        setState(() {
          _isAIChatLoading = false;
          _isTtsSpeaking = false;
          _lastTranscript = '';
          _partialTranscript = '';
        });
        if (_isFullAIChatMode && _stage == _Stage.home) {
          await _resumeSpeechAfterTts();
        }
      }
    }
  }

  static String _friendlyGeminiErrorMessage(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();

    if (normalized.contains('api key') ||
        normalized.contains('local.config.ts')) {
      return 'This demo uses Google Gemini as the backend language model! Unfortunately the Gemini API key is not configured in this build yet.';
    }

    if (normalized.contains('429') ||
        normalized.contains('rate limit') ||
        normalized.contains('quota') ||
        normalized.contains('resource exhausted') ||
        normalized.contains('too many requests')) {
      return 'This demo uses Google Gemini as the backend language model. Unfortunately Gemini is currently rate limited or handling too many requests. Please try again in a moment.';
    }

    if (normalized.contains('busy') ||
        normalized.contains('overloaded') ||
        normalized.contains('unavailable') ||
        normalized.contains('503') ||
        normalized.contains('deadline exceeded')) {
      return 'This demo uses Google Gemini as the backend language model. Unfortunately Gemini is temporarily busy or unavailable right now. Please try again in a moment.';
    }

    if (normalized.contains('socket') ||
        normalized.contains('network') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection') ||
        normalized.contains('timed out')) {
      return 'This demo uses Google Gemini as the backend language model. Unfortunately Gemini service is not reachable right now. Please check the network connection and try again.';
    }

    return 'This demo uses Google Gemini as the backend language model. Unfortunately Gemini returned an error for this request, so I could not answer right now. Please try again in a moment.';
  }

  Future<String> _generateGeminiReply(String userText, int epoch) async {
    final apiKey = _geminiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('Gemini API key was not loaded from local.config.ts.');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent',
    );
    final nextHistory = [
      ..._geminiConversation,
      {
        'role': 'user',
        'parts': [
          {'text': userText},
        ],
      },
    ];

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    _activeGeminiClient = client;
    late final HttpClientResponse response;
    late final String body;
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 30));
      request.headers.contentType = ContentType.json;
      request.headers.set('x-goog-api-key', apiKey);
      request.write(
        jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': _geminiSystemPrompt},
            ],
          },
          'contents': nextHistory,
          'tools': [
            {'google_search': {}},
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 512,
            'thinkingConfig': {'thinkingBudget': 256},
          },
        }),
      );

      response = await request.close().timeout(const Duration(seconds: 60));
      body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 60));
    } finally {
      client.close(force: true);
      if (identical(_activeGeminiClient, client)) _activeGeminiClient = null;
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      final message = error is Map ? error['message'] : null;
      throw StateError(
        'Gemini ${response.statusCode}: ${message ?? 'Request failed'}',
      );
    }

    final candidates = payload['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw StateError('Gemini returned no candidates.');
    }
    final content = (candidates.first as Map?)?['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) {
      throw StateError('Gemini returned no text parts.');
    }
    final text = parts
        .map((part) => part is Map ? part['text']?.toString() ?? '' : '')
        .join(' ')
        .trim();
    if (text.isEmpty) throw StateError('Gemini returned an empty response.');
    final normalized = normalizeTextForSpeech(text);
    if (!_isSpeechUiEpochCurrent(epoch)) {
      throw StateError('Chat session ended.');
    }
    _geminiConversation
      ..clear()
      ..addAll([
        ...nextHistory,
        {
          'role': 'model',
          'parts': [
            {'text': normalized},
          ],
        },
      ]);
    return normalized;
  }

  Future<void> _speakManualText() async {
    final text = _ttsController.text.trim();
    if (text.isEmpty) return;
    final epoch = _speechUiEpoch;
    await _runBusy(() async {
      setState(() {
        _isManualTtsSpeaking = true;
        _isTtsSpeaking = true;
        _message = '$_voiceName is speaking...';
        _currentSpeechSentence = 'Speaking now: $text';
      });
      await _speakWhileSpeechPaused(
        text,
        speakerId: _speakerId,
        speed: _speakerSpeed,
      );
      if (_isSpeechUiEpochCurrent(epoch)) {
        setState(() {
          _isManualTtsSpeaking = false;
          _isTtsSpeaking = false;
          _currentSpeechSentence = '';
          _message = 'TTS Test Mode';
        });
      }
    });
  }

  int _beginSpeechUiEpoch() {
    _speechUiEpoch += 1;
    _suppressSpeechResults = false;
    _activeGeminiClient?.close(force: true);
    _activeGeminiClient = null;
    return _speechUiEpoch;
  }

  bool _isSpeechUiEpochCurrent(int epoch) => mounted && _speechUiEpoch == epoch;

  Future<void> _pauseSpeechForTts() async {
    _speechSilenceTimer?.cancel();
    if (mounted) {
      setState(() {
        _isTtsSpeaking = true;
      });
    }
    try {
      await _speech.pauseSpeechRecognition();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _speakWhileSpeechPaused(
    String text, {
    required int speakerId,
    required double speed,
  }) async {
    final epoch = _speechUiEpoch;
    await _pauseSpeechForTts();
    if (!_isSpeechUiEpochCurrent(epoch)) return;
    await _applySelectedTtsVoice();
    if (!_isSpeechUiEpochCurrent(epoch)) return;
    await _speech.speak(
      _applyTtsTextPolicy(text),
      speakerId: speakerId,
      speed: speed,
    );
  }

  String _applyTtsTextPolicy(String text) {
    return text
        .replaceAll("DaVoice's", 'the voice')
        .replaceAll('DaVoice', 'The Voice');
  }

  Future<void> _resumeSpeechAfterTts([
    Duration settleDelay = const Duration(milliseconds: 300),
  ]) async {
    final epoch = _speechUiEpoch;
    if (!mounted ||
        _stage != _Stage.home ||
        !(_isFullAIChatMode || _speechEchoSessionActive)) {
      return;
    }
    _suppressSpeechResults = true;
    try {
      await _speech.unPauseSpeechRecognition(-1);
      await Future<void>.delayed(settleDelay);
      if (!_isSpeechUiEpochCurrent(epoch)) return;
      if (Platform.isAndroid && _isFullAIChatMode) {
        await _speech.isRecognizing();
      }
      if (!_isSpeechUiEpochCurrent(epoch)) return;
      setState(() {
        _isTtsSpeaking = false;
        _message = 'Listening...';
        _currentSpeechSentence = 'Listening...';
      });
    } catch (error) {
      if (_isSpeechUiEpochCurrent(epoch)) {
        setState(
          () => _message =
              'Microphone did not reopen. Choose Mode and try again.',
        );
      }
    } finally {
      if (_isSpeechUiEpochCurrent(epoch)) _suppressSpeechResults = false;
    }
  }

  void _scheduleSpeechEchoTimeout() {
    _speechSilenceTimer?.cancel();
    _speechSilenceTimer = Timer(_speechSilenceTimeout, () {
      unawaited(_repeatTranscriptAfterSilence());
    });
  }

  void _scheduleAIChatTimeout() {
    _speechSilenceTimer?.cancel();
    _speechSilenceTimer = Timer(_speechSilenceTimeout, () {
      final text = _lastTranscript.trim();
      if (text.isEmpty || _isAIChatLoading || !_isFullAIChatMode) return;
      unawaited(_answerLikeVoiceAssistant(text));
    });
  }

  Future<void> _repeatTranscriptAfterSilence() async {
    if (!_speechEchoSessionActive || _isTtsSpeaking) return;
    final text = _lastTranscript.trim();
    if (text.isEmpty || !_speechResultsAllowed || !_speechEchoSessionActive) {
      return;
    }
    final speechUiEpoch = _beginSpeechUiEpoch();
    setState(() {
      _currentSpeechSentence = 'Speaking now: $text';
      _message = 'Speaking what you said...';
      _partialTranscript = '';
    });

    try {
      await _speakWhileSpeechPaused(
        text,
        speakerId: _speakerId,
        speed: _speakerSpeed,
      );
      if (!_isSpeechUiEpochCurrent(speechUiEpoch)) return;
      setState(() {
        _lastTranscript = '';
        _partialTranscript = '';
        _currentSpeechSentence = '';
        _message = 'Listening...';
        _isTtsSpeaking = false;
      });
      await _resumeSpeechAfterTts();
    } catch (error) {
      if (!_isSpeechUiEpochCurrent(speechUiEpoch)) return;
      setState(() {
        _isTtsSpeaking = false;
        _message = 'Speech repeat failed: $error';
      });
    }
  }

  Future<void> _stopSpeakerVerificationVerify() async {
    _svElapsedTimer?.cancel();
    _svElapsedTimer = null;
    await _svVerifyResultSub?.cancel();
    _svVerifyResultSub = null;
    await _svVerifyErrorSub?.cancel();
    _svVerifyErrorSub = null;
    final controller = _svVerifyController;
    _svVerifyController = null;
    if (controller != null) {
      try {
        await controller.stop();
      } catch (_) {}
      try {
        await controller.destroy();
      } catch (_) {}
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy || !mounted) return;
    final busyEpoch = ++_busyEpoch;
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (error) {
      _log('ERROR: $error');
      if (!mounted || busyEpoch != _busyEpoch) return;
      setState(() {
        _message = error.toString();
        if (_stage == _Stage.preparing) _setupFailed = true;
      });
    } finally {
      if (mounted && busyEpoch == _busyEpoch) setState(() => _isBusy = false);
    }
  }

  Future<File> _enrollmentJsonFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/sv_enrollment.json');
  }

  Future<void> _loadSavedEnrollmentJson() async {
    final file = await _enrollmentJsonFile();
    _log('loadEnrollmentJsonFromFile path=${file.path}');
    if (!await file.exists()) {
      _savedEnrollmentJson = null;
      _savedEnrollmentJsonPath = null;
      return;
    }

    final enrollmentJson = (await file.readAsString()).trim();
    if (enrollmentJson.length < 10) {
      _savedEnrollmentJson = null;
      _savedEnrollmentJsonPath = null;
      return;
    }

    _savedEnrollmentJson = enrollmentJson;
    _savedEnrollmentJsonPath = file.path;
    _log('loaded enrollment json len=${enrollmentJson.length}');
  }

  Future<void> _ensureMicPermission() async {
    final current = await Permission.microphone.status;
    _log('Microphone permission current=$current');
    if (current.isGranted) return;

    final requested = await Permission.microphone.request();
    _log('Microphone permission requested=$requested');
    if (!requested.isGranted) {
      throw StateError(
        'Microphone permission was not granted. Speaker verification, wake word, and speech recognition cannot use the microphone.',
      );
    }
  }

  Future<void> _ensureSpeechRecognitionPermission() async {
    final current = await Permission.speech.status;
    _log('iOS speech recognition permission current=$current');
    if (current.isGranted) return;

    final requested = await Permission.speech.request();
    _log('iOS speech recognition permission requested=$requested');
    if (!requested.isGranted) {
      throw StateError(
        'iOS Speech Recognition permission was not granted. Transcription cannot run.',
      );
    }
  }

  Future<_SVStepResult> _waitForNextSVStep(
    String controllerId,
    int beforeCollected,
    Completer<String> doneCompleter,
  ) {
    if (doneCompleter.isCompleted) {
      return Future.value(_SVStepResult.done);
    }

    final completer = Completer<_SVStepResult>();
    Timer? timeout;
    StreamSubscription<Map<String, dynamic>>? progressSub;
    StreamSubscription<Map<String, dynamic>>? doneSub;
    StreamSubscription<Map<String, dynamic>>? errorSub;

    Future<void> cleanup() async {
      timeout?.cancel();
      await progressSub?.cancel();
      await doneSub?.cancel();
      await errorSub?.cancel();
    }

    void complete(_SVStepResult result) {
      if (completer.isCompleted) return;
      completer.complete(result);
      unawaited(cleanup());
    }

    void completeError(Object error) {
      if (completer.isCompleted) return;
      completer.completeError(error);
      unawaited(cleanup());
    }

    progressSub = onSpeakerVerificationOnboardingProgress((event) {
      if (event['controllerId'] != controllerId) return;
      final collected = _readInt(event['collected'], beforeCollected);
      if (collected > beforeCollected) {
        complete(_SVStepResult.progress);
      }
    });

    doneSub = onSpeakerVerificationOnboardingDone((event) {
      if (event['controllerId'] != controllerId) return;
      complete(_SVStepResult.done);
    });

    errorSub = onSpeakerVerificationError((event) {
      if (event['controllerId'] != controllerId) return;
      completeError(StateError('Speaker verification error: $event'));
    });

    timeout = Timer(const Duration(seconds: 30), () {
      completeError(
        TimeoutException(
          'Timed out waiting for speaker verification progress. Check microphone permission and speak into the device.',
        ),
      );
    });

    return completer.future;
  }

  _SVStepResult _handleSVStepPayload(
    dynamic payload,
    int beforeCollected,
    Completer<String> doneCompleter,
  ) {
    if (payload is! Map) {
      return _SVStepResult.progress;
    }

    final event = Map<String, dynamic>.from(payload);

    final collected = _readInt(event['collected'], _svCollected);
    final target = _readInt(event['target'], _svTarget);
    if (mounted) {
      setState(() {
        _svCollected = collected;
        _svTarget = target;
        _message = 'Collected $_svCollected/$_svTarget voice samples.';
      });
    } else {
      _svCollected = collected;
      _svTarget = target;
    }

    final json =
        event['enrollmentJson'] ?? event['enrollment'] ?? event['json'];
    if (json is String && json.length > 10 && !doneCompleter.isCompleted) {
      doneCompleter.complete(json);
      return _SVStepResult.done;
    }

    final eventName = event['event'] ?? event['eventName'] ?? event['type'];
    if (eventName == 'onSpeakerVerificationOnboardingDone') {
      if (!doneCompleter.isCompleted) {
        doneCompleter.completeError(
          StateError('Onboarding completed without enrollment JSON.'),
        );
      }
      return _SVStepResult.done;
    }

    return _SVStepResult.progress;
  }

  void _log(String message) {
    debugPrint('[DavoiceExample] $message');
  }

  Future<String> _writeEnrollmentJsonToFile(String enrollmentJson) async {
    final file = await _enrollmentJsonFile();
    await file.writeAsString(enrollmentJson, flush: true);
    _log('wrote enrollment json to ${file.path} len=${enrollmentJson.length}');
    return file.path;
  }

  Future<void> _pauseWakeWordDetection() async {
    final wakeword = _wakeword;
    if (wakeword == null) return;
    if (!await wakeword.pauseDetection(stopMic: false)) {
      throw StateError('Could not pause wake-word detection.');
    }
  }

  Future<void> _unPauseWakeWordDetection() async {
    final wakeword = _wakeword;
    if (wakeword == null) return;
    if (!await wakeword.unPauseDetection()) {
      throw StateError('Could not resume wake-word detection.');
    }
  }

  Future<void> _captureWakeWordRecordingPaths() async {
    final wakeword = _wakeword;
    if (wakeword == null) return;
    try {
      await wakeword.getRecordingWav();
      if (Platform.isAndroid) {
        await wakeword.getRecordingWavArray();
      }
    } catch (_) {}
  }

  String get _selectedTtsModel {
    if (_usesSharedTtsModel) {
      return 'assets/models/model_ex2_rich_hanna_ariana.dm';
    }
    if (_voiceChoice == _VoiceChoice.rich) {
      return 'assets/models/model_ex2_rich.dm';
    }
    return _voiceChoice == _VoiceChoice.hanna
        ? 'assets/models/model_ex_hanna_light_davoice_ph.dm'
        : 'assets/models/model_ex_ariana_fast_davoice_phoneme.dm';
  }

  String? _appliedTtsVoice;

  Future<void> _applySelectedTtsVoice() async {
    if (!_usesSharedTtsModel && _voiceChoice != _VoiceChoice.rich) return;
    final voice = _voiceName;
    if (_appliedTtsVoice == voice) return;
    final result = await _speech.changeVoice(voice);
    if (result != 0) {
      throw StateError('Could not select the $voice voice.');
    }
    _appliedTtsVoice = voice;
  }

  String get _wakewordModel => 'assets/models/hey_coach_model_28_22012026b.dm';
  String get _speakerModel => 'assets/models/sv.dm';

  String get _voiceName {
    switch (_voiceChoice) {
      case _VoiceChoice.hanna:
        return 'Hanna';
      case _VoiceChoice.ariana:
        return 'Ariana';
      case _VoiceChoice.rich:
        return 'Rich';
    }
  }

  String get _otherVoiceNames {
    return _VoiceChoice.values
        .where((voice) => voice != _voiceChoice)
        .map(_voiceNameForChoice)
        .join(' or ');
  }

  String _voiceNameForChoice(_VoiceChoice voice) {
    switch (voice) {
      case _VoiceChoice.hanna:
        return 'Hanna';
      case _VoiceChoice.ariana:
        return 'Ariana';
      case _VoiceChoice.rich:
        return 'Rich';
    }
  }

  double get _speakerSpeed {
    switch (_voiceChoice) {
      case _VoiceChoice.hanna:
        return _usesSharedTtsModel ? _hannaSpeakerSpeed : 0.9;
      case _VoiceChoice.ariana:
        return _usesSharedTtsModel ? _arianaSpeakerSpeed : 0.88;
      case _VoiceChoice.rich:
        return _richSpeakerSpeed;
    }
  }

  static int _readInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double _scoreForSVUI(double? score, bool nativeMatch) {
    final now = DateTime.now();
    final currentScore = score;
    final wasInHold =
        _svMatchHoldUntil != null && now.isBefore(_svMatchHoldUntil!);

    if (nativeMatch && !wasInHold) {
      _svHeldScores.clear();
    }
    if (currentScore != null && (nativeMatch || wasInHold)) {
      _svHeldScores.add(_SVHeldScore(now, currentScore));
      _svHeldScores.removeWhere(
        (item) => now.difference(item.time) > _svMatchHold,
      );
    }
    if (nativeMatch) {
      _svMatchHoldUntil = now.add(_svMatchHold);
    }

    final inHold =
        _svMatchHoldUntil != null && now.isBefore(_svMatchHoldUntil!);
    if (inHold && _svHeldScores.isNotEmpty) {
      return _svHeldScores
          .map((item) => item.score)
          .reduce((value, element) => value > element ? value : element);
    }
    return currentScore ?? double.nan;
  }

  static bool _matchForSVUI(double score, bool nativeMatch) {
    if (Platform.isAndroid) {
      return score.isFinite && score >= _androidSvUiMatchThreshold;
    }
    return nativeMatch;
  }

  static double _displayScoreForSVUI(double score, bool nativeMatch) {
    if (!_matchForSVUI(score, nativeMatch) || !score.isFinite) return score;
    final fixed = score.toStringAsFixed(3);
    final suffix = fixed.length >= 2 ? fixed.substring(fixed.length - 2) : '00';
    return double.tryParse('0.9$suffix') ?? score;
  }

  static String _formatWakeWord(String fileOrPhrase) {
    final name = fileOrPhrase.split('/').last.split('.').first;
    return name
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .takeWhile((part) => part.toLowerCase() != 'model')
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar:
          (_stage == _Stage.home || _stage == _Stage.ttsTest) && !_wakeWordArmed
          ? SafeArea(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => unawaited(_goBackToModeSelection()),
                    child: const Text('Choose Mode'),
                  ),
                  if (_isTtsSpeaking || _isAIChatLoading)
                    TextButton(
                      onPressed: () => unawaited(_stopPlayback()),
                      child: const Text('Stop'),
                    ),
                  if (_isFullAIChatMode)
                    TextButton(
                      onPressed: _showChatHistory,
                      child: const Text('Chat History'),
                    ),
                ],
              ),
            )
          : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(color: _rnBackground),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildStage(context),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context) {
    switch (_stage) {
      case _Stage.preparing:
        return _PromptShell(
          message: _message,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PromptTitle('Voice Demo'),
              if (_isBusy) const LinearProgressIndicator(),
              if (!_narration.skipped)
                TextButton(
                  onPressed: _skipNarration,
                  child: const Text('Skip Narration'),
                ),
              if (_setupFailed && !_isBusy) ...[
                TextField(
                  controller: _licenseController,
                  decoration: InputDecoration(
                    labelText: 'Davoice license key',
                    helperText: _licenseSource,
                  ),
                ),
                _PrimaryButton(label: 'Retry setup', onPressed: _startDemo),
              ],
            ],
          ),
        );
      case _Stage.voicePicker:
        return _PromptShell(
          message: _isBusy ? 'Preparing your voice...' : _message,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PromptTitle('Choose Voice'),
              const SizedBox(height: 10),
              const SizedBox(height: 10),
              const Text(
                'Choose the voice for your demo.',
                textAlign: TextAlign.center,
                style: _Styles.body,
              ),
              const SizedBox(height: 18),
              _OptionLabel('Voice'),
              _SegmentedButtons(
                children: [
                  _ChoiceButton(
                    label: 'Hanna',
                    selected: _voiceChoice == _VoiceChoice.hanna,
                    onPressed: _isBusy
                        ? null
                        : () {
                            setState(() => _voiceChoice = _VoiceChoice.hanna);
                          },
                  ),
                  _ChoiceButton(
                    label: 'Rich',
                    selected: _voiceChoice == _VoiceChoice.rich,
                    onPressed: _isBusy
                        ? null
                        : () {
                            setState(() => _voiceChoice = _VoiceChoice.rich);
                          },
                  ),
                  _ChoiceButton(
                    label: 'Ariana',
                    selected: _voiceChoice == _VoiceChoice.ariana,
                    onPressed: _isBusy
                        ? null
                        : () {
                            setState(() => _voiceChoice = _VoiceChoice.ariana);
                          },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _PrimaryButton(
                label: _isBusy ? 'Preparing...' : 'Continue',
                onPressed: _isBusy ? null : () => _continueFromVoicePicker(),
              ),
            ],
          ),
        );
      case _Stage.svPrompt:
        final hasSavedEnrollment = _savedEnrollmentJsonPath != null;
        return _PromptShell(
          message: _message,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PromptTitle(
                hasSavedEnrollment
                    ? 'Use Saved Signature?'
                    : 'Enable Speaker Verification?',
              ),
              const SizedBox(height: 10),
              Text(
                hasSavedEnrollment
                    ? 'Use the saved speaker signature, create a new one, or skip speaker verification.'
                    : 'Create a speaker signature now, or skip speaker verification.',
                style: _Styles.body,
              ),
              const SizedBox(height: 20),
              if (hasSavedEnrollment) ...[
                _PrimaryButton(
                  label: 'Use Saved Signature',
                  onPressed: _isBusy
                      ? null
                      : () => _useSavedSpeakerVerification(),
                ),
                const SizedBox(height: 10),
              ],
              _PrimaryButton(
                label: hasSavedEnrollment
                    ? 'Create New Signature'
                    : 'Create Signature',
                onPressed: _isBusy
                    ? null
                    : () => _runSpeakerVerificationOnboarding(),
              ),
              const SizedBox(height: 10),
              _SecondaryButton(
                label: 'Skip',
                onPressed: _isBusy ? null : () => _skipSpeakerVerification(),
              ),
            ],
          ),
        );
      case _Stage.svStatus:
        final isOnboarding = _svStatusPhase == _SVStatusPhase.onboarding;
        return _PromptShell(
          message: _message,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isOnboarding) ...[
                const _PromptTitle('Speaker Verification'),
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: _svTarget == 0 ? 0 : _svCollected / _svTarget,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 12),
                Text(
                  'Samples $_svCollected/$_svTarget',
                  style: _Styles.bodyStrong,
                ),
              ] else ...[
                const _PromptTitle('Speaker Verification Running'),
                const SizedBox(height: 10),
                const Text(
                  'Say a few words to verify this speaker signature.',
                  style: _Styles.body,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Last Score',
                        value: _lastSvScore?.toStringAsFixed(3) ?? 'N/A',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        label: 'Match',
                        value: _lastSvMatch == null
                            ? 'N/A'
                            : (_lastSvMatch! ? 'YES' : 'NO'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        label: 'Since Last',
                        value: _svElapsed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _PrimaryButton(
                  label: _svStatusCanContinue ? 'Continue' : 'Waiting...',
                  onPressed: !_svStatusCanContinue || _isBusy
                      ? null
                      : () => _continueAfterSpeakerVerification(),
                ),
              ],
            ],
          ),
        );
      case _Stage.modePicker:
        return _PromptShell(
          message: _isSwitchingMode
              ? 'Opening mode...'
              : _message.startsWith('Could not')
              ? _message
              : '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PromptTitle('Choose Mode'),
              const SizedBox(height: 18),
              _ModeButton(
                title: 'Full AI Chat',
                description: 'STT → Gemini → TTS',
                selected: _appModeChoice == _AppModeChoice.fullAiChat,
                onPressed: () {
                  unawaited(_selectMode(_AppModeChoice.fullAiChat));
                },
              ),
              const SizedBox(height: 10),
              _ModeButton(
                title: 'Combined STT + TTS',
                description: 'Speak → hear it back',
                selected: _appModeChoice == _AppModeChoice.combined,
                onPressed: () {
                  unawaited(_selectMode(_AppModeChoice.combined));
                },
              ),
              const SizedBox(height: 10),
              _ModeButton(
                title: 'STT Only',
                description: 'Show transcript, no playback',
                selected: _appModeChoice == _AppModeChoice.sttOnly,
                onPressed: () {
                  unawaited(_selectMode(_AppModeChoice.sttOnly));
                },
              ),
              const SizedBox(height: 10),
              _ModeButton(
                title: 'Type to TTS',
                description: 'Type text → hear it spoken',
                selected: _appModeChoice == _AppModeChoice.typeToTts,
                onPressed: () {
                  unawaited(_selectMode(_AppModeChoice.typeToTts));
                },
              ),
            ],
          ),
        );
      case _Stage.ttsTest:
        return _TtsTestScreen(
          voiceName: _voiceName,
          controller: _ttsController,
          isSpeaking: _isManualTtsSpeaking || _isBusy,
          onSpeak: () => _speakManualText(),
          onBack: () => unawaited(_goBackToModeSelection()),
          onClear: _ttsController.clear,
        );
      case _Stage.home:
        return _HomeScreen(
          message: _message,
          voiceName: _voiceName,
          wakeWord: _lastWakeWord,
          speechMode: _speechEchoSessionActive ? _appModeChoice : null,
          isFullAIChatMode: _isFullAIChatMode,
          currentSpeechSentence: _currentSpeechSentence,
          introScript: _introScript,
          aiChatResponse: _aiChatResponse,
          lastTranscript: _lastTranscript,
          partialTranscript: _partialTranscript,
          introSpeaking: _isIntroSpeaking,
        );
    }
  }
}

class _PromptShell extends StatelessWidget {
  const _PromptShell({required this.child, required this.message});

  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        child: Column(
          children: [
            const _Logo(),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: _rnCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _rnSoftBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    child,
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: _Styles.body,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({
    required this.message,
    required this.voiceName,
    required this.wakeWord,
    required this.speechMode,
    required this.isFullAIChatMode,
    required this.currentSpeechSentence,
    required this.introScript,
    required this.aiChatResponse,
    required this.lastTranscript,
    required this.partialTranscript,
    required this.introSpeaking,
  });

  final String message;
  final String voiceName;
  final String wakeWord;
  final _AppModeChoice? speechMode;
  final bool isFullAIChatMode;
  final String currentSpeechSentence;
  final String introScript;
  final String aiChatResponse;
  final String lastTranscript;
  final String partialTranscript;
  final bool introSpeaking;

  @override
  Widget build(BuildContext context) {
    final active = isFullAIChatMode || speechMode != null;
    final title = isFullAIChatMode
        ? 'Full AI Chat'
        : speechMode == _AppModeChoice.combined
        ? 'Combined STT + TTS'
        : speechMode == _AppModeChoice.sttOnly
        ? 'STT Only'
        : 'Say "$wakeWord"';
    return _PromptShell(
      message: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PromptTitle(title),
          if (!active) ...[
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: _Styles.body),
          ] else ...[
            _InfoBlock(label: 'Speaker', value: voiceName),
            _InfoBlock(label: 'Status', value: message),
            _InfoBlock(
              label: isFullAIChatMode ? 'Transcript' : 'Current sentence',
              value: partialTranscript.isNotEmpty
                  ? partialTranscript
                  : currentSpeechSentence.isNotEmpty
                  ? currentSpeechSentence
                  : 'Listening...',
            ),
            if (isFullAIChatMode && aiChatResponse.isNotEmpty)
              _InfoBlock(label: 'Gemini reply', value: aiChatResponse),
            if (!isFullAIChatMode &&
                lastTranscript.isNotEmpty &&
                lastTranscript != partialTranscript &&
                lastTranscript != currentSpeechSentence)
              _InfoBlock(label: 'Last sentence', value: lastTranscript),
          ],
        ],
      ),
    );
  }
}

class _TtsTestScreen extends StatelessWidget {
  const _TtsTestScreen({
    required this.voiceName,
    required this.controller,
    required this.isSpeaking,
    required this.onSpeak,
    required this.onBack,
    required this.onClear,
  });

  final String voiceName;
  final TextEditingController controller;
  final bool isSpeaking;
  final VoidCallback onSpeak;
  final VoidCallback onBack;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _PromptShell(
      message: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PromptTitle('TTS Test Mode'),
          const SizedBox(height: 8),
          Text(voiceName, textAlign: TextAlign.center, style: _Styles.body),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Write text to speak...',
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: isSpeaking ? 'Speaking...' : 'Speak',
            onPressed: isSpeaking ? null : onSpeak,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(label: 'Clear', onPressed: onClear),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SecondaryButton(label: 'Back', onPressed: onBack),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 304),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x85101a2f),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x33ffffff)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4008101f),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Image.asset(
              'assets/images/logo.jpeg',
              height: 86,
              width: 270,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptTitle extends StatelessWidget {
  const _PromptTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _Styles.title, textAlign: TextAlign.center);
  }
}

class _OptionLabel extends StatelessWidget {
  const _OptionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: _Styles.label),
    );
  }
}

class _SegmentedButtons extends StatelessWidget {
  const _SegmentedButtons({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i += 1) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: _buttonStyle(selected ? _rnGreen : const Color(0x33ffffff)),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.title,
    required this.description,
    required this.selected,
    required this.onPressed,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(
          color: selected ? const Color(0x66ffffff) : const Color(0x4dffffff),
          width: selected ? 2 : 1,
        ),
        foregroundColor: _rnText,
        backgroundColor: selected ? _rnGreen : const Color(0x33ffffff),
      ),
      onPressed: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, textAlign: TextAlign.center, style: _Styles.bodyStrong),
          const SizedBox(height: 4),
          Text(description, textAlign: TextAlign.center, style: _Styles.small),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: _buttonStyle(_rnBlue),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: _buttonStyle(const Color(0x33ffffff)),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _rnSoftFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _rnSoftBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _Styles.label),
            const SizedBox(height: 4),
            Text(value, style: _Styles.bodyStrong),
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _Styles.label),
          const SizedBox(height: 4),
          Text(value, style: _Styles.body),
        ],
      ),
    );
  }
}

ButtonStyle _buttonStyle(Color color) {
  return FilledButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0x33ffffff),
    disabledForegroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
  );
}

class _Styles {
  static const title = TextStyle(
    color: _rnText,
    fontSize: 24,
    height: 1.18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const body = TextStyle(
    color: _rnMutedText,
    fontSize: 16,
    height: 1.35,
    letterSpacing: 0,
  );
  static const bodyStrong = TextStyle(
    color: _rnText,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const label = TextStyle(
    color: Color(0xd9ffffff),
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );
  static const small = TextStyle(
    color: _rnMutedText,
    fontSize: 13,
    height: 1.3,
    letterSpacing: 0,
  );
}
