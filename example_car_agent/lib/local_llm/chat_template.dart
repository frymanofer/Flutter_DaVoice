/// How a model expects a conversation to be rendered into its prompt. Every
/// instruction-tuned family is trained on one format; a mismatch produces
/// replies that ramble and never stop. Ported from the RN example's
/// src/local_llm/types.ts and chatTemplates.ts.
///
/// Don't include a BOS token: the native tokenizer adds it and parses the
/// special-token markers below.
class ChatTemplate {
  const ChatTemplate({
    required this.systemPrefix,
    required this.userPrefix,
    required this.assistantPrefix,
    required this.turnSuffix,
    required this.mergeSystemIntoFirstUser,
    required this.stopSequences,
    this.generationPrefix = '',
    this.spacedToolJson = false,
  });

  factory ChatTemplate.fromJson(Map<String, dynamic> json) {
    return ChatTemplate(
      systemPrefix: json['systemPrefix'] as String? ?? '',
      userPrefix: json['userPrefix'] as String? ?? '',
      assistantPrefix: json['assistantPrefix'] as String? ?? '',
      turnSuffix: json['turnSuffix'] as String? ?? '',
      mergeSystemIntoFirstUser: json['systemMode'] == 'merge-into-first-user',
      stopSequences: [
        for (final stop in json['stopSequences'] as List? ?? const []) stop.toString(),
      ],
      generationPrefix: json['generationPrefix'] as String? ?? '',
      spacedToolJson: json['spacedToolJson'] as bool? ?? false,
    );
  }

  final String systemPrefix;
  final String userPrefix;
  final String assistantPrefix;

  /// Closes every turn, whatever its role.
  final String turnSuffix;

  /// The model has no system role (Gemma): the system prompt is prepended to
  /// the first user turn instead of getting its own turn.
  final bool mergeSystemIntoFirstUser;

  /// Generated text is cut at the first of these, for models whose GGUF
  /// metadata doesn't mark the turn-end marker as end-of-generation.
  final List<String> stopSequences;

  /// Opens the reply being generated (not earlier replies), e.g. Qwen3's
  /// empty `<think>\n\n</think>\n\n`: thinking off, as its own template does.
  final String generationPrefix;

  /// Tool calls as JSON with spaces after ':' and ',' (Qwen3's own template).
  final bool spacedToolJson;

  Map<String, dynamic> toJson() => {
        'systemPrefix': systemPrefix,
        'userPrefix': userPrefix,
        'assistantPrefix': assistantPrefix,
        'turnSuffix': turnSuffix,
        'systemMode': mergeSystemIntoFirstUser ? 'merge-into-first-user' : 'role',
        'stopSequences': stopSequences,
        if (generationPrefix.isNotEmpty) 'generationPrefix': generationPrefix,
        if (spacedToolJson) 'spacedToolJson': true,
      };

  bool sameAs(ChatTemplate other) =>
      systemPrefix == other.systemPrefix &&
      userPrefix == other.userPrefix &&
      assistantPrefix == other.assistantPrefix &&
      turnSuffix == other.turnSuffix &&
      mergeSystemIntoFirstUser == other.mergeSystemIntoFirstUser &&
      stopSequences.join('\u0000') == other.stopSequences.join('\u0000') &&
      generationPrefix == other.generationPrefix &&
      spacedToolJson == other.spacedToolJson;
}

/// A named template family users pick from when adding a model.
class ChatTemplatePreset {
  const ChatTemplatePreset(this.id, this.label, this.usedBy, this.template);

  final String id;
  final String label;

  /// Which model families use it, shown in the picker.
  final String usedBy;
  final ChatTemplate template;
}

const chatTemplatePresets = [
  ChatTemplatePreset(
    'gemma',
    'Gemma',
    'Gemma 2 / 3 / 3n',
    ChatTemplate(
      systemPrefix: '',
      userPrefix: '<start_of_turn>user\n',
      assistantPrefix: '<start_of_turn>model\n',
      turnSuffix: '<end_of_turn>\n',
      mergeSystemIntoFirstUser: true,
      stopSequences: ['<end_of_turn>'],
    ),
  ),
  ChatTemplatePreset(
    'chatml',
    'ChatML',
    'Qwen 2 / 2.5, SmolLM2, Hermes',
    ChatTemplate(
      systemPrefix: '<|im_start|>system\n',
      userPrefix: '<|im_start|>user\n',
      assistantPrefix: '<|im_start|>assistant\n',
      turnSuffix: '<|im_end|>\n',
      mergeSystemIntoFirstUser: false,
      stopSequences: ['<|im_end|>'],
    ),
  ),
  // ChatML with thinking off, as Qwen3's own template renders it
  // (enable_thinking false): the reply opens with an empty think block.
  ChatTemplatePreset(
    'qwen3',
    'Qwen3',
    'Qwen3, DaVoice Agent',
    ChatTemplate(
      systemPrefix: '<|im_start|>system\n',
      userPrefix: '<|im_start|>user\n',
      assistantPrefix: '<|im_start|>assistant\n',
      turnSuffix: '<|im_end|>\n',
      mergeSystemIntoFirstUser: false,
      stopSequences: ['<|im_end|>'],
      generationPrefix: '<think>\n\n</think>\n\n',
      spacedToolJson: true,
    ),
  ),
  ChatTemplatePreset(
    'llama3',
    'Llama 3',
    'Llama 3 / 3.1 / 3.2',
    ChatTemplate(
      systemPrefix: '<|start_header_id|>system<|end_header_id|>\n\n',
      userPrefix: '<|start_header_id|>user<|end_header_id|>\n\n',
      assistantPrefix: '<|start_header_id|>assistant<|end_header_id|>\n\n',
      turnSuffix: '<|eot_id|>',
      mergeSystemIntoFirstUser: false,
      stopSequences: ['<|eot_id|>'],
    ),
  ),
  ChatTemplatePreset(
    'phi3',
    'Phi-3',
    'Phi-3 / 3.5',
    ChatTemplate(
      systemPrefix: '<|system|>\n',
      userPrefix: '<|user|>\n',
      assistantPrefix: '<|assistant|>\n',
      turnSuffix: '<|end|>\n',
      mergeSystemIntoFirstUser: false,
      stopSequences: ['<|end|>'],
    ),
  ),
];

ChatTemplatePreset presetById(String id) =>
    chatTemplatePresets.firstWhere((preset) => preset.id == id);

/// The preset [template] matches exactly, if any.
ChatTemplatePreset? findMatchingPreset(ChatTemplate template) {
  for (final preset in chatTemplatePresets) {
    if (preset.template.sameAs(template)) return preset;
  }
  return null;
}
