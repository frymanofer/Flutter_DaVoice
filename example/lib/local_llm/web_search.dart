import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'needs_web_search.dart' show officeHolderPage;

/// Web search for Local AI Chat's time-sensitive questions, with a replaceable
/// search engine. Port of the RN example's src/local_llm/rag/web/.
///
/// Built in: Wikipedia (default, free, no key), Tavily and Brave (API keys).
/// Any other search API works too: implement [WebSearchEngine] and pass it to
/// [WebSearch.configure].
///
/// ```dart
/// WebSearch.configure();                                                // Wikipedia
/// WebSearch.configure(engine: 'tavily', tavilyApiKey: key);             // Tavily
/// WebSearch.configure(engine: 'brave', braveApiKey: key);               // Brave
/// WebSearch.configure(customEngine: MySearchEngine());                  // your own
/// ```
///
/// Keys never live in code: the demo reads them from the git-ignored
/// local.config.ts asset, like GEMINI_API_KEY.

/// A short piece of text a search returned, ready to go into the prompt.
class WebRagPassage {
  const WebRagPassage({required this.text, required this.url, this.title});

  final String text;
  final String url;
  final String? title;
}

/// A search backend. Return short plain-text passages (no HTML, a few hundred
/// characters each), most relevant first, at most [maxResults]. Throw on
/// failure; the caller falls back to Wikipedia or tells the user it couldn't
/// search.
abstract class WebSearchEngine {
  /// Shown in the status line and logs, e.g. "Wikipedia".
  String get name;

  Future<List<WebRagPassage>> search(String query, {required int maxResults});
}

/// Fetches and decodes JSON. Replaceable in tests.
typedef JsonFetcher = Future<dynamic> Function(
  Uri uri, {
  String method,
  Map<String, String> headers,
  String? body,
});

const _clientId = 'DaVoiceDemo/1.0 (https://davoice.io; info@davoice.io)';

/// Default [JsonFetcher]: dart:io HttpClient, 5 s connection timeout.
Future<dynamic> httpJsonFetcher(
  Uri uri, {
  String method = 'GET',
  Map<String, String> headers = const {},
  String? body,
}) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..userAgent = _clientId;
  try {
    final request = await client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (body != null) request.write(body);
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode} from ${uri.host}', uri: uri);
    }
    return jsonDecode(text);
  } finally {
    client.close(force: true);
  }
}

/// Max characters per passage: enough for a fact, short enough for a 1.5B model.
const maxPassageChars = 450;

String clipPassage(String text, [int maxChars = maxPassageChars]) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.length <= maxChars) return clean;
  return '${clean.substring(0, maxChars).replaceFirst(RegExp(r'\s+\S*$'), '')}...';
}

/// Removes HTML tags and decodes the common entities search APIs return.
String stripHtml(String text) => text
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'&#x27;|&#39;'), "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&');

/// Wikipedia: free, no key. Good for "who currently holds this office"
/// questions (article introductions name the current holder); no news, prices
/// or weather. Returns the best page's two most relevant sentences: a second
/// page is usually noise that confuses a small model.
class WikipediaSearchEngine implements WebSearchEngine {
  WikipediaSearchEngine({JsonFetcher? fetchJson}) : _fetch = fetchJson ?? httpJsonFetcher;

  final JsonFetcher _fetch;
  static const _headers = {'Api-User-Agent': _clientId};
  static final _stopWords = {
    ...'who what when where which why how is are was were the a an of in on at to for and or do does did current currently now today right latest tell me please'
        .split(' '),
    "who's",
    "what's",
  };

  @override
  String get name => 'Wikipedia';

  static List<String> _keywords(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9\s']"), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.length > 1 && !_stopWords.contains(word))
      .toList();

  /// The [count] sentences of [extract] most relevant to [query], favoring ones
  /// that say who or what is current, and their best score.
  static ({String text, double score}) _bestSentences(String extract, String query, [int count = 2]) {
    final words = [for (final word in _keywords(query)) RegExp('\\b${RegExp.escape(word)}', caseSensitive: false)];
    final sentences = extract.split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.length > 20).toList();
    final scored = <({String sentence, int index, double score})>[];
    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      var score = words.where((word) => word.hasMatch(sentence)).length.toDouble();
      if (RegExp(r'\b(current|currently|incumbent|officeholder|serving as|as of)\b', caseSensitive: false).hasMatch(sentence)) {
        score += 2;
      }
      if (RegExp(r'\b20(2[4-9]|[3-9]\d)\b').hasMatch(sentence)) score += 1.5;
      if (i == 0) score += 0.5;
      scored.add((sentence: sentence, index: i, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final best = scored.take(count).toList()..sort((a, b) => a.index.compareTo(b.index));
    return (
      text: best.map((s) => s.sentence).join(' '),
      score: best.fold(0.0, (max, s) => s.score > max ? s.score : max),
    );
  }

  @override
  Future<List<WebRagPassage>> search(String query, {required int maxResults}) async {
    // "Who holds this office" questions: the office's own page, whose intro
    // names the current holder (keyword search often finds the wrong article).
    final officePage = officeHolderPage(query);
    if (officePage != null) {
      final passages = await _bestPassage([officePage], officePage);
      if (passages.isNotEmpty) return passages;
    }
    final terms = _keywords(query).join(' ');
    final found = await _fetch(
      Uri.https('en.wikipedia.org', '/w/api.php', {
        'format': 'json',
        'action': 'query',
        'list': 'search',
        'srlimit': '3',
        'srsearch': terms.isEmpty ? query : terms,
      }),
      headers: _headers,
    );
    final titles = [
      for (final result in (found?['query']?['search'] as List? ?? const [])) result['title'].toString(),
    ];
    if (titles.isEmpty) return const [];
    return _bestPassage(titles, query);
  }

  /// The most relevant sentences of the best of these pages' introductions.
  Future<List<WebRagPassage>> _bestPassage(List<String> titles, String query) async {
    final pages = await _fetch(
      Uri.https('en.wikipedia.org', '/w/api.php', {
        'format': 'json',
        'action': 'query',
        'prop': 'extracts',
        'exintro': '1',
        'explaintext': '1',
        'redirects': '1',
        'titles': titles.join('|'),
      }),
      headers: _headers,
    );
    final candidates = <({double score, WebRagPassage passage})>[];
    for (final page in (pages?['query']?['pages'] as Map? ?? const {}).values) {
      final extract = page['extract'];
      if (extract is! String || extract.trim().isEmpty) continue;
      final best = _bestSentences(extract, query);
      final title = page['title'].toString();
      candidates.add((
        score: best.score,
        passage: WebRagPassage(
          text: clipPassage(best.text),
          url: 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}',
          title: title,
        ),
      ));
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(1).map((c) => c.passage).toList();
  }
}

/// Tavily (https://tavily.com): web search made for LLMs. Free plan: 1,000
/// searches a month, no credit card. Returns Tavily's short answer first, then
/// the top results' content.
class TavilySearchEngine implements WebSearchEngine {
  TavilySearchEngine(String apiKey, {JsonFetcher? fetchJson})
      : _apiKey = apiKey.trim(),
        _fetch = fetchJson ?? httpJsonFetcher {
    if (_apiKey.isEmpty) throw ArgumentError('Tavily needs an API key');
  }

  final String _apiKey;
  final JsonFetcher _fetch;

  @override
  String get name => 'Tavily';

  @override
  Future<List<WebRagPassage>> search(String query, {required int maxResults}) async {
    final json = await _fetch(
      Uri.https('api.tavily.com', '/search'),
      method: 'POST',
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_apiKey'},
      body: jsonEncode({
        'query': query,
        'search_depth': 'basic',
        'max_results': maxResults,
        'include_answer': true,
      }),
    );
    final passages = <WebRagPassage>[];
    final answer = json?['answer'];
    if (answer is String && answer.trim().isNotEmpty) {
      passages.add(WebRagPassage(text: clipPassage(answer), url: 'https://tavily.com', title: 'Tavily answer'));
    }
    for (final result in (json?['results'] as List? ?? const [])) {
      if (passages.length >= maxResults) break;
      final content = result['content'];
      if (content is! String || content.trim().isEmpty) continue;
      passages.add(WebRagPassage(
        text: clipPassage(content),
        url: result['url']?.toString() ?? '',
        title: result['title']?.toString(),
      ));
    }
    return passages;
  }
}

/// Brave Search API (https://brave.com/search/api): independent web index.
/// Plans include monthly free credit but need a payment method on file. Uses
/// each result's description plus up to two extra snippets.
class BraveSearchEngine implements WebSearchEngine {
  BraveSearchEngine(String apiKey, {JsonFetcher? fetchJson})
      : _apiKey = apiKey.trim(),
        _fetch = fetchJson ?? httpJsonFetcher {
    if (_apiKey.isEmpty) throw ArgumentError('Brave Search needs an API key');
  }

  final String _apiKey;
  final JsonFetcher _fetch;

  @override
  String get name => 'Brave';

  @override
  Future<List<WebRagPassage>> search(String query, {required int maxResults}) async {
    final json = await _fetch(
      Uri.https('api.search.brave.com', '/res/v1/web/search', {
        'q': query,
        'count': '$maxResults',
        'extra_snippets': 'true',
      }),
      headers: {'Accept': 'application/json', 'X-Subscription-Token': _apiKey},
    );
    final passages = <WebRagPassage>[];
    for (final result in (json?['web']?['results'] as List? ?? const [])) {
      if (passages.length >= maxResults) break;
      final snippets = (result['extra_snippets'] as List? ?? const []).take(2).map((s) => s.toString());
      final text = stripHtml([result['description']?.toString() ?? '', ...snippets].join(' '));
      if (text.trim().isEmpty) continue;
      passages.add(WebRagPassage(
        text: clipPassage(text),
        url: result['url']?.toString() ?? '',
        title: result['title']?.toString(),
      ));
    }
    return passages;
  }
}

/// Chooses the search engine and runs searches with a time limit and a
/// Wikipedia fallback.
class WebSearch {
  WebSearch._();

  static WebSearchEngine _wikipedia = WikipediaSearchEngine();
  static WebSearchEngine _engine = _wikipedia;
  static bool _fallbackToWikipedia = true;
  static int _maxResults = 3;
  static Duration _timeout = const Duration(seconds: 5);
  static String _lastSource = 'Wikipedia';

  /// Name of the engine that produced the last successful result.
  static String get lastSource => _lastSource;

  /// The engine [configure] selected.
  static WebSearchEngine get engine => _engine;

  /// Chooses the engine: [engine] is 'wikipedia' (default), 'tavily' or
  /// 'brave', or pass [customEngine] for any other search API. A built-in
  /// engine whose key is missing falls back to Wikipedia with a warning, so
  /// the app still works. [fetchJson] replaces HTTP for the built-in engines
  /// (tests).
  static void configure({
    String engine = 'wikipedia',
    WebSearchEngine? customEngine,
    String? tavilyApiKey,
    String? braveApiKey,
    bool fallbackToWikipedia = true,
    int maxResults = 3,
    Duration timeout = const Duration(seconds: 5),
    JsonFetcher? fetchJson,
  }) {
    _fallbackToWikipedia = fallbackToWikipedia;
    _maxResults = maxResults < 1 ? 1 : maxResults;
    _timeout = timeout;
    _wikipedia = WikipediaSearchEngine(fetchJson: fetchJson);
    if (customEngine != null) {
      _engine = customEngine;
      return;
    }
    try {
      _engine = switch (engine.trim().toLowerCase()) {
        'wikipedia' || '' => _wikipedia,
        'tavily' => TavilySearchEngine(tavilyApiKey ?? '', fetchJson: fetchJson),
        'brave' => BraveSearchEngine(braveApiKey ?? '', fetchJson: fetchJson),
        _ => throw ArgumentError('Unknown web search engine "$engine"'),
      };
    } catch (error) {
      // ignore: avoid_print
      print('[LocalLLM] web search engine "$engine" unavailable ($error); using Wikipedia');
      _engine = _wikipedia;
    }
  }

  static Future<List<WebRagPassage>> _run(WebSearchEngine engine, String query) async {
    final passages = await engine.search(query, maxResults: _maxResults).timeout(_timeout);
    return passages.take(_maxResults).toList();
  }

  /// Searches with the configured engine, then Wikipedia if allowed. Throws
  /// only when every engine tried failed.
  static Future<List<WebRagPassage>> search(String query) async {
    Object? firstError;
    try {
      final passages = await _run(_engine, query);
      if (passages.isNotEmpty || identical(_engine, _wikipedia) || !_fallbackToWikipedia) {
        _lastSource = _engine.name;
        return passages;
      }
    } catch (error) {
      firstError = error;
      // ignore: avoid_print
      print('[LocalLLM] ${_engine.name} search failed: $error');
      if (identical(_engine, _wikipedia) || !_fallbackToWikipedia) rethrow;
    }
    try {
      final passages = await _run(_wikipedia, query);
      _lastSource = _wikipedia.name;
      return passages;
    } catch (error) {
      throw firstError ?? error;
    }
  }
}
