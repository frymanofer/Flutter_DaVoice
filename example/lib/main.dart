import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'agent/agent_pack.dart';
import 'agent/local_agent.dart';
import 'calories/calorie_log.dart';
import 'calories/calories_card.dart';
import 'flow/startup_narration.dart';
import 'flow/transcript.dart';
import 'local_llm/local_llm_service.dart';
import 'local_llm/model_picker.dart';
import 'text_field_menu.dart';
import 'voice_clone/voice_clone.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_davoice/flutter_davoice.dart';
import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';
import 'package:flutter_wake_word/flutter_wake_word.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Local AI Chat's behavior and data (assets/agent/), used synchronously later.
  await loadAgentPack();
  runApp(const DavoiceExampleApp());
}

const _speakerId = 0;
// Id of the app's single enrolled speaker (live speaker-verification API).
const _svSpeakerId = 'user';
const _sharedTtsModel = 'assets/models/model_ex2_rich_kate.dm';
const _svOnboardingSampleCount = 5;
const _androidSvUiMatchThreshold = 0.34;
final _svDecisionThreshold = Platform.isAndroid ? 0.34 : 0.35;
const _svMatchHold = Duration(milliseconds: 750);
// Same speeds as the RN example's src/tts/index.ts.
const _richSpeakerSpeed = 0.95; // RICH_SPEAKER_SPEED_NEW_MODEL
const _sharedModelSpeakerSpeed = 1.0; // KATE / ARIANA / HANNA_SPEAKER_SPEED_NEW_MODEL
const _clonedVoiceSpeed = 1.0; // CLONED_VOICE_SPEED
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
// Voice cloning (the RN example's clone* styles).
const _cloneNewVoiceColor = Color(0xffaf52de);
const _cloneDeleteColor = Color(0xd9ff3b30);
const _cloneRedColor = Color(0xffff3b30);
const _cloneStopColor = Color(0xffff9500);
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

/// The RN example's TTS_VOICE_OPTIONS: the built-in voices, in the same order.
/// Every voice is a speaker of the shared model (model_ex2_rich_kate.dm), and
/// so is every cloned voice (lib/voice_clone/voice_clone.dart).
const _builtInVoices = ['Ariana', 'Rich', 'Hanna', 'Kate', 'Jenny', 'Matthew', 'Gloria'];
const _defaultVoice = 'Rich';

enum _AppModeChoice { localAiChat, fullAiChat, combined, sttOnly, typeToTts }

enum _Stage {
  preparing,
  voicePicker,
  voiceClone,
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
  // A built-in voice or the name of a cloned voice.
  String _voiceChoice = _defaultVoice;
  // Voice cloning (lib/voice_clone/voice_clone.dart): the cloned voices found
  // in the cloned voices folder, and the "Clone a new Voice" screen.
  List<String> _clonedVoices = const [];
  String _clonedVoicesFolder = '';
  final _cloneNameController = TextEditingController();
  bool _cloneUseMicrophone = true;
  // Voice volume in percent (100 = the recording's loudness), sent as volume = percent / 100.
  int _cloneVolumePercent = defaultVoiceVolumePercent;
  bool _cloneRecording = false;
  double _cloneRecordSeconds = 0;
  double _cloneRecordPeak = 0;
  ({String path, String label})? _cloneAudio;
  bool _cloneBusy = false;
  String? _cloneError;
  VoiceCloneResult? _cloneResult;
  Timer? _cloneStatusTimer;
  // "Use Microphone" scrolls the clone screen down to the record button.
  final _cloneScrollController = ScrollController();
  final _cloneRecordButtonKey = GlobalKey();
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
  // Local AI Chat: on-device model (flutter_davoice_llm), same license as the
  // other DaVoice libraries.
  // The agent (lib/agent/local_agent.dart: web search, fillers, the calorie
  // tracker's tools) runs the turns. MCP server tools, if configured in
  // local.config.ts, are added at warm-up.
  final _calories = CalorieLog();
  late final _localLlm = LocalLlmService(
    licenseKey: () => _licenseController.text.trim(),
  );
  String? _mcpServerUrl;
  String? _mcpServerToken;
  Future<void>? _mcpToolsLoaded;
  String _localModelName = '';
  String _localModelStatus = '';
  int _localModelWarmUpSeq = 0;
  bool _localGenerationActive = false;

  bool get _isLocalAIChat => _appModeChoice == _AppModeChoice.localAiChat;

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
    _cloneStatusTimer?.cancel();
    if (_cloneRecording) unawaited(cancelVoiceRecording());
    _cloneNameController.dispose();
    _cloneScrollController.dispose();
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
      String? value(String name) => RegExp(
        name + r'''\s*=\s*['"]([^'"]*)['"]''',
      ).firstMatch(config)?.group(1)?.trim();
      // Local AI Chat's web search engine (all optional): WEB_SEARCH_ENGINE =
      // 'wikipedia' (default, no key) | 'tavily' | 'brave', plus the API keys.
      // Calorie demo: foods missing from the list are looked up on Wikipedia,
      // and first on USDA FoodData Central when USDA_API_KEY is set.
      await LocalAgent.setKeys(
        webSearchEngine: value('WEB_SEARCH_ENGINE'),
        tavilyApiKey: value('TAVILY_API_KEY'),
        braveApiKey: value('BRAVE_API_KEY'),
        usdaApiKey: value('USDA_API_KEY'),
      );
      // Optional remote MCP server for Local AI Chat's tools.
      _mcpServerUrl = value('MCP_SERVER_URL');
      _mcpServerToken = value('MCP_SERVER_TOKEN');
      final key = value('GEMINI_API_KEY');
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
          // Process the user's words into the model while they still speak,
          // so the reply only has to process the last few words.
          if (_isLocalAIChat) {
            unawaited(_localLlm.prefillForTurn(_localChatHistory(), merged));
          }
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
      final cloningChoices = _clonedVoices.isNotEmpty
          ? 'You can either clone a new voice, select from your cloned voices, or select from the built-in voices.'
          : 'You can either clone a new voice, or select from the built-in voices.';
      await _speakStartupNarration([
        'Hey there, My name is $_voiceName. In this application we will use my cloned voice in order to showcase our voice AI agent capabilities.',
        "Don't worry. I will be your personal guide to walk you through this demonstration step by step.",
        'First, please choose which voice you want to use. $cloningChoices',
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
        // Like the RN example: the wake word pauses (mic kept) while speech reloads.
        await _pauseWakeWordDetection();
        try {
          await _speech.destroyAll();
          await _initializeSpeech(null);
        } finally {
          await _unPauseWakeWordDetection();
        }
      }
      await _applySelectedTtsVoice();
      await _speakStartupNarration([
        'You selected $_voiceName.',
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
      final doneCompleter = Completer<String>();

      final errorSub = onSpeakerVerificationError((event) {
        if (event['controllerId'] != 'svMic1' || !mounted) return;

        if (!doneCompleter.isCompleted) {
          doneCompleter.completeError(
            StateError('${event['error'] ?? 'Speaker verification failed.'}'),
          );
        }

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
      String? completedEnrollmentPath;
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
          completedEnrollmentPath = event['enrollmentJsonPath']?.toString();
          if (!doneCompleter.isCompleted) doneCompleter.complete(json);
        } else if (!doneCompleter.isCompleted) {
          doneCompleter.completeError(
            StateError('Onboarding completed without enrollment JSON.'),
          );
        }
      });

      try {
        final enrollmentFile = await _enrollmentJsonFile();
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
          savePath: enrollmentFile.path,
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
        final enrollmentJsonPath = completedEnrollmentPath;
        if (enrollmentJsonPath != enrollmentFile.path ||
            !await enrollmentFile.exists()) {
          throw StateError(
            'Speaker profile was not saved at the requested path.',
          );
        }

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
      _log('Wake-word event received phrase=${phrase ?? model ?? 'unknown'}');
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
    // Match the React Native startWakewordDetection lifecycle exactly. Its
    // helper always stops the instance before starting it, including the first
    // start after creation.
    await wakeword.stopKeywordDetection(_wakewordInstanceId);
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
    if (!mounted) return;
    // React Native resumes this same detector immediately after Speech.initAll
    // and Speech.pauseSpeechRecognition. It remains active through the rest of
    // onboarding and narration; the Dart callback gate controls navigation.
    await _unPauseWakeWordDetection();
    _log('Wake-word detection resumed after Speech.initAll');
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
        speakerId: _svSpeakerId,
      ),
    );
    if (!mounted) {
      await _speech.destroyAll();
      return;
    }
    _loadedTtsModel = _selectedTtsModel;
    // Cloned voices: a (re)load forgets the folder, so set it again.
    final clonedVoices = await loadClonedVoices(_speech);
    if (!mounted) return;
    _updateClonedVoices(clonedVoices);
    await _applySelectedTtsVoice();
    await _speech.pauseSpeechRecognition();
  }

  Future<void> _finishSpeakerVerification() async {
    await _runBusy(() async {
      var enrollment = _enrollmentJsonPath;
      // Enroll the speaker into the already-running wake word and STT (live
      // API, like the RN example): no destroyAll()/initAll() and no wake-word
      // restart; both libraries apply the change immediately.
      try {
        await _applySpeakerVerificationChoice(enrollment);
      } catch (error) {
        _log('[SV] applying speaker verification failed: $error');
        enrollment = null;
        _enrollmentJsonPath = null;
        if (mounted) {
          setState(() => _message = 'Speaker verification could not be enabled. Continuing without it.');
        }
      }
      if (!mounted) return;
      await _speakStartupNarration([
        enrollment == null
            ? 'Speaker verification skipped.'
            : 'Speaker verification is ready!',
        'Now please say the wake word Hey Coach to continue.',
      ]);
      if (!mounted) return;
      setState(() {
        _wakeWordArmed = true;
        _stage = _Stage.home;
        _message = 'Say the wake word "Hey Coach" to continue.';
      });
    });
  }

  /// Live speaker verification: enrolls [enrollmentJsonPath] as the app's
  /// speaker in the running wake word and STT, or (null: skipped) clears any
  /// speaker left from an earlier run.
  Future<void> _applySpeakerVerificationChoice(String? enrollmentJsonPath) async {
    final wakeword = _wakeword;
    if (enrollmentJsonPath != null && enrollmentJsonPath.isNotEmpty) {
      _log('[SV] live addSpeaker $_svSpeakerId $enrollmentJsonPath');
      if (wakeword != null) {
        final wakewordIds = await wakeword.addSpeaker(_svSpeakerId, enrollmentJsonPath);
        _log('[SV] wake word speakers: $wakewordIds');
      }
      final sttIds = await _speech.addSpeaker(_svSpeakerId, enrollmentJsonPath);
      _log('[SV] STT speakers: $sttIds');
    } else {
      _log('[SV] skipped; clearing speakers');
      if (wakeword != null) await wakeword.setSpeakers(const []);
      await _speech.setSpeakers(const []);
    }
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
    if (_isBusy || _isHandlingWakeWord || !_wakeWordArmed) {
      _log(
        'Wake-word event ignored: busy=$_isBusy handling=$_isHandlingWakeWord armed=$_wakeWordArmed',
      );
      return;
    }
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
          'Now you can test the voice capabilities in five different ways. You can select a Local AI Chat that runs fully on this device, a full AI Chat using remote Gemini, or simply test Speech to Text and Text to Speech individually or a combination of both.',
        ]);
        if (!mounted) return;
        setState(() {
          _appModeChoice = _AppModeChoice.combined;
          _pendingWakeWordForModeChoice = wakeWord;
          _stage = _Stage.modePicker;
          _message =
              'Now you can choose from five options, a Local AI Chat on this device, a full AI Chat option, testing Speech to Text individually, testing Text to Speech individually, or a combination of both Speech to Text and Text to Speech.';
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
    if (_appModeChoice == _AppModeChoice.fullAiChat || _isLocalAIChat) {
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
      _message = _isLocalAIChat ? 'Speak with the on-device AI.' : 'Speak with Gemini.';
      _partialTranscript = 'Listening...';
      _currentSpeechSentence = 'Listening...';
      _aiChatResponse = '';
      _lastTranscript = '';
      _geminiConversation.clear();
    });
    // Load the model now, in the background, never in the middle of a turn.
    if (_isLocalAIChat) _warmUpLocalModel();
    await _speech.pauseSpeechRecognition();
    await _resumeSpeechAfterTts();
  }

  /// The Local AI Chat conversation so far, oldest first, in the agent's
  /// shape: a reply keeps its tool calls and results (the agent puts them
  /// before it, so later prompts show that actions are done by calling tools).
  List<Map<String, Object?>> _localChatHistory() => [
        for (final message in _chatHistory)
          {
            'role': message['role'],
            'text': message['text'] ?? '',
            if (message['tools'] != null) 'toolMessages': jsonDecode(message['tools']!),
          },
      ];

  /// Connects the MCP server from local.config.ts once (before the first
  /// warm-up: the tool list is part of the cached system prompt). A failure
  /// only logs; the calorie tools keep working.
  Future<void> _loadMcpTools() => _mcpToolsLoaded ??= () async {
        final url = _mcpServerUrl;
        if (url == null || url.isEmpty) return;
        try {
          final server = await connectMcpServer(
            Uri.parse(url),
            headers: {if ((_mcpServerToken ?? '').isNotEmpty) 'Authorization': 'Bearer $_mcpServerToken'},
            timeout: const Duration(seconds: 8),
          );
          _log('MCP server connected (${server.client.protocolEra}): ${server.tools.map((t) => t.name).join(', ')}');
          // They run on a remote server: the agent says a filler while they run.
          await _localLlm.setExternalTools(server.tools);
        } catch (error) {
          _log('MCP server unavailable: $error');
        }
      }();

  /// Downloads (if needed) and loads the selected on-device model, then
  /// prefills the system prompt. Runs when Local AI Chat opens and after a
  /// model switch; only the latest call updates the status.
  void _warmUpLocalModel() {
    final seq = ++_localModelWarmUpSeq;
    bool isLatest() => mounted && seq == _localModelWarmUpSeq;
    setState(() => _localModelStatus = 'Loading...');
    unawaited(_localLlm.store.selectedModel().then((model) {
      if (isLatest()) setState(() => _localModelName = model.displayName);
    }));
    unawaited(_calories.load());
    _loadMcpTools()
        .then((_) => _localLlm.warmUp(
          history: _localChatHistory(),
          onDownloadProgress: (fraction) {
            if (!isLatest()) return;
            setState(() {
              _localModelStatus = fraction >= 1
                  ? 'Loading...'
                  : 'Downloading ${(fraction * 100).round()}%';
            });
          },
        ))
        .then((model) async {
          if (!isLatest()) return;
          setState(() {
            _localModelName = model.displayName;
            _localModelStatus = 'Ready';
          });
          final deleted = await _localLlm.store.deleteUnusedModelFiles();
          if (deleted.isNotEmpty) _log('Deleted unused model files: $deleted');
        })
        .catchError((Object error) {
          _log('Local model warm-up failed: $error');
          if (isLatest()) {
            setState(() => _localModelStatus = 'Failed: ${_localErrorText(error)}');
          }
        });
  }

  static String _localErrorText(Object error) =>
      error is LocalLlmException ? error.message : error.toString();

  void _showLocalModelPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => LocalLlmModelPicker(
        store: _localLlm.store,
        isBusy: _isAIChatLoading,
        onSelected: (model) {
          setState(() => _localModelName = model.displayName);
          _warmUpLocalModel();
        },
      ),
    );
  }

  /// One Local AI Chat turn: streams the on-device reply and speaks each
  /// sentence as soon as it is complete. Errors are spoken as they are.
  Future<void> _answerWithLocalModel(String userText) async {
    final epoch = _speechUiEpoch;
    _isAIChatLoading = true;
    final history = _localChatHistory();
    _chatHistory.add({'role': 'user', 'text': userText});
    try {
      await _pauseSpeechForTts();
      if (!_isSpeechUiEpochCurrent(epoch)) return;

      final model = await _localLlm.store.selectedModel();
      if (!_localLlm.isModelReady(model.id)) {
        // Still downloading or loading: say so now rather than hold the turn.
        final status = _localModelStatus;
        final progress = RegExp(r'^Downloading (\d+)%').firstMatch(status);
        final String reply;
        if (status.startsWith('Failed')) {
          _warmUpLocalModel(); // retry the download/load
          reply =
              'The on-device model, ${model.displayName}, failed to load, so I am trying again. Please ask me again in a moment.';
        } else if (progress != null) {
          reply =
              'The on-device model, ${model.displayName}, is still downloading. It is ${progress.group(1)} percent done. Please ask me again when it is ready.';
        } else {
          reply =
              'The on-device model, ${model.displayName}, is still loading. Please ask me again in a moment.';
        }
        _chatHistory.add({'role': 'model', 'text': reply});
        setState(() {
          _aiChatResponse = reply;
          _currentSpeechSentence = 'Local AI: $reply';
          _message = 'Speaking Local AI reply...';
        });
        await _speakWhileSpeechPaused(reply, speakerId: _speakerId, speed: _speakerSpeed);
        return;
      }

      setState(() {
        _aiChatResponse = '';
        _currentSpeechSentence = 'Local AI is thinking...';
        _message = 'Generating local AI reply...';
        _partialTranscript = '';
      });
      await _applySelectedTtsVoice();
      if (!_isSpeechUiEpochCurrent(epoch)) return;

      var reply = '';
      var pendingSentence = '';
      var spoken = Future<void>.value();
      var toolMessages = const <Map<String, Object?>>[];
      String? webSource;
      var shown = '';
      late void Function(String) speakSentence;
      speakSentence = (String sentence) {
        final startsAfter = spoken;
        spoken = _speech.speak(
          _applyTtsTextPolicy(normalizeTextForSpeech(sentence)),
          speakerId: _speakerId,
          speed: _speakerSpeed,
        );
        // Show each sentence when its turn to be spoken comes, so the text
        // never runs ahead of the voice.
        unawaited(startsAfter.catchError((_) {}).then((_) {
          if (!mounted || !_isSpeechUiEpochCurrent(epoch)) return;
          shown = shown.isEmpty ? sentence : '$shown $sentence';
          setState(() {
            _aiChatResponse = shown;
            _currentSpeechSentence = 'Local AI: $sentence';
          });
        }));
      };

      _localGenerationActive = true;
      try {
        // The agent searches the web for time-sensitive questions ("who is the
        // president...") and looks up unknown foods online; meanwhile it sends
        // a short filler to say, so the wait isn't silent. Fillers aren't part
        // of the reply or the history.
        final turn = await _localLlm.generateReplyStream(history, userText, (delta) {
          if (!_isSpeechUiEpochCurrent(epoch)) return;
          reply += delta;
          final split = splitCompletedSentences(pendingSentence + delta);
          pendingSentence = split.remainder;
          split.completed.forEach(speakSentence);
          setState(() => _message = 'Streaming local AI reply...');
        }, onEvent: (event) {
          if (!_isSpeechUiEpochCurrent(epoch)) return;
          if (event.type == 'filler') {
            speakSentence(event.text);
          } else if (event.type == 'status' && event.json['status'] == 'searching') {
            setState(() => _message = 'Searching the web...');
          } else if (event.type == 'webSearch') {
            setState(() {
              _message = event.json['failed'] == true
                  ? 'Could not search online; answering from memory...'
                  : 'Searched online (${event.json['source']}); generating reply...';
            });
          }
        });
        toolMessages = turn.toolMessages;
        webSource = turn.webSearch?['source'] as String?;
      } finally {
        _localGenerationActive = false;
      }
      if (!_isSpeechUiEpochCurrent(epoch)) return;
      if (pendingSentence.trim().isNotEmpty) speakSentence(pendingSentence.trim());
      reply = reply.trim();
      _log('[AIChat][LOCAL_LLM] "$userText"${webSource == null ? '' : ' (searched $webSource)'} -> $reply');
      _chatHistory.add({
        'role': 'model',
        'text': reply,
        if (toolMessages.isNotEmpty) 'tools': jsonEncode(toolMessages),
      });
      setState(() {
        _lastTranscript = '';
        _message = 'Speaking Local AI reply...';
      });
      await spoken;
      // Everything was spoken: show the reply with its original formatting.
      if (_isSpeechUiEpochCurrent(epoch) && mounted) setState(() => _aiChatResponse = reply);
    } catch (error) {
      if (!_isSpeechUiEpochCurrent(epoch)) return;
      final friendlyReply = 'Local AI chat error: ${_localErrorText(error)}';
      _log(friendlyReply);
      _chatHistory.add({'role': 'model', 'text': friendlyReply});
      setState(() {
        _aiChatResponse = friendlyReply;
        _currentSpeechSentence = 'Local AI: $friendlyReply';
        _message = 'Local AI is unavailable.';
      });
      try {
        await _speakWhileSpeechPaused(friendlyReply, speakerId: _speakerId, speed: _speakerSpeed);
      } catch (_) {
        // Keep the error visible if speaking it also fails.
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

  Future<void> _answerLikeVoiceAssistant(String transcript) async {
    final cleaned = transcript.trim();
    if (cleaned.isEmpty ||
        _isAIChatLoading ||
        !_isFullAIChatMode ||
        _stage != _Stage.home) {
      return;
    }
    if (_isLocalAIChat) return _answerWithLocalModel(cleaned);
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
    if (_localGenerationActive) {
      unawaited(_localLlm.cancel().catchError((Object _) {}));
    }
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

  /// The RN example's getTTSVoiceConfig(...).model.
  String get _selectedTtsModel {
    return _sharedTtsModel;
  }

  String? _appliedTtsVoice;

  Future<void> _applySelectedTtsVoice() async {
    final voice = _voiceName;
    if (_appliedTtsVoice == voice) return;
    final result = await _speech.changeVoice(voice);
    if (result != 0) {
      throw StateError('Could not select the $voice voice.');
    }
    _appliedTtsVoice = voice;
  }

  // ---- Voice cloning screen ----

  void _updateClonedVoices(List<String> names) {
    if (!mounted) return;
    setState(() => _clonedVoices = names);
  }

  static String _errorText(Object error) =>
      error is PlatformException ? (error.message ?? error.code) : '$error';

  Future<void> _openVoiceCloneScreen() async {
    final folder = await clonedVoicesPath();
    if (!mounted) return;
    _cloneNameController.clear();
    setState(() {
      _clonedVoicesFolder = folder;
      _cloneUseMicrophone = true;
      _cloneVolumePercent = defaultVoiceVolumePercent;
      _cloneAudio = null;
      _cloneError = null;
      _cloneResult = null;
      _cloneRecordSeconds = 0;
      _cloneRecordPeak = 0;
      _stage = _Stage.voiceClone;
    });
  }

  Future<void> _closeVoiceCloneScreen() async {
    if (_cloneRecording) await _stopCloneRecording(discard: true);
    if (!mounted) return;
    setState(() => _stage = _Stage.voicePicker);
  }

  Future<void> _startCloneRecording() async {
    if (_cloneRecording) return;
    setState(() {
      _cloneError = null;
      _cloneResult = null;
      _cloneAudio = null;
    });
    try {
      // The wake word releases the microphone while the sample is recorded
      // (speech recognition is already paused on this screen).
      await _wakeword?.pauseDetection(stopMic: true);
      await startVoiceRecording();
      if (!mounted) return;
      setState(() {
        _cloneRecording = true;
        _cloneRecordSeconds = 0;
        _cloneRecordPeak = 0;
      });
      _cloneStatusTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
        try {
          final status = await getVoiceRecordingStatus();
          if (!mounted || !_cloneRecording) return;
          setState(() {
            _cloneRecordSeconds = status.seconds;
            _cloneRecordPeak = status.peak;
          });
          if (status.seconds >= maxRecordingSeconds) unawaited(_stopCloneRecording(discard: false));
        } catch (_) {
          // the next tick tries again
        }
      });
    } catch (error) {
      try {
        await _wakeword?.unPauseDetection();
      } catch (_) {}
      if (mounted) setState(() => _cloneError = 'Recording could not start: ${_errorText(error)}');
    }
  }

  Future<void> _stopCloneRecording({required bool discard}) async {
    if (!_cloneRecording) return;
    _cloneStatusTimer?.cancel();
    _cloneStatusTimer = null;
    if (mounted) {
      setState(() => _cloneRecording = false);
    } else {
      _cloneRecording = false;
    }
    try {
      if (discard) {
        await cancelVoiceRecording();
      } else {
        final recording = await stopVoiceRecording();
        if (mounted) {
          setState(() {
            _cloneAudio = (
              path: recording.path,
              label: 'Microphone recording (${recording.seconds.toStringAsFixed(1)} s)',
            );
            if (recording.seconds < 4) {
              _cloneError =
                  'The recording is very short. Record about $recommendedRecordingSeconds seconds for a good voice.';
            }
          });
        }
      }
    } catch (error) {
      if (mounted) setState(() => _cloneError = 'Recording failed: ${_errorText(error)}');
    } finally {
      try {
        await _wakeword?.unPauseDetection();
      } catch (_) {}
    }
  }

  Future<void> _pickCloneFile() async {
    setState(() {
      _cloneError = null;
      _cloneResult = null;
    });
    try {
      final file = await pickVoiceAudioFile();
      if (file != null && mounted) setState(() => _cloneAudio = (path: file.path, label: file.name));
    } catch (error) {
      if (mounted) setState(() => _cloneError = 'The file could not be opened: ${_errorText(error)}');
    }
  }

  Future<void> _createVoiceFromSample() async {
    final problem = voiceNameProblem(_cloneNameController.text, _builtInVoices);
    if (problem != null) {
      setState(() => _cloneError = problem);
      return;
    }
    final audio = _cloneAudio;
    if (audio == null) {
      setState(() => _cloneError = _cloneUseMicrophone ? 'Record your voice first.' : 'Choose an audio file first.');
      return;
    }
    setState(() {
      _cloneBusy = true;
      _cloneError = null;
      _cloneResult = null;
    });
    try {
      final result = await createClonedVoice(_speech, audio.path, _cloneNameController.text,
          volume: _cloneVolumePercent / 100);
      // A voice with the same name was replaced: select it again before it speaks.
      _appliedTtsVoice = null;
      final names = await loadClonedVoices(_speech);
      if (!mounted) return;
      setState(() => _cloneResult = result);
      _updateClonedVoices(names);
    } catch (error) {
      if (mounted) setState(() => _cloneError = 'The voice could not be created: ${_errorText(error)}');
    } finally {
      if (mounted) setState(() => _cloneBusy = false);
    }
  }

  // A new volume needs a new voice: clear the result so "Create Voice" shows
  // again (the same name replaces the voice).
  void _changeCloneVolume(int delta) {
    setState(() {
      _cloneVolumePercent = (_cloneVolumePercent + delta).clamp(minVoiceVolumePercent, maxVoiceVolumePercent);
      _cloneResult = null;
    });
  }

  Future<void> _listenToClonedVoice() async {
    final result = _cloneResult;
    if (result == null) return;
    try {
      // The narrator's voice is selected again before it next speaks.
      _appliedTtsVoice = null;
      await _speech.changeVoice(result.voice);
      await _speech.speak(
        _applyTtsTextPolicy('Hi! I am ${result.voice}. This is my new cloned voice.'),
        speed: _speedFor(result.voice),
      );
    } catch (error) {
      if (mounted) setState(() => _cloneError = 'The voice could not be played: ${_errorText(error)}');
    }
  }

  // Scrolls the clone screen so the record button sits near the bottom of the
  // screen, with the text to read above it (after this frame's layout).
  void _chooseMicrophoneSample() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final button = _cloneRecordButtonKey.currentContext?.findRenderObject();
      if (button == null || !button.attached || !_cloneScrollController.hasClients) return;
      final position = _cloneScrollController.position;
      final offset = RenderAbstractViewport.of(button).getOffsetToReveal(button, 1.0).offset + 32;
      _cloneScrollController.animateTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble(),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _playCloneSample() async {
    final audio = _cloneAudio;
    if (audio == null) return;
    try {
      // The whole sample, as recorded or uploaded.
      await _speech.playWav(audio.path, markAsLast: false);
    } catch (error) {
      if (mounted) setState(() => _cloneError = 'The recording could not be played: ${_errorText(error)}');
    }
  }

  Future<void> _confirmDeleteClonedVoice(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cloned Voice'),
        content: Text('Delete the voice "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xffff3b30)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _removeClonedVoice(name);
  }

  Future<void> _removeClonedVoice(String name) async {
    try {
      final names = await deleteClonedVoice(_speech, name);
      if (!mounted) return;
      _updateClonedVoices(names);
      if (_voiceChoice == name) setState(() => _voiceChoice = _defaultVoice);
      if (_appliedTtsVoice == name) {
        // The narrator was using it: back to the selected voice.
        _appliedTtsVoice = null;
        await _applySelectedTtsVoice();
      }
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Cloned Voice'),
          content: Text('The voice could not be deleted: ${_errorText(error)}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  void _chooseClonedVoice() {
    final result = _cloneResult;
    if (result == null) return;
    setState(() {
      _voiceChoice = result.voice;
      _stage = _Stage.voicePicker;
    });
  }

  String get _wakewordModel => 'assets/models/hey_coach_model_28_22012026b.dm';
  String get _speakerModel => 'assets/models/sv.dm';

  String get _voiceName => _voiceChoice;

  double get _speakerSpeed => _speedFor(_voiceChoice);

  /// The RN example's getTTSVoiceConfig(...).speed.
  static double _speedFor(String voice) {
    if (voice == 'Rich') return _richSpeakerSpeed;
    if (_builtInVoices.contains(voice)) return _sharedModelSpeakerSpeed;
    return _clonedVoiceSpeed;
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

  // Two per row, like the RN example's voice grid.
  Widget _voiceGrid(List<String> voices) {
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final voice in voices)
            SizedBox(
              width: (constraints.maxWidth - 10) / 2,
              child: _ChoiceButton(
                label: voice,
                selected: _voiceChoice == voice,
                onPressed: _isBusy ? null : () => setState(() => _voiceChoice = voice),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceCloneScreen() {
    final name = _cloneNameController.text.trim().toLowerCase();
    final existingClone = _clonedVoices.where((voice) => voice.toLowerCase() == name).firstOrNull;
    final seconds = _cloneRecordSeconds.floor();
    final recordClock = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final clipping = _cloneRecordPeak > 0.97;
    final audio = _cloneAudio;
    final result = _cloneResult;
    return _PromptShell(
      message: '',
      scrollController: _cloneScrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PromptTitle('Clone a New Voice'),
          const SizedBox(height: 10),
          const Text(
            'Record one person speaking for about $recommendedRecordingSeconds seconds, or upload a recording of one person speaking.',
            textAlign: TextAlign.center,
            style: _Styles.body,
          ),
          const SizedBox(height: 18),
          _OptionLabel('Voice Name'),
          TextField(
            controller: _cloneNameController,
            contextMenuBuilder: textFieldContextMenu,
            enabled: !_cloneBusy,
            style: const TextStyle(color: _rnText, fontSize: 16),
            decoration: const InputDecoration(hintText: 'For example: Dana'),
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            inputFormatters: [LengthLimitingTextInputFormatter(30)],
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _cloneError = null),
          ),
          const SizedBox(height: 8),
          Text(
            existingClone != null
                ? 'Replaces your cloned voice "$existingClone".'
                : 'The voice appears under this name in the voice list. Letters, digits, spaces and dashes.',
            style: _Styles.small,
          ),
          const SizedBox(height: 18),
          _OptionLabel('Voice Sample'),
          Row(
            children: [
              for (final mic in [true, false]) ...[
                if (!mic) const SizedBox(width: 10),
                Expanded(
                  child: _ChoiceButton(
                    label: mic ? 'Use Microphone' : 'Upload a File',
                    selected: _cloneUseMicrophone == mic,
                    onPressed: _cloneRecording || _cloneBusy
                        ? null
                        : () {
                            setState(() {
                              _cloneUseMicrophone = mic;
                              _cloneAudio = null;
                              _cloneError = null;
                              _cloneResult = null;
                            });
                            if (mic) _chooseMicrophoneSample();
                          },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          if (_cloneUseMicrophone) ...[
            const Text(
              'In a quiet room, read this text aloud in your natural voice, at a steady distance from the phone:',
              style: _Styles.small,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _rnSoftFill, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                voiceCloneReadingText,
                style: TextStyle(color: _rnText, fontSize: 16, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    recordClock,
                    style: const TextStyle(
                      color: _rnText,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      height: 10,
                      color: const Color(0x26ffffff),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _cloneRecordPeak.clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: ColoredBox(color: clipping ? _cloneRedColor : _rnGreen),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _cloneRecording
                  ? clipping
                      ? 'Too loud: move the phone a little further away.'
                      : _cloneRecordSeconds < recommendedRecordingSeconds
                          ? 'Keep reading: about $recommendedRecordingSeconds seconds is best.'
                          : 'Good. Stop when you finish the sentence.'
                  : 'Recording stops by itself after $maxRecordingSeconds seconds.',
              style: _Styles.small,
            ),
            const SizedBox(height: 10),
            FilledButton(
              key: _cloneRecordButtonKey,
              style: _buttonStyle(_cloneRecording ? _cloneStopColor : _cloneRedColor),
              onPressed: _cloneBusy
                  ? null
                  : () => unawaited(
                        _cloneRecording ? _stopCloneRecording(discard: false) : _startCloneRecording(),
                      ),
              child: Text(_cloneRecording ? 'Stop Recording' : audio != null ? 'Record Again' : 'Start Recording'),
            ),
          ] else ...[
            const Text(
              'A recording of one person speaking, without music: wav, mp3, m4a, aac, flac or ogg.',
              style: _Styles.small,
            ),
            const SizedBox(height: 10),
            _SecondaryButton(
              label: audio != null ? 'Choose Another File' : 'Choose Audio File',
              onPressed: _cloneBusy ? null : () => unawaited(_pickCloneFile()),
            ),
          ],
          const SizedBox(height: 14),
          if (audio != null && !_cloneRecording) ...[
            Row(
              children: [
                Expanded(
                  child: Text('Sample: ${audio.label}', style: const TextStyle(color: _rnText, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: _buttonStyle(const Color(0x33ffffff)).copyWith(
                    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                  onPressed: _cloneBusy ? null : () => unawaited(_playCloneSample()),
                  child: const Text('Play Recording'),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          _OptionLabel('Voice Volume'),
          Row(
            children: [
              SizedBox(
                width: 52,
                child: _ChoiceButton(
                  label: '−',
                  selected: false,
                  onPressed: _cloneBusy || _cloneVolumePercent <= minVoiceVolumePercent
                      ? null
                      : () => _changeCloneVolume(-voiceVolumeStep),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 64,
                child: Text(
                  '$_cloneVolumePercent%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _rnText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 52,
                child: _ChoiceButton(
                  label: '+',
                  selected: false,
                  onPressed: _cloneBusy || _cloneVolumePercent >= maxVoiceVolumePercent
                      ? null
                      : () => _changeCloneVolume(voiceVolumeStep),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _cloneVolumePercent == defaultVoiceVolumePercent
                ? 'Same loudness as the recording.'
                : '${(_cloneVolumePercent - 100).abs()}% ${_cloneVolumePercent > 100 ? 'louder' : 'quieter'} than the recording.',
            style: _Styles.small,
          ),
          const SizedBox(height: 14),
          if (_cloneError != null) ...[
            Text(_cloneError!, style: const TextStyle(color: Color(0xffff6b6b), fontSize: 14, height: 1.4)),
            const SizedBox(height: 6),
          ],
          if (result != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x1f34c759),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x6634c759)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Voice "${result.voice}" is ready.', style: _Styles.bodyStrong),
                  if (result.warnings.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'The recording has little clear speech, so the voice may not sound its best. For a better voice, record again for about $recommendedRecordingSeconds seconds in a quiet room.',
                      style: TextStyle(color: Color(0xffffb340), fontSize: 13, height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceButton(
                          label: 'Listen',
                          selected: false,
                          onPressed: () => unawaited(_listenToClonedVoice()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChoiceButton(label: 'Use This Voice', selected: true, onPressed: _chooseClonedVoice),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            _PrimaryButton(
              label: _cloneBusy ? 'Creating Voice...' : 'Create Voice',
              onPressed: _cloneBusy || _cloneRecording ? null : () => unawaited(_createVoiceFromSample()),
            ),
          const SizedBox(height: 10),
          _SecondaryButton(
            label: 'Back to Voices',
            onPressed: _cloneBusy ? null : () => unawaited(_closeVoiceCloneScreen()),
          ),
          const SizedBox(height: 14),
          Text(
            'Cloned voices folder: $_clonedVoicesFolder',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x73ffffff), fontSize: 11, height: 1.45),
          ),
        ],
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
                  contextMenuBuilder: textFieldContextMenu,
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
              const _PromptTitle('Choose Your Voice'),
              const SizedBox(height: 10),
              const Text(
                'Clone a new voice, select one of your cloned voices, or select a built-in voice before the demo starts.',
                textAlign: TextAlign.center,
                style: _Styles.body,
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: _buttonStyle(_cloneNewVoiceColor),
                onPressed: _isBusy ? null : () => unawaited(_openVoiceCloneScreen()),
                child: const Text('Clone a new Voice'),
              ),
              const SizedBox(height: 18),
              _OptionLabel('Cloned Voices'),
              if (_clonedVoices.isNotEmpty)
                _voiceGrid(_clonedVoices)
              else
                const Text('No cloned voices yet.', style: _Styles.small),
              if (_clonedVoices.contains(_voiceChoice)) ...[
                const SizedBox(height: 10),
                FilledButton(
                  style: _buttonStyle(_cloneDeleteColor),
                  onPressed: _isBusy ? null : () => unawaited(_confirmDeleteClonedVoice(_voiceChoice)),
                  child: Text('Delete "$_voiceChoice"'),
                ),
              ],
              const SizedBox(height: 18),
              _OptionLabel('Built-in Voices'),
              _voiceGrid(_builtInVoices),
              const SizedBox(height: 18),
              _PrimaryButton(
                label: _isBusy ? 'Preparing...' : 'Continue',
                onPressed: _isBusy ? null : () => _continueFromVoicePicker(),
              ),
            ],
          ),
        );
      case _Stage.voiceClone:
        return _buildVoiceCloneScreen();
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
                title: 'Local AI Chat',
                description: 'STT → on-device LLM → TTS',
                selected: _appModeChoice == _AppModeChoice.localAiChat,
                onPressed: () {
                  unawaited(_selectMode(_AppModeChoice.localAiChat));
                },
              ),
              const SizedBox(height: 10),
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
          isLocalAIChat: _isFullAIChatMode && _isLocalAIChat,
          localModelName: _localModelName,
          localModelStatus: _localModelStatus,
          onChangeLocalModel: _showLocalModelPicker,
          calorieStore: _calories,
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
  const _PromptShell({required this.child, required this.message, this.scrollController});

  final Widget child;
  final String message;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: SingleChildScrollView(
        controller: scrollController,
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
    this.isLocalAIChat = false,
    this.localModelName = '',
    this.localModelStatus = '',
    this.onChangeLocalModel,
    this.calorieStore,
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
  final bool isLocalAIChat;
  final String localModelName;
  final String localModelStatus;
  final VoidCallback? onChangeLocalModel;
  final CalorieLog? calorieStore;
  final String currentSpeechSentence;
  final String introScript;
  final String aiChatResponse;
  final String lastTranscript;
  final String partialTranscript;
  final bool introSpeaking;

  @override
  Widget build(BuildContext context) {
    final active = isFullAIChatMode || speechMode != null;
    final title = isLocalAIChat
        ? 'Local AI Chat'
        : isFullAIChatMode
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
            if (isLocalAIChat)
              Row(
                children: [
                  Expanded(
                    child: _InfoBlock(
                      label: 'Model',
                      value: [
                        localModelName.isEmpty ? '...' : localModelName,
                        if (localModelStatus.isNotEmpty) localModelStatus,
                      ].join(' · '),
                    ),
                  ),
                  TextButton(
                    onPressed: onChangeLocalModel,
                    child: const Text('Change'),
                  ),
                ],
              ),
            if (isLocalAIChat && calorieStore != null) CaloriesCard(store: calorieStore!),
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
              _InfoBlock(
                label: isLocalAIChat ? 'Local AI reply' : 'Gemini reply',
                value: aiChatResponse,
              ),
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
            contextMenuBuilder: textFieldContextMenu,
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
