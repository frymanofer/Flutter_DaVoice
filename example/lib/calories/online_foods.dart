import 'dart:math';

import '../local_llm/web_search.dart' show JsonFetcher, httpJsonFetcher;
import 'foods.dart';

// Online calorie lookup for foods that aren't in foods.dart. Port of the RN
// example's src/calories/onlineFoods.ts. Wikipedia is used by default (free,
// no key) but only knows plain foods, per 100 g. USDA FoodData Central also
// knows dishes and brands with real serving sizes; it needs a free API key
// (https://fdc.nal.usda.gov/api-key-signup), so it is off unless the app
// passes one (USDA_API_KEY in local.config.ts).

/// Calories of one serving of a food, from an online source.
class OnlineFood {
  const OnlineFood({
    required this.name,
    required this.source,
    required this.servingLabel,
    required this.servingCalories,
    this.kcalPer100g,
  });

  /// Display name, e.g. "Kiwifruit".
  final String name;

  /// Source name, said to the user, e.g. "Wikipedia".
  final String source;

  /// The serving [servingCalories] is for, e.g. "100 g" or "1 medium croissant (57 g)".
  final String servingLabel;
  final num servingCalories;

  /// For amounts the user gives in grams; null when the source has no weight.
  final num? kcalPer100g;
}

/// A place to look up calories. Add your own (a nutrition API, your own
/// database) and pass it to setFoodCalorieSources in calorie_tools.dart.
abstract class FoodCalorieSource {
  String get name;

  /// null when the source has no match; throws when it can't be reached.
  Future<OnlineFood?> lookup(String food);
}

// Words that say how food was served, not what it was: "a bowl of hummus" is hummus.
final _servingWords =
    'of with and in slice piece bowl cup glass plate can bottle serving portion handful homemade fresh'.split(' ').toSet();

/// True when [candidate] (a page title or food description) is about [food]:
/// every meaningful word of the food starts a word of the candidate
/// ("kiwi" → "Kiwifruit", "chicken pad thai" → "Pad Thai with chicken"),
/// so "croissant" never matches "Croissan'wich".
bool matchesFood(String food, String candidate) {
  final words = normalizeFoodName(food).split(' ').where((w) => w.isNotEmpty && !_servingWords.contains(w)).toList();
  final candidateWords = normalizeFoodName(candidate).split(' ');
  return words.isNotEmpty && words.every((word) => candidateWords.any((c) => c.startsWith(word)));
}

String _cleanWikitext(String text) => text
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll(RegExp(r"'''?"), '')
    .replaceAllMapped(RegExp(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]'), (m) => m[1]!)
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The {{Infobox nutritional value}} of a page: energy (given in kJ, or kcal)
/// per 100 g unless the box names another serving size.
({String name, double kcal, String? servingSize})? parseNutritionInfobox(String wikitext) {
  final start = wikitext.indexOf(RegExp(r'\{\{\s*(?:infobox[ _])?nutritional[ _]?value', caseSensitive: false));
  if (start < 0) return null;
  final box = wikitext.substring(start, (start + 4000).clamp(0, wikitext.length));
  String param(String key) =>
      RegExp('\\|\\s*$key\\s*=\\s*([^\\n|}]*)', caseSensitive: false).firstMatch(box)?.group(1)?.trim() ?? '';
  final kj = double.tryParse(param('kJ').replaceAll(',', ''));
  final kcal = kj != null ? kj / 4.184 : double.tryParse(param('kcal').replaceAll(',', ''));
  if (kcal == null || kcal <= 0) return null;
  final servingSize = _cleanWikitext(param('serving_size'));
  return (name: _cleanWikitext(param('name')), kcal: kcal, servingSize: servingSize.isEmpty ? null : servingSize);
}

({String title, ({String name, double kcal, String? servingSize})? box}) _wikipediaPage(dynamic page) {
  final title = '${page['title'] ?? ''}'
      .replaceFirst(RegExp(r'\s*\([^)]*\)$'), '')
      .replaceFirst(RegExp(r' as food$', caseSensitive: false), '');
  final revisions = page['revisions'] as List?;
  final content = revisions == null || revisions.isEmpty ? '' : '${revisions.first['slots']?['main']?['content'] ?? ''}';
  return (title: title, box: parseNutritionInfobox(content));
}

/// Wikipedia's nutrition infoboxes: plain foods (fruit, vegetables, grains,
/// some dishes such as hummus), per 100 g. Searches only pages that have one.
class WikipediaFoodSource implements FoodCalorieSource {
  WikipediaFoodSource({JsonFetcher? fetchJson}) : _fetchJson = fetchJson ?? httpJsonFetcher;

  final JsonFetcher _fetchJson;

  @override
  String get name => 'Wikipedia';

  @override
  Future<OnlineFood?> lookup(String food) async {
    final data = await _fetchJson(Uri.https('en.wikipedia.org', '/w/api.php', {
      'format': 'json',
      'formatversion': '2',
      'action': 'query',
      'generator': 'search',
      'gsrlimit': '3',
      'gsrsearch': '$food hastemplate:"Infobox nutritional value"',
      'prop': 'revisions',
      'rvprop': 'content',
      'rvslots': 'main',
    }));
    final query = data is Map ? data['query'] : null;
    final pages = [...((query is Map ? query['pages'] : null) as List? ?? const [])]
      ..sort((a, b) => ((a['index'] ?? 0) as num).compareTo((b['index'] ?? 0) as num));
    final matches = [
      for (final page in pages)
        if (_wikipediaPage(page) case (title: final title, box: final box?) when matchesFood(food, '$title ${box.name}'))
          (title: title, box: box),
    ];
    // A page named after the food beats one that only mentions it in its
    // infobox: "kiwi" → Kiwifruit, not Actinidia arguta ("hardy kiwi").
    final ranked = [
      ...matches.where((m) => matchesFood(food, m.title)),
      ...matches.where((m) => !matchesFood(food, m.title)),
    ];
    for (final (:title, :box) in ranked) {
      final serving = box.servingSize;
      if (serving == null || RegExp(r'^100\s*g$', caseSensitive: false).hasMatch(serving)) {
        return OnlineFood(name: title, source: name, servingLabel: '100 g', servingCalories: box.kcal, kcalPer100g: box.kcal);
      }
      final grams = double.tryParse(RegExp(r'(\d+(?:\.\d+)?)\s*g\b').firstMatch(serving)?.group(1) ?? '');
      return OnlineFood(
        name: title,
        source: name,
        servingLabel: serving,
        servingCalories: box.kcal,
        kcalPer100g: grams != null && grams > 0 ? box.kcal * 100 / grams : null,
      );
    }
    return null;
  }
}

/// Picks a USDA portion for "one" of a food: a medium or regular one, else
/// USDA's default serving ("Quantity not specified"), else the first.
({String label, int grams})? _pickUsdaPortion(List measures) {
  final usable = [
    for (final m in measures)
      if (m is Map && m['gramWeight'] is num && (m['gramWeight'] as num) > 0 && m['disseminationText'] is String) m,
  ]..sort((a, b) => ((a['rank'] ?? 99) as num).compareTo((b['rank'] ?? 99) as num));
  Map? find(RegExp pattern) {
    for (final m in usable) {
      if (pattern.hasMatch(m['disseminationText'] as String)) return m;
    }
    return null;
  }

  final notSpecified = RegExp('quantity not specified', caseSensitive: false);
  final pick = find(RegExp(r'^1 (medium|regular)\b', caseSensitive: false)) ??
      find(notSpecified) ??
      (usable.isEmpty ? null : usable.first);
  if (pick == null) return null;
  final grams = (pick['gramWeight'] as num).round();
  final text = pick['disseminationText'] as String;
  return (label: notSpecified.hasMatch(text) ? '$grams g' : '$text ($grams g)', grams: grams);
}

/// USDA FoodData Central (FNDDS, the foods people actually report eating:
/// dishes, fast food, drinks) with serving sizes. Needs a free API key.
class UsdaFoodSource implements FoodCalorieSource {
  UsdaFoodSource(this.apiKey, {JsonFetcher? fetchJson}) : _fetchJson = fetchJson ?? httpJsonFetcher;

  final String apiKey;
  final JsonFetcher _fetchJson;

  @override
  String get name => 'USDA';

  @override
  Future<OnlineFood?> lookup(String food) async {
    final data = await _fetchJson(Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
      'api_key': apiKey,
      'dataType': 'Survey (FNDDS)',
      'pageSize': '3',
      'query': food,
    }));
    for (final item in (data is Map ? data['foods'] : null) as List? ?? const []) {
      if (item is! Map) continue;
      final description = '${item['description'] ?? ''}';
      num? kcalPer100g;
      for (final n in item['foodNutrients'] as List? ?? const []) {
        if (n is Map && n['unitName'] == 'KCAL' && '${n['nutrientName']}'.toLowerCase().contains('energy') && n['value'] is num) {
          kcalPer100g = n['value'] as num;
          break;
        }
      }
      if (description.isEmpty || kcalPer100g == null || kcalPer100g <= 0 || !matchesFood(food, description)) continue;
      final name = description.replaceFirst(RegExp(r',\s*(NFS|raw)$', caseSensitive: false), '');
      final portion = _pickUsdaPortion(item['foodMeasures'] as List? ?? const []);
      return portion == null
          ? OnlineFood(name: name, source: this.name, servingLabel: '100 g', servingCalories: kcalPer100g, kcalPer100g: kcalPer100g)
          : OnlineFood(
              name: name,
              source: this.name,
              servingLabel: portion.label,
              servingCalories: kcalPer100g * portion.grams / 100,
              kcalPer100g: kcalPer100g,
            );
    }
    return null;
  }
}

// Said while a food is looked up online, so the wait isn't silent. Several
// phrasings, never the same one twice in a row.
const _foodLookupFillers = [
  'I need to check online for the calories in {food}.',
  "{Food} isn't on my list, so let me look it up online.",
  'Let me look up the calories for {food} online.',
  "One moment, I'm checking online how many calories {food} has.",
  'Give me a second to find {food} online.',
  'Let me search online for the calories in {food}.',
];
String _lastFoodLookupFiller = '';

String pickFoodLookupFiller(String food, [Random? random]) {
  final choices = _foodLookupFillers.where((f) => f != _lastFoodLookupFiller).toList();
  _lastFoodLookupFiller = choices[(random ?? Random()).nextInt(choices.length)];
  var name = food.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
  if (name.isEmpty || name.length > 40) name = 'this food';
  return _lastFoodLookupFiller
      .replaceFirst('{Food}', name[0].toUpperCase() + name.substring(1))
      .replaceFirst('{food}', name);
}
