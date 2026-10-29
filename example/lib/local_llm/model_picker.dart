import 'package:flutter/material.dart';

import '../text_field_menu.dart';
import 'chat_template.dart';
import 'model_config.dart';
import 'model_store.dart';

/// Bottom sheet for choosing Local AI Chat's model, downloading or deleting
/// model files, and adding custom GGUF models. Port of the RN example's
/// ModelPicker.tsx. [onSelected] runs after the selection is saved.
class LocalLlmModelPicker extends StatefulWidget {
  const LocalLlmModelPicker({
    super.key,
    required this.store,
    required this.isBusy,
    required this.onSelected,
  });

  final LocalLlmModelStore store;

  /// True while a reply is being generated; switching models is blocked then.
  final bool isBusy;
  final void Function(LocalLlmModelConfig model) onSelected;

  @override
  State<LocalLlmModelPicker> createState() => _LocalLlmModelPickerState();
}

class _LocalLlmModelPickerState extends State<LocalLlmModelPicker> {
  List<LocalLlmModelConfig> _models = const [];
  String? _selectedId;
  final _downloaded = <String, bool>{};
  final _progress = <String, double>{};
  bool _isAdding = false;
  String _formError = '';
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _contextSize = TextEditingController(text: '$localLlmDefaultCustomContextSize');
  String _templateChoice = 'chatml';
  final _customFields = {
    for (final key in ['systemPrefix', 'userPrefix', 'assistantPrefix', 'turnSuffix', 'stop'])
      key: TextEditingController(),
  };
  bool _mergeSystem = false;

  @override
  void initState() {
    super.initState();
    _chooseTemplate('chatml');
    _refresh();
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _contextSize.dispose();
    for (final controller in _customFields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final models = await widget.store.listModels();
    final selected = await widget.store.selectedModel();
    final downloaded = <String, bool>{
      for (final model in models) model.id: await widget.store.isDownloaded(model),
    };
    if (!mounted) return;
    setState(() {
      _models = models;
      _selectedId = selected.id;
      _downloaded
        ..clear()
        ..addAll(downloaded);
    });
  }

  Future<void> _select(LocalLlmModelConfig model) async {
    if (widget.isBusy || model.id == _selectedId) return;
    await widget.store.selectModel(model.id);
    if (!mounted) return;
    setState(() => _selectedId = model.id);
    widget.onSelected(model);
  }

  Future<void> _download(LocalLlmModelConfig model) async {
    setState(() => _progress[model.id] = 0);
    try {
      await widget.store.download(model, onProgress: (fraction) {
        if (mounted) setState(() => _progress[model.id] = fraction);
      });
    } catch (error) {
      if (mounted) _showMessage('Download failed', '$error');
    } finally {
      if (mounted) setState(() => _progress.remove(model.id));
      await _refresh();
    }
  }

  Future<void> _confirmDeleteFile(LocalLlmModelConfig model) async {
    final ok = await _confirm(
      'Delete model file?',
      '${model.displayName} will be downloaded again when used.',
      'Delete',
    );
    if (!ok) return;
    await widget.store.deleteModelFile(model);
    await _refresh();
  }

  Future<void> _confirmRemove(LocalLlmModelConfig model) async {
    final ok = await _confirm(
      'Remove model?',
      'Removes ${model.displayName} from the list and deletes its file.',
      'Remove',
    );
    if (!ok) return;
    await widget.store.deleteModelFile(model);
    await widget.store.removeCustomModel(model.id);
    await _refresh();
  }

  void _chooseTemplate(String choice) {
    setState(() {
      _templateChoice = choice;
      if (choice == 'custom') return;
      final template = presetById(choice).template;
      _customFields['systemPrefix']!.text = template.systemPrefix;
      _customFields['userPrefix']!.text = template.userPrefix;
      _customFields['assistantPrefix']!.text = template.assistantPrefix;
      _customFields['turnSuffix']!.text = template.turnSuffix;
      _customFields['stop']!.text = template.stopSequences.join(', ');
      _mergeSystem = template.mergeSystemIntoFirstUser;
    });
  }

  ChatTemplate _formTemplate() {
    if (_templateChoice != 'custom') return presetById(_templateChoice).template;
    // Typed "\n" becomes a real newline.
    String field(String key) => _customFields[key]!.text.replaceAll(r'\n', '\n');
    return ChatTemplate(
      systemPrefix: field('systemPrefix'),
      userPrefix: field('userPrefix'),
      assistantPrefix: field('assistantPrefix'),
      turnSuffix: field('turnSuffix'),
      mergeSystemIntoFirstUser: _mergeSystem,
      stopSequences: field('stop')
          .split(',')
          .map((stop) => stop.trim())
          .where((stop) => stop.isNotEmpty)
          .toList(),
    );
  }

  Future<void> _addModel() async {
    try {
      final model = await widget.store.addCustomModel(
        displayName: _name.text,
        url: _url.text,
        contextSize: int.tryParse(_contextSize.text.trim()) ?? 0,
        chatTemplate: _formTemplate(),
      );
      _name.clear();
      _url.clear();
      setState(() {
        _isAdding = false;
        _formError = '';
      });
      await _refresh();
      await _select(model);
    } on FormatException catch (error) {
      setState(() => _formError = error.message);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessage(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  static String _formatSize(int? bytes) {
    if (bytes == null) return '';
    return bytes >= 1e9 ? '${(bytes / 1e9).toStringAsFixed(1)} GB' : '${(bytes / 1e6).round()} MB';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text('On-device model', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
              ],
            ),
            if (widget.isBusy)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Wait for the current reply to finish to switch models.'),
              ),
            for (final model in _models) _modelTile(model),
            const SizedBox(height: 8),
            if (!_isAdding)
              OutlinedButton(
                onPressed: () => setState(() => _isAdding = true),
                child: const Text('+ Add custom model'),
              )
            else
              _addForm(),
          ],
        ),
      ),
    );
  }

  Widget _modelTile(LocalLlmModelConfig model) {
    final selected = model.id == _selectedId;
    final downloaded = _downloaded[model.id] ?? false;
    final progress = _progress[model.id];
    final template = findMatchingPreset(model.chatTemplate)?.label ?? 'Custom template';
    final size = _formatSize(model.sizeBytes);
    return Card(
      child: InkWell(
        onTap: () => _select(model),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${selected ? '✓ ' : ''}${model.displayName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text([if (size.isNotEmpty) size, template, '${model.contextSize} tokens'].join(' · ')),
              Text(
                progress != null
                    ? 'Downloading ${(progress * 100).round()}%'
                    : downloaded
                        ? 'Downloaded'
                        : 'Not downloaded',
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (downloaded)
                    TextButton(onPressed: () => _confirmDeleteFile(model), child: const Text('Delete file'))
                  else if (progress == null)
                    TextButton(onPressed: () => _download(model), child: const Text('Download')),
                  if (model.isCustom)
                    TextButton(onPressed: () => _confirmRemove(model), child: const Text('Remove')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addForm() {
    Widget field(String label, TextEditingController controller, {String? hint, TextInputType? type}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: controller,
          keyboardType: type,
          contextMenuBuilder: textFieldContextMenu,
          autocorrect: false,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Custom model', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        field('Name', _name, hint: 'e.g. Llama 3.2 3B'),
        field('GGUF download URL (https)', _url, hint: 'https://huggingface.co/.../model-Q4_K_M.gguf', type: TextInputType.url),
        field('Context size (tokens)', _contextSize, type: TextInputType.number),
        const Text('Chat template'),
        Wrap(
          spacing: 8,
          children: [
            for (final preset in chatTemplatePresets)
              ChoiceChip(
                label: Text(preset.label),
                selected: _templateChoice == preset.id,
                onSelected: (_) => _chooseTemplate(preset.id),
              ),
            ChoiceChip(
              label: const Text('Custom'),
              selected: _templateChoice == 'custom',
              onSelected: (_) => _chooseTemplate('custom'),
            ),
          ],
        ),
        Text(
          _templateChoice == 'custom'
              ? r'Type \n for a line break. Stop sequences are comma-separated.'
              : 'Used by ${presetById(_templateChoice).usedBy}.',
        ),
        if (_templateChoice == 'custom') ...[
          field('System prefix', _customFields['systemPrefix']!),
          field('User prefix', _customFields['userPrefix']!),
          field('Assistant prefix', _customFields['assistantPrefix']!),
          field('Turn suffix', _customFields['turnSuffix']!),
          field('Stop sequences', _customFields['stop']!),
          SwitchListTile(
            title: const Text('No system role (merge into first user turn)'),
            value: _mergeSystem,
            onChanged: (value) => setState(() => _mergeSystem = value),
          ),
        ],
        if (_formError.isNotEmpty)
          Text(_formError, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _isAdding = false;
                _formError = '';
              }),
              child: const Text('Cancel'),
            ),
            const Spacer(),
            FilledButton(onPressed: _addModel, child: const Text('Add model')),
          ],
        ),
      ],
    );
  }
}
