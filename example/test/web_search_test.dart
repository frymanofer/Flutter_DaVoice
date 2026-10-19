import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_davoice_example/local_llm/chat_template.dart';
import 'package:flutter_davoice_example/local_llm/local_llm_service.dart';
import 'package:flutter_davoice_example/local_llm/needs_web_search.dart';
import 'package:flutter_davoice_example/local_llm/prompt.dart';
import 'package:flutter_davoice_example/local_llm/web_search.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordedCall {
  RecordedCall(this.uri, this.method, this.headers, this.body);
  final Uri uri;
  final String method;
  final Map<String, String> headers;
  final String? body;
}

/// Records requests and answers with [handler].
JsonFetcher fakeFetcher(List<RecordedCall> calls, dynamic Function(Uri uri) handler) {
  return (Uri uri, {String method = 'GET', Map<String, String> headers = const {}, String? body}) async {
    calls.add(RecordedCall(uri, method, headers, body));
    final result = handler(uri);
    if (result is Exception) throw result;
    return result;
  };
}

dynamic wikipediaAnswer(Uri uri) => uri.queryParameters['list'] == 'search'
    ? {
        'query': {
          'search': [
            {'title': 'President of the United States'},
          ],
        },
      }
    : {
        'query': {
          'pages': {
            '1': {
              'title': 'President of the United States',
              'extract': 'The president of the United States is the head of state. '
                  'The office has grown over time since the first president took office in 1789. '
                  'Donald Trump is the 47th and current president since January 20, 2025.',
            },
          },
        },
      };

class _SlowEngine implements WebSearchEngine {
  @override
  String get name => 'Slow';
  @override
  Future<List<WebRagPassage>> search(String query, {required int maxResults}) => Completer<List<WebRagPassage>>().future;
}

class _MyEngine implements WebSearchEngine {
  @override
  String get name => 'MySearch';
  @override
  Future<List<WebRagPassage>> search(String query, {required int maxResults}) async =>
      [for (var i = 1; i <= 4; i++) WebRagPassage(text: '$query $i', url: 'u')];
}

void main() {
  tearDown(() => WebSearch.configure());

  group('office holder questions (same rules as RN)', () {
    test('yes/no and "who runs" questions search', () {
      for (final q in ['Is Joe Biden the president?', 'Is Biden still president?', 'Who runs the US?', 'Who is in charge of the UK']) {
        expect(needsWebSearch(q), isTrue, reason: q);
      }
      expect(needsWebSearch('Who wrote Hamlet?'), isFalse);
    });

    test("the office's own Wikipedia page, not the question's words", () {
      expect(officeHolderPage('Is Joe Biden the president?'), 'President of the United States');
      expect(officeHolderPage('Who runs the US?'), 'President of the United States');
      expect(officeHolderPage('Who is the British prime minister'), 'Prime Minister of the United Kingdom');
      expect(officeHolderPage('Who is the French president right now'), 'President of France');
      expect(officeHolderPage('who is the mayor of london'), 'Mayor of London');
      expect(officeHolderPage('Who is the pope?'), 'Pope');
      expect(officeHolderPage('Who is the CEO of Apple'), isNull);
      expect(officeHolderPage('Tell me a story about a king'), isNull);
    });
  });

  group('needsWebSearch (same rules as RN)', () {
    test('time-sensitive questions search', () {
      for (final q in [
        'Who is the president of the US?',
        'Who is the prime minister of Israel',
        'What is the weather today in Tel Aviv',
        'Who won the Champions League',
        'What happened in 2026',
        'Who is the CEO of Apple',
      ]) {
        expect(needsWebSearch(q), isTrue, reason: q);
      }
    });
    test('ordinary questions do not', () {
      for (final q in [
        'Tell me a story about a king',
        'What is the capital of France?',
        'How do I make pasta?',
        'Explain photosynthesis',
      ]) {
        expect(needsWebSearch(q), isFalse, reason: q);
      }
    });
  });

  test('search phrases: topic-matched, never repeated back to back, one sentence, no Mmm', () {
    final rng = Random(7);
    final seen = <String>{};
    var previous = '';
    for (var i = 0; i < 2000; i++) {
      final phrase = pickSearchFiller(
        ['What is the weather today?', 'Who is the president?', 'Price of bitcoin?'][i % 3],
        rng,
      );
      expect(phrase, isNot(previous));
      previous = phrase;
      seen.add(phrase);
    }
    for (var i = 0; i < 30; i++) {
      seen.add(pickSearchFailedFiller(rng));
    }
    expect(seen, contains('Let me check the latest forecast.'));
    expect(seen, contains('Well, that is a good question, let me search.'));
    for (final phrase in seen) {
      expect(RegExp(r'[.!?]').allMatches(phrase).length, 1, reason: phrase);
      expect(phrase.toLowerCase(), isNot(contains('mmm')));
      expect(phrase.toLowerCase(), isNot(contains('hmm')));
    }
  });

  group('WebSearch engines', () {
    test('Tavily: request shape and parsing', () async {
      final calls = <RecordedCall>[];
      WebSearch.configure(
        engine: 'tavily',
        tavilyApiKey: ' tvly-KEY ',
        fetchJson: fakeFetcher(calls, (_) => {
              'answer': "John Ternus is Apple's CEO.",
              'results': [
                {'title': 'A', 'url': 'https://a', 'content': 'Ternus became CEO in September 2026.'},
                {'title': 'B', 'url': 'https://b', 'content': ''},
              ],
            }),
      );
      final passages = await WebSearch.search('Who is the CEO of Apple?');
      expect(calls.single.uri.toString(), 'https://api.tavily.com/search');
      expect(calls.single.method, 'POST');
      expect(calls.single.headers['Authorization'], 'Bearer tvly-KEY');
      expect(jsonDecode(calls.single.body!), {
        'query': 'Who is the CEO of Apple?',
        'search_depth': 'basic',
        'max_results': 3,
        'include_answer': true,
      });
      expect(passages.map((p) => p.text), ["John Ternus is Apple's CEO.", 'Ternus became CEO in September 2026.']);
      expect(WebSearch.lastSource, 'Tavily');
    });

    test('Brave: request shape, HTML stripped, extra snippets used', () async {
      final calls = <RecordedCall>[];
      WebSearch.configure(
        engine: 'brave',
        braveApiKey: 'BSA-KEY',
        maxResults: 2,
        fetchJson: fakeFetcher(calls, (_) => {
              'web': {
                'results': [
                  {
                    'title': 'Pope',
                    'url': 'https://p',
                    'description': 'The <strong>current pope</strong> is Leo XIV &amp; he&#x27;s American.',
                    'extra_snippets': ['Elected 8 May 2025.', 'x', 'y'],
                  },
                ],
              },
            }),
      );
      final passages = await WebSearch.search('Who is the current pope?');
      final uri = calls.single.uri;
      expect('${uri.host}${uri.path}', 'api.search.brave.com/res/v1/web/search');
      expect(uri.queryParameters, {'q': 'Who is the current pope?', 'count': '2', 'extra_snippets': 'true'});
      expect(calls.single.headers['X-Subscription-Token'], 'BSA-KEY');
      expect(passages.single.text, "The current pope is Leo XIV & he's American. Elected 8 May 2025. x");
      expect(WebSearch.lastSource, 'Brave');
    });

    test('Wikipedia: picks the sentence naming the current holder', () async {
      WebSearch.configure(fetchJson: fakeFetcher([], wikipediaAnswer));
      final passages = await WebSearch.search('Who is the president of the US?');
      expect(passages.single.text, contains('Donald Trump is the 47th and current president'));
      expect(passages.single.url, 'https://en.wikipedia.org/wiki/President_of_the_United_States');
    });

    test('missing key: Wikipedia is used', () {
      WebSearch.configure(engine: 'brave');
      expect(WebSearch.engine.name, 'Wikipedia');
    });

    test('engine error: falls back to Wikipedia', () async {
      WebSearch.configure(
        engine: 'tavily',
        tavilyApiKey: 'k',
        fetchJson: fakeFetcher([], (uri) => uri.host == 'api.tavily.com' ? const HttpException('HTTP 401') : wikipediaAnswer(uri)),
      );
      final passages = await WebSearch.search('Who is the president of the US?');
      expect(WebSearch.lastSource, 'Wikipedia');
      expect(passages.single.text, contains('Donald Trump'));
    });

    test('fallback disabled: the engine error is reported', () async {
      final calls = <RecordedCall>[];
      WebSearch.configure(
        engine: 'tavily',
        tavilyApiKey: 'k',
        fallbackToWikipedia: false,
        fetchJson: fakeFetcher(calls, (_) => const HttpException('HTTP 500')),
      );
      await expectLater(WebSearch.search('q'), throwsA(isA<HttpException>()));
      expect(calls, hasLength(1));
    });

    test('custom engine: used as is, results capped', () async {
      WebSearch.configure(customEngine: _MyEngine(), maxResults: 2);
      final passages = await WebSearch.search('hi');
      expect(passages.map((p) => p.text), ['hi 1', 'hi 2']);
      expect(WebSearch.lastSource, 'MySearch');
    });

    test('timeout: a hanging engine is abandoned, then Wikipedia is tried', () async {
      WebSearch.configure(
        customEngine: _SlowEngine(),
        timeout: const Duration(milliseconds: 200),
        fetchJson: fakeFetcher([], (uri) => {
              'query': {'search': []},
            }),
      );
      final timer = Stopwatch()..start();
      final passages = await WebSearch.search('q');
      expect(timer.elapsedMilliseconds, lessThan(2000));
      expect(passages, isEmpty);
      expect(WebSearch.lastSource, 'Wikipedia');
    });
  });

  group('prompt with web results', () {
    final chatml = presetById('chatml').template;

    test('results follow the question; date in the system prompt; prefix still matches', () {
      final prompt = assemblePrompt(
        template: chatml,
        history: const [],
        userText: 'What is the latest iPhone?',
        systemPrompt: 'SYS',
        currentDate: 'Saturday, October 17, 2026',
        webPassages: const [WebRagPassage(text: 'The iPhone 18 is the latest model.', url: 'u')],
      );
      expect(prompt, startsWith("<|im_start|>system\nSYS\n\nToday's date is Saturday, October 17, 2026.<|im_end|>\n"));
      expect(prompt, contains('What is the latest iPhone?\n\nWeb search results, newer than your training data:\n- The iPhone 18 is the latest model.\n'));
      final prefix = assemblePromptPrefix(
        template: chatml,
        history: const [],
        partialUserText: 'What is the',
        systemPrompt: 'SYS',
        currentDate: 'Saturday, October 17, 2026',
      );
      expect(prompt.startsWith(prefix), isTrue);
    });

    test('an office-holder question is asked neutrally with results, kept as said without', () {
      const results = [WebRagPassage(text: 'Donald Trump is the 47th and current president.', url: 'u')];
      final withResults =
          assemblePrompt(template: chatml, history: const [], userText: 'Is Joe Biden the president?', webPassages: results);
      expect(withResults, contains('<|im_start|>user\nWho is the president of the United States today?\n\nWeb search results'));
      expect(withResults, isNot(contains('Joe Biden')));
      final failed = assemblePrompt(
          template: chatml, history: const [], userText: 'Is Joe Biden the president?', webSearchFailed: true);
      expect(failed, contains('Is Joe Biden the president?'));
      expect(officeHolderQuestion('How old is the president?'), isNull);
    });

    test('failed search asks for an "as of my training" answer', () {
      final prompt = assemblePrompt(template: chatml, history: const [], userText: 'Q', webSearchFailed: true);
      expect(prompt, contains('as of my training'));
      expect(prompt, isNot(contains('Web search results')));
    });

    test('currentDateText format', () {
      expect(currentDateText(DateTime(2026, 10, 17)), 'Saturday, October 17, 2026');
    });
  });
}
