// On-device check of Local AI Chat's turns through the app's LocalLlmService
// and the shared native agent core (DavoiceAgent): a multi-turn calorie
// conversation (routing, tools, prompts, the calorie log in SQLite, online
// food lookups) and a web search, checking the tracker's real total after
// every message.
//
//   flutter test integration_test/agent_core_test.dart -d <device>
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_davoice_example/agent/agent_pack.dart';
import 'package:flutter_davoice_example/agent/local_agent.dart';
import 'package:flutter_davoice_example/local_llm/local_llm_service.dart';
import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAgentPack);

  testWidgets('calorie conversation and web search through the native agent core', (tester) async {
    final license = (await rootBundle.loadString('licensekey.txt')).trim();
    // A fresh day: the app's agent database, before the agent first opens it.
    final dbPath = '${(await getApplicationSupportDirectory()).path}/davoice_agent.db';
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('$dbPath$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    final service = LocalLlmService(licenseKey: () => license);
    final load = Stopwatch()..start();
    final model = await service.warmUp();
    debugPrint('[AgentCore] ${model.displayName} ready in ${load.elapsedMilliseconds} ms');

    final agent = await LocalAgent.get();
    final fillers = <String>[];
    LocalAgent.listen((e) {
      if (e.type == 'filler') fillers.add('${e.reason}: ${e.text}');
    });
    debugPrint('[AgentCore] core info: ${await agent.call('info')}');

    Future<num> total() async => ((await agent.skill('calories', 'log.get')) as Map)['total'] as num;

    // Same history shape as main.dart's _localChatHistory.
    final history = <Map<String, Object?>>[];
    Future<TurnResult> turn(String text) async {
      final spoken = StringBuffer();
      final result = await service.generateReplyStream(List.of(history), text, spoken.write);
      if (spoken.toString() != result.text) debugPrint('[AgentCore] streamed text differs from the result');
      history
        ..add({'role': 'user', 'text': text})
        ..add({'role': 'model', 'text': result.text, 'toolMessages': result.toolMessages});
      return result;
    }

    // (message, expected total afterwards): local_llm_tools_test.dart's list.
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
      ('I ate a kiwi', 1703),
      ('I ate 200 g of kiwi', 1828),
      ('I ate a zorblat', 1828),
      ('I had 150 grams of lentils', 1999),
      ('I ate 100 g of tofu', 2075),
      ('And two papayas', 2161),
      ('Remove the kiwi', 2036),
      ("I didn't eat the tofu", 1960),
      ('Remove 50 calories', 1910),
      ('Undo that', 1960),
      ('Delete the lentils from my list', 1789),
    ];
    const deletes = {'Remove the kiwi', "I didn't eat the tofu", 'Delete the lentils from my list'};
    final failures = <String>[];
    for (final (userText, expectedTotal) in conversation) {
      final timer = Stopwatch()..start();
      final entriesBefore = ((await agent.skill('calories', 'log.get')) as Map)['entries'] as List;
      final removedBefore = entriesBefore.where((e) => (e as Map)['label'] == 'Removed').length;
      final result = await turn(userText);
      final changed = result.toolResults.any((r) => r['ok'] == true && (r['call'] as Map)['name'] != 'get_calories_today');
      final offersAgain = changed &&
          RegExp(r"\b(would you like|do you want|shall i|should i|want me to|like me to)\b", caseSensitive: false)
              .hasMatch(result.text);
      final now = await total();
      final totalOk = (now - expectedTotal).abs() <= 3;
      final entries = ((await agent.skill('calories', 'log.get')) as Map)['entries'] as List;
      final removed = entries.where((e) => (e as Map)['label'] == 'Removed').length;
      final deletedLine = !deletes.contains(userText) || removed == removedBefore;
      if (!totalOk) failures.add('"$userText": total $now, expected $expectedTotal');
      if (offersAgain) failures.add('"$userText": change made, but the reply offers to make it: ${result.text}');
      if (!deletedLine) failures.add('"$userText": added a "Removed" line instead of deleting the food');
      final calls = result.toolResults
          .map((r) => '${(r['call'] as Map)['name']}(${(r['call'] as Map)['arguments']}) ${r['ok'] == true ? 'ok' : 'error: ${r['error']}'}')
          .join('; ');
      debugPrint('[AgentCore] ${totalOk && !offersAgain && deletedLine ? 'OK ' : 'BAD'} "$userText" -> $calls\n'
          '      spoken: ${result.text}\n      total $now | ${timer.elapsedMilliseconds} ms');
    }

    // A time-sensitive question: real Wikipedia through the native HTTP client.
    final search = await turn('Is Joe Biden the president?');
    debugPrint('[AgentCore] search: ${search.webSearch?['source']} failed=${search.webSearch?['failed']} -> ${search.text}');
    if (search.webSearch == null || search.webSearch!['failed'] == true) failures.add('web search failed or did not run');
    if (!search.text.contains('Trump')) failures.add('president answer: ${search.text}');
    debugPrint('[AgentCore] fillers: $fillers');
    if (!fillers.any((f) => f.startsWith('foodLookup'))) failures.add('no food lookup filler');
    if (!fillers.any((f) => f.startsWith('webSearch'))) failures.add('no web search filler');

    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
