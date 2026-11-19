import 'dart:async';

import 'package:flutter/foundation.dart';

import '../agent/local_agent.dart';

/// One line of today's calorie log.
class CalorieEntry {
  const CalorieEntry({required this.id, required this.label, required this.calories});

  factory CalorieEntry.fromJson(Map<String, Object?> json) => CalorieEntry(
        id: json['id'] as String,
        label: json['label'] as String,
        calories: (json['calories'] as num).round(),
      );

  final String id;
  final String label;

  /// Negative for removals and downward corrections.
  final int calories;
}

/// Today's calorie log for the UI: a view of the native agent core's calories
/// skill (the log lives in its SQLite database). The on-device AI changes it
/// by voice; every change arrives as an agent `skill` event.
class CalorieLog extends ChangeNotifier {
  CalorieLog() {
    _unsubscribe = LocalAgent.listen((event) {
      if (event.type == 'skill' && event.json['skill'] == 'calories') _show(event.json);
    });
  }

  late final void Function() _unsubscribe;
  List<CalorieEntry> entries = const [];
  int total = 0;
  bool canUndo = false;

  /// Reads the log (the agent is created on first use).
  Future<void> load() async {
    try {
      final agent = await LocalAgent.get();
      _show(Map<String, Object?>.from(await agent.skill('calories', 'log.get') as Map));
    } catch (error) {
      debugPrint('[Calories] could not read the log: $error');
    }
  }

  Future<void> undo() async {
    final agent = await LocalAgent.get();
    _show(Map<String, Object?>.from(await agent.skill('calories', 'log.undo') as Map));
  }

  void _show(Map<String, Object?> log) {
    entries = [for (final e in log['entries'] as List? ?? const []) CalorieEntry.fromJson(Map<String, Object?>.from(e as Map))];
    total = (log['total'] as num? ?? 0).round();
    canUndo = log['canUndo'] == true;
    notifyListeners();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
