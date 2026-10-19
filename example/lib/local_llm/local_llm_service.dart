import 'dart:async';

import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';

import '../agent/local_agent.dart';
import 'model_config.dart';
import 'model_store.dart';

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
  Future<void>? _chatTemplateSet;

  /// Tools of a remote MCP server, next to the calorie tracker's. They run
  /// online, so the agent says a filler while they run. Set before [warmUp]:
  /// the tool list is part of the system prompt the engine caches.
  Future<void> setExternalTools(List<ToolDefinition> tools) async {
    await (await _agent()).setTools(tools, online: (_) => true);
  }

  /// The agent, set up for [model]'s chat template.
  Future<DavoiceAgent> _agentFor(LocalLlmModelConfig model) async {
    final agent = await _agent();
    // Set once per model, even when calls race (warm-up and a prefill).
    if (_chatTemplateFor != model.id) {
      _chatTemplateFor = model.id;
      _chatTemplateSet = agent.configure({'chatTemplate': model.chatTemplate.toJson()});
    }
    await _chatTemplateSet;
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
  }) async {
    final model = await store.selectedModel();
    await _ensureModelLoaded(model, onDownloadProgress);
    await prefillForTurn(history, '');
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
    return agent.turn(
      {'text': userText, 'history': history, 'date': currentDateText()},
      onEvent: (event) {
        if (event.type == 'text') {
          onDelta(event.text);
        } else {
          onEvent?.call(event);
        }
      },
    );
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
  }
}
