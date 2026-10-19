// Typical calories per common serving, so the app — not the model — does the
// math: a 1.5B model extracts "2 × egg" reliably but guesses calories poorly.
// Values are rough averages for a demo, not nutrition advice. Generated from
// the RN example's src/calories/foods.ts; keep the two in sync.
const _foodCalories = <String, int>{
  'egg': 78,
  'boiled egg': 78,
  'omelette': 190,
  'banana': 105,
  'apple': 95,
  'orange': 62,
  'pear': 100,
  'peach': 60,
  'mango': 200,
  'cup of grapes': 100,
  'grapes': 100,
  'strawberries': 50,
  'blueberries': 85,
  'carrot': 25,
  'avocado': 240,
  'slice of pizza': 285,
  'pizza': 285,
  'can of coke': 140,
  'coke': 140,
  'coca cola': 140,
  'soda': 140,
  'diet coke': 1,
  'coffee': 2,
  'espresso': 3,
  'latte': 190,
  'cappuccino': 120,
  'tea': 2,
  'water': 0,
  'glass of milk': 120,
  'milk': 120,
  'orange juice': 110,
  'juice': 110,
  'smoothie': 200,
  'protein shake': 160,
  'beer': 150,
  'glass of wine': 125,
  'wine': 125,
  'slice of bread': 80,
  'bread': 80,
  'toast': 80,
  'bagel': 250,
  'croissant': 230,
  'pita': 165,
  'pancake': 90,
  'waffle': 220,
  'donut': 250,
  'muffin': 400,
  'cookie': 50,
  'chocolate bar': 230,
  'chocolate': 230,
  'granola bar': 120,
  'protein bar': 200,
  'yogurt': 150,
  'bowl of oatmeal': 160,
  'oatmeal': 160,
  'cereal': 200,
  'cup of rice': 205,
  'rice': 205,
  'pasta': 220,
  'chicken breast': 165,
  'chicken': 165,
  'steak': 500,
  'salmon': 360,
  'tuna': 130,
  'salad': 150,
  'sandwich': 350,
  'burger': 500,
  'hamburger': 500,
  'cheeseburger': 550,
  'fries': 365,
  'hot dog': 290,
  'burrito': 450,
  'taco': 170,
  'sushi roll': 300,
  'sushi': 300,
  'soup': 150,
  'potato': 160,
  'sweet potato': 110,
  'hummus': 70,
  'falafel': 57,
  'shawarma': 550,
  'slice of cheese': 110,
  'cheese': 110,
  'almonds': 160,
  'nuts': 170,
  'peanut butter': 95,
  'ice cream': 140,
};

String _singular(String word) {
  if (word.endsWith('ies') && word.length > 4) return '${word.substring(0, word.length - 3)}y';
  if (RegExp(r'(ches|shes|oes)$').hasMatch(word)) return word.substring(0, word.length - 2);
  if (word.endsWith('s') && !word.endsWith('ss') && word.length > 3) return word.substring(0, word.length - 1);
  return word;
}

/// Normalizes "Two slices of Pizza" style names to the table's keys (also used
/// to check online matches, online_foods.dart).
String normalizeFoodName(String food) => food
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z\s]'), ' ')
    .replaceAll(RegExp(r'\b(a|an|some|the|my|of the|small|large|big|medium)\b'), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map(_singular)
    .join(' ');

final _normalized = [
  for (final entry in _foodCalories.entries) (key: normalizeFoodName(entry.key), name: entry.key, calories: entry.value),
];

/// Calories of one serving of [food], or null if it isn't in the table.
/// Prefers an exact name, then the longest table name inside it
/// ("can of coke" → coke, "scrambled eggs" → egg).
({String name, int calories})? lookupFoodCalories(String food) {
  final key = normalizeFoodName(food);
  if (key.isEmpty) return null;
  for (final f in _normalized) {
    if (f.key == key) return (name: f.name, calories: f.calories);
  }
  final padded = ' $key ';
  final contained = _normalized.where((f) => padded.contains(' ${f.key} ')).toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  if (contained.isEmpty) return null;
  return (name: contained.first.name, calories: contained.first.calories);
}
