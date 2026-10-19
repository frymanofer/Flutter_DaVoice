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
    this.isCustom = false,
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
      isCustom: json['isCustom'] as bool? ?? true,
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

  /// False for built-in entries; user-added models can be removed.
  final bool isCustom;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'filename': filename,
        'url': url,
        'contextSize': contextSize,
        'chatTemplate': chatTemplate.toJson(),
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        'isCustom': isCustom,
      };
}

const localLlmQwen25_1_5b = 'qwen2.5-1.5b-instruct';

/// Same built-in models as the RN example.
final builtinLocalLlmModels = [
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

/// Fast on phones (Q4_0) and small enough to download quickly.
const localLlmDefaultModelId = localLlmQwen25_1_5b;

/// Context size prefilled for a user-added model.
const localLlmDefaultCustomContextSize = 4096;

/// Subdirectory of the app support directory models and settings live in.
const localLlmStorageDir = 'local_llm';
