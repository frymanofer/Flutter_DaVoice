import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'chat_template.dart';
import 'model_config.dart';

/// Which models exist (built-ins plus user-added), which one is selected, and
/// their downloaded GGUF files. Settings persist in one small JSON file under
/// the app support directory, which users don't see. Ported from the RN
/// example's ModelRegistry.ts and ModelManager.ts.
class LocalLlmModelStore {
  LocalLlmModelStore({Future<Directory> Function()? baseDirectory})
      : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDirectory;
  _RegistryFile? _cached;
  Future<void> _writeChain = Future<void>.value();
  final _inFlightDownloads = <String, Future<void>>{};

  Future<Directory> _storageDir() async =>
      Directory('${(await _baseDirectory()).path}/$localLlmStorageDir');

  Future<Directory> _modelsDir() async => Directory('${(await _storageDir()).path}/models');

  Future<File> _registryFile() async => File('${(await _storageDir()).path}/model_registry.json');

  Future<_RegistryFile> _readRegistry() async {
    if (_cached != null) return _cached!;
    var registry = const _RegistryFile(localLlmDefaultModelId, []);
    try {
      final file = await _registryFile();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        registry = _RegistryFile(
          json['selectedModelId'] as String? ?? localLlmDefaultModelId,
          [
            for (final entry in json['customModels'] as List? ?? const [])
              LocalLlmModelConfig.fromJson(Map<String, dynamic>.from(entry as Map)),
          ],
        );
      }
    } catch (_) {
      // A corrupt settings file must not block the chat; use the defaults.
    }
    return _cached = registry;
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
        'customModels': [for (final model in next.customModels) model.toJson()],
      }));
    });
    return _writeChain;
  }

  Future<List<LocalLlmModelConfig>> listModels() async =>
      [...builtinLocalLlmModels, ...(await _readRegistry()).customModels];

  /// The selected model, or the default when the stored selection no longer
  /// exists (e.g. a removed custom model).
  Future<LocalLlmModelConfig> selectedModel() async {
    final selectedId = (await _readRegistry()).selectedModelId;
    final models = await listModels();
    return models.where((model) => model.id == selectedId).firstOrNull ??
        builtinLocalLlmModels.firstWhere((model) => model.id == localLlmDefaultModelId);
  }

  Future<void> selectModel(String id) async {
    if (!(await listModels()).any((model) => model.id == id)) {
      throw StateError('Unknown local LLM model "$id"');
    }
    await _writeRegistry((registry) => _RegistryFile(id, registry.customModels));
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
        _RegistryFile(registry.selectedModelId, [...registry.customModels, model]));
    return model;
  }

  /// Removes a user-added model from the list (its file is kept; call
  /// [deleteModelFile] first if wanted).
  Future<void> removeCustomModel(String id) async {
    await _writeRegistry((registry) => _RegistryFile(
          registry.selectedModelId == id ? localLlmDefaultModelId : registry.selectedModelId,
          registry.customModels.where((model) => model.id != id).toList(),
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
    final inUse = {for (final model in await listModels()) model.filename};
    final deleted = <String>[];
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
  const _RegistryFile(this.selectedModelId, this.customModels);

  final String selectedModelId;
  final List<LocalLlmModelConfig> customModels;
}
