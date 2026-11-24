// What the driver HEARS when one request did several car actions (same as the React Native example_car_agent's src/car/speechComposer.ts):
// the car tools' own sentences of actions that ran in a row become one natural sentence:
//   "I closed all the doors. I locked the car."  ->  "All set. I closed all the doors and locked the car. Everything is secure."
//   "Fechei todas as portas. Tranquei o carro."  ->  "Pronto, já fiz isso para você. Fechei todas as portas e tranquei o carro. Agora o carro está todo seguro."
// Accuracy: nothing here decides an action. Only sentences of actions that really ran (recorded by the tool runner in this turn) are
// merged, word for word; anything else (a question, a refusal, an undo, a status answer that is not "I did X") is said as it was. The
// conversation history the model sees keeps the original sentences (the wording it was trained on): only speech and the screen change.
import 'basic_language.dart';

class CarTurnAction {
  const CarTurnAction(this.tool, this.say, this.merge, {this.args = const {}, this.kind, this.offer});
  final String tool;
  final String say;

  /// false: refused / failed / an undo: never merged
  final bool merge;

  /// the call's arguments (picks the friendly closing line)
  final Map<String, Object?> args;

  /// 'did' = changed the car; 'already' = it was already so; 'answer' = a lookup. Only 'did' gets the friendly words.
  final String? kind;

  /// the calls a plain "yes" to this reply runs (the result's offer, handled by the agent core), by name
  final List<String>? offer;

  CarTurnAction withSay(String s) => CarTurnAction(tool, s, merge, args: args, kind: kind, offer: offer);
}

final List<CarTurnAction> _turn = [];
int _variant = 0;

/// Call before each request.
void beginCarTurn() {
  _turn.clear();
  beginBasicTurn();
}

/// Called by the car tool runner with the sentence it returns.
void noteCarSay(String tool, String say, bool merge, {Map<String, Object?> args = const {}, String? kind, List<String>? offer}) {
  if (say.trim().isNotEmpty) _turn.add(CarTurnAction(tool, say.trim(), merge, args: args, kind: kind, offer: offer));
}

List<CarTurnAction> carTurnActions() => List.unmodifiable(_turn);

/// Before beginCarTurn: the calls the previous request's offer runs on a plain "yes" (the agent core keeps it for one request), or null.
List<String>? pendingOfferCalls() {
  for (final a in _turn.reversed) {
    if (a.offer != null && a.offer!.isNotEmpty) return a.offer;
  }
  return null;
}

/// For tests: start the openers from the first one.
void resetSpeechVariant() {
  _variant = 0;
  _ackVariant = 0;
}

const _openers = {
  'en': ['All set.', 'Done.', 'You got it.'],
  'pt': ['Pronto, já fiz isso para você.', 'Certo, já resolvi isso para você.', 'Tudo certo, já cuidei disso para você.'],
};
const _secure = {'en': 'Everything is secure.', 'pt': 'Agora o carro está todo seguro.'};
const _closingTools = {'close_doors', 'set_window', 'set_sunroof', 'set_trunk'};
const _lookupTools = {'get_vehicle_status', 'get_trip_eta', 'find_along_route'};

// ---- a friendlier voice (2026-11-21, user: "more like Otto", VW's assistant; as the RN example): the same facts, word for word, with a
// warm opener and, every other time, a short closing line that fits the action. Only for actions that really ran, tuned languages only.
const _friendlyOpeners = {
  'en': ['Sure, you got it.', 'You got it!', 'Consider it done!', 'Alright, all set!', 'There you go!'],
  'pt': ['Claro, já fiz isso para você.', 'Pronto, já fiz isso para você.', 'Certo, já resolvi isso para você.', 'Tudo certo, já cuidei disso para você.', 'Feito, já está tudo certinho agora.'],
};
// pt-BR wording (2026-11-22, temporary until the pt-BR voice model is fixed; as the RN example): the speech library speaks one sentence
// at a time and the pt-BR model drops or garbles short sentences said alone ("Claro!", "Tranquei o carro."). Every pt sentence here was
// synthesized 5 times with the app's model and voice and understood 5/5 by speech-to-text; keep new ones at about six words and test them.

/// What the car says while a request takes a moment (Otto's "Entendido.").
const _acks = {
  'en': ['Got it.', 'On it.', 'One moment.'],
  'pt': ['Entendido, só um instante, por favor.', 'Só um instante, já vou fazer isso.', 'Pode deixar, só um instante, por favor.'],
};
int _ackVariant = 0;

/// A short acknowledgement for a request that takes a moment, or null (Basic languages keep their own flow).
String? carAck(String language) {
  final lang = language == 'pt-BR' ? 'pt' : language == 'en' ? 'en' : null;
  if (lang == null) return null;
  final list = _acks[lang]!;
  return list[_ackVariant++ % list.length];
}

/// The closing line for an action that ran, or null.
String? _friendlyTail(CarTurnAction a, String lang, [bool driving = false]) {
  final g = a.args;
  String t(String en, String pt) => lang == 'pt' ? pt : en;
  num n(Object? v) => v is num ? v : num.tryParse('${v ?? 0}') ?? 0;
  switch (a.tool) {
    case 'unlock_car':
      return driving ? null : t('Come on in!', 'Pode entrar, o carro já está aberto.');
    case 'lock_car':
      return t("You're good to go.", 'Pode ficar tranquilo, está tudo seguro.');
    case 'set_window':
      return g['position'] == 'close' ? null : t('Enjoy the fresh air.', 'Aproveite o vento fresco da estrada.');
    case 'set_sunroof':
      return g['action'] == 'close' ? null : t('Enjoy the view!', 'Aproveite a vista lá de cima.');
    case 'comfort_feeling':
      return g['feeling'] == 'hot' ? t("It'll cool down in a minute.", 'O carro vai refrescar em um minutinho.') : t("It'll feel cozier in a minute.", 'Já já o carro fica mais quentinho.');
    case 'set_temperature':
      if (g['temperature'] != null) return null;
      final c = n(g['change']);
      return c > 0 ? t("It'll warm up soon.", 'O carro vai esquentar em um minutinho.') : c < 0 ? t("It'll cool down soon.", 'O carro vai refrescar em um minutinho.') : null;
    case 'set_seat_climate':
      if (g['level'] == 'off') return null;
      return g['feature'] == 'ventilation' ? t('That should cool you down.', 'A ventilação do banco vai refrescar você.') : t('Nice and cozy.', 'O assento vai ficar quentinho rapidinho.');
    case 'set_steering_wheel_heater':
      return g['on'] == false ? null : t('Warm hands coming up.', 'O volante vai ficar quentinho rapidinho.');
    case 'navigate_to':
      return t("Let's go!", 'Vamos lá, tenha uma ótima viagem!');
    case 'play_media':
    case 'tune_radio':
      return t('Enjoy the music!', 'Aproveite a música durante a viagem.');
    case 'set_defrost':
      return g['on'] == false ? null : t("You'll see clearly in a moment.", 'O vidro vai desembaçar em um minutinho.');
  }
  return null;
}

bool _did(CarTurnAction a) => (a.kind ?? (_lookupTools.contains(a.tool) ? 'answer' : 'did')) == 'did';

// ---- how a tool sentence is SAID (2026-11-21 reply review, as the RN example's spokenSay): the tools' sentences stay as they are in the
// history (the model was trained with them); only the spoken wording is smoother. Same facts, same numbers; tuned languages.

/// "airport" -> "the airport" (a common noun the model wrote without its article); names, "home" and "my office" stay as they are.
String _enPlace(String d) {
  final p = d.replaceAll('_', ' ').trim();
  return RegExp(r'^[a-z]').hasMatch(p) &&
          !RegExp(r'^(the|a|an|my|your|our|his|her|their|work|downtown)\b').hasMatch(p) &&
          !RegExp(r"'s\b").hasMatch(p)
      ? 'the $p'
      : p;
}

/// "aeroporto" -> (to: "o aeroporto", at: "no aeroporto"); "casa" -> (to: "casa", at: "em casa"); "São Paulo" stays.
({String to, String at}) _ptPlace(String d) {
  final p = d.replaceAll('_', ' ').trim();
  if (RegExp(r'^casa$', caseSensitive: false).hasMatch(p)) return (to: 'casa', at: 'em casa');
  final art = RegExp(r'^(o|a|os|as) (.+)$', caseSensitive: false).firstMatch(p);
  if (art != null) {
    const into = {'o': 'no', 'a': 'na', 'os': 'nos', 'as': 'nas'};
    return (to: p, at: '${into[art.group(1)!.toLowerCase()]} ${art.group(2)}');
  }
  if (RegExp(r'^[a-zà-ü]').hasMatch(p) &&
      !RegExp(r'^(um|uma|meu|minha|meus|minhas|seu|sua|nosso|nossa)\b', caseSensitive: false).hasMatch(p)) {
    final fem = RegExp(r'(a|ção|dade|gem)$', caseSensitive: false).hasMatch(p.split(' ').first);
    return (to: '${fem ? 'a' : 'o'} $p', at: '${fem ? 'na' : 'no'} $p');
  }
  return (to: p, at: 'em $p');
}

/// The sentence as the driver hears it (or the tool's own sentence when nothing reads better).
String spokenSay(CarTurnAction a, String language) {
  final s = a.say;
  // an undo (car_tools.dart "Undone. <the tool's sentence>"): said as putting it back, the sentence said like any other
  final undo = RegExp(r'^(Undone|Desfeito)\. (.+)$', dotAll: true).firstMatch(s);
  if (undo != null && (language == 'en' || language == 'pt-BR')) {
    return '${language == 'en' ? 'Okay, I put it back.' : 'Pronto, voltei tudo como estava antes.'} ${spokenSay(a.withSay(undo[2]!), language)}';
  }
  final change = num.tryParse('${a.args['change'] ?? 0}') ?? 0;
  if (a.tool == 'find_along_route' && (a.offer?.contains('navigate_to') ?? false) && (language == 'en' || language == 'pt-BR')) {
    return '$s ${language == 'en' ? 'Want me to take you there?' : 'Quer que eu te leve até lá?'}';
  }
  final List<(RegExp, String Function(Match))> sub;
  if (language == 'en') {
    sub = [
      (RegExp(r'^I set the whole cabin to (.+)$'), (m) => 'I set the temperature to ${m[1]}'),
      (RegExp(r'^I raised the whole cabin to (.+)$'), (m) => 'I turned the temperature up to ${m[1]}'),
      (RegExp(r'^I lowered the whole cabin to (.+)$'), (m) => 'I turned the temperature down to ${m[1]}'),
      (RegExp(r'^The whole cabin is already at (.+)$'), (m) => 'The temperature is already at ${m[1]}'),
      (RegExp(r'^I set the fan to level (\d+)\.$'),
          (m) => change > 0 ? 'I turned the fan up to level ${m[1]}.' : change < 0 ? 'I turned the fan down to level ${m[1]}.' : 'I set the fan to level ${m[1]}.'),
      (RegExp(r'^I set the (heater|ventilation) in (the .+? seat) to (\w+)\.$'), (m) => 'I set ${m[2]} ${m[1]} to ${m[3]}.'),
      (RegExp(r'^I turned off the (heater|ventilation) in (the .+? seat)\.$'), (m) => 'I turned off ${m[2]} ${m[1]}.'),
      (RegExp(r'^The (heater|ventilation) in (the .+? seat) is already (.+)$'),
          (m) => '${m[2]![0].toUpperCase()}${m[2]!.substring(1)} ${m[1]} is already ${m[3]}'),
      (RegExp(r'^I turned the (rear defogger|windshield defrost) (on|off)\.$'), (m) => 'I turned ${m[2]} the ${m[1]}.'),
      (RegExp(r'^Navigating to (.+?): (.*)$'),
          (m) => m[1] == 'home' ? 'Navigating home: ${m[2]}' : 'Navigating to ${_enPlace(m[1]!)}: ${m[2]}'),
      (RegExp(r"^You'll get to (.+?) in about (.*)$"),
          (m) => m[1] == 'home' ? "You'll get home in about ${m[2]}" : "You'll get to ${_enPlace(m[1]!)} in about ${m[2]}"),
      (RegExp(r'^(.*) Close them first\?$'), (m) => '${m[1]} Want me to close them first?'),
      (RegExp(r'^(.*) Close it first\?$'), (m) => '${m[1]} Want me to close it first?'),
      (RegExp(r"^I didn't change it: (.+) must be between (\S+) and (\S+)\.$"), (m) {
        final w = m[1]!;
        return "Sorry, ${RegExp(r'^(am|fm)$').hasMatch(w) ? w.toUpperCase() : w == 'volume' ? 'the volume' : w} only goes from ${m[2]} to ${m[3]}.";
      }),
      (RegExp(r"^I didn't change the temperature: both values must be between (\S+) and (\S+)\.$"),
          (m) => 'Sorry, the temperature only goes from ${m[1]} to ${m[2]}.'),
      (RegExp(r"^I can't do that while the car is moving\.$"), (m) => "Sorry, I can't do that while we're moving."),
    ];
  } else if (language == 'pt-BR') {
    sub = [
      (RegExp(r'^Coloquei a cabine toda em (.+)$'), (m) => 'Coloquei a temperatura em ${m[1]}'),
      (RegExp(r'^Subi a cabine toda para (.+)$'), (m) => 'Subi a temperatura para ${m[1]}'),
      (RegExp(r'^Baixei a cabine toda para (.+)$'), (m) => 'Baixei a temperatura para ${m[1]}'),
      (RegExp(r'^A cabine toda já está em (.+)$'), (m) => 'A temperatura já está em ${m[1]}'),
      (RegExp(r'^Coloquei a ventilação no nível (\d+)\.$'), (m) => change > 0
          ? 'Aumentei a ventilação para o nível ${m[1]}.'
          : change < 0 ? 'Baixei a ventilação para o nível ${m[1]}.' : 'Coloquei a ventilação no nível ${m[1]}.'),
      (RegExp(r'^Coloquei (o aquecimento|a ventilação) do banco (.+)$'), (m) => 'Liguei ${m[1]} do banco ${m[2]}'),
      (RegExp(r'^Indo para (.+?): (.*)$'), (m) => 'Indo para ${_ptPlace(m[1]!).to}: ${m[2]}'),
      (RegExp(r'^Você chega em (.+?) em cerca de (.*)$'), (m) => 'Você chega ${_ptPlace(m[1]!).at} em cerca de ${m[2]}'),
      (RegExp(r'^Não mudei: (.+) precisa ficar entre (\S+) e (\S+)\.$'), (m) {
        final w = m[1]!;
        return 'Desculpe, ${RegExp(r'^(am|fm)$').hasMatch(w) ? w.toUpperCase() : w} só vai de ${m[2]} a ${m[3]}.';
      }),
      (RegExp(r'^Não mudei a temperatura: os dois valores precisam ficar entre (\S+) e (\S+)\.$'),
          (m) => 'Desculpe, a temperatura só vai de ${m[1]} a ${m[2]}.'),
      (RegExp(r'^Não posso fazer isso com o carro em movimento\.$'), (m) => 'Desculpe, não dá pra fazer isso com o carro em movimento.'),
    ];
  } else {
    return s;
  }
  for (final (re, to) in sub) {
    final m = re.firstMatch(s);
    if (m != null) return to(m);
  }
  return s;
}

/// pt-BR: a short tool sentence said ON ITS OWN is said longer (tested wording, see _friendlyOpeners); a merged sentence stays as it is.
/// "vidros" is said as "janelas" here (the pt-BR model's "vidros" is heard as "vídeos"). Same list as the RN example's PT_LONGER.
final List<(RegExp, String Function(Match))> _ptLonger = [
  (RegExp(r'^Tranquei o carro\.$'), (m) => 'Tranquei todas as portas do carro.'),
  (RegExp(r'^Destranquei o carro\.$'), (m) => 'Destranquei todas as portas do carro.'),
  (RegExp(r'^Abri todas as portas\.$'), (m) => 'Abri todas as portas do carro.'),
  (RegExp(r'^Fechei todas as portas\.$'), (m) => 'Fechei todas as portas para você.'),
  (RegExp(r'^Abri todos os vidros\.$'), (m) => 'Abri todas as janelas do carro para você.'),
  (RegExp(r'^Fechei todos os vidros\.$'), (m) => 'Fechei todas as janelas do carro.'),
  (RegExp(r'^Abri o teto solar\.$'), (m) => 'Deixei o teto solar aberto para você.'),
  (RegExp(r'^Fechei o teto solar\.$'), (m) => 'Fechei o teto solar para você.'),
  (RegExp(r'^Inclinei o teto solar\.$'), (m) => 'Deixei o teto solar inclinado, como você pediu.'),
  (RegExp(r'^Tocando (.+)\.$'), (m) => 'Agora tocando ${m[1]} para você.'),
  (RegExp(r'^Sintonizei a rádio (\S+)\.$'), (m) => 'Sintonizei a rádio ${m[1]} para você.'),
  (RegExp(r'^(Liguei|Desliguei) o desembaçador traseiro\.$'), (m) => '${m[1]} o desembaçador traseiro para você.'),
];

String _ptLongerSentence(String sentence) {
  for (final (re, to) in _ptLonger) {
    final m = re.firstMatch(sentence);
    if (m != null) return to(m);
  }
  return sentence;
}

/// "A. B! C" -> ["A.", "B!", "C"]: a sentence ends at a word ending in . ! or ? ("2,1 km." and "87.5" stay whole).
List<String> _sentencesOf(String text) {
  final out = <String>[];
  var cur = <String>[];
  for (final w in text.split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    cur.add(w);
    if (RegExp(r'[.!?]$').hasMatch(w)) {
      out.add(cur.join(' '));
      cur = [];
    }
  }
  if (cur.isNotEmpty) out.add(cur.join(' '));
  return out;
}

/// One action that ran, said with a warm opener (none when the car already said "Got it.") and, every other time, its closing line.
String _friendlyOne(CarTurnAction a, String lang, bool acked, [bool driving = false]) {
  final v = _variant++;
  final openers = _friendlyOpeners[lang]!;
  final opener = acked ? '' : '${openers[v % openers.length]} ';
  final tail = v % 2 == 0 ? _friendlyTail(a, lang, driving) : null;
  return '$opener${a.say}${tail != null ? ' $tail' : ''}';
}

/// "I closed all the doors." -> "closed all the doors" (en); "Fechei todas as portas." -> "fechei todas as portas" (pt); else null.
String? _clause(String say, bool pt) {
  final s = say.trim();
  if (!RegExp(r'[.!]$').hasMatch(s) ||
      RegExp(r'[.!?]\s').hasMatch(s.substring(0, s.length - 1))) {
    return null;
  }
  final body = s.substring(0, s.length - 1);
  if (!pt) {
    return RegExp(r"^I (?:'ve |have )?([a-z].*)$").firstMatch(body)?.group(1);
  }
  final first = body.split(' ').first;
  if (!RegExp(r'^[A-ZÁÉÍÓÚÂÊÔÃÕ][a-záéíóúâêôãõç]*i$').hasMatch(first)) {
    return null;
  }
  return body[0].toLowerCase() + body.substring(1);
}

String _join(List<String> parts, bool pt) => parts.length == 1
    ? parts.first
    : '${parts.sublist(0, parts.length - 1).join(', ')} ${pt ? 'e' : 'and'} ${parts.last}';

String? _merged(List<CarTurnAction> run, bool pt, bool friendly, [bool driving = false]) {
  final parts = [for (final a in run) _clause(a.say, pt)];
  final lang = pt ? 'pt' : 'en';
  final secures =
      run.any((a) => a.tool == 'lock_car') &&
      run.any((a) => _closingTools.contains(a.tool));
  if (parts.any((p) => p == null)) {
    // sentences that don't merge ("All the windows are already closed.", "Navigating to ..."): one after the other after the opener,
    // when at least one action ran and the rest were already so (2026-11-21: "I locked the car. All the windows are already closed.")
    if (!friendly || !run.any(_did) || !run.every((a) => _did(a) || a.kind == 'already')) return null;
    final opener = _openers[lang]![_variant++ % _openers[lang]!.length];
    return '$opener ${run.map((a) => a.say).join(' ')}${secures ? ' ${_secure[lang]}' : ''}';
  }
  final opener = _openers[lang]![_variant++ % _openers[lang]!.length];
  final body = _join(parts.cast<String>(), pt);
  final sentence = pt ? body[0].toUpperCase() + body.substring(1) : 'I $body';
  // the friendly closing line of the last action that has one ("I unlocked the car and opened all the doors. Come on in!")
  String? tail;
  if (!secures && friendly && run.every(_did)) {
    for (final a in run.reversed) {
      tail = _friendlyTail(a, lang, driving);
      if (tail != null) break;
    }
  }
  return '$opener $sentence.${secures ? ' ${_secure[lang]}' : ''}${tail != null ? ' $tail' : ''}';
}

/// The reply text as the driver should hear it. [text] = what the agent said (core order); [actions] = this turn's tool sentences in order.
String composeCarSpeech(
  String text,
  List<CarTurnAction> actions,
  String language, {
  bool acked = false,
  bool driving = false,
}) {
  final pt = language.toLowerCase().startsWith('pt');
  // the friendlier voice: the tuned languages only (a Basic language says its own short "done")
  final friendly = language == 'en' || language == 'pt-BR';
  final pending = [...actions];
  final segs = <(String, CarTurnAction?)>[];
  var rest = text.trim();
  while (rest.isNotEmpty) {
    final i = pending.indexWhere((a) => rest.startsWith(a.say));
    if (i >= 0) {
      final found = pending.removeAt(i);
      rest = rest.substring(found.say.length).trimLeft();
      // the action as it is said (spokenSay): the same facts in smoother words; merging and the friendly words work on it
      final a = found.withSay(spokenSay(found, language));
      segs.add((a.say, a));
      continue;
    }
    final m = RegExp(r'^.*?[.!?](?:\s+|$)', dotAll: true).firstMatch(rest);
    final piece = m?.group(0) ?? rest;
    segs.add((piece.trim(), null));
    rest = rest.substring(piece.length).trimLeft();
  }
  // friendly words only when everything said is the sentences of actions that ran (no refusal, question, undo or model text)
  final warm = friendly && segs.every((g) => g.$2?.merge ?? false);
  final out = <String>[];
  for (var i = 0; i < segs.length;) {
    if (segs[i].$2?.merge ?? false) {
      var j = i;
      while (j < segs.length && (segs[j].$2?.merge ?? false)) {
        j++;
      }
      final run = [for (final s in segs.sublist(i, j)) s.$2!];
      final one = run.length >= 2
          ? _merged(run, pt, warm, driving)
          : warm && run.length == 1 && _did(run.first)
              ? _friendlyOne(run.first, pt ? 'pt' : 'en', acked, driving)
              : null;
      final texts = segs.sublist(i, j).map((s) => s.$1).toList();
      out.add(one ?? [for (var k = 0; k < texts.length; k++) if (k == 0 || texts[k] != texts[k - 1]) texts[k]].join(' '));
      i = j;
    } else {
      out.add(segs[i].$1);
      i++;
    }
  }
  // two confirmed actions in a Basic language both say "Erledigt.": once is enough
  final said = [for (var k = 0; k < out.length; k++) if (k == 0 || out[k] != out[k - 1]) out[k]].join(' ');
  return language == 'pt-BR' ? _sentencesOf(said).map(_ptLongerSentence).join(' ') : said;
}
