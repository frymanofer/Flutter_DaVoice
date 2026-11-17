import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'chat_template.dart';
import 'demo.dart';
import 'model_config.dart';

/// Which models exist (built-ins plus user-added), which one is selected, and
/// their downloaded GGUF files. Settings persist in one small JSON file under
/// the app support directory, which users don't see. Ported from the RN
/// example's ModelRegistry.ts and ModelManager.ts.
class LocalLlmModelStore {
  LocalLlmModelStore({Future<Directory> Function()? baseDirectory, this.downloadPrebuiltStates = true})
      : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDirectory;

  /// False: [downloadPrebuiltState] only uses a pre-warmed state already on disk (tests: no network).
  final bool downloadPrebuiltStates;
  _RegistryFile? _cached;
  Future<void> _writeChain = Future<void>.value();
  final _inFlightDownloads = <String, Future<void>>{};
  final _inFlightStateDownloads = <String, Future<String?>>{};

  Future<Directory> _storageDir() async =>
      Directory('${(await _baseDirectory()).path}/$localLlmStorageDir');

  Future<Directory> _modelsDir() async => Directory('${(await _storageDir()).path}/models');

  Future<File> _registryFile() async => File('${(await _storageDir()).path}/model_registry.json');

  /// The car demo's minimum confidence for a local action (0 = off, the default); its own small file next to the registry.
  Future<double> localConfidence() async {
    try {
      final file = File('${(await _storageDir()).path}/local_confidence.json');
      if (await file.exists()) {
        final v = (jsonDecode(await file.readAsString()) as Map<String, dynamic>)['min'];
        if (v is num && v >= 0 && v <= 1) return v.toDouble();
      }
    } catch (_) {}
    return 0;
  }

  Future<void> setLocalConfidence(double value) async {
    final dir = await _storageDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    await File('${dir.path}/local_confidence.json').writeAsString(jsonEncode({'min': value}));
  }

  Future<_RegistryFile> _readRegistry() async {
    if (_cached != null) return _cached!;
    var registry = const _RegistryFile(localLlmDefaultModelId, [], 'car', {});
    var newDefault = false;
    try {
      final file = await _registryFile();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        // The app's default when the file was written: a new default (an app
        // update) is selected once, replacing an earlier choice.
        newDefault = (json['defaultModelId'] ?? localLlmEarlierDefaultModelId) != localLlmDefaultModelId;
        registry = _RegistryFile(
          newDefault ? localLlmDefaultModelId : json['selectedModelId'] as String? ?? localLlmDefaultModelId,
          [
            for (final entry in json['customModels'] as List? ?? const [])
              LocalLlmModelConfig.fromJson(Map<String, dynamic>.from(entry as Map)),
          ],
          localDemos.contains(json['demo']) ? json['demo'] as String : 'car',
          Map<String, String>.from(json['selectedByDemo'] as Map? ?? const {}),
        );
      }
    } catch (_) {
      // A corrupt settings file must not block the chat; use the defaults.
    }
    _cached = registry;
    setCurrentLocalDemo(registry.demo);
    if (newDefault) await _writeRegistry((registry) => registry);
    return registry;
  }

  /// Updates the cached copy now and serializes disk writes, so back-to-back
  /// changes (add, then select) can't land out of order.
  Future<void> _writeRegistry(_RegistryFile Function(_RegistryFile) update) async {
    final next = update(await _readRegistry());
    _cached = next;
    _writeChain = _writeChain.catchError((_) {}).then((_) async {
      final file = await _registryFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'selectedModelId': next.selectedModelId,
        'defaultModelId': localLlmDefaultModelId,
        'customModels': [for (final model in next.customModels) model.toJson()],
        'demo': next.demo,
        'selectedByDemo': next.selectedByDemo,
      }));
    });
    return _writeChain;
  }

  Future<List<LocalLlmModelConfig>> listModels() async =>
      [...builtinLocalLlmModels, ...(await _readRegistry()).customModels];

  /// The selected model, or the default when the stored selection no longer
  /// exists (e.g. a removed custom model).
  Future<LocalLlmModelConfig> selectedModel() async {
    final r = await _readRegistry();
    // each demo has its own model (its own pick, else the demo's default model)
    final selectedId = r.selectedByDemo[r.demo] ?? localLlmDemoDefaultModel[r.demo] ?? r.selectedModelId;
    final models = await listModels();
    // A model that is no longer listed (e.g. a removed older version) -> the demo's own default, then the app default.
    return models.where((model) => model.id == selectedId).firstOrNull ??
        models.where((model) => model.id == localLlmDemoDefaultModel[r.demo]).firstOrNull ??
        builtinLocalLlmModels.firstWhere((model) => model.id == localLlmDefaultModelId);
  }

  Future<void> selectModel(String id) async {
    if (!(await listModels()).any((model) => model.id == id)) {
      throw StateError('Unknown local LLM model "$id"');
    }
    await _writeRegistry((r) => _RegistryFile(id, r.customModels, r.demo, {...r.selectedByDemo, r.demo: id}));
  }

  /// The Local AI Chat demo ('calories' / 'car').
  Future<String> demo() async => (await _readRegistry()).demo;

  Future<void> setDemo(String demo) async {
    setCurrentLocalDemo(demo);
    await _writeRegistry((r) => _RegistryFile(r.selectedModelId, r.customModels, currentLocalDemo, r.selectedByDemo));
  }

  /// Where a saved KV-cache state lives (FlutterDavoiceLlm.saveState / loadState): the processed system prompt, restored at the
  /// next start instead of ~40 s of prompt processing on a phone CPU. Keyed by the model file and context size, and by
  /// [promptKey] (the prompt's system part, see [stablePromptKey]): two demos / languages keep two states.
  Future<String> kvStatePath(LocalLlmModelConfig model, [String? promptKey]) async =>
      '${(await _modelsDir()).path}/${_kvStatePrefix(model)}${promptKey != null ? '$promptKey.' : ''}kvstate';

  /// Where the pre-warmed state for [language] ([LocalLlmModelConfig.prebuiltStates]) is stored: the same prefix as the model's own
  /// saved states, so the newest-2-per-model cleanup treats it as one of them.
  Future<String> prebuiltStatePath(LocalLlmModelConfig model, String language) async =>
      '${(await _modelsDir()).path}/${_kvStatePrefix(model)}prebuilt-$language.kvstate';

  /// Downloads the pre-warmed state of [language] for [model] if the model has one and it isn't on disk yet (sha256 checked; a
  /// failure only logs: the phone then warms up itself). Resolves to the file's path, or null when there is none. Port of the RN
  /// example's downloadPrebuiltState.
  Future<String?> downloadPrebuiltState(
    LocalLlmModelConfig model,
    String language, {
    void Function(double fraction)? onProgress,
  }) {
    final entry = model.prebuiltStates[language];
    if (entry == null) return Future.value(null);
    return () async {
      final destPath = await prebuiltStatePath(model, language);
      final running = _inFlightStateDownloads[destPath];
      if (running != null) return running;
      final job = _downloadPrebuiltStateOnce(model, language, entry, destPath, onProgress).catchError((Object error) {
        // ignore: avoid_print
        print('[LocalLLM] pre-warmed state not downloaded (the phone warms up itself): $error');
        return null;
      }).whenComplete(() {
        // Block body: returning remove()'s value (this very future) would make whenComplete wait for itself.
        _inFlightStateDownloads.remove(destPath);
      });
      _inFlightStateDownloads[destPath] = job;
      return job;
    }();
  }

  Future<String?> _downloadPrebuiltStateOnce(
    LocalLlmModelConfig model,
    String language,
    PrebuiltState entry,
    String destPath,
    void Function(double fraction)? onProgress,
  ) async {
    final dest = File(destPath);
    if (await dest.exists()) return destPath;
    if (entry.url.isEmpty || !downloadPrebuiltStates) return null; // not hosted / off (a copied-in file above is still used)
    final dir = await _modelsDir();
    await dir.create(recursive: true);
    // The phone already saved its own state for this language (states are named "<language>-<prompt hash>"): no 400 MB download.
    final own = '${_kvStatePrefix(model)}$language-';
    await for (final e in dir.list()) {
      final name = e.uri.pathSegments.last;
      if (e is File && name.startsWith(own) && name.endsWith('.kvstate')) return null;
    }
    final temp = File('$destPath.download');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final response = await (await client.getUrl(Uri.parse(entry.url))).close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('pre-warmed state download failed: HTTP ${response.statusCode}');
      }
      final total = response.contentLength > 0 ? response.contentLength : entry.sizeBytes;
      var received = 0;
      var lastReport = DateTime.fromMillisecondsSinceEpoch(0);
      final sink = temp.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          final now = DateTime.now();
          if (onProgress != null && now.difference(lastReport).inMilliseconds >= 100) {
            lastReport = now;
            onProgress(received / total);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      final digest = await sha256.bind(temp.openRead()).first;
      if (digest.toString() != entry.sha256.toLowerCase()) {
        throw const HttpException('pre-warmed state download failed: checksum mismatch');
      }
      if (await dest.exists()) {
        await temp.delete();
      } else {
        await temp.rename(destPath);
      }
      onProgress?.call(1);
      return destPath;
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  String _kvStatePrefix(LocalLlmModelConfig model) {
    final key = (model.sha256 ?? '${model.sizeBytes ?? 0}');
    return '${model.filename}.${key.length > 12 ? key.substring(0, 12) : key}.ctx${model.contextSize}.';
  }

  /// Adds a user-defined model. The id and file name come from the name and
  /// are made unique, so two models never share a downloaded file.
  Future<LocalLlmModelConfig> addCustomModel({
    required String displayName,
    required String url,
    required int contextSize,
    required ChatTemplate chatTemplate,
  }) async {
    final name = displayName.trim();
    final link = url.trim();
    if (name.isEmpty) throw const FormatException('Model name is required');
    if (!link.toLowerCase().startsWith('https://')) {
      throw const FormatException('Model URL must start with https://');
    }
    if (!RegExp(r'\.gguf(\?|$)', caseSensitive: false).hasMatch(link)) {
      throw const FormatException('Model URL must point to a .gguf file');
    }
    if (contextSize < 512) throw const FormatException('Context size must be at least 512');

    final existingIds = {for (final model in await listModels()) model.id};
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9.]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = 'custom-${slug.isEmpty ? 'model' : slug}';
    var id = base;
    for (var n = 2; existingIds.contains(id); n++) {
      id = '$base-$n';
    }
    final model = LocalLlmModelConfig(
      id: id,
      displayName: name,
      filename: '$id.gguf',
      url: link,
      contextSize: contextSize,
      chatTemplate: chatTemplate,
      isCustom: true,
    );
    await _writeRegistry((registry) =>
        _RegistryFile(registry.selectedModelId, [...registry.customModels, model], registry.demo, registry.selectedByDemo));
    return model;
  }

  /// Removes a user-added model from the list (its file is kept; call
  /// [deleteModelFile] first if wanted).
  Future<void> removeCustomModel(String id) async {
    await _writeRegistry((registry) => _RegistryFile(
          registry.selectedModelId == id ? localLlmDefaultModelId : registry.selectedModelId,
          registry.customModels.where((model) => model.id != id).toList(),
          registry.demo,
          {for (final e in registry.selectedByDemo.entries) if (e.value != id) e.key: e.value},
        ));
  }

  Future<String> modelPath(LocalLlmModelConfig model) async =>
      '${(await _modelsDir()).path}/${model.filename}';

  Future<bool> isDownloaded(LocalLlmModelConfig model) async =>
      File(await modelPath(model)).exists();

  Future<void> deleteModelFile(LocalLlmModelConfig model) async {
    final file = File(await modelPath(model));
    if (await file.exists()) await file.delete();
  }

  /// Downloads [model]'s GGUF unless it is already on disk. Concurrent callers
  /// for the same model join one transfer (two writers into one file corrupt
  /// it). Downloads to a temporary file and renames it when complete.
  Future<void> download(
    LocalLlmModelConfig model, {
    void Function(double fraction)? onProgress,
  }) {
    final existing = _inFlightDownloads[model.id];
    if (existing != null) return existing;
    final transfer = _downloadOnce(model, onProgress).whenComplete(() {
      _inFlightDownloads.remove(model.id);
    });
    _inFlightDownloads[model.id] = transfer;
    return transfer;
  }

  Future<void> _downloadOnce(
    LocalLlmModelConfig model,
    void Function(double fraction)? onProgress,
  ) async {
    final dest = File(await modelPath(model));
    if (await dest.exists()) return;
    await dest.parent.create(recursive: true);
    final temp = File('${dest.path}.download');

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(model.url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException(
          'Model download failed for ${model.displayName}: HTTP ${response.statusCode}',
        );
      }
      final total = response.contentLength;
      var received = 0;
      var lastReport = DateTime.fromMillisecondsSinceEpoch(0);
      final sink = temp.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          final now = DateTime.now();
          // About 10 updates a second; a multi-GB file only crosses a few
          // dozen whole-percent boundaries.
          if (total > 0 && onProgress != null && now.difference(lastReport).inMilliseconds >= 100) {
            lastReport = now;
            onProgress(received / total);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (total > 0 && received != total) {
        throw HttpException(
          'Model download for ${model.displayName} was cut off ($received of $total bytes)',
        );
      }
      // A wrong file would otherwise load as a broken model.
      final expected = model.sha256;
      if (expected != null) {
        final digest = await sha256.bind(temp.openRead()).first;
        if (digest.toString() != expected.toLowerCase()) {
          throw HttpException('Model download failed for ${model.displayName}: checksum mismatch');
        }
      }
      if (await dest.exists()) {
        await temp.delete();
      } else {
        await temp.rename(dest.path);
      }
      onProgress?.call(1);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  /// Deletes `.gguf` files no listed model uses any more (e.g. after a
  /// built-in model switched files). Returns the deleted file names.
  Future<List<String>> deleteUnusedModelFiles() async {
    final dir = await _modelsDir();
    if (!await dir.exists()) return const [];
    final models = await listModels();
    final inUse = {for (final model in models) model.filename};
    final deleted = <String>[];
    // Saved states: each model file keeps its newest [kvStatesPerModel]; others and states of removed models are deleted.
    final prefixes = {for (final model in models) _kvStatePrefix(model)};
    final states = <File>[];
    await for (final entry in dir.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is File && (name.endsWith('.kvstate') || name.endsWith('.kvstate.tmp'))) states.add(entry);
    }
    states.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final kept = <String, int>{};
    for (final f in states) {
      final name = f.uri.pathSegments.last;
      final prefix = prefixes.where((p) => name.startsWith(p)).firstOrNull;
      final n = prefix == null ? kvStatesPerModel : (kept[prefix] ?? 0);
      if (prefix != null && !name.endsWith('.tmp') && n < kvStatesPerModel) {
        kept[prefix] = n + 1;
        continue;
      }
      await f.delete();
      deleted.add(name);
    }
    await for (final entry in dir.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is File && name.endsWith('.gguf') && !inUse.contains(name)) {
        await entry.delete();
        deleted.add(name);
      }
    }
    return deleted;
  }
}

class _RegistryFile {
  const _RegistryFile(this.selectedModelId, this.customModels, [this.demo = 'car', this.selectedByDemo = const {}]);

  final String selectedModelId;
  final List<LocalLlmModelConfig> customModels;
  final String demo;
  final Map<String, String> selectedByDemo;
}

/// Which saved state fits this prompt: a hash of its system part (persona, language, tools) WITHOUT the date line, which changes
/// every day (port of the RN example's stablePromptKey: FNV-1a, 32 bits, same value for the same prompt).
String stablePromptKey(String prompt, String dateText) {
  final userAt = prompt.indexOf('<|im_start|>user');
  final system = (userAt >= 0 ? prompt.substring(0, userAt) : prompt).split(dateText).join();
  var h = 0x811c9dc5;
  for (final unit in system.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// Saved states kept per model file (one per prompt variant, ~435 MB each).
const kvStatesPerModel = 2;
