import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';

import 'calorie_store.dart';
import 'foods.dart';
import 'online_foods.dart';

// The Local AI Chat demo's app tools: the on-device model logs, removes,
// corrects, reads and undoes today's calories by voice. Port of the RN
// example's src/calories/calorieTools.ts; descriptions and argument names are
// the ones measured on Qwen2.5 1.5B / 3B, so keep them in sync. The model
// extracts food and quantity; the app looks up the calories (foods.dart, then
// online: online_foods.dart).

List<FoodCalorieSource> _onlineSources = [WikipediaFoodSource()];
void Function(String food)? _onOnlineLookup;

/// Called when a food has to be looked up online (not in the table, not looked
/// up before), so the app can say something while it waits (pickFoodLookupFiller).
void setOnlineFoodLookupListener(void Function(String food)? listener) => _onOnlineLookup = listener;
final _onlineCache = <String, OnlineFood?>{};
const _onlineLookupTimeout = Duration(seconds: 6);

/// Online sources tried, in order, for foods that aren't in foods.dart.
/// Default: Wikipedia only. For USDA FoodData Central (dishes, brands, serving
/// sizes): `setFoodCalorieSources([UsdaFoodSource(apiKey), WikipediaFoodSource()])`.
void setFoodCalorieSources(List<FoodCalorieSource> sources) {
  _onlineSources = [...sources];
  _onlineCache.clear();
}

/// Tries each online source in turn. `noMatch` names the sources that answered
/// without a match; `unreachable` the ones that failed (offline, rate limit).
Future<({OnlineFood? found, List<String> noMatch, List<String> unreachable})> _lookupOnline(String food) async {
  final key = normalizeFoodName(food);
  final noMatch = <String>[];
  final unreachable = <String>[];
  if (_onlineCache.containsKey(key)) {
    return (found: _onlineCache[key], noMatch: [for (final s in _onlineSources) s.name], unreachable: unreachable);
  }
  if (_onlineSources.isNotEmpty) _onOnlineLookup?.call(food);
  for (final source in _onlineSources) {
    try {
      final found = await source.lookup(food).timeout(_onlineLookupTimeout);
      if (found != null) {
        _onlineCache[key] = found;
        return (found: found, noMatch: noMatch, unreachable: unreachable);
      }
      noMatch.add(source.name);
    } catch (error) {
      // ignore: avoid_print
      print('[Calories] ${source.name} lookup for "$food" failed: $error');
      unreachable.add(source.name);
    }
  }
  if (unreachable.isEmpty) _onlineCache[key] = null;
  return (found: null, noMatch: noMatch, unreachable: unreachable);
}

/// Worded to be repeated to the user as is (small models do).
String _unknownFoodMessage(String food, List<String> noMatch, List<String> unreachable) {
  final message = StringBuffer(
    "I couldn't find $food in my food list${noMatch.isEmpty ? '' : ' or on ${noMatch.join(' or ')}'}.",
  );
  if (unreachable.isNotEmpty) message.write(" I couldn't reach ${unreachable.join(' or ')} right now.");
  if (!_onlineSources.any((s) => s.name == 'USDA')) {
    message.write(' The app can also use the USDA food database if you add a USDA API key.');
  }
  message.write(' How many calories did it have?');
  return message.toString();
}

// Words around a food name that don't name the food: "I didn't eat the kiwi",
// "delete the lentils from my list".
final _notFoodWords = ('i me you can could please just actually didn didnt t did not never eat ate eaten have had drink '
        'drank remove delete erase take off away get rid of with and in from on to list today tracker entry entries item '
        'food line one it that this')
    .split(' ')
    .toSet();
final _lastEntry = RegExp(
  r'^\s*(it|that|this|(the )?(last|latest|previous)( one| thing| item| entry| food)?)\s*$'
  r'|\b(last|latest|previous) (one|thing|item|entry|food)\b|\b(remove|delete|erase) (it|that|this)\b',
  caseSensitive: false,
);

List<String> _foodWords(String text) =>
    normalizeFoodName(text).split(' ').where((w) => w.length > 1 && !_notFoodWords.contains(w)).toList();

List<CalorieEntry> _loggedFoods(List<CalorieEntry> entries) =>
    [for (final e in entries) if (e.calories > 0 && !e.label.startsWith('Set total to')) e];

/// The logged food the user means, from a food name or the user's whole
/// sentence: the most recent entry whose label contains the most of its words
/// ("kiwi" → "Kiwifruit (200 g, Wikipedia)", "I didn't eat the eggs" →
/// "2 × egg"); "it" / "the last one" → the most recent food.
CalorieEntry? _findLoggedFood(List<CalorieEntry> entries, String food) {
  final foods = _loggedFoods(entries);
  if (_lastEntry.hasMatch(food)) return foods.isEmpty ? null : foods.last;
  final words = _foodWords(food);
  if (words.isEmpty) return null;
  CalorieEntry? best;
  var bestScore = 0;
  for (final entry in foods) {
    final labelWords = normalizeFoodName(entry.label).split(' ');
    final score = words.where((word) => labelWords.any((l) => l.startsWith(word))).length;
    if (score > 0 && score >= bestScore) {
      best = entry;
      bestScore = score;
    }
  }
  return best;
}

final _grams = RegExp(r'(\d+(?:\.\d+)?)\s*(?:g|gr|grams?)\b', caseSensitive: false);

/// "200 grams of lentils" → 200, if the user said exactly one weight in grams.
num? _gramsSaid(String userText) {
  final matches = _grams.allMatches(userText).toList();
  return matches.length == 1 ? num.parse(matches.first[1]!) : null;
}

/// Added to the system prompt with the tools.
const calorieToolInstructions =
    'The app shows a calories-today tracker. Call a tool only when the user wants to log, change, undo or check '
    'THEIR OWN calories for today. A question about how many calories a food has is general knowledge: '
    'answer it directly, without any tool. Only use the tools listed below; for anything else answer normally. '
    'A tool result with "ok": true means the change is already made: say in one short sentence what was done; '
    'never ask whether to do it.';

/// Said when a tracker request didn't lead to a tool call (nothing changed).
const calorieMissingToolReply =
    "Sorry, I couldn't update the calorie tracker. Could you say it again, maybe with the number of calories?";

/// Per-message tool policy for the calorie demo, from the user's words alone.
/// When the words make the intent clear, the tool is named, which is far more
/// reliable with small on-device models than letting them choose:
/// - "How many calories are in an apple?" → none (general knowledge);
/// - read / undo → that tool, called directly (no arguments needed);
/// - set / remove / log → that tool; the model fills in the numbers;
/// - anything else → auto (the model decides).
ToolChoice calorieToolChoice(String userText) {
  final text = userText.toLowerCase();
  bool has(String pattern) => RegExp(pattern).hasMatch(text);
  final asksAboutAFood = has(r'\b(how many|how much)\b.*\bcalories?\b') && has(r'\b(in|does|do)\b');
  final aboutTheUser = has(r"\b(i|i'm|i've|me|my|today|so far)\b");
  if (asksAboutAFood && !aboutTheUser) return ToolChoice.none;
  if (has(r'\b(undo|cancel (it|that)|that was wrong|take that back)\b')) {
    return const ToolChoice.named('undo_last_change');
  }
  if (has(r'\b(set (it|my|the|today)|reset|in total|total (is|was|to)|clear (it|the list|everything|all)|(remove|delete) (all|everything))\b')) {
    return const ToolChoice.named('set_calories_today');
  }
  // "Remove 100 calories" subtracts a number; "remove the kiwi" / "I didn't eat
  // the coke" deletes that food's line.
  if (has(r'\b(remove|subtract|take off|take away|minus|delete|erase)\b') || has(r"\b(didn'?t|did not|never) (eat|have|drink)\b")) {
    final justANumber =
        has(r'\d+\s*(k?cals?|calories?)\b') || has(r'^\W*(remove|subtract|take off|take away|minus)\s+\d+\W*$');
    return ToolChoice.named(justANumber ? 'remove_calories' : 'delete_food');
  }
  if (has(r'\b(i (just )?(ate|had|drank)|log|add|ate|drank)\b')) return const ToolChoice.named('log_food');
  // Follow-ups without a verb: "And a banana", "also two cookies".
  if (has(r'^\s*(and|also|plus)\s+(a|an|some|one|two|three|four|five|\d+)\b')) {
    return const ToolChoice.named('log_food');
  }
  if (has(r"\b(how (much|many)( calories)? (have|did) i|my total|so far|today's total|calories (have i|today)|what have i eaten|what did i eat)\b")) {
    return const ToolChoice.named('get_calories_today');
  }
  return ToolChoice.auto;
}

String _gramsText(num grams) => grams == grams.roundToDouble() ? grams.round().toString() : grams.toString();

final _justCalories = RegExp(r'^\s*(k?cal(orie)?s?)?\s*$', caseSensitive: false);

/// The calorie tools, bound to [store].
List<ToolDefinition> calorieTools(CalorieStore store) => [
      ToolDefinition(
        name: 'get_calories_today',
        description: "Read the user's calorie tracker: today's total and entries.",
        inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
        handler: (args, context) async {
          await store.load();
          final recent = store.entries.length > 8 ? store.entries.sublist(store.entries.length - 8) : store.entries;
          return {
            'total_today': store.total,
            'entries': [
              for (final e in recent) {'item': e.label, 'calories': e.calories},
            ],
          };
        },
      ),
      ToolDefinition(
        name: 'log_food',
        description: "Log something the user says they ate or drank ('I ate', 'I had', 'log', 'add'). Give the food name "
            'and quantity; the app knows the calories of common foods. Set calories only if the user said a number.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'food': {
              'type': 'string',
              'description': "Food or drink, singular, e.g. egg, banana, slice of pizza, can of coke. Use 'calories' "
                  'if the user only said a number.',
            },
            'quantity': {'type': 'number', 'description': 'How many, default 1', 'minimum': 0},
            'calories': {'type': 'integer', 'description': 'Total calories, only if the user said the number', 'minimum': 0},
          },
          'required': ['food'],
        },
        handler: (args, context) async {
          final food = args['food'] as String;
          var count = args['quantity'] is num && (args['quantity'] as num) > 0 ? args['quantity'] as num : 1;
          var calories = args['calories'] as num?;
          // Trust a calorie number only if the user said it: small models
          // fill in their own (poor) guesses even when told not to.
          final userText = context['userText'] is String ? context['userText'] as String : '';
          // A weight ("200 grams") is neither a calorie number nor a count.
          final grams = _gramsSaid(userText);
          final said =
              RegExp(r'\d+').allMatches(userText.replaceAll(_grams, ' ')).map((m) => int.parse(m[0]!)).toSet();
          if (grams != null && count == grams) count = 1;
          if (calories != null && userText.isNotEmpty && !said.contains(calories.round())) calories = null;
          // "Add 300 calories" sometimes arrives as {food: "calories", quantity: 300}.
          if (calories == null && _justCalories.hasMatch(food) && count > 1) {
            calories = count;
            count = 1;
          }
          final num amount;
          final String label;
          String? source;
          final countText = count == count.roundToDouble() ? count.round().toString() : count.toString();
          final known = calories == null ? lookupFoodCalories(food) : null;
          if (calories != null) {
            amount = calories;
            label = _justCalories.hasMatch(food) ? 'Calories' : food;
          } else if (known != null) {
            amount = known.calories * count;
            label = count == 1 ? known.name : '$countText × ${known.name}';
          } else {
            final online = await _lookupOnline(food);
            final found = online.found;
            if (found == null) throw StateError(_unknownFoodMessage(food, online.noMatch, online.unreachable));
            source = found.source;
            final per100g = found.kcalPer100g;
            if (grams != null && per100g != null) {
              // "200 grams of lentils".
              amount = per100g * grams / 100;
              label = '${found.name} (${_gramsText(grams)} g, $source)';
            } else {
              amount = found.servingCalories * count;
              label = '${count == 1 ? '' : '$countText × '}${found.name} (${found.servingLabel}, $source)';
            }
          }
          final newTotal = await store.add(label, amount);
          return {
            'ok': true,
            'status': "Done: added to today's tracker",
            'logged': label,
            'calories': amount.round(),
            'total_today': newTotal,
            'source': ?source,
          };
        },
      ),
      // `food` is optional: when the app names this tool (calorieToolChoice), it
      // is called directly and the food is found from the user's own words,
      // since it must be one of today's entries; small models sometimes miss
      // this call.
      ToolDefinition(
        name: 'delete_food',
        description:
            "Delete a food or drink from today's list ('remove the kiwi', 'delete the coke', 'I didn't eat the banana').",
        inputSchema: const {
          'type': 'object',
          'properties': {
            'food': {'type': 'string', 'description': "The food to delete, e.g. kiwi, or 'last' for the last one"},
          },
        },
        handler: (args, context) async {
          await store.load();
          final food = (args['food'] as String?)?.trim() ?? '';
          final userText = context['userText'] is String ? context['userText'] as String : '';
          final entry = _findLoggedFood(store.entries, food.isNotEmpty ? food : userText);
          if (entry == null) {
            final what = food.isNotEmpty ? food : (_foodWords(userText).isEmpty ? 'that' : _foodWords(userText).join(' '));
            final foods = _loggedFoods(store.entries);
            final listed = [
              for (final e in foods.length > 6 ? foods.sublist(foods.length - 6) : foods) '${e.label}, ${e.calories} calories',
            ];
            // Worded to be repeated to the user as is (small models do).
            throw StateError(
              listed.isEmpty
                  ? "Today's list is empty, so there is nothing to remove."
                  : "I couldn't find $what in today's list. The list has: ${listed.join('; ')}. Which one should I remove?",
            );
          }
          final newTotal = await store.deleteEntry(entry.id);
          return {
            'ok': true,
            'status': "Done: deleted from today's list",
            'deleted': entry.label,
            'calories': entry.calories,
            'total_today': newTotal,
          };
        },
      ),
      ToolDefinition(
        name: 'remove_calories',
        description:
            "Subtract a number of calories from today's total ('remove 100 calories'). To remove a food, use delete_food.",
        inputSchema: const {
          'type': 'object',
          'properties': {
            'amount': {'type': 'integer', 'minimum': 0},
          },
          'required': ['amount'],
        },
        handler: (args, context) async {
          final amount = args['amount'] as num;
          return {
            'ok': true,
            'status': "Done: removed from today's total",
            'removed': amount,
            'total_today': await store.remove(amount),
          };
        },
      ),
      ToolDefinition(
        name: 'set_calories_today',
        description: "Replace today's total with an exact number, e.g. 'set it to 1500', 'reset to zero', 'today I ate "
            "1200 in total'.",
        inputSchema: const {
          'type': 'object',
          'properties': {
            'total': {'type': 'integer', 'minimum': 0},
          },
          'required': ['total'],
        },
        handler: (args, context) async => {
          'ok': true,
          'status': "Done: today's total replaced",
          'total_today': await store.setTotal(args['total'] as num),
        },
      ),
      ToolDefinition(
        name: 'undo_last_change',
        description: "Undo the last change to the calorie tracker ('undo', 'that was wrong', 'cancel that').",
        inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
        handler: (args, context) async {
          final after = await store.undo();
          return after == null
              ? {'ok': false, 'error': 'There is nothing to undo.'}
              : {'ok': true, 'status': 'Done: the last change was undone', 'total_today': after};
        },
      ),
    ];
