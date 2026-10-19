import 'dart:io';

import 'package:flutter_davoice_example/calories/calorie_store.dart';
import 'package:flutter_davoice_example/calories/calorie_tools.dart';
import 'package:flutter_davoice_example/calories/foods.dart';
import 'package:flutter_davoice_example/calories/online_foods.dart';
import 'package:flutter_davoice_example/local_llm/chat_template.dart';
import 'package:flutter_davoice_example/local_llm/prompt.dart';
import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('food table: exact, plural and contained names', () {
    expect(lookupFoodCalories('egg')?.calories, 78);
    expect(lookupFoodCalories('Eggs')?.calories, 78);
    expect(lookupFoodCalories('can of coke')?.calories, 140);
    expect(lookupFoodCalories('two slices of pizza')?.name, 'slice of pizza');
    expect(lookupFoodCalories('zorblat'), isNull);
  });

  test('tool policy per message', () {
    String choice(String text) => calorieToolChoice(text).toString();
    expect(choice('How many calories are in an apple?'), 'none');
    expect(choice('I had two eggs for breakfast'), '{name: log_food}');
    expect(choice('And a banana'), '{name: log_food}');
    expect(choice('Remove 100 calories'), '{name: remove_calories}');
    expect(choice('take off 50'), '{name: remove_calories}');
    expect(choice('Remove the kiwi'), '{name: delete_food}');
    expect(choice('Delete the banana from my list'), '{name: delete_food}');
    expect(choice("I didn't eat the coke"), '{name: delete_food}');
    expect(choice('Remove 2 eggs'), '{name: delete_food}');
    expect(choice('Clear the list'), '{name: set_calories_today}');
    expect(choice('Set it to 1500'), '{name: set_calories_today}');
    expect(choice('Actually today I ate 1200 calories in total'), '{name: set_calories_today}');
    expect(choice('Undo that'), '{name: undo_last_change}');
    expect(choice('How much have I eaten today?'), '{name: get_calories_today}');
    expect(choice('Tell me a short joke'), 'auto');
  });

  group('calorie tools', () {
    late Directory dir;
    late CalorieStore store;
    late Map<String, ToolDefinition> tools;

    setUp(() async {
      setFoodCalorieSources(const []); // no network in unit tests
      dir = await Directory.systemTemp.createTemp('calories_test');
      store = CalorieStore(baseDirectory: () async => dir);
      tools = {for (final t in calorieTools(store)) t.name: t};
    });

    tearDown(() async {
      await store.flush();
      await dir.delete(recursive: true);
    });

    test('log_food: the food table computes calories; model guesses are ignored', () async {
      final result = await tools['log_food']!.handler(
        {'food': 'eggs', 'quantity': 2, 'calories': 80},
        {'userText': 'I had two eggs for breakfast'},
      ) as Map;
      expect(result['calories'], 156);
      expect(result['logged'], '2 × egg');
      expect(store.total, 156);
    });

    test('log_food: a number the user said is used; "300 calories" shape is handled', () async {
      await tools['log_food']!.handler({'food': 'sandwich', 'calories': 500}, {'userText': 'I ate a sandwich of about 500 calories'});
      await tools['log_food']!.handler({'food': 'calories', 'quantity': 300}, {'userText': 'Add 300 calories'});
      expect(store.total, 800);
    });

    test('log_food: unknown food asks for the calories', () async {
      expect(
        () => tools['log_food']!.handler({'food': 'zorblat'}, {'userText': 'I ate a zorblat'}),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('How many calories did it have'))),
      );
    });

    test('remove never goes below zero; set and undo; persisted', () async {
      await tools['log_food']!.handler({'food': 'banana'}, {'userText': 'I had a banana'});
      await tools['remove_calories']!.handler({'amount': 500}, {});
      expect(store.total, 0);
      await tools['set_calories_today']!.handler({'total': 1500}, {});
      expect(store.total, 1500);
      final undone = await tools['undo_last_change']!.handler({}, {}) as Map;
      expect(undone['total_today'], 0);
      await store.flush();
      final reopened = CalorieStore(baseDirectory: () async => dir);
      await reopened.load();
      expect(reopened.total, 0);
      expect(reopened.canUndo, isTrue);
    });

    test('delete_food deletes the line (latest match, "last"), undo restores it, unknown lists the foods', () async {
      final tools = {for (final t in calorieTools(store)) t.name: t};
      await tools['log_food']!.handler({'food': 'eggs', 'quantity': 2}, {'userText': 'I had two eggs'});
      await tools['log_food']!.handler({'food': 'banana'}, {'userText': 'and a banana'});
      await tools['log_food']!.handler({'food': 'can of coke'}, {'userText': 'log a can of coke'});
      final deleted = await tools['delete_food']!.handler({'food': 'the banana'}, {}) as Map;
      expect(deleted['deleted'], 'banana');
      expect(store.total, 296);
      expect(store.entries.map((e) => e.label), ['2 × egg', 'can of coke']);
      await tools['undo_last_change']!.handler({}, {});
      expect(store.total, 401);
      await tools['delete_food']!.handler({'food': 'last'}, {});
      expect(store.entries.map((e) => e.label), ['2 × egg', 'banana']);
      expect(
        () => tools['delete_food']!.handler({'food': 'kiwi'}, {}),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          "I couldn't find kiwi in today's list. The list has: 2 × egg, 156 calories; banana, 105 calories. "
              'Which one should I remove?',
        )),
      );
      // Called directly (no arguments): the food comes from the user's words.
      await tools['delete_food']!.handler({}, {'userText': "I didn't eat the eggs"});
      expect(store.entries.map((e) => e.label), ['banana']);
      await tools['log_food']!.handler({'food': 'eggs', 'quantity': 2}, {'userText': 'I had two eggs'});
      await tools['delete_food']!.handler({}, {'userText': 'Remove the last one'});
      expect(store.entries.map((e) => e.label), ['banana']);
      expect(
        () => tools['delete_food']!.handler({}, {'userText': 'Please remove the kiwi from my list'}),
        throwsA(isA<StateError>().having((e) => e.message, 'message', startsWith("I couldn't find kiwi in today's list."))),
      );
    });

    test('runToolTurn with a named tool (no model call needed for reads)', () async {
      await store.add('banana', 105);
      final seen = <List<ToolTurnMessage>>[];
      final turn = await runToolTurn(
        tools: calorieTools(store),
        toolChoice: calorieToolChoice('How much have I eaten today?'),
        generate: (messages, onToken) async {
          seen.add(messages);
          onToken('You have eaten 105 calories today.');
        },
      );
      expect(seen.single.last.content, contains('"total_today":105'));
      expect(turn.text, 'You have eaten 105 calories today.');
    });
  });

  group('online food lookup', () {
    // Shapes of real Wikipedia (formatversion=2) and USDA FNDDS responses.
    Map<String, Object?> wikipedia(List<(String, String)> pages) => {
          'query': {
            'pages': [
              for (final (i, (title, wikitext)) in pages.indexed)
                {
                  'title': title,
                  'index': i + 1,
                  'revisions': [
                    {
                      'slots': {
                        'main': {'content': wikitext},
                      },
                    },
                  ],
                },
            ],
          },
        };
    final wikiPages = {
      'kiwi': [
        ('Actinidia arguta', '{{Nutritional value|name=Hardy kiwi, raw|kJ=322}}'),
        ('Kiwifruit', '{{Infobox nutritional value | name=Kiwifruit, Zespri SunGold, raw | kJ = 264 | protein=1 g}}'),
      ],
      'lentils': [
        ('Lentil', '=== Nutritional value ===\n{{nutritionalvalue|name=Lentils, mature seeds, cooked|kJ=477|water=69.64 g}}'),
      ],
      'empanada': [
        ('Burger King breakfast sandwiches', "{{Nutritional value|name=Croissan'wich breakfast sandwich|kJ=2176}}"),
      ],
    };
    final usdaFoods = {
      'empanada': [
        {
          'description': 'Empanada',
          'foodNutrients': [
            {'nutrientName': 'Energy', 'unitName': 'KCAL', 'value': 406},
          ],
          'foodMeasures': [
            {'disseminationText': 'Quantity not specified', 'gramWeight': 70, 'rank': 1},
            {'disseminationText': '1 mini empanada', 'gramWeight': 28, 'rank': 4},
            {'disseminationText': '1 medium empanada', 'gramWeight': 57, 'rank': 5},
          ],
        },
      ],
      'pad thai': [
        {
          'description': 'Pad Thai with chicken',
          'foodNutrients': [
            {'nutrientName': 'Energy', 'unitName': 'KCAL', 'value': 154},
          ],
          'foodMeasures': [
            {'disseminationText': '1 cup', 'gramWeight': 200, 'rank': 1},
            {'disseminationText': 'Quantity not specified', 'gramWeight': 200, 'rank': 2},
          ],
        },
      ],
    };
    Future<dynamic> wikiFetch(Uri uri, {String method = 'GET', Map<String, String> headers = const {}, String? body}) async {
      final food = uri.queryParameters['gsrsearch']!.split(' hastemplate:').first;
      return wikipedia(wikiPages[food] ?? const []);
    }

    Future<dynamic> usdaFetch(Uri uri, {String method = 'GET', Map<String, String> headers = const {}, String? body}) async {
      expect(uri.queryParameters['api_key'], 'KEY');
      return {'foods': usdaFoods[uri.queryParameters['query']] ?? const []};
    }

    Future<dynamic> offline(Uri uri, {String method = 'GET', Map<String, String> headers = const {}, String? body}) =>
        throw const SocketException('offline');

    late Directory dir;
    late CalorieStore store;
    late ToolDefinition logFood;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('calories_online_test');
      store = CalorieStore(baseDirectory: () async => dir);
      logFood = calorieTools(store).firstWhere((t) => t.name == 'log_food');
    });

    tearDown(() async {
      await store.flush();
      await dir.delete(recursive: true);
    });

    test('matching: names must really match', () {
      expect(matchesFood('kiwi', 'Kiwifruit'), isTrue);
      expect(matchesFood('chicken pad thai', 'Pad Thai with chicken'), isTrue);
      expect(matchesFood('a bowl of lentils', 'Lentil'), isTrue);
      expect(matchesFood('croissant', "Croissan'wich breakfast sandwich"), isFalse);
    });

    test('Wikipedia (default): per 100 g, grams the user said, wrong pages skipped', () async {
      setFoodCalorieSources([WikipediaFoodSource(fetchJson: wikiFetch)]);
      final kiwi = await logFood.handler({'food': 'kiwi'}, {'userText': 'I ate a kiwi'}) as Map;
      expect(kiwi['logged'], 'Kiwifruit (100 g, Wikipedia)');
      expect(kiwi['calories'], 63);
      expect(kiwi['source'], 'Wikipedia');
      // The model may put the grams in quantity or calories; both are ignored.
      final lentils = await logFood.handler(
        {'food': 'lentils', 'quantity': 200, 'calories': 200},
        {'userText': 'I had 200 grams of lentils'},
      ) as Map;
      expect(lentils['logged'], 'Lentil (200 g, Wikipedia)');
      expect(lentils['calories'], 228);
      expect(
        () => logFood.handler({'food': 'empanada'}, {'userText': 'I ate an empanada'}),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          "I couldn't find empanada in my food list or on Wikipedia. The app can also use the USDA food database "
              'if you add a USDA API key. How many calories did it have?',
        )),
      );
    });

    test('USDA when configured: serving sizes, then Wikipedia', () async {
      setFoodCalorieSources([
        UsdaFoodSource('KEY', fetchJson: usdaFetch),
        WikipediaFoodSource(fetchJson: wikiFetch),
      ]);
      final empanadas = await logFood.handler({'food': 'empanada', 'quantity': 2}, {'userText': 'I had two empanadas'}) as Map;
      expect(empanadas['logged'], '2 × Empanada (1 medium empanada (57 g), USDA)');
      expect(empanadas['calories'], 463);
      final padThai = await logFood.handler({'food': 'pad thai'}, {'userText': 'I had pad thai'}) as Map;
      expect(padThai['logged'], 'Pad Thai with chicken (200 g, USDA)');
      expect(padThai['calories'], 308);
      final kiwi = await logFood.handler({'food': 'kiwi'}, {'userText': 'I ate a kiwi'}) as Map;
      expect(kiwi['source'], 'Wikipedia');
      expect(
        () => logFood.handler({'food': 'zorblat'}, {'userText': 'I ate a zorblat'}),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          "I couldn't find zorblat in my food list or on USDA or Wikipedia. How many calories did it have?",
        )),
      );
    });

    test('a filler is requested only when a food is really looked up online', () async {
      final lookedUp = <String>[];
      setOnlineFoodLookupListener(lookedUp.add);
      addTearDown(() => setOnlineFoodLookupListener(null));
      setFoodCalorieSources([WikipediaFoodSource(fetchJson: wikiFetch)]);
      await logFood.handler({'food': 'banana'}, {'userText': 'I had a banana'}); // in the table
      await logFood.handler({'food': 'kiwi'}, {'userText': 'I ate a kiwi'});
      await logFood.handler({'food': 'kiwi'}, {'userText': 'and another kiwi'}); // cached
      expect(lookedUp, ['kiwi']);
      final filler = pickFoodLookupFiller('kiwi');
      expect(filler, contains(RegExp('kiwi', caseSensitive: false)));
      expect(pickFoodLookupFiller('kiwi'), isNot(filler)); // never twice in a row
    });

    test('offline: says the source could not be reached', () async {
      setFoodCalorieSources([WikipediaFoodSource(fetchJson: offline)]);
      expect(
        () => logFood.handler({'food': 'kiwi'}, {'userText': 'I ate a kiwi'}),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains("I couldn't reach Wikipedia right now"))),
      );
      expect(store.total, 0);
    });
  });

  test('prompt: tool block in the system prompt; tool messages after the user turn; prefix matches', () {
    final chatml = presetById('chatml').template;
    final tools = calorieTools(CalorieStore(baseDirectory: () async => Directory.systemTemp));
    final prompt = assemblePrompt(
      template: chatml,
      history: const [],
      userText: 'Undo that',
      systemPrompt: 'SYS',
      tools: tools,
      toolInstructions: calorieToolInstructions,
      toolMessages: const [
        ChatTurn(fromUser: false, text: '<tool_call>\n{"name": "undo_last_change", "arguments": {}}\n</tool_call>'),
        ChatTurn(fromUser: true, text: '<tool_response>\n{"ok":true}\n</tool_response>'),
      ],
    );
    expect(prompt, startsWith('<|im_start|>system\nSYS\n\nThe app shows a calories-today tracker.'));
    expect(prompt, contains('# Tools'));
    expect(
      prompt,
      endsWith('<|im_start|>user\nUndo that<|im_end|>\n<|im_start|>assistant\n<tool_call>\n{"name": "undo_last_change", '
          '"arguments": {}}\n</tool_call><|im_end|>\n<|im_start|>user\n<tool_response>\n{"ok":true}\n</tool_response>'
          '<|im_end|>\n<|im_start|>assistant\n'),
    );
    final prefix = assemblePromptPrefix(
      template: chatml,
      history: const [],
      partialUserText: 'Undo',
      systemPrompt: 'SYS',
      tools: tools,
      toolInstructions: calorieToolInstructions,
    );
    expect(prompt.startsWith(prefix), isTrue);
  });
}
