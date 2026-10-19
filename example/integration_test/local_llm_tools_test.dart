// On-device check of Local AI Chat's tool calling, without the voice UI: a
// multi-turn calorie conversation through the same LocalLlmService, calorie
// tools and history handling the app uses, checking the tracker's real total
// after every message.
//
//   flutter test integration_test/local_llm_tools_test.dart -d <device>
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_davoice_example/calories/calorie_store.dart';
import 'package:flutter_davoice_example/calories/calorie_tools.dart';
import 'package:flutter_davoice_example/local_llm/local_llm_service.dart';
import 'package:flutter_davoice_example/local_llm/prompt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('calorie tracker changed by voice commands, multi-turn', (tester) async {
    final license = (await rootBundle.loadString('licensekey.txt')).trim();
    final tmp = await getTemporaryDirectory();
    final store = CalorieStore(baseDirectory: () async => tmp);
    await store.load();
    await store.setTotal(0); // start the day at zero for the test
    final service = LocalLlmService(licenseKey: () => license)
      ..setTools(
        calorieTools(store),
        instructions: calorieToolInstructions,
        toolChoice: calorieToolChoice,
        missingToolCallReply: calorieMissingToolReply,
      );
    final load = Stopwatch()..start();
    final model = await service.warmUp();
    debugPrint('[LocalLlmTools] ${model.displayName} ready in ${load.elapsedMilliseconds} ms');

    // Same history shape as main.dart: each reply's tool messages before it.
    final history = <Map<String, String>>[];
    List<ChatTurn> turns() => [
          for (final m in history) ...[
            if (m['tools'] != null)
              for (final t in jsonDecode(m['tools']!) as List)
                ChatTurn(fromUser: t['role'] == 'user', text: t['content'] as String),
            if ((m['text'] ?? '').isNotEmpty) ChatTurn(fromUser: m['role'] == 'user', text: m['text']!),
          ],
        ];

    // (message, expected total afterwards)
    const conversation = [
      ('I had two eggs for breakfast', 156),
      ('And a banana', 261),
      ('Remove 100 calories', 161),
      ('How much have I eaten today?', 161),
      ('Undo that', 261),
      ('Set it to 1500', 1500),
      ('How many calories are in an apple?', 1500),
      ('Tell me a short joke', 1500),
      ('Log a can of coke', 1640),
      ('I ate a kiwi', 1703), // not in the table: Wikipedia, per 100 g
      ('I ate 200 g of kiwi', 1828), // a weight: 2 × 62.5
      ('I ate a zorblat', 1828), // found nowhere: asks for the calories
      ('I had 150 grams of lentils', 1999), // Wikipedia 114 per 100 g
      ('I ate 100 g of tofu', 2075),
      ('And two papayas', 2161), // 2 × 43 (per 100 g)
      ('Remove the kiwi', 2036), // deletes the latest kiwi line (125)
      ("I didn't eat the tofu", 1960),
      ('Remove 50 calories', 1910), // a number: subtracted
      ('Undo that', 1960),
      ('Delete the lentils from my list', 1789),
    ];
    // Removing a named food must delete its line, not add a "Removed" line.
    const deletes = {'Remove the kiwi', "I didn't eat the tofu", 'Delete the lentils from my list'};
    final failures = <String>[];
    for (final (userText, expectedTotal) in conversation) {
      final timer = Stopwatch()..start();
      final reply = StringBuffer();
      final calls = <String>[];
      var changed = false;
      final removedLinesBefore = store.entries.where((e) => e.label == 'Removed').length;
      final toolMessages = await service.generateReplyStream(
        turns(),
        userText,
        reply.write,
        onToolResult: (r) {
          calls.add('${r.call.name}(${jsonEncode(r.call.arguments)}) ${r.ok ? 'ok' : 'error: ${r.error}'}');
          if (r.ok && r.call.name != 'get_calories_today') changed = true;
        },
      );
      history
        ..add({'role': 'user', 'text': userText})
        ..add({
          'role': 'model',
          'text': reply.toString().trim(),
          if (toolMessages.isNotEmpty) 'tools': jsonEncode([for (final m in toolMessages) m.toJson()]),
        });
      final spoken = reply.toString().trim();
      // After a change was made, the reply must say so, not offer to do it.
      final offersAgain = changed &&
          RegExp(r"\b(would you like|do you want|shall i|should i|want me to|like me to)\b", caseSensitive: false)
              .hasMatch(spoken);
      // Online sources give fractional calories; allow rounding.
      final totalOk = (store.total - expectedTotal).abs() <= 3;
      final removedLines = store.entries.where((e) => e.label == 'Removed').length;
      final deletedLine = !deletes.contains(userText) || removedLines == removedLinesBefore;
      if (!deletedLine) failures.add('"$userText": added a "Removed" line instead of deleting the food');
      final ok = totalOk && !offersAgain && deletedLine;
      if (!totalOk) failures.add('"$userText": total ${store.total}, expected $expectedTotal');
      if (offersAgain) failures.add('"$userText": change made, but the reply offers to make it: $spoken');
      debugPrint('[LocalLlmTools] ${ok ? 'OK ' : 'BAD'} "$userText" -> ${calls.join('; ')}\n'
          '      spoken: ${reply.toString().trim()}\n      total ${store.total} | ${timer.elapsedMilliseconds} ms');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
