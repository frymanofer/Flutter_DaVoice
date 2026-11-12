// Language packs (port of the React Native example's src/tts/languagePacks.ts, 2026-11-12): only English and Brazilian
// Portuguese voices are built into the app. Every other language's TTS model + voice-cloning encoder is downloaded from
// DaVoice's Cloudflare R2 the first time the language is chosen, sha256 checked, into the documents folder
// (language_packs/<language>/). assets/language_packs.json says which languages are built in ("bundled") and where the others
// come from ("baseUrl"); a built-in language's files must also be listed in pubspec.yaml (test/language_packs_test.dart).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class LanguagePackFile {
  const LanguagePackFile(this.filename, this.sizeBytes, this.sha256);

  final String filename;
  final int sizeBytes;
  final String sha256;
}

class LanguagePackProgress {
  const LanguagePackProgress(this.verifying, this.bytesDone, this.bytesTotal);

  /// True while the downloaded file's sha256 is checked.
  final bool verifying;
  final int bytesDone;
  final int bytesTotal;
}

class LanguagePackConfig {
  LanguagePackConfig(this.baseUrl, this.bundled, this.files);

  factory LanguagePackConfig.fromJson(Map<String, dynamic> json) {
    LanguagePackFile file(Map<String, dynamic> f) =>
        LanguagePackFile(f['file'] as String, (f['bytes'] as num).toInt(), (f['sha256'] as String).toLowerCase());
    return LanguagePackConfig(
      (json['baseUrl'] as String? ?? '').replaceAll(RegExp(r'/+$'), ''),
      [for (final id in json['bundled'] as List? ?? const []) id as String],
      {
        for (final e in (json['languages'] as Map<String, dynamic>).entries)
          e.key: {
            'model': file(Map<String, dynamic>.from(e.value['model'] as Map)),
            'embedder': file(Map<String, dynamic>.from(e.value['embedder'] as Map)),
          },
      },
    );
  }

  final String baseUrl;
  final List<String> bundled;

  /// language -> {'model': ..., 'embedder': ...}
  final Map<String, Map<String, LanguagePackFile>> files;
}

LanguagePackConfig? _config;
final _ready = <String>{};
Directory? _documents;
final _inFlight = <String, Future<void>>{};
final _cancelled = <String>{};
final _clients = <String, HttpClient>{};

/// Reads assets/language_packs.json once (call before the language screen, like the agent packs). [config] / [documents]: tests.
Future<void> loadLanguagePacks({LanguagePackConfig? config, Directory? documents}) async {
  _config = config ?? LanguagePackConfig.fromJson(jsonDecode(await rootBundle.loadString('assets/language_packs.json')) as Map<String, dynamic>);
  _documents = documents ?? await getApplicationDocumentsDirectory();
  _ready.clear();
}

LanguagePackConfig get _c => _config ?? (throw StateError('loadLanguagePacks() was not called'));

/// True when [language] is not built in and comes as a downloaded language pack.
bool isDownloadableLanguage(String language) => !_c.bundled.contains(language) && _c.files.containsKey(language);

int languagePackSizeBytes(String language) =>
    (_c.files[language]?.values ?? const <LanguagePackFile>[]).fold(0, (sum, f) => sum + f.sizeBytes);

String _dir(String language) => '${_documents!.path}/language_packs/$language';

String _path(String language, LanguagePackFile f) => '${_dir(language)}/${f.filename}';

Future<bool> _complete(String language, LanguagePackFile f) async {
  final file = File(_path(language, f));
  return await file.exists() && await file.length() == f.sizeBytes;
}

/// Checks the files on disk (present, exact size; sha256 was checked when they were downloaded). Built-in languages: true.
Future<bool> isLanguagePackReady(String language) async {
  if (!isDownloadableLanguage(language)) return true;
  for (final f in _c.files[language]!.values) {
    if (!await _complete(language, f)) {
      _ready.remove(language);
      return false;
    }
  }
  _ready.add(language);
  return true;
}

/// The file the speech library loads for [language]'s [kind] ('model' or 'embedder'): the Flutter asset path of a built-in
/// language, the absolute path of a downloaded one (after [isLanguagePackReady]), or null.
String? languageFile(String language, String kind) {
  final f = _c.files[language]?[kind];
  if (f == null) return null;
  if (_c.bundled.contains(language)) return 'assets/models/${f.filename}';
  return _ready.contains(language) ? _path(language, f) : null;
}

/// Stops a running download (the partial file is removed; the next download starts over).
void cancelLanguagePackDownload(String language) {
  _cancelled.add(language);
  _clients[language]?.close(force: true);
}

/// Downloads [language]'s pack if it isn't on disk yet; concurrent callers join one download. Throws a readable message.
Future<void> downloadLanguagePack(String language, {void Function(LanguagePackProgress)? onProgress}) {
  final running = _inFlight[language];
  if (running != null) return running;
  _cancelled.remove(language);
  final job = _download(language, onProgress).whenComplete(() {
    _inFlight.remove(language);
    _clients.remove(language)?.close(force: true);
  });
  _inFlight[language] = job;
  return job;
}

Future<void> _download(String language, void Function(LanguagePackProgress)? onProgress) async {
  if (await isLanguagePackReady(language)) return;
  if (_c.baseUrl.isEmpty) throw StateError('This language pack is not available yet (its download address is not set in the app).');
  final files = _c.files[language]!.values.toList();
  final total = files.fold(0, (sum, f) => sum + f.sizeBytes);
  await Directory(_dir(language)).create(recursive: true);
  var before = 0;
  for (final f in files) {
    final dest = File(_path(language, f));
    if (await _complete(language, f)) {
      before += f.sizeBytes;
      onProgress?.call(LanguagePackProgress(false, before, total));
      continue;
    }
    final temp = File('${dest.path}.download');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    _clients[language] = client;
    try {
      if (_cancelled.contains(language)) throw StateError('Download cancelled.');
      final response = await (await client.getUrl(Uri.parse('${_c.baseUrl}/${f.filename}'))).close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('Download failed: HTTP ${response.statusCode} for ${f.filename}.');
      }
      var received = 0;
      var last = DateTime.fromMillisecondsSinceEpoch(0);
      final sink = temp.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          final now = DateTime.now();
          if (now.difference(last).inMilliseconds >= 100) {
            last = now;
            onProgress?.call(LanguagePackProgress(false, before + received, total));
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      before += f.sizeBytes;
      onProgress?.call(LanguagePackProgress(true, before, total));
      final digest = await sha256.bind(temp.openRead()).first;
      if (digest.toString() != f.sha256) {
        throw HttpException('Download failed: ${f.filename} is damaged (checksum mismatch). Please retry.');
      }
      if (await dest.exists()) await dest.delete();
      await temp.rename(dest.path);
    } catch (error) {
      if (await temp.exists()) await temp.delete();
      if (_cancelled.contains(language)) throw StateError('Download cancelled.');
      rethrow;
    } finally {
      client.close(force: true);
    }
  }
  if (!await isLanguagePackReady(language)) throw StateError('Download failed: the language pack is incomplete. Please retry.');
}
