import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../flow/transcript.dart';
import '../flow/app_language.dart';
import '../flow/fragments.dart';
import '../local_llm/model_config.dart';

/// The remote assistant of Local AI Chat's DaVoice Agent model: Gemini (the
/// same model, key and Google Search grounding as AI Chat) answers what the
/// small model on the phone hands over: time-sensitive questions, small talk,
/// questions about the user, knowledge, long writing (agent.json "remote").
/// The agent says a filler meanwhile and speaks the answer as the reply. Any
/// failure is reported as {failure, detail}: the agent tells the user what
/// went wrong (agent.json "remote.errors"), never a guess from the phone.
/// Port of the RN example's src/aichat/remote.ts.
class RemoteAssistant {
  RemoteAssistant._();

  static String? _apiKey;
  static String _model = '';
  static String _systemPrompt = '';

  /// AI Chat's Gemini settings (from config/local.config.ts).
  static void configure({
    required String apiKey,
    required String model,
    required String systemPrompt,
  }) {
    _apiKey = apiKey;
    _model = model;
    _systemPrompt = systemPrompt;
  }

  static const _role =
      "You are the online helper of an assistant that runs on the user's phone. You cannot do anything on the "
      "phone (no logging, timers, messages or settings): if asked to, say you can't do that. Reply only to the "
      "user's last message, in one to four short spoken sentences.";

  /// Answers the agent's {"type": "remote", ...} request with {"text"}, or
  /// {"failure": offline | busy | unavailable | failed, "detail"}.
  static Future<Map<String, Object?>> answer(
    Map<String, Object?> request,
  ) async {
    final language = currentAppLanguage;
    // The model said it can't do this (remote.cannotReplies, reason "cannot"): not available in this demo - unless it is a
    // fragment of speech the model declined, which is noise, not an unsupported feature ("Alma Alma.").
    if (request['reason'] == 'cannot') {
      if (isTooShortForDecline('${request['userText'] ?? request['query'] ?? ''}')) {
        // ignore: avoid_print
        print('[AIChat][REMOTE] declined fragment: asking to repeat');
        return {'text': didNotCatch[language] ?? didNotCatch['en']};
      }
      // ignore: avoid_print
      print('[AIChat][REMOTE] not available in this demo (the model declined)');
      return {'text': localLlmNotInDemoMessage[language] ?? localLlmNotInDemoMessage['en']};
    }
    // No remote model set up (model_config.dart localLlmLayer2 'none'): say so instead of answering.
    if (localLlmLayer2 == 'none') {
      // ignore: avoid_print
      print('[AIChat][REMOTE] no remote model set up (reason ${request['reason'] ?? '-'}): telling the user');
      return {'text': localLlmNoRemoteMessage[language] ?? localLlmNoRemoteMessage['en']};
    }
    try {
      return await _askGemini(request);
    } catch (error) {
      final detail = error is StateError ? error.message : error.toString();
      final failure = _failureKind(error, detail);
      // ignore: avoid_print
      print('[AIChat][REMOTE] failed ($failure): $detail');
      return {'failure': failure, 'detail': detail};
    }
  }

  /// Which kind of failure an error is, for the sentence the user hears.
  static String _failureKind(Object error, String detail) {
    if (error is SocketException ||
        error is HandshakeException ||
        error is TimeoutException ||
        error is HttpException) {
      return 'offline';
    }
    final status = int.tryParse(
      RegExp(r'Gemini (\d{3})').firstMatch(detail)?.group(1) ?? '',
    );
    if (status == 429 || (status != null && status >= 500)) return 'busy';
    if (status != null && status >= 400) return 'unavailable';
    if (detail.contains('API key')) return 'unavailable';
    return 'failed';
  }

  static Future<Map<String, Object?>> _askGemini(
    Map<String, Object?> request,
  ) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('Gemini API key was not loaded from config/local.config.ts.');
    }
    final context = <String>[];
    final date = request['date']?.toString() ?? '';
    if (date.isNotEmpty) context.add('Today is $date.');
    final known = [
      for (final fact in request['facts'] as List? ?? const [])
        fact.toString().trim(),
      (request['memory']?.toString() ?? '').trim(),
    ].where((line) => line.isNotEmpty).toList();
    if (known.isNotEmpty) {
      context.add(
        'What the assistant knows about the user:\n${known.join('\n')}',
      );
    }
    // E.g. the calorie total the user asked for: Gemini words the answer.
    final results = [
      for (final r in request['toolResults'] as List? ?? const [])
        if (r is Map &&
            r['ok'] == true &&
            (r['call'] as Map?)?['name'] != 'handoff_remote')
          {'tool': (r['call'] as Map?)?['name'], 'result': r['result']},
    ];
    if (results.isNotEmpty) {
      context.add(
        "What the phone's tools returned for this request (answer from it):\n${jsonEncode(results)}",
      );
    }

    // Gemini wants the turns to alternate, starting with the user.
    final contents = <Map<String, Object?>>[];
    void add(String role, String text) {
      final last = contents.isEmpty ? null : contents.last;
      if (last != null && last['role'] == role) {
        final parts = last['parts'] as List<Map<String, String>>;
        parts[0] = {'text': '${parts[0]['text']}\n$text'};
      } else if (contents.isNotEmpty || role == 'user') {
        contents.add({
          'role': role,
          'parts': [
            {'text': text},
          ],
        });
      }
    }

    for (final message in request['history'] as List? ?? const []) {
      if (message is! Map) continue;
      final text = (message['text']?.toString() ?? '').trim();
      if (text.isNotEmpty) {
        add(message['role'] == 'user' ? 'user' : 'model', text);
      }
    }
    final userText = (request['userText']?.toString() ?? '').isNotEmpty
        ? request['userText'].toString()
        : request['query']?.toString() ?? '';
    add('user', userText);

    // ignore: avoid_print
    print('[AIChat][REMOTE] (${request['reason']}) "$userText"');
    final system = [
      _systemPrompt,
      [_role, ...context].join('\n\n'),
      llmReplyInstructionFor(currentAppLanguage),
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final httpRequest = await client
          .postUrl(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
            ),
          )
          .timeout(const Duration(seconds: 15));
      httpRequest.headers.contentType = ContentType.json;
      httpRequest.headers.set('x-goog-api-key', apiKey);
      httpRequest.write(
        jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': system},
            ],
          },
          'contents': contents,
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
      final response = await httpRequest.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      final payload = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = payload['error'];
        throw StateError(
          'Gemini ${response.statusCode}: ${error is Map ? error['message'] : 'Request failed'}',
        );
      }
      final candidates = payload['candidates'];
      final first = candidates is List && candidates.isNotEmpty
          ? candidates.first
          : null;
      final content = first is Map ? first['content'] : null;
      final parts = content is Map ? content['parts'] : null;
      final text = parts is List
          ? parts
                .map(
                  (part) => part is Map ? part['text']?.toString() ?? '' : '',
                )
                .join(' ')
                .trim()
          : '';
      if (text.isEmpty) throw StateError('Gemini returned an empty response.');
      return {'text': normalizeTextForSpeech(text)};
    } finally {
      client.close(force: true);
    }
  }
}
