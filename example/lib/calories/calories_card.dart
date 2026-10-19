import 'package:flutter/material.dart';

import 'calorie_store.dart';

/// "Calories today" card for Local AI Chat. The on-device AI changes it by
/// voice through the calorie tools; every change shows here immediately and
/// can be undone with the button (or by saying "undo that").
class CaloriesCard extends StatelessWidget {
  const CaloriesCard({super.key, required this.store});

  final CalorieStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final recent = store.entries.reversed.take(3).toList();
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0x2434c759),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x7334c759)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CALORIES TODAY',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Color(0xa6ffffff)),
                        ),
                        Text(
                          '${store.total}',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: store.canUndo ? () => store.undo() : null,
                    child: const Text('Undo'),
                  ),
                ],
              ),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Try: "I had two eggs", "remove 200", "set it to 1500", "how much have I eaten?"',
                    style: TextStyle(fontSize: 13, color: Color(0xb3ffffff)),
                  ),
                )
              else
                for (final entry in recent)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(entry.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Colors.white)),
                        ),
                        Text(
                          '${entry.calories >= 0 ? '+' : '−'}${entry.calories.abs()}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
