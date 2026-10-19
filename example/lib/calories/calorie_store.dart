import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// Today's calories for the Local AI Chat demo: a list of entries (foods,
// removals, corrections) whose sum is the total, persisted to a small JSON
// file, with an undo history. The AI changes it through the tools in
// calorie_tools.dart; the UI listens for changes. Port of the RN example's
// src/calories/CalorieStore.ts.

class CalorieEntry {
  const CalorieEntry({required this.id, required this.label, required this.calories, required this.at});

  factory CalorieEntry.fromJson(Map<String, Object?> json) => CalorieEntry(
        id: json['id'] as String,
        label: json['label'] as String,
        calories: (json['calories'] as num).round(),
        at: (json['at'] as num).toInt(),
      );

  final String id;
  final String label;

  /// Negative for removals and downward corrections.
  final int calories;
  final int at;

  Map<String, Object?> toJson() => {'id': id, 'label': label, 'calories': calories, 'at': at};
}

const _maxUndo = 20;

String _today() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class CalorieStore extends ChangeNotifier {
  CalorieStore({Future<Directory> Function()? baseDirectory})
      : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDirectory;
  String? _date;
  List<CalorieEntry> _entries = const [];
  List<List<CalorieEntry>> _undo = const [];
  Future<void> _writeChain = Future<void>.value();
  int _nextId = 1;

  List<CalorieEntry> get entries => _entries;
  int get total => _entries.fold(0, (sum, e) => sum + e.calories);
  bool get canUndo => _undo.isNotEmpty;

  Future<File> _file() async => File('${(await _baseDirectory()).path}/calories/today.json');

  /// Loads today's entries (a new day starts empty).
  Future<void> load() async {
    if (_date == _today()) return;
    _date = _today();
    _entries = const [];
    _undo = const [];
    try {
      final file = await _file();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
        if (json['date'] == _date) {
          List<CalorieEntry> parse(Object? list) => [
                for (final e in (list as List? ?? const [])) CalorieEntry.fromJson(Map<String, Object?>.from(e as Map)),
              ];
          _entries = parse(json['entries']);
          _undo = [for (final snapshot in (json['undo'] as List? ?? const [])) parse(snapshot)];
        }
      }
    } catch (_) {
      // A corrupt file starts the day fresh.
    }
    notifyListeners();
  }

  void _change(List<CalorieEntry> entries) {
    _undo = [..._undo, _entries];
    if (_undo.length > _maxUndo) _undo = _undo.sublist(_undo.length - _maxUndo);
    _entries = entries;
    _save();
  }

  void _save() {
    final snapshot = jsonEncode({
      'date': _date,
      'entries': [for (final e in _entries) e.toJson()],
      'undo': [
        for (final s in _undo) [for (final e in s) e.toJson()],
      ],
    });
    _writeChain = _writeChain.catchError((_) {}).then((_) async {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(snapshot);
    });
    notifyListeners();
  }

  CalorieEntry _entry(String label, num calories) => CalorieEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}-${_nextId++}',
        label: label,
        calories: calories.round(),
        at: DateTime.now().millisecondsSinceEpoch,
      );

  Future<int> add(String label, num calories) async {
    await load();
    _change([..._entries, _entry(label, calories)]);
    return total;
  }

  /// Removes up to [calories] (the total never goes below zero).
  Future<int> remove(num calories) async {
    await load();
    final amount = calories.abs() < (total < 0 ? 0 : total) ? calories.abs() : (total < 0 ? 0 : total);
    return add('Removed', -amount);
  }

  /// Deletes one entry (undoable). Returns the new total, or null if there is
  /// no such entry.
  Future<int?> deleteEntry(String id) async {
    await load();
    if (!_entries.any((e) => e.id == id)) return null;
    _change([for (final e in _entries) if (e.id != id) e]);
    return total;
  }

  /// Corrects today's total to exactly [newTotal] (kept as an adjustment
  /// entry, so the earlier entries and undo still make sense).
  Future<int> setTotal(num newTotal) async {
    await load();
    final rounded = newTotal.round();
    _change([..._entries, _entry('Set total to $rounded', rounded - total)]);
    return total;
  }

  /// Reverts the last change. Returns the new total, or null if there was
  /// nothing to undo.
  Future<int?> undo() async {
    await load();
    if (_undo.isEmpty) return null;
    _entries = _undo.last;
    _undo = _undo.sublist(0, _undo.length - 1);
    _save();
    return total;
  }

  /// Waits for pending writes (tests).
  Future<void> flush() => _writeChain;
}
