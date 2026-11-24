// Basic language support for the car agent (2026-11-21; port of the RN example's src/car/basicLanguage.ts). The on-device model and
// the agent core's word lists are tuned for English and Brazilian Portuguese only. In every other language ("Basic") the agent never
// acts on its own reading of the request: each car action is first ASKED in the user's language ("Soll ich das Fahrerfenster öffnen?")
// and runs only after a plain yes. Read-only lookups (fuel, ETA, places) answer directly. The sentences come from
// assets/car/basic_languages.json (the same file as the RN example).
//
// How the yes reaches the action: the car tool refuses with an "offer" (the call itself); the agent core runs an offered call when the
// next request is a plain yes. The core's yes / no words are English + Portuguese, so the app turns a plain "ja" / "sí" / "oui" ... into
// "yes" / "no" before the request goes to the agent (normalizeYesNo). The offered call then reaches the tool again and runs.
import 'dart:convert';


Map<String, Map<String, Object?>> _langs = {};

/// Loads assets/car/basic_languages.json (loadCarToolDefinitions does it).
void loadBasicLanguages(String json) {
  final data = jsonDecode(json) as Map<String, Object?>;
  _langs = {
    for (final e in (data['languages'] as Map).entries) e.key as String: Map<String, Object?>.from(e.value as Map),
  };
}

/// The languages the model and the agent core were tuned for: they act directly.
const tunedLanguages = {'en', 'pt-BR'};
bool isBasicLanguage(String? language) => !tunedLanguages.contains(language ?? 'en');

Map<String, Object?> _entry(String language) => _langs[language] ?? _langs['en'] ?? const {};
Map<String, String> _table(Map<String, Object?> e, String key) =>
    e[key] is Map ? (e[key] as Map).map((k, v) => MapEntry('$k', '$v')) : const {};

/// The app's own sentence in a Basic language (whichSeat, didNotCatch, notInDemo, noRemote, lowClarify, lowDecline, lowNoRemote).
String? basicMessage(String language, String key) =>
    isBasicLanguage(language) ? _table(_langs[language] ?? const {}, 'messages')[key] : null;

/// The agent pack's spoken prompts in a Basic language (see agent_pack.dart).
Map<String, Object?>? basicPackTexts(String language) {
  if (!isBasicLanguage(language)) return null;
  final p = _langs[language]?['pack'];
  return p is Map ? Map<String, Object?>.from(p) : null;
}

String _fill(String tpl, Map<String, String> vars) =>
    tpl.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => vars[m[1]] ?? m[0]!);
String _capFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String _num(Object? n, String language) {
  final v = n is num ? n : num.tryParse('$n');
  if (v == null) return '$n';
  final r = (v * 10).round() / 10;
  final s = r == r.roundToDouble() ? '${r.round()}' : '$r';
  return language == 'en' ? s : s.replaceAll('.', ',');
}

String _deg(Object? t, Object? unit, String language) => '${_num(t, language)} °${unit == 'fahrenheit' ? 'F' : 'C'}';

/// The action a call stands for, as a short phrase ("das Fahrerfenster öffnen"). Unknown calls get the generic phrase.
String describeCall(String name, Map<String, Object?> args, String language) {
  final e = _entry(language);
  final t = _table(e, 't');
  String T(String key, [Map<String, String> vars = const {}]) => _fill(t[key] ?? t['generic'] ?? '', vars);
  String pick(String table, Object? key, String fallback) {
    final m = _table(e, table);
    return m['$key'] ?? m[fallback] ?? (key == null ? '' : '$key');
  }

  final a = args;
  switch (name) {
    case 'set_window':
      final pos = const ['open', 'close', 'half', 'crack'].contains(a['position']) ? a['position'] : 'open';
      return T('window.$pos', {'window': pick('window', a['window'] ?? 'all', 'all')});
    case 'open_door':
      return T('door.open', {'door': pick('door', a['door'] ?? 'all', 'all')});
    case 'close_doors':
      return T('door.close', {'door': pick('door', a['door'] ?? 'all', 'all')});
    case 'lock_car':
    case 'unlock_car':
      final door = a['door'] != null && a['door'] != 'all' ? pick('door', a['door'], 'car') : _table(e, 'door')['car'] ?? '';
      return T(name == 'lock_car' ? 'lock' : 'unlock', {'door': door});
    case 'set_sunroof':
      return T('sunroof.${const ['open', 'tilt', 'close'].contains(a['action']) ? a['action'] : 'open'}');
    case 'set_trunk':
      return T('${a['which'] == 'frunk' ? 'frunk' : 'trunk'}.${a['action'] == 'close' ? 'close' : 'open'}');
    case 'set_temperature':
      if (a['temperature'] != null) {
        final temp = _deg(a['temperature'], a['unit'], language);
        return a['zone'] != null && a['zone'] != 'all'
            ? T('temp.setZone', {'t': temp, 'zone': pick('zone', a['zone'], 'all')})
            : T('temp.set', {'t': temp});
      }
      final c = num.tryParse('${a['change'] ?? 1}') ?? 1;
      return T(c >= 0 ? 'temp.up' : 'temp.down', {'n': _num(c.abs() == 0 ? 1 : c.abs(), language)});
    case 'set_dual_zone_temperature':
      return T('dual', {'d': _deg(a['driver'], a['unit'], language), 'p': _deg(a['passenger'], a['unit'], language)});
    case 'comfort_feeling':
      return T(a['feeling'] == 'hot' ? 'feel.hot' : 'feel.cold');
    case 'set_fan_speed':
      if (a['level'] != null) return T('fan.set', {'n': _num(a['level'], language)});
      return T((num.tryParse('${a['change'] ?? 1}') ?? 1) >= 0 ? 'fan.up' : 'fan.down');
    case 'set_airflow':
      return T('air', {'mode': pick('air', a['mode'], 'face')});
    case 'set_defrost':
      return T('defrost.${a['target'] == 'rear' ? 'rear' : 'windshield'}.${a['on'] == false ? 'off' : 'on'}');
    case 'set_seat_climate':
      final vars = {'feature': pick('feature', a['feature'] ?? 'heater', 'heater'), 'seat': pick('seat', a['seat'] ?? 'driver', 'driver')};
      return a['level'] == 'off' ? T('seat.off', vars) : T('seat.set', {...vars, 'level': pick('level', a['level'] ?? 'medium', 'medium')});
    case 'set_steering_wheel_heater':
      return T(a['on'] == false ? 'wheel.off' : 'wheel.on');
    case 'play_media':
      return T('media', {'q': '${a['query'] ?? ''}'});
    case 'tune_radio':
      return T('radio', {'band': '${a['band'] ?? 'fm'}'.toUpperCase(), 'f': _num(a['frequency'], language)});
    case 'set_audio_source':
      return T('source', {'source': pick('source', a['source'], 'radio')});
    case 'set_volume':
      final act = '${a['action'] ?? ((num.tryParse('${a['change'] ?? 0}') ?? 0) < 0 ? 'down' : 'up')}';
      if (act == 'set') return T('vol.set', {'n': _num(a['level'], language)});
      return T('vol.${const ['up', 'down', 'mute', 'unmute'].contains(act) ? act : 'up'}');
    case 'navigate_to':
      final dest = '${a['destination'] ?? ''}'.trim();
      if (dest.toLowerCase() == 'home') return T('nav.home');
      if (dest.toLowerCase() == 'work') return T('nav.work');
      return T('nav', {'dest': dest});
    case 'set_route_avoid':
      return T('avoid', {'avoid': pick('avoid', a['avoid'], 'traffic')});
    default:
      return T('generic');
  }
}

/// One question for one or more calls: "Soll ich das Fahrerfenster öffnen und das Gebläse auf Stufe 3 stellen?"
String confirmQuestion(List<Map<String, Object?>> calls, String language) {
  final e = _entry(language);
  final parts = [
    for (final c in calls) describeCall('${c['name']}', Map<String, Object?>.from((c['arguments'] as Map?) ?? const {}), language),
  ];
  final and = '${e['and'] ?? 'and'}';
  final body = parts.isEmpty
      ? _table(e, 't')['generic'] ?? ''
      : parts.length == 1
          ? parts.first
          : '${parts.sublist(0, parts.length - 1).join(', ')} $and ${parts.last}';
  return _fill('${e['q'] ?? '{a}?'}', {'a': e['capitalize'] == true ? _capFirst(body) : body});
}

String basicDone(String language) => '${_entry(language)['done'] ?? ''}';
String basicCannot(String language) => '${_entry(language)['cannot'] ?? ''}';
String basicDriving(String language) => '${_entry(language)['driving'] ?? ''}';

/// A read-only lookup answered in the Basic language, or null (then the tool's own sentence is used).
String? basicAnswer(String name, Map<String, Object?> args, String language, {String? destination, required int fuelPercent}) {
  final e = _entry(language);
  final ans = _table(e, 'answer');
  String? A(String key, [Map<String, String> vars = const {}]) => ans[key] == null ? null : _fill(ans[key]!, vars);
  switch (name) {
    case 'get_trip_eta':
      return destination != null ? A('eta', {'min': '24'}) : A('eta.none');
    case 'find_along_route':
      return A('find', {'place': _table(e, 'place')['${args['place_type']}'] ?? '${args['place_type'] ?? ''}'});
    case 'get_vehicle_status':
      final item = '${args['item'] ?? ''}';
      return A('status.$item', {
        'km': item == 'fuel' ? '${(fuelPercent * 5).round()}' : '312',
        'pct': item == 'fuel' ? '$fuelPercent' : '76',
        'v': _num(12.4, language),
      });
  }
  return null;
}

// ---- what waits for a yes ----------------------------------------------------------------------------------------------------------

String _stable(Object? v) {
  if (v is List) return '[${v.map(_stable).join(',')}]';
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${_stable(v[k])}').join(',')}}';
  }
  return jsonEncode(v);
}

String _keyOf(String name, Map<String, Object?> args) => '$name|${_stable(args)}';

int _turn = 0;
final List<({String key, Map<String, Object?> call, int turn})> _pending = [];

/// Call before each request (after normalizeYesNo). Calls asked in the previous request stay confirmable for this one only.
void beginBasicTurn() {
  _turn += 1;
  _pending.removeWhere((p) => p.turn < _turn - 1);
}

/// True (and consumed) when this call was asked in the previous request: the user's yes ran it.
bool takeConfirmed(String name, Map<String, Object?> args) {
  final k = _keyOf(name, args);
  final i = _pending.indexWhere((p) => p.key == k && p.turn == _turn - 1);
  if (i < 0) return false;
  _pending.removeAt(i);
  return true;
}

/// Remembers calls to ask about; returns every call asked in this request (the core keeps one offer per request).
List<Map<String, Object?>> addPending(List<Map<String, Object?>> calls) {
  for (final call in calls) {
    final k = _keyOf('${call['name']}', Map<String, Object?>.from((call['arguments'] as Map?) ?? const {}));
    if (!_pending.any((p) => p.key == k && p.turn == _turn)) _pending.add((key: k, call: call, turn: _turn));
  }
  return [for (final p in _pending) if (p.turn == _turn) p.call];
}

void clearBasicPending() => _pending.clear();

/// Lower case, no accents, letters and digits only (as the RN example's fold).
const _accents = 'àa áa âa ãa äa åa āa ăa ąa çc ćc čc ďd èe ée êe ëe ēe ėe ęe ěe ìi íi îi ïi īi įi ñn ńn ňn òo óo ôo õo öo ōo őo '
    'ùu úu ûu üu ūu ůu űu ųu ýy ÿy žz źz żz śs šs şs řr ťt ţt ľl ĺl άα έε ήη ίι ϊι ΐι όο ύυ ϋυ ΰυ ώω';
final Map<String, String> _accentMap = {
  for (final pair in _accents.split(' ')) if (pair.runes.length == 2) String.fromCharCode(pair.runes.first): String.fromCharCode(pair.runes.last),
};
String _fold(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    b.write(_accentMap[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim();
}

final Map<String, RegExp> _phraseRe = {};
bool _onlyPhrases(String text, List<String> phrases, String cacheKey) {
  final re = _phraseRe.putIfAbsent(cacheKey, () {
    final alts = {for (final p in phrases) _fold(p)}.where((p) => p.isNotEmpty).toList()..sort((x, y) => y.length - x.length);
    return RegExp('^((${alts.map(RegExp.escape).join('|')})( |\$))+\$', unicode: true);
  });
  return re.hasMatch(_fold(text));
}

/// A plain yes / no to the agent's question in a Basic language -> "yes" / "no" (what the agent core understands), else null.
String? normalizeYesNo(String text, String language) {
  if (!isBasicLanguage(language) || !_pending.any((p) => p.turn == _turn)) return null;
  final e = _entry(language);
  final yes = ((e['yes'] as List?) ?? const []).map((x) => '$x').toList();
  final no = ((e['no'] as List?) ?? const []).map((x) => '$x').toList();
  if (_onlyPhrases(text, yes, '$language|yes')) return 'yes';
  if (_onlyPhrases(text, no, '$language|no')) return 'no';
  return null;
}

// ---- English hints for the model (as the RN example's withCarHints) -----------------------------------------------------------------

/// A hint pattern for the folded text: words are separated by single spaces, so \w = any non-space and \b = a space or the end.
RegExp _hintRegex(String pattern) {
  final out = StringBuffer();
  for (var i = 0; i < pattern.length; i++) {
    if (pattern[i] == r'\' && i + 1 < pattern.length && pattern[i + 1] == 'b') {
      final next = pattern.substring(i + 2);
      final end = next.isEmpty || next.startsWith('|') || next.startsWith(')') || next.startsWith('(?!') || next.startsWith('(?=');
      out.write(end ? r'(?= |$)' : r'(?:^| )');
      i++;
    } else if (pattern[i] == r'\' && i + 1 < pattern.length && pattern[i + 1] == 'w') {
      out.write('[^ ]');
      i++;
    } else {
      out.write(pattern[i]);
    }
  }
  return RegExp(out.toString(), unicode: true);
}

final Map<String, List<(RegExp, String)>> _hintCache = {};

/// Basic language: the car words the user said, in English, added in brackets for the model ("Mach die Musik leiser" ->
/// "Mach die Musik leiser (volume down, music)"). Tuned languages and sentences without a car word stay as they are.
String withCarHints(String text, String language) {
  if (!isBasicLanguage(language)) return text;
  final rules = _hintCache.putIfAbsent(language, () {
    final raw = _langs[language]?['hints'];
    return [
      if (raw is List)
        for (final r in raw) (_hintRegex('${(r as List)[0]}'), '${r[1]}'),
    ];
  });
  final folded = _fold(text);
  final words = <String>[];
  for (final (re, en) in rules) {
    if (re.hasMatch(folded) && !words.contains(en)) words.add(en);
  }
  return words.isEmpty ? text : '${text.trim()} (${words.join(', ')})';
}

/// Basic language: the model was tuned on Brazilian Portuguese, so its own words sometimes come out in Portuguese ("O que você quer
/// ouvir?" to a Swedish driver). Such a sentence is replaced by "Sorry, could you say it again?" in the user's language; null = keep it.
String? basicReplyFix(String sentence, String language) {
  if (!isBasicLanguage(language) || language.startsWith('pt')) return null;
  final pt = RegExp(r'(?:^|[^\p{L}])(você|voce|não|desculpe|ouvir|isso|quer|obrigad[oa]|disponível)(?=$|[^\p{L}])', unicode: true, caseSensitive: false);
  if (!pt.hasMatch(sentence)) return null;
  return basicMessage(language, 'didNotCatch');
}
