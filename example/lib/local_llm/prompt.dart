import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';

import 'chat_template.dart';
import 'needs_web_search.dart' show officeHolderQuestion;
import 'web_search.dart';

/// The system prompt for Local AI Chat (the RN example's
/// VOICE_ASSISTANT_PERSONA).
const voiceAssistantPersona =
    'You are a helpful voice assistant. Keep all answers under four sentences. '
    'Do not use markdown, bullet points, or numbered lists. '
    'Do not begin a sentence with "Certainly" or "Of course". '
    'Spell out abbreviations when reading aloud.';

/// One past turn of the conversation.
class ChatTurn {
  const ChatTurn({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

/// Web results for this turn, appended after the question (not to the system
/// prompt), so the system prompt and earlier turns stay identical between turns
/// and the engine's cache (and the prefill done while the user spoke) is still
/// reused. Same wording as the RN example's PromptAssembler.ts.
String _webBlock(List<WebRagPassage> passages, bool searchFailed) {
  if (passages.isNotEmpty) {
    final results = passages.map((p) => '- ${p.text}').join('\n');
    return '\n\nWeb search results, newer than your training data:\n$results\n'
        'Answer my question using these results: they are true today and override what you remember '
        'and anything said earlier in this conversation. '
        'Do not mention the search, sources or URLs.';
  }
  if (searchFailed) {
    return '\n\n(A web search for this question failed, for example because the device is offline. '
        'The app already told the user that. Say what was true as of your training data, '
        'using words like "as of my training". Never say it is true today, and never put '
        "today's date on it. Keep it to two sentences.)";
  }
  return '';
}

/// Renders the system prompt, the conversation so far and [userText] into the
/// model's chat template, ending with the assistant prefix the reply follows.
/// Ported from the RN example's PromptAssembler.ts (whose profile, memory and
/// tool inputs are all empty there). [currentDate] (e.g. "Saturday, October 17,
/// 2026") goes into the system prompt; [webPassages] / [webSearchFailed] follow
/// the question.
String assemblePrompt({
  required ChatTemplate template,
  required List<ChatTurn> history,
  required String userText,
  String systemPrompt = voiceAssistantPersona,
  String? currentDate,
  List<WebRagPassage> webPassages = const [],
  bool webSearchFailed = false,
  List<ToolDefinition> tools = const [],
  String toolInstructions = '',
  List<ChatTurn> toolMessages = const [],
}) {
  if (currentDate != null) systemPrompt = "$systemPrompt\n\nToday's date is $currentDate.";
  // Tools last, in the format the model was trained on (flutter_davoice_llm's
  // toolsSystemPrompt). Keep the list the same every turn: the engine caches
  // the system prompt.
  if (tools.isNotEmpty) {
    if (toolInstructions.isNotEmpty) systemPrompt = '$systemPrompt\n\n$toolInstructions';
    systemPrompt = '$systemPrompt\n\n${toolsSystemPrompt(tools)}';
  }
  final segments = StringBuffer();
  var pendingSystemText = '';
  if (template.mergeSystemIntoFirstUser) {
    pendingSystemText = systemPrompt;
  } else {
    segments.write(template.systemPrefix + systemPrompt + template.turnSuffix);
  }
  final turns = [
    ...history,
    // With search results, an office-holder question is asked neutrally (see
    // officeHolderQuestion); the history keeps the user's own words.
    ChatTurn(
      fromUser: true,
      text: (webPassages.isNotEmpty ? officeHolderQuestion(userText) ?? userText : userText) +
          _webBlock(webPassages, webSearchFailed),
    ),
    // This turn's tool calls and results so far (from runToolTurn).
    ...toolMessages,
  ];
  for (final turn in turns) {
    if (!turn.fromUser) {
      segments.write(template.assistantPrefix + turn.text + template.turnSuffix);
      continue;
    }
    final content = pendingSystemText.isEmpty ? turn.text : '$pendingSystemText\n\n${turn.text}';
    pendingSystemText = '';
    segments.write(template.userPrefix + content + template.turnSuffix);
  }
  segments.write(template.assistantPrefix);
  return segments.toString();
}

const _partialCutMarker = '\u0000partial-cut\u0000';

/// The beginning of the prompt [assemblePrompt] will produce once the user
/// finishes speaking: everything up to and including [partialUserText], without
/// the closing turn suffix. Prefilled while the user is still talking (and with
/// an empty text right after loading), so the final request only processes
/// what changed.
String assemblePromptPrefix({
  required ChatTemplate template,
  required List<ChatTurn> history,
  required String partialUserText,
  String systemPrompt = voiceAssistantPersona,
  String? currentDate,
  List<ToolDefinition> tools = const [],
  String toolInstructions = '',
}) {
  final prompt = assemblePrompt(
    template: template,
    history: history,
    userText: partialUserText + _partialCutMarker,
    systemPrompt: systemPrompt,
    currentDate: currentDate,
    tools: tools,
    toolInstructions: toolInstructions,
  );
  return prompt.substring(0, prompt.indexOf(_partialCutMarker));
}

/// Cuts streamed output at the first stop sequence (e.g. `<|im_end|>`), holding
/// back text that could be the start of one until the next delta proves
/// otherwise, so a marker split across tokens never leaks into the reply.
class StopSequenceFilter {
  StopSequenceFilter(this.stopSequences)
      : _maxHold = stopSequences.fold(0, (max, s) => s.length - 1 > max ? s.length - 1 : max);

  final List<String> stopSequences;
  final int _maxHold;
  String _held = '';
  bool _stopped = false;

  /// True once a stop sequence was seen; later input is ignored.
  bool get isStopped => _stopped;

  /// Feeds a delta and returns the text that is safe to emit now.
  String push(String delta) {
    if (_stopped) return '';
    final text = _held + delta;
    var cut = -1;
    for (final stop in stopSequences) {
      if (stop.isEmpty) continue;
      final index = text.indexOf(stop);
      if (index != -1 && (cut == -1 || index < cut)) cut = index;
    }
    if (cut != -1) {
      _stopped = true;
      _held = '';
      return text.substring(0, cut);
    }
    var hold = 0;
    for (var length = _maxHold < text.length ? _maxHold : text.length; length > 0; length--) {
      final tail = text.substring(text.length - length);
      if (stopSequences.any((stop) => stop.startsWith(tail))) {
        hold = length;
        break;
      }
    }
    _held = text.substring(text.length - hold);
    return text.substring(0, text.length - hold);
  }

  /// Releases held-back text at the end of generation.
  String flush() {
    final rest = _stopped ? '' : _held;
    _held = '';
    return rest;
  }
}

/// Splits [text] into finished sentences and the unfinished remainder, so TTS
/// can start on the first sentence while the model is still generating. Same
/// rule as the RN example's splitCompletedSentences.
({List<String> completed, String remainder}) splitCompletedSentences(String text) {
  final completed = <String>[];
  var start = 0;
  for (var index = 0; index < text.length; index++) {
    if (!'.!?'.contains(text[index])) continue;
    var boundary = index + 1;
    while (boundary < text.length && '"\')]'.contains(text[boundary])) {
      boundary++;
    }
    while (boundary < text.length && text[boundary].trim().isEmpty) {
      boundary++;
    }
    final sentence = text.substring(start, boundary).trim();
    if (sentence.isNotEmpty) completed.add(sentence);
    start = boundary;
    index = boundary - 1;
  }
  return (completed: completed, remainder: text.substring(start));
}
