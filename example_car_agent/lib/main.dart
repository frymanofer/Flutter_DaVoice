import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'agent/agent_pack.dart';
import 'agent/local_agent.dart';
import 'agent/remote_assistant.dart';
import 'calories/calorie_log.dart';
import 'car/car_tools.dart';
import 'car/speech_composer.dart';
import 'flow/app_language.dart';
import 'flow/fragments.dart';
import 'local_llm/demo.dart';
import 'speaker_verification/current_speaker.dart';
import 'flow/narration.dart';
import 'flow/transcript.dart';
import 'local_llm/confidence.dart';
import 'redesign/agent_loading_screen.dart';
import 'redesign/car_agent_screen.dart';
import 'redesign/install_speedometer_screen.dart';
import 'redesign/language_hood_screen.dart';
import 'redesign/speaker_screens.dart';
import 'redesign/theme.dart';
import 'redesign/voice_screen.dart';
import 'redesign/wake_word_screen.dart';
import 'redesign/voice_clone_screen.dart';
import 'speaker_verification/enrollment_sentences.dart';
import 'local_llm/local_llm_service.dart';
import 'local_llm/model_config.dart';
import 'local_llm/model_picker.dart';
import 'text_field_menu.dart';
import 'tts/language_packs.dart';
import 'tts/voice_styles.dart';
import 'voice_clone/voice_clone.dart';

import 'package:flutter/foundation.dart' show kDebugMode;
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
  await loadAgentPacks();
  await loadCarToolDefinitions();
  // Which languages' voices are built in and which are downloaded (assets/language_packs.json).
  await loadLanguagePacks();
  runApp(const DavoiceExampleApp());
}

const _speakerId = 0;
// Id of the app's single enrolled speaker (live speaker-verification API).
const _svSpeakerId = 'user';
// The TTS model per app language: built in or a downloaded language pack (lib/tts/language_packs.dart, as the RN example's
// src/tts/index.ts languageFile); every voice is a speaker of it.
const _brazilianSpeakerSpeed = 1.0; // BRAZILIAN_SPEAKER_SPEED
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

/// The English model's built-in voices, until the loaded model lists its own (speech.getAllVoices, like the RN example).
/// Every voice is a speaker of the language's model, and so is every cloned voice (lib/voice_clone/voice_clone.dart).
const _englishVoices = ['Ariana', 'Rich', 'Hanna', 'Kate', 'Jenny', 'Matthew', 'Gloria'];
const _defaultVoice = 'Rich';

enum _AppModeChoice { localAiChat, fullAiChat, combined, sttOnly, typeToTts }

enum _Stage {
  language,
  languageDownload,
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
      title: 'DaVoice Car',
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
        fontFamily: kFont,
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
        'Hello, I am one of the DaVoice voices. Type any text here and I will read it out loud, right on your phone.',
  );

  KeyWordFlutterPC? _wakeword;
  StreamSubscription<Map<String, dynamic>>? _wakewordSubscription;
  SpeakerVerificationMicController? _svController;
  SpeakerVerificationMicController? _svVerifyController;
  StreamSubscription<Map<String, dynamic>>? _svVerifyResultSub;
  StreamSubscription<Map<String, dynamic>>? _svVerifyErrorSub;
  Timer? _svElapsedTimer;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  // First of all: the language (it picks the TTS model, the voice-cloning encoder and the STT locale).
  _Stage _stage = _Stage.language;
  // The loaded model's built-in voices.
  List<String> _builtInVoices = _englishVoices;
  String? _loadedTtsModel;
  // A built-in voice or the name of a cloned voice.
  String _voiceChoice = _defaultVoice;
  // Voice cloning (lib/voice_clone/voice_clone.dart): the cloned voices found
  // in the cloned voices folder, and the "Clone a new Voice" screen.
  List<String> _clonedVoices = const [];
  // Emotion / style variants of each built-in voice (lib/tts/voice_styles.dart);
  // voices without any are not listed.
  Map<String, List<String>> _voiceAbilities = const {};
  String? _playingStyleExample;
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
  _SVStatusPhase _svStatusPhase = _SVStatusPhase.onboarding;
  bool _isBusy = false;
  int _busyEpoch = 0;
  bool _isFirstWakeWordCallback = true;
  bool _wakeWordArmed = false;
  bool _isHandlingWakeWord = false;
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
  String _aiChatResponse = '';
  // The last request was speech not meant for the assistant (command scope IGNORE): shown as heard, no reply box (as the RN example).
  String? _ignoredText;
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
  // config/local.config.ts, are added at warm-up.
  final _calories = CalorieLog();
  late final _localLlm = LocalLlmService(
    licenseKey: () => _licenseController.text.trim(),
  );
  String? _mcpServerUrl;
  String? _mcpServerToken;
  Future<void>? _mcpToolsLoaded;
  List<ToolDefinition> _mcpTools = const [];
  String _localModelName = '';
  String _localModelStatus = '';
  int _localModelWarmUpSeq = 0;
  // The Local AI Chat demo ('car' / 'calories') and the loading screen's stage timer (download / load / warm-up).
  // The car demo's Local confidence (core 2026-11-19; local_llm/confidence.dart): on / off, threshold 0..1 in 0.05 steps, fallback
  // clarify / remote / decline; persisted by the model store, sent to the agent before the next turn (no reload, no new session).
  ConfidenceSettings _localConfidence = ConfidenceSettings.defaults;
  // The last request's outcome and the model's score for its action (core 2026-11-19).
  TurnInfo _lastTurn = const TurnInfo();
  String _loadingStage = 'load';
  DateTime _loadingStageStartedAt = DateTime.now();
  Timer? _loadingTicker;
  bool _localGenerationActive = false;

  bool get _isLocalAIChat => _appModeChoice == _AppModeChoice.localAiChat;

  @override
  void initState() {
    super.initState();
    _loadGeminiApiKey();
    _listenToSpeechEvents();
    unawaited(_refreshReadyPacks());
    unawaited(_localLlm.store.localConfidence().then((v) {
      if (mounted) setState(() => _localConfidence = v);
    }));
    // The car agent: always the car demo (its pack, tools and car), as the React Native example_car_agent.
    unawaited(_localLlm.store.setDemo('car').catchError((Object e) => _log('could not save the demo choice: $e')));
  }

  @override
  void dispose() {
    _loadingTicker?.cancel();
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
      // Your keys (git-ignored, optional), else the committed template (placeholders: Full AI Chat then asks for a key).
      final config = await rootBundle.loadString('config/local.config.ts').catchError((Object _) => rootBundle.loadString('config/local.config.example.ts'));
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
      if (key != null && key.isNotEmpty) {
        // Local AI Chat's remote assistant uses AI Chat's Gemini settings.
        RemoteAssistant.configure(apiKey: key, model: _geminiModel, systemPrompt: _geminiSystemPrompt);
      }
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
        noteSpeechResult(event.speakerIds, event.speakerId);
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
          _message = 'Listening...';
        });
      }),
      _speech.onSpeechResults.listen((event) {
        noteSpeechResult(event.speakerIds, event.speakerId);
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
      await _prepareSpeechStep();
      if (!mounted) return;
      setState(() {
        _stage = _Stage.voicePicker;
        _message = '';
      });
    });
  }

  /// Between setup steps (as the React Native car agent's speakStartupNarration([])): no narration in this app, only the wake word
  /// disarmed, speech recognition paused and the selected voice applied.
  Future<void> _prepareSpeechStep() async {
    _wakeWordArmed = false;
    await _speech.pauseSpeechRecognition();
    await _applySelectedTtsVoice();
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
      await _prepareSpeechStep();
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
    final language = currentAppLanguage;
    Future<void> init() => _speech.initAll(
          DavoiceInitAllOptions(
            locale: appLanguageInfo(language).sttLocale,
            model: _selectedTtsModel,
            onboardingJsonPath: enrollmentJsonPath,
            speakerId: _svSpeakerId,
          ),
        );
    try {
      await init();
    } catch (error) {
      // A downloaded voice version that doesn't load (remote manifest update): back to the last working version, once.
      if (!isDownloadableLanguage(language) || !await rollbackLanguagePack(language)) rethrow;
      _log('[languagePacks] $language: the new voice files did not load, back to the last working version ($error)');
      await init();
    }
    if (isDownloadableLanguage(language)) unawaited(markLanguagePackWorking(language));
    if (!mounted) {
      await _speech.destroyAll();
      return;
    }
    _loadedTtsModel = _selectedTtsModel;
    final availableVoices = await _speech.getAllVoices();
    if (!mounted) return;
    // The model's own voices (each language's model has its own); keep the selection when it is one of them.
    setState(() {
      _builtInVoices = availableVoices.isNotEmpty ? availableVoices : [_defaultVoice];
      if (!_builtInVoices.contains(_voiceChoice) && !_clonedVoices.contains(_voiceChoice)) {
        // A TTS v1 language's own voice first (RN defaultTTSVoiceForLanguage), else Rich.
        final preferred = originalTtsVoices[currentAppLanguage] ?? _defaultVoice;
        _voiceChoice = _builtInVoices.contains(preferred)
            ? preferred
            : _builtInVoices.contains(_defaultVoice) ? _defaultVoice : _builtInVoices.first;
      }
    });
    final abilities = await loadVoiceAbilities(_speech, availableVoices);
    if (!mounted) return;
    _log('Voices with emotions / styles: $abilities');
    setState(() => _voiceAbilities = abilities);
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
      await _prepareSpeechStep();
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
      // Owner-only car actions (door_locks) need this voice from now on.
      setSpeakerGate(true, _svSpeakerId);
    } else {
      _log('[SV] skipped; clearing speakers');
      if (wakeword != null) await wakeword.setSpeakers(const []);
      await _speech.setSpeakers(const []);
      setSpeakerGate(false, null);
    }
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
        // Car agent (as the React Native example_car_agent): no mode menu and no narration; the first wake word opens the on-device
        // car agent.
        _appModeChoice = _AppModeChoice.localAiChat;
        await _switchLocalDemo('car', false);
        await _continueAfterWakeWordModeChoice(wakeWord);
        _isHandlingWakeWord = false;
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
        _isTtsSpeaking = false;
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

  Future<void> _enterSttOnlyMode(String wakeWord) async {
    _speechSilenceTimer?.cancel();
    setState(() {
      _stage = _Stage.home;
      _isFullAIChatMode = false;
      _speechEchoSessionActive = true;
      _isTtsSpeaking = false;
      _lastTranscript = '';
      _partialTranscript = '';
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
      _isTtsSpeaking = false;
      _message = _isLocalAIChat ? 'Speak with the on-device AI.' : 'Speak with Gemini.';
      _partialTranscript = 'Listening...';
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
            // a two-operation request (core 2026-11-13, as the RN example): replayed as its operations; older cores ignore it
            if (message['ops'] != null) 'operationTurns': jsonDecode(message['ops']!),
          },
      ];

  /// Connects the MCP server from config/local.config.ts once (before the first
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
          // They run on a remote server: the agent says a filler while they run (set with the car tools in the warm-up).
          _mcpTools = server.tools;
        } catch (error) {
          _log('MCP server unavailable: $error');
        }
      }();

  /// Downloads (if needed) and loads the selected on-device model, then
  /// prefills the system prompt. Runs when Local AI Chat opens and after a
  /// model switch; only the latest call updates the status.
  /// Sets the Local AI Chat status ('Loading...', 'Downloading N%', 'Warming up...', 'Ready', 'Failed: ...') and the loading
  /// screen's stage; the stage's seconds restart when it changes and tick until ready or failed.
  void _setLocalModelStatus(String status) {
    final stage = status.startsWith('Downloading')
        ? 'download'
        : status.startsWith('Warming')
        ? 'warmup'
        : status.startsWith('Failed')
        ? 'failed'
        : status == 'Ready'
        ? 'ready'
        : 'load';
    if (stage != _loadingStage) _loadingStageStartedAt = DateTime.now();
    _loadingStage = stage;
    _localModelStatus = status;
    if (stage == 'ready' || stage == 'failed') {
      _loadingTicker?.cancel();
      _loadingTicker = null;
    } else {
      _loadingTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Switches the Local AI Chat demo: the agent is re-created with that demo's pack; with [rewarm], the chat restarts on its model.
  Future<void> _switchLocalDemo(String demo, bool rewarm) async {
    if (demo == currentLocalDemo) return;
    await _localLlm.store.setDemo(demo);
    await LocalAgent.reset();
    if (rewarm) {
      _resetLocalChat();
      _warmUpLocalModel();
    }
  }

  /// Reset Chat: forgets the conversation (the model stays loaded).
  void _resetLocalChat() {
    _chatHistory.clear();
    setState(() {
      _aiChatResponse = '';
      _lastTranscript = '';
      _partialTranscript = '';
    });
  }

  void _warmUpLocalModel() {
    final seq = ++_localModelWarmUpSeq;
    bool isLatest() => mounted && seq == _localModelWarmUpSeq;
    setState(() => _setLocalModelStatus('Loading...'));
    unawaited(_localLlm.store.selectedModel().then((model) {
      if (isLatest()) setState(() => _localModelName = model.displayName);
    }));
    unawaited(_calories.load());
    _loadMcpTools()
        .then((_) async {
          // The car demo's tools in the wording the model was trained with; the calories demo has none (its skill is in its pack).
          final model = await _localLlm.store.selectedModel();
          final demoTools = currentLocalDemo == 'car' ? carTools(profile: localLlmCarTools, wording: model.toolWording ?? 'v1') : <ToolDefinition>[];
          await _localLlm.setExternalTools([...demoTools, ..._mcpTools], online: (t) => !carToolNames.contains(t.name));
        })
        .then((_) => _localLlm.warmUp(
          history: _localChatHistory(),
          onWarming: () {
            if (isLatest()) setState(() => _setLocalModelStatus('Warming up...'));
          },
          onDownloadProgress: (fraction) {
            if (!isLatest()) return;
            setState(() => _setLocalModelStatus(fraction >= 1 ? 'Loading...' : 'Downloading ${(fraction * 100).round()}%'));
          },
        ))
        .then((model) async {
          if (!isLatest()) return;
          setState(() {
            _localModelName = model.displayName;
            _setLocalModelStatus('Ready');
          });
          final deleted = await _localLlm.store.deleteUnusedModelFiles();
          if (deleted.isNotEmpty) _log('Deleted unused model files: $deleted');
        })
        .catchError((Object error) {
          _log('Local model warm-up failed: $error');
          if (isLatest()) {
            setState(() => _setLocalModelStatus('Failed: ${_localErrorText(error)}'));
          }
        });
  }

  static String _localErrorText(Object error) =>
      error is LocalLlmException ? error.message : error.toString();

  void _changeLocalConfidence(ConfidenceSettings next) {
    setState(() => _localConfidence = next);
    unawaited(_localLlm.store.setLocalConfidence(next));
  }

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

      // STT noise ("The.", "But.", "Alma Alma."): not sent to the model (flow/fragments.dart, same rules as the RN example).
      if (isNoiseFragment(userText)) {
        final reply = didNotCatch[currentAppLanguage] ?? didNotCatch['en']!;
        _log('noise fragment, asking to repeat: $userText');
        _chatHistory.add({'role': 'model', 'text': reply});
        setState(() {
          _aiChatResponse = reply;
        });
        await _speakWhileSpeechPaused(reply, speakerId: _speakerId, speed: _speakerSpeed);
        return;
      }

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
          _message = 'Speaking Local AI reply...';
        });
        await _speakWhileSpeechPaused(reply, speakerId: _speakerId, speed: _speakerSpeed);
        return;
      }

      setState(() {
        _aiChatResponse = '';
        _ignoredText = null;
        _message = 'Generating local AI reply...';
        _partialTranscript = '';
      });
      await _applySelectedTtsVoice();
      if (!_isSpeechUiEpochCurrent(epoch)) return;

      var reply = '';
      var pendingSentence = '';
      var heldSpeech = '';
      var spoken = Future<void>.value();
      var toolMessages = const <Map<String, Object?>>[];
      List<Object?>? operationTurns;
      String? webSource;
      var shown = '';
      late void Function(String) speakSentence;
      speakSentence = (String raw) {
        // Car demo: the model's bare "Done." is never a confirmation (the app says what it did) -> "didn't catch that".
        final sentence = currentLocalDemo == 'car' && isBareDone(raw) ? (didNotCatch[currentAppLanguage] ?? didNotCatch['en']!) : raw;
        // Straight to the speech queue: it prepares the next sentences while
        // this one plays. `spoken` completes when everything queued is spoken.
        spoken = _speech.speak(
          _applyTtsTextPolicy(normalizeTextForSpeech(sentence)),
          speakerId: _speakerId,
          speed: _speakerSpeed,
        );
        // Show the reply as it is generated, sentence by sentence.
        if (!mounted) return;
        shown = shown.isEmpty ? sentence : '$shown $sentence';
        setState(() {
          _aiChatResponse = shown;
        });
      };

      _localGenerationActive = true;
      try {
        // The agent searches the web for time-sensitive questions ("who is the
        // president...") and looks up unknown foods online; meanwhile it sends
        // a short filler to say, so the wait isn't silent. Fillers aren't part
        // of the reply or the history.
        if (_lastTurn.outcome != null) setState(() => _lastTurn = const TurnInfo());
        beginCarTurn();
        final turn = await _localLlm.generateReplyStream(history, userText, (delta) {
          if (!_isSpeechUiEpochCurrent(epoch)) return;
          reply += delta;
          // once a car action ran in this request, its sentences are held and said together at the end (speech_composer.dart)
          if (carTurnActions().isNotEmpty) {
            heldSpeech += delta;
            return;
          }
          final split = splitCompletedSentences(pendingSentence + delta);
          pendingSentence = split.remainder;
          split.completed.forEach(speakSentence);
          // Once per reply, not on every token: a rebuild per token slows the UI.
          if (_message != 'Streaming local AI reply...') {
            setState(() => _message = 'Streaming local AI reply...');
          }
        }, onEvent: (event) {
          if (!_isSpeechUiEpochCurrent(epoch)) return;
          if (event.type == 'filler') {
            speakSentence(event.text);
          } else if (event.type == 'status' && event.json['status'] == 'searching') {
            setState(() => _message = 'Searching the web...');
          } else if (event.type == 'status' && event.json['status'] == 'remote') {
            setState(() => _message = 'Asking the online assistant...');
          } else if (event.type == 'webSearch') {
            setState(() {
              _message = event.json['failed'] == true
                  ? 'Could not search online; answering from memory...'
                  : 'Searched online (${event.json['source']}); generating reply...';
            });
          }
        });
        // Command scope IGNORE (2026-11-15 brief): background talk, not for the assistant. No reply box, nothing said, and out of the
        // history the model sees; the finally block gives the microphone back.
        if (_isSpeechUiEpochCurrent(epoch)) setState(() => _lastTurn = TurnInfo.read(turn.json));
        if ((turn.json['scope'] as Map?)?['outcome'] == 'ignore' && reply.trim().isEmpty) {
          if (_chatHistory.isNotEmpty && _chatHistory.last['role'] == 'user') _chatHistory.removeLast();
          _log('[AIChat][LOCAL_LLM] ignored (${(turn.json['scope'] as Map)['reason'] ?? 'background'}): "$userText"');
          if (mounted) {
            setState(() {
              _ignoredText = userText;
              _message = 'Not for me: ignored.';
            });
          }
          return;
        }
        toolMessages = turn.toolMessages;
        operationTurns = turn.json['operationTurns'] as List?;
        webSource = turn.webSearch?['source'] as String?;
      } finally {
        _localGenerationActive = false;
      }
      if (!_isSpeechUiEpochCurrent(epoch)) return;
      if (pendingSentence.trim().isNotEmpty) speakSentence(pendingSentence.trim());
      if (heldSpeech.trim().isNotEmpty) {
        final composed = composeCarSpeech(heldSpeech, carTurnActions(), currentAppLanguage);
        if (composed != heldSpeech.trim()) _log('[AIChat][SPEECH] "${heldSpeech.trim()}" -> "$composed"');
        for (final sentence in splitCompletedSentences('$composed ').completed) {
          speakSentence(sentence);
        }
      }
      reply = reply.trim();
      _log('[AIChat][LOCAL_LLM] "$userText"${webSource == null ? '' : ' (searched $webSource)'} -> $reply');
      _chatHistory.add({
        'role': 'model',
        'text': reply,
        if (toolMessages.isNotEmpty) 'tools': jsonEncode(toolMessages),
        if (operationTurns != null) 'ops': jsonEncode(operationTurns),
      });
      setState(() {
        _lastTranscript = '';
        _message = 'Speaking Local AI reply...';
      });
      await spoken;
      // Everything was spoken: show the reply with its original formatting (the composed sentence when several actions ran).
      if (_isSpeechUiEpochCurrent(epoch) && mounted) setState(() => _aiChatResponse = heldSpeech.trim().isNotEmpty ? shown : reply);
    } catch (error) {
      if (!_isSpeechUiEpochCurrent(epoch)) return;
      final friendlyReply = 'Local AI chat error: ${_localErrorText(error)}';
      _log(friendlyReply);
      _chatHistory.add({'role': 'model', 'text': friendlyReply});
      setState(() {
        _aiChatResponse = friendlyReply;
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
        normalized.contains('config/local.config.ts')) {
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
      throw StateError('Gemini API key was not loaded from config/local.config.ts.');
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
              {'text': '$_geminiSystemPrompt ${llmReplyInstructionFor(currentAppLanguage)}'},
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
  String get _selectedTtsModel => languageFile(currentAppLanguage, 'model') ?? languageFile('en', 'model')!;

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

  // Plays an emotion / style example with its voice (the voice picked with
  // Continue is selected again before the narrator next speaks).
  Future<void> _playStyleExample(String voice, String text) async {
    if (_loadedTtsModel == null) return;
    setState(() => _playingStyleExample = text);
    try {
      _appliedTtsVoice = null;
      await _speech.stopSpeaking();
      await _speech.changeVoice(voice);
      await _speech.speak(_applyTtsTextPolicy(text), speed: _speedFor(voice));
    } catch (error) {
      _log('Style example failed: $error');
    } finally {
      if (mounted && _playingStyleExample == text) setState(() => _playingStyleExample = null);
    }
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
        _applyTtsTextPolicy(narration.cloneCreated(result.voice)),
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
  double _speedFor(String voice) {
    // Every voice of a non-English model, a cloned one included (RN getTTSVoiceConfig).
    if (currentAppLanguage != 'en') return _brazilianSpeakerSpeed;
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
      backgroundColor: C.bg,
      resizeToAvoidBottomInset: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(key: ValueKey(_stage), child: _buildStage(context)),
      ),
    );
  }

  Widget _buildVoiceCloneScreen() {
    final name = _cloneNameController.text.trim().toLowerCase();
    final result = _cloneResult;
    return VoiceCloneScreen(
      nameController: _cloneNameController,
      replaces: _clonedVoices.where((voice) => voice.toLowerCase() == name).firstOrNull,
      useMicrophone: _cloneUseMicrophone,
      readingText: voiceCloneReadingText,
      recommendedSeconds: recommendedRecordingSeconds,
      maxSeconds: maxRecordingSeconds,
      recording: _cloneRecording,
      recordSeconds: _cloneRecordSeconds,
      recordPeak: _cloneRecordPeak,
      sample: _cloneAudio?.label,
      volumePercent: _cloneVolumePercent,
      minVolumePercent: minVoiceVolumePercent,
      maxVolumePercent: maxVoiceVolumePercent,
      busy: _cloneBusy,
      error: _cloneError,
      resultVoice: result?.voice,
      resultWeak: result != null && result.warnings.isNotEmpty,
      folder: _clonedVoicesFolder,
      scrollController: _cloneScrollController,
      recordButtonKey: _cloneRecordButtonKey,
      onNameChanged: (_) => setState(() => _cloneError = null),
      onChangeSource: (mic) {
        setState(() {
          _cloneUseMicrophone = mic;
          _cloneAudio = null;
          _cloneError = null;
          _cloneResult = null;
        });
        if (mic) _chooseMicrophoneSample();
      },
      onToggleRecording: () => unawaited(_cloneRecording ? _stopCloneRecording(discard: false) : _startCloneRecording()),
      onPickFile: () => unawaited(_pickCloneFile()),
      onPlaySample: () => unawaited(_playCloneSample()),
      onVolumeDown: () => _changeCloneVolume(-voiceVolumeStep),
      onVolumeUp: () => _changeCloneVolume(voiceVolumeStep),
      onCreate: () => unawaited(_createVoiceFromSample()),
      onListen: () => unawaited(_listenToClonedVoice()),
      onUse: _chooseClonedVoice,
      onBack: () => unawaited(_closeVoiceCloneScreen()),
    );
  }

  /// The language screen's choice: the TTS model, voice-cloning encoder, STT locale, narration, agent packs and car replies
  /// follow it. Then the demo starts (permissions, speech engine, wake word).
  // Language packs (as the RN example, 2026-11-12): a language that isn't built in shows the download screen until its pack is on
  // the device; only then is the language chosen and the demo starts.
  String? _packLanguage;
  LanguagePackProgress? _packProgress;
  String? _packError;
  bool _packInstalled = false;
  final Map<String, bool> _readyPacks = {};

  Future<void> _refreshReadyPacks() async {
    // Remote voice manifest (signed; never code or the LLM): new voice files for downloaded languages without an app update.
    _log('[languagePacks] ${await refreshLanguagePackManifest()}');
    for (final l in appLanguageInfos) {
      if (isDownloadableLanguage(l.id)) _readyPacks[l.id] = await isLanguagePackReady(l.id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _selectLanguage(String language) async {
    if (!isDownloadableLanguage(language) || await isLanguagePackReady(language)) {
      _chooseLanguage(language);
      // a newer voice version (remote manifest) downloads quietly for the next start; this session keeps the one it has
      if (isDownloadableLanguage(language)) updateLanguagePackInBackground(language);
      return;
    }
    _startPackDownload(language);
  }

  void _startPackDownload(String language) {
    setState(() {
      _packLanguage = language;
      _packProgress = null;
      _packError = null;
      _packInstalled = false;
      _stage = _Stage.languageDownload;
    });
    downloadLanguagePack(language, onProgress: (p) {
      if (mounted && _packLanguage == language) setState(() => _packProgress = p);
    }).then((_) {
      if (!mounted || _packLanguage != language) return; // the user went back meanwhile
      _readyPacks[language] = true;
      setState(() => _packInstalled = true);   // "Ready to drive — choose a voice" continues (onContinue)
    }).catchError((Object error) {
      if (mounted && _packLanguage == language) {
        setState(() => _packError = error.toString().replaceFirst(RegExp(r'^(Bad state|HttpException): '), ''));
      }
    });
  }

  void _leavePackDownload() {
    final language = _packLanguage;
    if (language != null) cancelLanguagePackDownload(language);
    setState(() {
      _packLanguage = null;
      _stage = _Stage.language;
    });
  }

  void _chooseLanguage(String language) {
    setCurrentAppLanguage(language);
    setState(() {
      _voiceChoice = originalTtsVoices[language] ?? _defaultVoice;
      _stage = _Stage.preparing;
    });
    unawaited(_startDemo());
  }

  // The "VW Emerald" screens of the React Native example_car_agent (lib/redesign/), one per stage. The car agent only: the first wake word
  // opens the on-device car agent (no mode menu), Back returns to the wake word.
  Widget _buildStage(BuildContext context) {
    switch (_stage) {
      case _Stage.language:
        final languages = [
          for (final l in appLanguageInfos.where((l) => !l.hidden))
            HoodLanguage(
              id: l.id,
              code: l.id.toUpperCase(),
              shortName: l.label.split(' (').first.split(' ').first,
              name: l.label.split(' (').first,
              sizeMB: (languagePackSizeBytes(l.id) / 1e6).round(),
              installed: !isDownloadableLanguage(l.id) || _readyPacks[l.id] == true,
            ),
        ];
        return LanguageHoodScreen(languages: languages, defaultId: 'pt-BR', onInstall: (id) => unawaited(_selectLanguage(id)));
      case _Stage.languageDownload:
        final language = _packLanguage ?? 'en';
        final label = appLanguageInfo(language).label.split(' (').first;
        final total = _packProgress?.bytesTotal ?? languagePackSizeBytes(language);
        final done = (_packProgress?.bytesDone ?? 0).clamp(0, total);
        int mb(int bytes) => (bytes / 1e6).round();
        return InstallSpeedometerScreen(
          name: label,
          code: language.toUpperCase(),
          sizeMB: mb(total),
          pct: _packInstalled ? 100 : (total > 0 ? (done / total * 100).floor() : 0),
          mbDone: mb(_packInstalled ? total : done),
          mbTotal: mb(total),
          stage: _packProgress == null ? null : (_packProgress!.verifying ? 'verify' : 'download'),
          installed: _packInstalled,
          error: _packError,
          onCancel: _leavePackDownload,
          onRetry: () => _startPackDownload(language),
          onContinue: () {
            setState(() => _packInstalled = false);
            _packLanguage = null;
            _chooseLanguage(language);
          },
        );
      case _Stage.preparing:
        if (_setupFailed && !_isBusy) {
          return _PromptShell(
            message: _message,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _PromptTitle('Setup failed'),
                TextField(
                  controller: _licenseController,
                  contextMenuBuilder: textFieldContextMenu,
                  decoration: InputDecoration(labelText: 'Davoice license key', helperText: _licenseSource),
                ),
                _PrimaryButton(label: 'Retry setup', onPressed: _startDemo),
              ],
            ),
          );
        }
        return _wakeWordScreen();
      case _Stage.voicePicker:
        final originalVoiceName = originalTtsVoices[currentAppLanguage];
        final originalVoice = originalVoiceName != null && _builtInVoices.contains(originalVoiceName) ? originalVoiceName : null;
        final emotionVoices = _builtInVoices.where(_voiceAbilities.containsKey).toList();
        final examplesVoice = _voiceAbilities.containsKey(_voiceChoice) ? _voiceChoice : emotionVoices.firstOrNull;
        return VoiceScreen(
          expressive: [for (final v in emotionVoices) ExpressiveVoice(v, _voiceAbilities[v]?.length ?? 0)],
          originalVoice: originalVoice,
          builtIn: _builtInVoices.where((v) => !_voiceAbilities.containsKey(v) && v != originalVoice).toList(),
          cloned: _clonedVoices,
          selected: _voiceChoice,
          examples: examplesVoice == null ? const [] : voiceStyleExamples(_voiceAbilities[examplesVoice] ?? const [], currentAppLanguage),
          playingExample: _playingStyleExample,
          busy: _isBusy,
          onSelect: (voice) => setState(() => _voiceChoice = voice),
          onPlayExample: (text) {
            if (examplesVoice != null) unawaited(_playStyleExample(examplesVoice, text));
          },
          onClone: () => unawaited(_openVoiceCloneScreen()),
          onDeleteCloned: (voice) => unawaited(_confirmDeleteClonedVoice(voice)),
          onContinue: () => _continueFromVoicePicker(),
        );
      case _Stage.voiceClone:
        return _buildVoiceCloneScreen();
      case _Stage.svPrompt:
        return SpeakerScreen(
          hasSaved: _savedEnrollmentJsonPath != null,
          busy: _isBusy,
          onUseSaved: () => _useSavedSpeakerVerification(),
          onCreate: () => _runSpeakerVerificationOnboarding(),
          onSkip: () => _skipSpeakerVerification(),
        );
      case _Stage.svStatus:
        if (_svStatusPhase == _SVStatusPhase.onboarding) {
          return SignatureScreen(collected: _svCollected, target: _svTarget, sentences: enrollmentSentences(currentAppLanguage, 'Hey Coach'));
        }
        return VoiceTestScreen(
          wakePhrase: 'Hey Coach',
          score: _lastSvScore,
          isMatch: _lastSvMatch,
          sinceLast: _svElapsed,
          canContinue: _svStatusCanContinue && !_isBusy,
          onContinue: () => _continueAfterSpeakerVerification(),
        );
      case _Stage.modePicker:
      case _Stage.ttsTest:
        // not part of the car agent (the first wake word opens the car agent); shown only for a moment, if ever
        return _wakeWordScreen();
      case _Stage.home:
        if (_isFullAIChatMode && _isLocalAIChat) {
          if (_localModelStatus != 'Ready') {
            final pct = int.tryParse(RegExp(r'Downloading (\d+)%').firstMatch(_localModelStatus)?.group(1) ?? '') ?? 0;
            const order = ['download', 'load', 'warmup'];
            final at = _loadingStage == 'failed' ? -1 : order.indexOf(_loadingStage);
            return AgentLoadingScreen(
              modelName: _localModelName,
              stages: [
                LoadingStage(key: 'download', label: 'Download the model', detail: _loadingStage == 'download' ? '$pct%' : 'once, ~380 MB', progress: pct),
                const LoadingStage(key: 'load', label: 'Load it into memory', detail: ''),
                const LoadingStage(key: 'warmup', label: 'Warm up', detail: 'reads its instructions and tools once, so replies are fast'),
              ],
              activeIndex: at,
              seconds: DateTime.now().difference(_loadingStageStartedAt).inSeconds,
              error: _loadingStage == 'failed' ? _localModelStatus : null,
              onBack: () => unawaited(_leaveCarAgent()),
              onRetry: _warmUpLocalModel,
            );
          }
          return CarAgentScreen(
            language: currentAppLanguage,
            voice: _voiceName,
            wakePhrase: 'Hey Coach',
            heard: _ignoredText ??
                (_partialTranscript.isNotEmpty && _partialTranscript != 'Listening...' ? _partialTranscript : _lastTranscript),
            reply: _aiChatResponse,
            working: _isAIChatLoading,
            ignored: _ignoredText != null,
            modelName: _localModelName,
            localConfidence: _localConfidence,
            lastTurn: _lastTurn,
            onBack: () => unawaited(_leaveCarAgent()),
            onResetChat: _resetLocalChat,
            onChangeModel: _showLocalModelPicker,
            onChangeConfidence: _changeLocalConfidence,
            onSendText: kDebugMode
                ? (text) {
                    setState(() {
                      _lastTranscript = text;
                      _partialTranscript = '';
                      _ignoredText = null;
                    });
                    unawaited(_answerWithLocalModel(text));
                  }
                : null,
          );
        }
        return _wakeWordScreen();
    }
  }

  Widget _wakeWordScreen() {
    final listening = _message.startsWith('Say the wake word');
    return WakeWordScreen(
      wakePhrase: 'Hey Coach',
      message: _message.isEmpty ? 'Preparing…' : _message,
      listening: listening,
      heard: _message.startsWith('Wake word'),
      voice: _voiceName,
      language: appLanguageInfo(currentAppLanguage).label.split(' (').first,
      driverOnly: _enrollmentJsonPath != null,
    );
  }

  /// Back from the car agent (as the React Native example's leaveFullAIChatMode): the wake word screen, listening again.
  Future<void> _leaveCarAgent() async {
    if (_isSwitchingMode) return;
    _isSwitchingMode = true;
    _busyEpoch++;
    _beginSpeechUiEpoch();
    _speechSilenceTimer?.cancel();
    _speechEchoSessionActive = false;
    _isFullAIChatMode = false;
    _isHandlingWakeWord = false;
    _isAIChatLoading = false;
    try {
      await _speech.stopSpeaking();
      await _speech.pauseSpeechRecognition();
      try {
        await _unPauseWakeWordDetection();
      } catch (error) {
        _log('Could not resume wake-word detection: $error');
      }
      if (!mounted) return;
      setState(() {
        _isTtsSpeaking = false;
        _lastTranscript = '';
        _partialTranscript = '';
        _aiChatResponse = '';
        _wakeWordArmed = true;
        _stage = _Stage.home;
        _message = 'Say the wake word "Hey Coach" to continue.';
      });
    } finally {
      _isSwitchingMode = false;
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
