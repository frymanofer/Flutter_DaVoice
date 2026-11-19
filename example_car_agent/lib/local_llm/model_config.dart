import '../flow/rn_tables.g.dart';
import 'chat_template.dart';

/// A model the user can choose for Local AI Chat. Ported from the RN example's
/// src/local_llm/types.ts and constants.ts.
class LocalLlmModelConfig {
  const LocalLlmModelConfig({
    required this.id,
    required this.displayName,
    required this.filename,
    required this.url,
    required this.contextSize,
    required this.chatTemplate,
    this.sizeBytes,
    this.sha256,
    this.remoteAssistant = false,
    this.isCustom = false,
    this.usesRouter = true,
    this.modelTools = false,
    this.temperature,
    this.relevantMemory = true,
    this.toolWording,
    this.callGuards,
    this.historyAsRun = false,
    this.guidedToolCalls = false,
    this.promptOrder,
    this.guardRetry = false,
    this.maxOperations = 1,
    this.historyTurns = 0,
    this.compactToolResults = false,
    this.scope,
    this.undo = false,
    this.prebuiltStates = const {},
  });

  factory LocalLlmModelConfig.fromJson(Map<String, dynamic> json) {
    return LocalLlmModelConfig(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      filename: json['filename'] as String,
      url: json['url'] as String,
      contextSize: (json['contextSize'] as num).toInt(),
      chatTemplate: ChatTemplate.fromJson(
        Map<String, dynamic>.from(json['chatTemplate'] as Map),
      ),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      sha256: json['sha256'] as String?,
      remoteAssistant: json['remoteAssistant'] as bool? ?? false,
      isCustom: json['isCustom'] as bool? ?? true,
      usesRouter: json['usesRouter'] as bool? ?? true,
      modelTools: json['modelTools'] as bool? ?? false,
      temperature: (json['temperature'] as num?)?.toDouble(),
      relevantMemory: json['relevantMemory'] as bool? ?? true,
      toolWording: json['toolWording'] as String?,
      callGuards: json['callGuards'] as String?,
      historyAsRun: json['historyAsRun'] as bool? ?? false,
      guidedToolCalls: json['guidedToolCalls'] as bool? ?? false,
      promptOrder: json['promptOrder'] as String?,
      guardRetry: json['guardRetry'] as bool? ?? false,
      maxOperations: (json['maxOperations'] as num?)?.toInt() ?? 1,
      historyTurns: (json['historyTurns'] as num?)?.toInt() ?? 0,
      compactToolResults: json['compactToolResults'] as bool? ?? false,
      scope: (json['scope'] as Map?)?.cast<String, Object?>(),
      undo: json['undo'] as bool? ?? false,
    );
  }

  final String id;
  final String displayName;

  /// File name the GGUF is stored under on the device.
  final String filename;

  /// Where the GGUF is downloaded from.
  final String url;

  /// Context window the model is loaded with (KV-cache memory grows with it).
  final int contextSize;
  final ChatTemplate chatTemplate;

  /// Approximate download size, for display only.
  final int? sizeBytes;

  /// When set, a download whose SHA-256 differs is deleted and reported as failed.
  final String? sha256;

  /// Hands what it can't do well to the remote assistant (Gemini,
  /// agent/remote_assistant.dart): everything but the tool actions (agent.json
  /// "remote"). Offline, it answers itself.
  final bool remoteAssistant;

  /// False for built-in entries; user-added models can be removed.
  final bool isCustom;

  /// False: the model decides every turn with every tool (fine-tuned DaVoice models: no intent router, no skill rules).
  final bool usesRouter;

  /// Trained to call web_search and get_time itself.
  final bool modelTools;

  /// Local sampling for agent turns (0 = greedy); null keeps the engine's default.
  final double? temperature;

  /// False: no saved facts attached to the prompt (car commands).
  final bool relevantMemory;

  /// Which car tool descriptions the model sees ('v1', 'h2', 'h3'): the wording it was trained / benchmarked with.
  final String? toolWording;

  /// The core's call guards: 'off', 'shadow' (logged only) or 'correct' (fix / block).
  final String? callGuards;

  /// Agent configure "historyAsRun" (2026-11-11): a guard-corrected call stays in the history as it ran, and the follow-up guard
  /// ("não, o outro de trás" keeps the previous action) is on with callGuards 'correct'.
  final bool historyAsRun;

  /// Agent configure "guidedToolCalls": the certain parts of a JSON tool call are fed in one batch (same calls, fewer decode steps).
  final bool guidedToolCalls;

  /// Agent configure "promptOrder": 'trained' (default) or 'cache' (only for a model validated in that order).
  final String? promptOrder;

  /// Agent configure "guardRetry" (core 2026-11-12, as the RN example): when a guard blocks a wrong-tool call ("close the windows" ->
  /// close_doors), the same model reconsiders once with that tool excluded; the new call passes every guard, otherwise the user is asked.
  final bool guardRetry;

  /// Agent configure "maxOperations" (core 2026-11-13, Q3, as the RN example): 2 = a request with two clear commands ("fecha os vidros
  /// e trava o carro") runs both, one after the other, in the same session; each is decided and checked on its own words, never run
  /// twice; a third is not done and the user hears so. Default 1. Older cores ignore the key.
  final int maxOperations;

  /// Agent configure "historyTurns" (core 2026-11-13, as the RN example): only the last N user turns in the prompt (0 = all that fit).
  final int historyTurns;

  /// Agent configure "compactToolResults" (core 2026-11-13): a tool that answered with its own sentence shows {"ok":true} in the prompt.
  final bool compactToolResults;

  /// Agent configure "scope" (core 2026-11-14, dev; as the RN example): which requests the local model gets at all. A deterministic
  /// check of the words before the model: a straightforward car command stays local; a general request goes to the remote assistant;
  /// an incomplete / vague / garbled one is asked again; a car function without a tool here is declined; speech not meant for the
  /// assistant is ignored. null = off (everything goes to the model, as before). Older cores ignore the key.
  final Map<String, Object?>? scope;

  /// Agent configure "undo" (core 2026-11-14, dev): "desfaz" / "undo that" puts the car back as it was before the last request (the
  /// car tools return how; car/car_undo.dart). Older cores ignore the key.
  final bool undo;

  /// Pre-warmed KV states by app language (as the RN example's prebuiltStates): the system prompt already processed offline with
  /// this exact model file, pack, tools and settings, so the first start skips the 25-40 s warm-up. Downloaded with the model
  /// (sha256 checked); a language without one warms up on the phone as before. Only valid with promptOrder 'cache'. Built-ins only.
  final Map<String, PrebuiltState> prebuiltStates;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'filename': filename,
        'url': url,
        'contextSize': contextSize,
        'chatTemplate': chatTemplate.toJson(),
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        if (sha256 != null) 'sha256': sha256,
        if (remoteAssistant) 'remoteAssistant': true,
        'isCustom': isCustom,
        if (!usesRouter) 'usesRouter': false,
        if (modelTools) 'modelTools': true,
        if (temperature != null) 'temperature': temperature,
        if (!relevantMemory) 'relevantMemory': false,
        if (toolWording != null) 'toolWording': toolWording,
        if (callGuards != null) 'callGuards': callGuards,
        if (historyAsRun) 'historyAsRun': true,
        if (guidedToolCalls) 'guidedToolCalls': true,
        if (promptOrder != null) 'promptOrder': promptOrder,
        if (guardRetry) 'guardRetry': true,
        if (maxOperations != 1) 'maxOperations': maxOperations,
        if (historyTurns != 0) 'historyTurns': historyTurns,
        if (compactToolResults) 'compactToolResults': true,
        if (scope != null) 'scope': scope,
        if (undo) 'undo': true,
      };
}

const localLlmQwen25_1_5b = 'qwen2.5-1.5b-instruct';
// The same built-in DaVoice models as the RN example (src/local_llm/constants.ts, 2026-11-10).
// The latest models (2026-11-12, user: every app uses the latest): the Personal Agent (ft7f2_it900) for the calories demo and the
// Automotive Agent (g3c_it3639) for the car demo. Older Automotive entries (ft7c, ft7e, ft7f2, r4b, r8d) were removed (a phone that had one
// selected falls back to its demo's default, model_store.dart selectedModel).
const localLlmDavoicePersonal = 'davoice-personal-agent-0.6b';
// Automotive Agent g3c_it3639: the car demo's default since 2026-11-17 (as the RN example).
const localLlmDavoiceAutomotiveG3c = 'davoice-automotive-agent-0.6b-g3c-it3639';
// EXPERIMENTAL Automotive Agent candidates (2026-11-11; C3 preferred, A fallback; NOT defaults; files sideloaded for the in-app test).
const localLlmDavoiceAutomotiveC3Exp = 'davoice-automotive-agent-0.6b-c3-auto3-h3-it300-experimental';
const localLlmDavoiceAutomotiveAExp = 'davoice-automotive-agent-0.6b-a-auto1-h3-it1050-experimental';

const _r2 = 'https://pub-27f94b1602c647ab95a601086cf52820.r2.dev/agent-llm';
const _it900File = 'davoice-agent-qwen3-0.6b-vw-ft7f2-it900-q4_0.gguf';
const _it900Url = '$_r2/ft7f2_it900-q4_0.gguf';
const _it900Sha = '2826a24b9391a40c2933370a15deb342d530ddee904687c649a898738bdbcf6b';

/// Same built-in models as the RN example.
final builtinLocalLlmModels = [
  // The calories demo's model: calories, memory, notes, developer tools, handoff (no car tools in that demo): ft7f2_it900.
  LocalLlmModelConfig(
    id: localLlmDavoicePersonal,
    displayName: 'DaVoice Personal Agent 0.6B',
    filename: _it900File,
    url: _it900Url,
    contextSize: 8192,
    chatTemplate: presetById('qwen3').template,
    sizeBytes: 381565920,
    sha256: _it900Sha,
    remoteAssistant: true,
    usesRouter: false,
    modelTools: true,
    temperature: 0,
    callGuards: 'correct',
  ),
  // Automotive Agent g3c_it3639: the car demo's DEFAULT since 2026-11-17 (as the RN example). R2 upload
  // verified 2026-11-17 (HTTP 200, size + sha256 of the full download). Exactly one model is loaded; never an automatic fallback.
  LocalLlmModelConfig(
    id: localLlmDavoiceAutomotiveG3c,
    displayName: 'DaVoice Automotive Agent 0.6B',
    filename: 'davoice-automotive-qwen3-0.6b-g3c-it3639-q4_0.gguf',
    url: '$_r2/auto16_g3c_it3639-q4_0.gguf',
    contextSize: 6144,   // 2026-11-13 (as the RN example): same decisions as 8192 on the S20, 0.23 GB less
    chatTemplate: presetById('qwen3').template,
    sizeBytes: 381565920,
    sha256: 'c39fbd65b259573d67dfb7da1935f1d0087156d7eefd97e131536a436c4d0ba8',
    remoteAssistant: true,
    usesRouter: false,
    modelTools: true,
    temperature: 0,
    relevantMemory: false,
    toolWording: 'h3d',
    callGuards: 'correct',
    historyAsRun: true,
    guidedToolCalls: true,
    promptOrder: 'cache',
    guardRetry: true,
    // two clear commands in one request run both (core 2026-11-13, Q3; older cores ignore it)
    maxOperations: 2,
    // latency (core 2026-11-13, as the RN example): the last 6 user turns, {"ok":true} for tools that answered with their own sentence
    historyTurns: 6,
    compactToolResults: true,
    // Command scope + undo (core 2026-11-14, dev g29zh; as the RN example; older cores ignore both): only straightforward car
    // commands reach the model (<= 10 words; up to 15 when clear; up to 22 for a clear car request such as a dual zone with a
    // preamble); general requests go to the remote assistant, garbled / vague ones are asked again, car functions without a tool
    // are declined, background speech is ignored. "desfaz" / "undo" restores the car's previous state (car/car_undo.dart).
    scope: {'enabled': true, 'localMaxWords': 10, 'strictMaxWords': 15, 'hardMaxWords': 22},
    // undo on (flutter_davoice_llm 0.0.14 carries the core with undo; as the RN example).
    undo: true,
    // Pre-warmed states made 2026-11-17 on the S20 by the RN example (core g29zm); R2 upload verified 2026-11-17 (size + sha256).
    prebuiltStates: {
      'en': PrebuiltState(
        url: '$_r2/prewarm/g3c_it3639_prewarm_en.kvstate',
        sha256: '75a35e15c774b9b63223b4b71e3283f6abffbf3b52e6343f16b04d9f26cd325f',
        sizeBytes: 426699589,
      ),
      'pt-BR': PrebuiltState(
        url: '$_r2/prewarm/g3c_it3639_prewarm_pt-BR.kvstate',
        sha256: 'f794a202844afdcb754678ce092da729dbdc66377c5e39c78d81300c683f11a0',
        sizeBytes: 429681893,
      ),
    },
  ),
  // EXPERIMENTAL Automotive Agent C3 / A (as the RN example's constants.ts): not hosted (url empty), sideloaded for the in-app test.
  LocalLlmModelConfig(
    id: localLlmDavoiceAutomotiveC3Exp,
    displayName: 'DaVoice Automotive Agent 0.6B (C3, EXPERIMENTAL)',
    filename: 'davoice-automotive-qwen3-0.6b-auto3-h3-it300-q4_0.gguf',
    url: '',
    contextSize: 8192,
    chatTemplate: presetById('qwen3').template,
    sizeBytes: 381565920,
    sha256: '2fa0cbf7d0c1d258d8f218a228685efdff2ae5ecce2cdd899908ab3b805e7b1d',
    remoteAssistant: true,
    usesRouter: false,
    modelTools: true,
    temperature: 0,
    relevantMemory: false,
    toolWording: 'h3',
    callGuards: 'correct',
    historyAsRun: true,
    guidedToolCalls: true,
  ),
  LocalLlmModelConfig(
    id: localLlmDavoiceAutomotiveAExp,
    displayName: 'DaVoice Automotive Agent 0.6B (A, EXPERIMENTAL)',
    filename: 'davoice-automotive-qwen3-0.6b-auto1-h3-it1050-q4_0.gguf',
    url: '',
    contextSize: 8192,
    chatTemplate: presetById('qwen3').template,
    sizeBytes: 381565920,
    sha256: '008bb5ca2efaf184f1b510f0a348a4542a11388b9b5a7148636a62c9275ac598',
    remoteAssistant: true,
    usesRouter: false,
    modelTools: true,
    temperature: 0,
    relevantMemory: false,
    toolWording: 'h3',
    callGuards: 'correct',
    historyAsRun: true,
    guidedToolCalls: true,
  ),
  LocalLlmModelConfig(
    id: 'gemma-3n-e2b-it',
    displayName: 'Gemma 3n E2B',
    filename: 'gemma-3n-E2B-it-Q4_K_M.gguf',
    url: 'https://huggingface.co/unsloth/gemma-3n-E2B-it-GGUF/resolve/main/gemma-3n-E2B-it-Q4_K_M.gguf',
    contextSize: 16384,
    chatTemplate: presetById('gemma').template,
    sizeBytes: 3030000000,
  ),
  LocalLlmModelConfig(
    id: 'gemma-3n-e4b-it',
    displayName: 'Gemma 3n E4B',
    filename: 'gemma-3n-E4B-it-Q4_K_M.gguf',
    url: 'https://huggingface.co/unsloth/gemma-3n-E4B-it-GGUF/resolve/main/gemma-3n-E4B-it-Q4_K_M.gguf',
    contextSize: 16384,
    chatTemplate: presetById('gemma').template,
    sizeBytes: 4540000000,
  ),
  LocalLlmModelConfig(
    id: localLlmQwen25_1_5b,
    displayName: 'Qwen2.5 1.5B',
    filename: 'qwen2.5-1.5b-instruct-q4_0.gguf',
    url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_0.gguf',
    contextSize: 8192,
    chatTemplate: presetById('chatml').template,
    sizeBytes: 1066227232,
  ),
  // Better at tool calling and calorie knowledge than 1.5B, but about twice
  // as slow on phone CPUs. Fast on iPhones with Metal (A14+).
  LocalLlmModelConfig(
    id: 'qwen2.5-3b-instruct',
    displayName: 'Qwen2.5 3B',
    filename: 'qwen2.5-3b-instruct-q4_0.gguf',
    url: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_0.gguf',
    contextSize: 8192,
    chatTemplate: presetById('chatml').template,
    sizeBytes: 1997879712,
  ),
];

/// The default outside the demos' own defaults (2026-11-12: the Personal Agent; was ft7e, removed). Changing this switches every
/// install to the new default once (see model_store.dart); the user can pick another model afterwards.
const localLlmDefaultModelId = localLlmDavoicePersonal;

/// Each Local AI Chat demo's model until the user picks another one in that demo (lib/local_llm/demo.dart).
const localLlmDemoDefaultModel = {'calories': localLlmDavoicePersonal, 'car': localLlmDavoiceAutomotiveG3c};

/// The car tools in the prompt: the VW Brazil demo's profile ('vw_demo') or the whole catalog ('all').
const localLlmCarTools = 'vw_demo';

/// Who answers what the DaVoice models hand over: 'none' = no remote model is set up (the app says [localLlmNoRemoteMessage]);
/// 'cloud' = Gemini (agent/remote_assistant.dart). Same as the RN example's LOCAL_LLM_LAYER2.
const localLlmLayer2 = 'none';

const localLlmNoRemoteMessage = noRemoteTexts;

/// What the agent says instead of the model's "That's not available here" (the request was understood, this demo can't do it).
const localLlmNotInDemoMessage = notInDemoTexts;

/// The default before the registry recorded it (files written until 2026-11-05).
const localLlmEarlierDefaultModelId = localLlmQwen25_1_5b;

/// Context size prefilled for a user-added model.
const localLlmDefaultCustomContextSize = 4096;

/// Subdirectory of the app support directory models and settings live in.
const localLlmStorageDir = 'local_llm';

/// A pre-warmed KV state file (see [LocalLlmModelConfig.prebuiltStates]).
class PrebuiltState {
  const PrebuiltState({required this.url, required this.sha256, required this.sizeBytes});

  final String url;
  final String sha256;
  final int sizeBytes;
}

/// The car demo's "Local confidence" choices (2026-11-17, as the RN example): the minimum probability the on-device model must have
/// for a car action to run locally; below it the request goes to the remote assistant. 0 = off.
const localLlmConfidenceChoices = [0.0, 0.8, 0.9, 0.95];

/// What the user hears when a command was below the confidence minimum and no remote model is set up (localLlmLayer2 'none').
const localLlmLowConfidenceMessage = {
  'en': 'For this command I need a remote agent.',
  'pt-BR': 'Para esse comando eu preciso de um agente remoto.',
};
