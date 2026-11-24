import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';

import '../agent/local_agent.dart';
import '../car/car_state.dart';
import '../car/car_tools.dart' show carUndoResults;
import '../flow/app_language.dart';
import '../speaker_verification/current_speaker.dart';
import 'confidence.dart';
import 'demo.dart';
import 'model_config.dart';
import 'model_store.dart';
import '../general_questions_config.dart';
import '../car/basic_language.dart';

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// e.g. "Saturday, October 17, 2026". Changes once a day, so the system prompt
/// (and the engine's cache of it) stays the same within a day.
String currentDateText([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}, ${d.year}';
}

/// Local AI Chat's engine side: downloads and loads the selected model ahead
/// of time, and runs turns through the shared native agent core
/// ([LocalAgent]): web search, fillers, the calorie tracker's tools, prompt
/// assembly and the model, the same as in the RN example. Ported from the RN
/// example's LocalLLMProvider (aichat/provider.ts) and LocalLLMLoader.ts.
///
/// History is the app's chat history in the agent's shape: `role` user /
/// model, `text`, and a model reply's `toolMessages`.
class LocalLlmService {
  LocalLlmService({
    required this.licenseKey,
    FlutterDavoiceLlm? llm,
    LocalLlmModelStore? store,
    Future<DavoiceAgent> Function()? agent,
  })  : llm = llm ?? FlutterDavoiceLlm(),
        store = store ?? LocalLlmModelStore(),
        _agent = agent ?? LocalAgent.get;

  /// Returns the DaVoice license key (the same one the other libraries use).
  final String Function() licenseKey;
  final FlutterDavoiceLlm llm;
  final LocalLlmModelStore store;
  final Future<DavoiceAgent> Function() _agent;
  String? _chatTemplateFor;
  DavoiceAgent? _configuredAgent;
  Future<void>? _chatTemplateSet;
  String? _stateRestoredFor;
  int _nativeLoads = 0;

  /// The app's own tools (the car's) and a remote MCP server's. [online] tools get a filler while they run (default: all). Set
  /// before [warmUp]: the tool list is part of the system prompt the engine caches.
  Future<void> setExternalTools(List<ToolDefinition> tools, {bool Function(ToolDefinition tool)? online}) async {
    await (await _agent()).setTools(tools, online: online ?? (_) => true);
  }

  /// The core's call guards for [mode]: 'correct' fixes / blocks (the split-tool opposite check can only block: 'enforce').
  static Map<String, String> _callGuardSettings(String mode, {bool historyAsRun = false}) {
    final opposite = mode == 'correct' ? 'enforce' : mode;
    // followUp reads the previous turn's calls from the history: only meaningful (and only on) with historyAsRun.
    final followUp = historyAsRun ? mode : 'off';
    // dualZone (core g10+): one temperature per side said unambiguously -> the dual-zone call gets exactly those values; a call that
    // would drop or copy a side is blocked (asked again), never redirected. Older native cores ignore the key. (As the RN example.)
    return {'polarity': mode, 'direction': mode, 'absRel': mode, 'zone': mode, 'capability': mode, 'numberGround': mode, 'opposite': opposite, 'followUp': followUp, 'dualZone': mode, 'enumWords': mode};
  }

  /// The agent, set up for [model] (as the RN example's provider.ts agentFor): chat template, remote assistant, router, model
  /// tools, memory, sampling, guards. Sent again for a new agent (a demo switch) or another model.
  // The steering side last sent to the agent (configure "vehicle"), and to which agent.
  String? _steeringSent;
  DavoiceAgent? _steeringSentTo;
  // The Local confidence last sent (configure "confidence", core 2026-11-17; older cores ignore it), and to which agent.
  String? _confidenceSent;
  DavoiceAgent? _confidenceSentTo;

  Future<DavoiceAgent> _agentFor(LocalLlmModelConfig model) async {
    final agent = await _agent();
    if (_chatTemplateFor != model.id || !identical(_configuredAgent, agent)) {
      _chatTemplateFor = model.id;
      _configuredAgent = agent;
      _chatTemplateSet = agent.configure({
        'chatTemplate': model.chatTemplate.toJson(),
        // The remote assistant (agent/remote_assistant.dart: the "no remote model" message, or Gemini with 'cloud').
        'remote': model.remoteAssistant ? {'enabled': true, 'timeoutMs': 15000} : false,
        // false: the model decides every turn with every tool (no router, no skill rules).
        'intentRouter': model.usesRouter,
        // web_search + get_time for a model trained to call them.
        'webSearchTool': model.modelTools,
        'timeTool': model.modelTools,
        // Saved facts: the pack's 'small' profile; none attached for models that opt out (car commands).
        'memory': {'profile': 'small', if (!model.relevantMemory) 'relevantMax': 0},
        if (model.temperature != null) 'sampling': {'temperature': model.temperature},
        // Sent every time, so switching models never keeps the previous model's guards. Every decision is logged.
        'guards': _callGuardSettings(model.callGuards ?? 'off', historyAsRun: model.historyAsRun),
        // Sent every time (shared agent): the previous model's settings must not stick.
        'historyAsRun': model.historyAsRun,
        'guidedToolCalls': model.guidedToolCalls,
        'promptOrder': model.promptOrder ?? 'trained',
        'guardRetry': model.guardRetry,
        // Two operations per request (core 2026-11-13, Q3; older cores ignore it). Sent every time: the shared agent must not keep it.
        'maxOperations': model.maxOperations,
        // History window + compact tool results (core 2026-11-13, latency; older cores ignore them).
        'historyTurns': model.historyTurns,
        'compactToolResults': model.compactToolResults,
        // Command scope + undo (core 2026-11-14; older cores ignore them). Sent every time (shared agent): off unless the model sets them.
        'scope': model.scope ?? {'enabled': false},
        'undo': model.undo,
      });
    }
    await _chatTemplateSet;
    // the car's results carry their undo only when the agent uses it (an older core would show it to the model)
    carUndoResults = model.undo;
    // The car's steering-wheel side (core 2026-11-13, Q4; older cores ignore it): "o banco da direita" is the passenger in a left-hand-drive
    // car and the driver in a right-hand-drive one; explicit left / right positions stay physical. Sent again when it changes.
    // Local confidence (core 2026-11-19, configure "confidence" {enabled, min, fallback, messages}; confidence.dart): the car demo's
    // setting, off in the other demo. Sent when it changes: no model reload, no new session. Safety (core 2026-11-19, configure "safety"):
    // never-act + "which seat?" stay on whatever the confidence setting; only their sentences follow the app's language.
    final language = currentAppLanguage;
    final confidence = currentLocalDemo == 'car' ? await store.localConfidence() : ConfidenceSettings.defaults.copyWith(enabled: false);
    final confidenceKey = '${jsonEncode(confidence.toJson())}|$language|${model.id}';
    if (!identical(_confidenceSentTo, agent) || _confidenceSent != confidenceKey) {
      _confidenceSentTo = agent;
      _confidenceSent = confidenceKey;
      final pt = language.toLowerCase().startsWith('pt');
      final basic = currentLocalDemo == 'car' && isBasicLanguage(language);
      await agent.configure({
        'confidence': toCoreConfidence(confidence, language),
        'safety': {
          'neverAct': true,
          'seatAsk': true,
          'messages': {
            'whichSeat': basicMessage(language, 'whichSeat') ?? (pt ? 'Qual banco: o seu, o do carona ou os dois?' : "Which seat: yours, the passenger's, or both?"),
            'unsupported': localLlmNotInDemoMessage[language] ?? basicMessage(language, 'notInDemo') ?? localLlmNotInDemoMessage['en'],
          },
        },
        // Basic language (car/basic_language.dart): the command scope and the checks that look for English / Portuguese words would
        // drop or block nearly every request, so they are off; every car action is asked first and runs only after a yes instead.
        // The tuned languages get the model's own settings back (sent again whenever the language or the model changes).
        'scope': basic ? {'enabled': false} : (model.scope ?? {'enabled': false}),
        'guards': {
          ..._callGuardSettings(model.callGuards ?? 'off', historyAsRun: model.historyAsRun),
          if (basic) 'capability': 'off',
          if (basic) 'polarity': 'off',
        },
      });
      // general_questions_config.dart 'local' (core 2026-11-19, remote {"answer": "self"}): a general question is looked up and answered by
      // this model itself after the intro. Sent on its own: an older core refuses "self" and keeps the app's remote (= 'message').
      if (model.remoteAssistant && generalQuestionsMode == 'local') {
        try {
          await agent.configure({
            'remote': {
              'enabled': true,
              'timeoutMs': 15000,
              'answer': 'self',
              'selfPrompt': 'car',
              'selfIntro': generalQuestionsLocalIntro[language] ?? generalQuestionsLocalIntro['en'],
              'selfNoAnswer': generalQuestionsLocalNoAnswer[language] ?? generalQuestionsLocalNoAnswer['en'],
              'selfSourceLead': generalQuestionsSourceLead[language] ?? generalQuestionsSourceLead['en'],
            },
          });
        } catch (error) {
          // ignore: avoid_print
          print('[LocalLLM] this agent core cannot answer general questions itself (remote "self"); the message is used: $error');
        }
      }
    }
    final steering = Car.instance.state.steering;
    if (!identical(_steeringSentTo, agent) || _steeringSent != steering) {
      _steeringSentTo = agent;
      _steeringSent = steering;
      await agent.configure({'vehicle': {'steering': steering}});
    }
    return agent;
  }

  // The engine holds one model. This latch is set synchronously, so callers
  // that race join one load instead of each mapping the same GGUF (loading a
  // model twice concurrently is what pushes a phone into swap).
  String? _activeModelId;
  Future<void>? _activeLoad;
  bool _activeLoadDone = false;

  /// True once [modelId] has finished loading and is the engine's model.
  bool isModelReady(String modelId) => _activeLoadDone && _activeModelId == modelId;

  /// Downloads (if needed) and loads the selected model, then prefills the
  /// system prompt, so the first turn pays for none of it. Call when Local AI
  /// Chat opens and after the user picks another model, never mid-turn.
  Future<LocalLlmModelConfig> warmUp({
    List<Map<String, Object?>> history = const [],
    void Function(double fraction)? onDownloadProgress,
    void Function()? onWarming,
  }) async {
    final model = await store.selectedModel();
    // The pre-warmed state of the app's language (model.prebuiltStates) downloads next to the model: one progress bar over both files.
    final language = currentAppLanguage;
    final prebuilt = model.prebuiltStates[language];
    final modelBytes = model.sizeBytes ?? 1;
    final stateBytes = prebuilt?.sizeBytes ?? 0;
    var modelPart = 0.0;
    var statePart = 0.0;
    void report() => onDownloadProgress?.call((modelPart * modelBytes + statePart * stateBytes) / (modelBytes + stateBytes));
    final prebuiltDownload = store.downloadPrebuiltState(model, language, onProgress: (f) {
      statePart = f;
      report();
    });
    await _ensureModelLoaded(model, (f) {
      modelPart = f;
      report();
    });
    final prebuiltPath = await prebuiltDownload;
    onWarming?.call();
    // The system prompt processed at an earlier start: restored in under a second instead of ~30-40 s of prompt processing on a
    // phone CPU. Keyed by the prompt's system part (demo, language, tools), newest 2 per model file (model_store.dart). Only once
    // per native load; a broken file is deleted.
    try {
      final agent = await _agentFor(model);
      final date = currentDateText();
      final prompt = await agent.call('prompt', {'text': 'Hello', 'history': history, 'date': date}) as String;
      // Language in the name: see LocalLlmModelStore.downloadPrebuiltState (as the RN example).
      final statePath = await store.kvStatePath(model, '$language-${stablePromptKey(prompt, date)}');
      final stateExists = await File(statePath).exists();
      // No state of its own yet: the pre-warmed one (same prompt up to the date line in the cache prompt order).
      final restorePath = stateExists ? statePath : prebuiltPath;
      var restoredPrebuilt = false;
      final load = '${model.id}#$_nativeLoads';
      if (_stateRestoredFor != load && restorePath != null) {
        final t0 = DateTime.now();
        try {
          final n = await llm.loadState(restorePath);
          restoredPrebuilt = !stateExists;
          // ignore: avoid_print
          print('[LocalLLM] KV state restored${restoredPrebuilt ? ' (pre-warmed)' : ''}: $n tokens in ${DateTime.now().difference(t0).inMilliseconds} ms');
        } catch (error) {
          // ignore: avoid_print
          print('[LocalLLM] KV state not usable, deleted: $error');
          final broken = File(restorePath);
          await broken.delete().catchError((_) => broken);
        }
      }
      _stateRestoredFor = load;
      // Answer once, briefly, on the agent's real prompt: the system prompt is in the cache and the first decode has run.
      final started = DateTime.now();
      var tokens = 0;
      await llm.generateStream(prompt, (_, done) {
        if (!done && ++tokens == 4) llm.cancel();
      });
      final warmMs = DateTime.now().difference(started).inMilliseconds;
      // ignore: avoid_print
      print('[LocalLLM] warm-up answered ($tokens tokens) in $warmMs ms');
      // Save the processed prompt when there is none for it yet, or the warm-up had to do real work (the file is ~400 MB).
      // A pre-warmed state that fit (a fast warm-up) is not copied: it stays the state of this prompt.
      if ((!stateExists && !(restoredPrebuilt && warmMs <= 5000)) || warmMs > 5000) {
        final t0 = DateTime.now();
        final n = await llm.saveState(statePath);
        // ignore: avoid_print
        print('[LocalLLM] KV state saved: $n tokens in ${DateTime.now().difference(t0).inMilliseconds} ms');
        unawaited(store.deleteUnusedModelFiles().catchError((_) => <String>[]));
      }
    } catch (error) {
      // Only a speed-up: a failure here must not block the chat.
      // ignore: avoid_print
      print('[LocalLLM] warm-up state step skipped: $error');
      await prefillForTurn(history, '');
    }
    return model;
  }

  /// Processes the conversation plus the user's words so far into the model's
  /// cache in the background. No-op until the selected model is loaded; never
  /// throws.
  Future<void> prefillForTurn(List<Map<String, Object?>> history, String partialUserText) async {
    try {
      final model = await store.selectedModel();
      if (!isModelReady(model.id)) return;
      (await _agentFor(model)).prefill(history, partialUserText);
    } catch (_) {
      // Prefill is only an optimization.
    }
  }

  /// One turn. Reply text streams to [onDelta]; [onEvent] gets everything
  /// else the agent reports while working: `filler` (say it while waiting:
  /// web search, food lookup, MCP tool), `status`, `webSearch`, `toolResult`.
  /// Keep the result's `toolMessages` in the history with the reply. Loads the
  /// model first if needed (callers normally check [isModelReady] and warm up
  /// instead).
  Future<TurnResult> generateReplyStream(
    List<Map<String, Object?>> history,
    String userText,
    void Function(String delta) onDelta, {
    void Function(AgentEvent event)? onEvent,
  }) async {
    final model = await store.selectedModel();
    await _ensureModelLoaded(model, null);
    final agent = await _agentFor(model);
    try {
      return await agent.turn(
      {'text': userText, 'history': history, 'date': currentDateText()},
        onEvent: (event) {
          if (event.type == 'text') {
            onDelta(event.text);
          } else {
            onEvent?.call(event);
          }
        },
      );
    } finally {
      // The next request starts with nobody heard (door authorization).
      clearHeardSpeakers();
    }
  }

  /// Stops the turn being run, if any.
  Future<void> cancel() async => (await _agent()).cancel();

  Future<void> _ensureModelLoaded(
    LocalLlmModelConfig model,
    void Function(double fraction)? onDownloadProgress,
  ) {
    final active = _activeLoad;
    if (active != null && _activeModelId == model.id) return active;
    _activeLoadDone = false;
    late final Future<void> load;
    load = () async {
      if (active != null) await active.catchError((_) {});
      try {
        await _loadOnce(model, onDownloadProgress);
        if (identical(_activeLoad, load)) _activeLoadDone = true;
      } catch (_) {
        // A failed attempt is retryable.
        if (identical(_activeLoad, load)) {
          _activeLoad = null;
          _activeModelId = null;
        }
        rethrow;
      }
    }();
    _activeModelId = model.id;
    _activeLoad = load;
    return load;
  }

  Future<void> _loadOnce(
    LocalLlmModelConfig model,
    void Function(double fraction)? onDownloadProgress,
  ) async {
    if (!await store.isDownloaded(model)) {
      await store.download(model, onProgress: onDownloadProgress);
    }
    if (!await llm.setLicense(licenseKey())) {
      throw LocalLlmException(
        LocalLlmErrorCode.licenseRequired,
        'The license was rejected for ${model.displayName}',
      );
    }
    await llm.loadModel(
      await store.modelPath(model),
      options: LocalLlmLoadOptions(contextSize: model.contextSize),
    );
    _nativeLoads++;
  }
}
