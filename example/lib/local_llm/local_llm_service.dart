import 'dart:async';

import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';

import 'model_config.dart';
import 'model_store.dart';
import 'prompt.dart';
import 'web_search.dart';

/// Result of [LocalLlmService.searchWeb], passed on to generateReplyStream.
class WebSearchOutcome {
  const WebSearchOutcome({required this.passages, required this.source, required this.failed});

  final List<WebRagPassage> passages;

  /// Name of the engine that answered, e.g. "Wikipedia".
  final String source;

  /// True when nothing usable came back (offline, timeout, no results).
  final bool failed;
}

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
/// of time, prefills the prompt while the user speaks, and streams replies.
/// Ported from the RN example's LocalLLMProvider (aichat/provider.ts) and
/// LocalLLMLoader.ts.
class LocalLlmService {
  LocalLlmService({
    required this.licenseKey,
    FlutterDavoiceLlm? llm,
    LocalLlmModelStore? store,
  })  : llm = llm ?? FlutterDavoiceLlm(),
        store = store ?? LocalLlmModelStore();

  /// Returns the DaVoice license key (the same one the other libraries use).
  final String Function() licenseKey;
  final FlutterDavoiceLlm llm;
  final LocalLlmModelStore store;

  List<ToolDefinition> _tools = const [];
  String _toolInstructions = '';
  ToolChoice Function(String userText) _toolChoice = (_) => ToolChoice.auto;
  String _missingToolCallReply = "Sorry, I couldn't do that. Could you say it again?";

  /// Tools the model may call (app tools and/or MCP server tools), the rules
  /// for using them (added to the system prompt), a per-message [toolChoice]
  /// from the user's words, and what to say when a required tool call never
  /// came. Set before [warmUp]: the tool list is part of the system prompt the
  /// engine caches.
  void setTools(
    List<ToolDefinition> tools, {
    String instructions = '',
    ToolChoice Function(String userText)? toolChoice,
    String? missingToolCallReply,
  }) {
    _tools = tools;
    _toolInstructions = instructions;
    _toolChoice = toolChoice ?? (_) => ToolChoice.auto;
    if (missingToolCallReply != null) _missingToolCallReply = missingToolCallReply;
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
    List<ChatTurn> history = const [],
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
  Future<void> prefillForTurn(List<ChatTurn> history, String partialUserText) async {
    try {
      final model = await store.selectedModel();
      if (!isModelReady(model.id)) return;
      await llm.prefill(assemblePromptPrefix(
        template: model.chatTemplate,
        history: history,
        partialUserText: partialUserText,
        currentDate: currentDateText(),
        tools: _tools,
        toolInstructions: _toolInstructions,
      ));
    } catch (_) {
      // Prefill is only an optimization.
    }
  }

  /// Searches the web for [query] (call it only for time-sensitive questions,
  /// see needs_web_search.dart). Never throws: a failure is reported in the
  /// outcome so the reply can say it couldn't check online.
  Future<WebSearchOutcome> searchWeb(String query) async {
    final timer = Stopwatch()..start();
    try {
      final passages = await WebSearch.search(query);
      // ignore: avoid_print
      print('[LocalLLM] web search via ${WebSearch.lastSource}: ${passages.length} results in ${timer.elapsedMilliseconds} ms');
      return WebSearchOutcome(passages: passages, source: WebSearch.lastSource, failed: passages.isEmpty);
    } catch (error) {
      // ignore: avoid_print
      print('[LocalLLM] web search failed: $error');
      return WebSearchOutcome(passages: const [], source: WebSearch.lastSource, failed: true);
    }
  }

  /// Streams a reply to [userText]. [onDelta] receives speakable text (turn
  /// markers and tool-call JSON removed). [webSearch]: results of [searchWeb]
  /// for this question, if it searched. With tools set, the model may call
  /// them (see flutter_davoice_llm's runToolTurn); [onToolResult] reports each
  /// call. Returns the turn's tool calls and results: keep them in the history
  /// so later prompts show that actions are done by calling tools. Loads the
  /// model first if needed (callers normally check [isModelReady] and warm up
  /// instead).
  Future<List<ToolTurnMessage>> generateReplyStream(
    List<ChatTurn> history,
    String userText,
    void Function(String delta) onDelta, {
    WebSearchOutcome? webSearch,
    void Function(ToolCallResult result)? onToolResult,
  }) async {
    final model = await store.selectedModel();
    await _ensureModelLoaded(model, null);

    // One model reply for the prompt plus this turn's tool messages, with the
    // template's turn-end marker cut off.
    Future<void> generateRound(List<ToolTurnMessage> toolMessages, void Function(String text) onToken) async {
      final prompt = assemblePrompt(
        template: model.chatTemplate,
        history: history,
        userText: userText,
        currentDate: currentDateText(),
        webPassages: webSearch?.passages ?? const [],
        webSearchFailed: webSearch?.failed ?? false,
        tools: _tools,
        toolInstructions: _toolInstructions,
        toolMessages: [for (final m in toolMessages) ChatTurn(fromUser: m.fromUser, text: m.content)],
      );
      final stopFilter = StopSequenceFilter(model.chatTemplate.stopSequences);
      await llm.generateStream(prompt, (token, done) {
        if (done) {
          final rest = stopFilter.flush();
          if (rest.isNotEmpty) onToken(rest);
          return;
        }
        final wasStopped = stopFilter.isStopped;
        final text = stopFilter.push(token);
        if (text.isNotEmpty) onToken(text);
        // Stop generating at the turn-end marker; native still sends done.
        if (!wasStopped && stopFilter.isStopped) unawaited(llm.cancel());
      });
    }

    if (_tools.isEmpty) {
      await generateRound(const [], onDelta);
      return const [];
    }
    final turn = await runToolTurn(
      tools: _tools,
      generate: generateRound,
      onText: onDelta,
      onToolResult: onToolResult,
      toolChoice: _toolChoice(userText),
      context: {'userText': userText},
    );
    if (turn.missingRequiredToolCall) onDelta(_missingToolCallReply);
    return turn.messages;
  }

  /// Stops the reply being generated, if any.
  Future<void> cancel() => llm.cancel();

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
