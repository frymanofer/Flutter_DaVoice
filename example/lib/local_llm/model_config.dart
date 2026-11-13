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
      };
}

const localLlmQwen25_1_5b = 'qwen2.5-1.5b-instruct';
// The same built-in DaVoice models as the RN example (src/local_llm/constants.ts, 2026-11-10).
// The latest models (2026-11-12, user: every app uses the latest): the Personal Agent (ft7f2_it900) for the calories demo and the
// Automotive Agent r4b_it100 for the car demo. The older ft7c / ft7e / ft7f2 Automotive entries were removed (a phone that had one
// selected falls back to its demo's default, model_store.dart selectedModel).
const localLlmDavoicePersonal = 'davoice-personal-agent-0.6b';
const localLlmDavoiceAutomotiveR4b = 'davoice-automotive-agent-0.6b-r4b-it100';
// Automotive Agent r8d_it150 (the preferred model, h3d wording; as the RN example): url empty until its R2 upload is verified.
const localLlmDavoiceAutomotiveR8d = 'davoice-automotive-agent-0.6b-r8d-it150';
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
  // The car demo's model: Automotive Agent r4b_it100 (as the RN example's constants.ts): the simulated VW car's tools (h3), guards
  // correcting / blocking + the follow-up guard, guided tool calls, the cache prompt order and pre-warmed states (en, pt-BR).
  LocalLlmModelConfig(
    id: localLlmDavoiceAutomotiveR4b,
    displayName: 'DaVoice Automotive Agent 0.6B',
    filename: 'davoice-automotive-qwen3-0.6b-r4b-it100-q4_0.gguf',
    url: '$_r2/auto5_r4b_it100-q4_0.gguf',
    contextSize: 8192,
    chatTemplate: presetById('qwen3').template,
    sizeBytes: 381565920,
    sha256: '1c078e961c5f4e16ae0f667d213fa06de53f3f4bc92c9248427bdb37237bd205',
    remoteAssistant: true,
    usesRouter: false,
    modelTools: true,
    temperature: 0,
    relevantMemory: false,
    toolWording: 'h3',
    callGuards: 'correct',
    historyAsRun: true,
    guidedToolCalls: true,
    promptOrder: 'cache',
    guardRetry: true,
    // Made 2026-11-11 on the S20 by the RN example (r4b + cache order + agent_automotive pack + h3 vw_demo tools); verified on R2
    // 2026-11-12 (HTTP 200, size + sha256). Regenerate whenever the model, pack, tools or core prompt text change.
    prebuiltStates: {
      'en': PrebuiltState(
        url: '$_r2/prewarm/r4b_it100_prewarm_en.kvstate',
        sha256: '90685bef9146b3a796b94d5ce5534b91002882cc4abe49400f1157ab7c35f3ef',
        sizeBytes: 398482405,
      ),
      'pt-BR': PrebuiltState(
        url: '$_r2/prewarm/r4b_it100_prewarm_pt-BR.kvstate',
        sha256: '68502883de5e13438dfb116d68be2595d2c97fa6843f75955582be3e85f9990a',
        sizeBytes: 401464709,
      ),
    },
  ),
  // Automotive Agent r8d_it150 (as the RN example): h3d wording, the bounded guard retry; url empty until the R2 upload is verified
  // (a file already in the models folder is used). Becomes the car demo's default with its pre-warmed states.
  LocalLlmModelConfig(
    id: localLlmDavoiceAutomotiveR8d,
    displayName: 'DaVoice Automotive Agent 0.6B (r8d)',
    filename: 'davoice-automotive-qwen3-0.6b-r8d-it150-q4_0.gguf',
    url: '',
    contextSize: 8192,
    chatTemplate: presetById('qwen3').template,
    sizeBytes: 381565920,
    sha256: 'a977c181c3af6aa49991d927e66256fba77502af76bf42291109e3c3c4b2a550',
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
    // Pre-warmed states made on the S20 by the RN example (same prompt); url empty until uploaded and verified.
    prebuiltStates: {
      'en': PrebuiltState(
        url: '',
        sha256: 'ae8ec4f6ce359d171faddc31d2195af8da4cf5b8b66e2d64fc0630058b58a6d9',
        sizeBytes: 426699589,
      ),
      'pt-BR': PrebuiltState(
        url: '',
        sha256: 'e5fc93e1a3af51741a7748125452ef89e166b97f08aee58d7249575830d8007d',
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
const localLlmDemoDefaultModel = {'calories': localLlmDavoicePersonal, 'car': localLlmDavoiceAutomotiveR4b};

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
