// Language packs (port of the React Native example's src/tts/languagePacks.ts, 2026-11-12): only English and Brazilian
// Portuguese voices are built into the app. Every other language's TTS model + voice-cloning encoder is downloaded from
// DaVoice's Cloudflare R2 the first time the language is chosen, sha256 checked. assets/language_packs.json says which languages
// are built in ("bundled") and where the others come from ("baseUrl"); a built-in language's files must also be listed in
// pubspec.yaml (test/language_packs_test.dart).
//
// Remote voice manifest (as the RN example): installed apps get new voice files without an app update.
//  - refreshLanguagePackManifest() fetches <baseUrl>/manifest.json in the background. Used only when its Ed25519 signature verifies
//    with manifestPublicKey (the private key never ships), its schema is one this app reads, and every entry is valid (file name,
//    size, sha256). It only changes WHICH voice files a downloaded language uses: never code, never the LLM, never a built-in
//    language; the files still come from the same baseUrl, sha256-checked. Offline / missing / invalid: the built-in config.
//  - Atomic: each version has its own folder (language_packs/<language>/<version>/); a new version is used only once BOTH files are
//    downloaded and verified. The last WORKING version is kept (markLanguagePackWorking after the speech engine loaded it); a new
//    version that fails to load is rolled back (rollbackLanguagePack) and never used again.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Ed25519 public key of DaVoice's voice-manifest signer (base64, 32 bytes; the same key as the RN example).
const manifestPublicKey = '7/WYUqZDy1sTXyE4CKepClQ8GAEz0rvpbSWSMAIBYDA=';
const _manifestSchema = 1;

class LanguagePackFile {
  const LanguagePackFile(this.filename, this.sizeBytes, this.sha256);

  final String filename;
  final int sizeBytes;
  final String sha256;

  Map<String, Object> toJson() => {'file': filename, 'bytes': sizeBytes, 'sha256': sha256};
}

class LanguagePackProgress {
  const LanguagePackProgress(this.verifying, this.bytesDone, this.bytesTotal);

  /// True while the downloaded file's sha256 is checked.
  final bool verifying;
  final int bytesDone;
  final int bytesTotal;
}

LanguagePackFile _file(Map<String, dynamic> f) =>
    LanguagePackFile(f['file'] as String, (f['bytes'] as num).toInt(), (f['sha256'] as String).toLowerCase());

class LanguagePackConfig {
  LanguagePackConfig(this.baseUrl, this.bundled, this.files);

  factory LanguagePackConfig.fromJson(Map<String, dynamic> json) {
    return LanguagePackConfig(
      (json['baseUrl'] as String? ?? '').replaceAll(RegExp(r'/+$'), ''),
      [for (final id in json['bundled'] as List? ?? const []) id as String],
      {
        for (final e in (json['languages'] as Map<String, dynamic>).entries)
          e.key: {
            'model': _file(Map<String, dynamic>.from(e.value['model'] as Map)),
            'embedder': _file(Map<String, dynamic>.from(e.value['embedder'] as Map)),
          },
      },
    );
  }

  final String baseUrl;
  final List<String> bundled;

  /// language -> {'model': ..., 'embedder': ...}
  final Map<String, Map<String, LanguagePackFile>> files;
}

class VerifiedManifest {
  const VerifiedManifest(this.version, this.languages);

  final String version;
  final Map<String, Map<String, LanguagePackFile>> languages;
}

LanguagePackConfig? _config;
Directory? _documents;
VerifiedManifest? _manifest;
Map<String, Map<String, LanguagePackFile>> _working = {};
Map<String, List<String>> _bad = {};
final _active = <String, Map<String, LanguagePackFile>>{};
final _inFlight = <String, Future<void>>{};
final _cancelled = <String>{};
final _clients = <String, HttpClient>{};

/// Reads assets/language_packs.json and the stored manifest / working / bad versions once (call before the language screen).
/// [config] / [documents]: tests.
Future<void> loadLanguagePacks({LanguagePackConfig? config, Directory? documents}) async {
  _config = config ?? LanguagePackConfig.fromJson(jsonDecode(await rootBundle.loadString('assets/language_packs.json')) as Map<String, dynamic>);
  _documents = documents ?? await getApplicationDocumentsDirectory();
  _active.clear();
  _manifest = null;
  _working = {};
  _bad = {};
  try {
    final stored = File('$_root/manifest.json');
    if (await stored.exists()) _manifest = await verifyManifest(await stored.readAsString());   // a stored file is verified again
    final w = File('$_root/working.json');
    if (await w.exists()) {
      _working = {
        for (final e in (jsonDecode(await w.readAsString()) as Map<String, dynamic>).entries)
          e.key: {for (final k in ['model', 'embedder']) k: _file(Map<String, dynamic>.from((e.value as Map)[k] as Map))},
      };
    }
    final b = File('$_root/bad.json');
    if (await b.exists()) {
      _bad = {for (final e in (jsonDecode(await b.readAsString()) as Map<String, dynamic>).entries) e.key: [for (final v in e.value as List) v as String]};
    }
  } catch (_) {
    // a broken state file: the built-in config
  }
}

LanguagePackConfig get _c => _config ?? (throw StateError('loadLanguagePacks() was not called'));
String get _root => '${_documents!.path}/language_packs';

String get manifestUrl => _c.baseUrl.isEmpty ? '' : '${_c.baseUrl}/manifest.json';

final _fileName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,120}\.dm$');

LanguagePackFile? _entry(Object? x) {
  if (x is! Map) return null;
  final file = x['file'], bytes = x['bytes'], sha = x['sha256'];
  if (file is! String || !_fileName.hasMatch(file)) return null;
  if (bytes is! int || bytes <= 0 || bytes > 2000000000) return null;
  if (sha is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) return null;
  return LanguagePackFile(file, bytes, sha);
}

/// Parses and verifies a manifest file: `{"payload": "(json)", "signature": "(base64 Ed25519 over the payload's UTF-8 bytes)"}`.
/// Null when anything is off (signature, schema, any invalid entry: never applied in part); only downloaded languages are kept.
Future<VerifiedManifest?> verifyManifest(String text, {String publicKey = manifestPublicKey}) async {
  try {
    final outer = jsonDecode(text);
    if (outer is! Map || outer['payload'] is! String || outer['signature'] is! String) return null;
    final payload = outer['payload'] as String;
    final ok = await Ed25519().verify(
      utf8.encode(payload),
      signature: Signature(base64Decode(outer['signature'] as String),
          publicKey: SimplePublicKey(base64Decode(publicKey), type: KeyPairType.ed25519)),
    );
    if (!ok) return null;
    final p = jsonDecode(payload);
    if (p is! Map || p['schema'] != _manifestSchema || p['version'] is! String || (p['version'] as String).isEmpty || p['languages'] is! Map) {
      return null;
    }
    final languages = <String, Map<String, LanguagePackFile>>{};
    for (final e in (p['languages'] as Map).entries) {
      final id = e.key as String;
      if (!isDownloadableLanguage(id)) continue;   // built-in or unknown languages are never changed by a manifest
      final v = e.value;
      final model = v is Map ? _entry(v['model']) : null;
      final embedder = v is Map ? _entry(v['embedder']) : null;
      if (model == null || embedder == null) return null;
      languages[id] = {'model': model, 'embedder': embedder};
    }
    return VerifiedManifest(p['version'] as String, languages);
  } catch (_) {
    return null;
  }
}

String _versionKey(Map<String, LanguagePackFile> pack) =>
    '${pack['model']!.sha256.substring(0, 12)}-${pack['embedder']!.sha256.substring(0, 12)}';

String _versionDir(String language, Map<String, LanguagePackFile> pack) => '$_root/$language/${_versionKey(pack)}';

String _path(String language, Map<String, LanguagePackFile> pack, String kind) => '${_versionDir(language, pack)}/${pack[kind]!.filename}';

Map<String, LanguagePackFile>? _wanted(String language) {
  final fromManifest = _manifest?.languages[language];
  if (fromManifest != null && !(_bad[language] ?? const []).contains(_versionKey(fromManifest))) return fromManifest;
  return isDownloadableLanguage(language) ? _c.files[language] : null;
}

Future<void> _writeJsonAtomic(String path, Object value) async {
  await Directory(_root).create(recursive: true);
  final tmp = File('$path.tmp');
  await tmp.writeAsString(jsonEncode(value));
  await tmp.rename(path);
}

/// Fetches, verifies and stores the remote manifest (call once at app start, in the background; never throws). Returns what
/// happened, for the log.
Future<String> refreshLanguagePackManifest({Duration timeout = const Duration(seconds: 8)}) async {
  try {
    if (manifestUrl.isEmpty) return 'no manifest URL';
    final client = HttpClient()..connectionTimeout = timeout;
    String text;
    try {
      final response = await (await client.getUrl(Uri.parse(manifestUrl))).close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return 'no remote manifest (HTTP ${response.statusCode}); ${_manifest != null ? 'stored ${_manifest!.version}' : 'built-in config'}';
      }
      text = await response.transform(utf8.decoder).join().timeout(timeout);
    } finally {
      client.close(force: true);
    }
    final verified = await verifyManifest(text);
    if (verified == null) return 'remote manifest REJECTED (signature / schema / entries); ${_manifest != null ? 'stored ${_manifest!.version}' : 'built-in config'}';
    if (_manifest?.version == verified.version) return 'manifest ${verified.version} unchanged';
    await _writeJsonAtomic('$_root/manifest.json', jsonDecode(text) as Object);
    _manifest = verified;
    return 'manifest ${verified.version} applied (${verified.languages.keys.join(', ')})';
  } catch (error) {
    return 'manifest not refreshed: $error';
  }
}

Future<bool> _complete(String language, Map<String, LanguagePackFile> pack) async {
  for (final kind in const ['model', 'embedder']) {
    final f = File(_path(language, pack, kind));
    if (!await f.exists() || await f.length() != pack[kind]!.sizeBytes) return false;
  }
  return true;
}

/// Files of the first layout (language_packs/`<language>/<file>`, before versions): moved into their version folder once.
Future<void> _migrateLegacy(String language, Map<String, LanguagePackFile> pack) async {
  for (final kind in const ['model', 'embedder']) {
    final f = File('$_root/$language/${pack[kind]!.filename}');
    if (!await f.exists() || await f.length() != pack[kind]!.sizeBytes) return;
  }
  await Directory(_versionDir(language, pack)).create(recursive: true);
  for (final kind in const ['model', 'embedder']) {
    await File('$_root/$language/${pack[kind]!.filename}').rename(_path(language, pack, kind));
  }
}

/// True when [language] is not built in and comes as a downloaded language pack.
bool isDownloadableLanguage(String language) => !_c.bundled.contains(language) && _c.files.containsKey(language);

int languagePackSizeBytes(String language) =>
    (_wanted(language)?.values ?? const <LanguagePackFile>[]).fold(0, (sum, f) => sum + f.sizeBytes);

/// True when a usable version is on the device: the wanted one (manifest or built-in), else the last working one (used while the
/// new version downloads in the background). Built-in languages: true.
Future<bool> isLanguagePackReady(String language) async {
  final wanted = _wanted(language);
  if (wanted == null) return true;
  if (!await _complete(language, wanted)) {
    try {
      await _migrateLegacy(language, wanted);
    } catch (_) {}
  }
  if (await _complete(language, wanted)) {
    _active[language] = wanted;
    return true;
  }
  final last = _working[language];
  if (last != null && await _complete(language, last)) {
    _active[language] = last;
    return true;
  }
  _active.remove(language);
  return false;
}

/// True when a newer wanted version exists than the one in use (downloaded in the background for the next start).
bool languagePackUpdatePending(String language) {
  final wanted = _wanted(language), using = _active[language];
  return wanted != null && using != null && _versionKey(wanted) != _versionKey(using);
}

/// The file the speech library loads for [language]'s [kind] ('model' or 'embedder'): the Flutter asset path of a built-in
/// language, the absolute path of the downloaded version in use (after [isLanguagePackReady]), or null.
String? languageFile(String language, String kind) {
  if (_c.bundled.contains(language)) {
    final f = _c.files[language]?[kind];
    return f == null ? null : 'assets/models/${f.filename}';
  }
  final pack = _active[language];
  return pack == null ? null : _path(language, pack, kind);
}

/// The speech engine loaded [language]'s files: this version is the last working one. Older versions are removed (one previous
/// version is kept to roll back to).
Future<void> markLanguagePackWorking(String language) async {
  final pack = _active[language];
  if (pack == null) return;
  final previous = _working[language];
  _working = {..._working, language: pack};
  try {
    await _writeJsonAtomic('$_root/working.json', {
      for (final e in _working.entries) e.key: {for (final k in e.value.entries) k.key: k.value.toJson()},
    });
    final keep = {_versionKey(pack), if (previous != null) _versionKey(previous), if (_wanted(language) != null) _versionKey(_wanted(language)!)};
    await for (final entry in Directory('$_root/$language').list()) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      // other versions, and loose files of the first (unversioned) layout
      if (entry is! Directory || !keep.contains(name)) await entry.delete(recursive: true);
    }
  } catch (_) {
    // only bookkeeping / cleanup
  }
}

/// The speech engine could NOT load [language]'s files: that version is never used again and the last working one is selected
/// (true), or there is none (false: the app reports the error as before).
Future<bool> rollbackLanguagePack(String language) async {
  final failed = _active[language], last = _working[language];
  if (failed == null || last == null || _versionKey(failed) == _versionKey(last) || !await _complete(language, last)) return false;
  _bad = {..._bad, language: [...?_bad[language], _versionKey(failed)]};
  try {
    await _writeJsonAtomic('$_root/bad.json', _bad);
  } catch (_) {}
  _active[language] = last;
  return true;
}

/// Stops a running download (the partial file is removed; the next download starts over).
void cancelLanguagePackDownload(String language) {
  _cancelled.add(language);
  _clients[language]?.close(force: true);
}

/// Downloads the wanted version of [language] into its own folder if it isn't complete yet; concurrent callers join one
/// download. The version in use is not touched. Throws a readable message.
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

/// A newer version (remote manifest) while an older one is in use: downloaded quietly for the next start; never throws.
void updateLanguagePackInBackground(String language) {
  if (!languagePackUpdatePending(language)) return;
  unawaited(downloadLanguagePack(language).catchError((Object error) {
    // ignore: avoid_print
    print('[languagePacks] background update of $language failed (the current version stays): $error');
  }));
}

Future<void> _download(String language, void Function(LanguagePackProgress)? onProgress) async {
  final pack = _wanted(language);
  if (pack == null) return;
  if (!await _complete(language, pack)) {
    try {
      await _migrateLegacy(language, pack);
    } catch (_) {}
  }
  if (await _complete(language, pack)) {
    await isLanguagePackReady(language);
    return;
  }
  if (_c.baseUrl.isEmpty) throw StateError('This language pack is not available yet (its download address is not set in the app).');
  final total = pack.values.fold(0, (sum, f) => sum + f.sizeBytes);
  await Directory(_versionDir(language, pack)).create(recursive: true);
  var before = 0;
  for (final kind in const ['model', 'embedder']) {
    final f = pack[kind]!;
    final dest = File(_path(language, pack, kind));
    if (await dest.exists() && await dest.length() == f.sizeBytes) {
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
      final digest = await hash.sha256.bind(temp.openRead()).first;
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
