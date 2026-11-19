// What the driver HEARS when one request did several car actions (same as the React Native example_car_agent's src/car/speechComposer.ts):
// the car tools' own sentences of actions that ran in a row become one natural sentence:
//   "I closed all the doors. I locked the car."  ->  "All set. I closed all the doors and locked the car. Everything is secure."
//   "Fechei todas as portas. Tranquei o carro."  ->  "Pronto! Fechei todas as portas e tranquei o carro. Está tudo seguro."
// Accuracy: nothing here decides an action. Only sentences of actions that really ran (recorded by the tool runner in this turn) are
// merged, word for word; anything else (a question, a refusal, an undo, a status answer that is not "I did X") is said as it was. The
// conversation history the model sees keeps the original sentences (the wording it was trained on): only speech and the screen change.

class CarTurnAction {
  const CarTurnAction(this.tool, this.say, this.merge);
  final String tool;
  final String say;

  /// false: refused / failed / an undo: never merged
  final bool merge;
}

final List<CarTurnAction> _turn = [];
int _variant = 0;

/// Call before each request.
void beginCarTurn() => _turn.clear();

/// Called by the car tool runner with the sentence it returns.
void noteCarSay(String tool, String say, bool merge) {
  if (say.trim().isNotEmpty) _turn.add(CarTurnAction(tool, say.trim(), merge));
}

List<CarTurnAction> carTurnActions() => List.unmodifiable(_turn);

/// For tests: start the openers from the first one.
void resetSpeechVariant() => _variant = 0;

const _openers = {
  'en': ['All set.', 'Done.', 'You got it.'],
  'pt': ['Pronto!', 'Feito!', 'Tudo certo!'],
};
const _secure = {'en': 'Everything is secure.', 'pt': 'Está tudo seguro.'};
const _closingTools = {'close_doors', 'set_window', 'set_sunroof', 'set_trunk'};

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

String? _merged(List<CarTurnAction> run, bool pt) {
  final parts = [for (final a in run) _clause(a.say, pt)];
  if (parts.any((p) => p == null)) return null;
  final lang = pt ? 'pt' : 'en';
  final opener = _openers[lang]![_variant++ % _openers[lang]!.length];
  final body = _join(parts.cast<String>(), pt);
  final sentence = pt ? body[0].toUpperCase() + body.substring(1) : 'I $body';
  final secures =
      run.any((a) => a.tool == 'lock_car') &&
      run.any((a) => _closingTools.contains(a.tool));
  return '$opener $sentence.${secures ? ' ${_secure[lang]}' : ''}';
}

/// The reply text as the driver should hear it. [text] = what the agent said (core order); [actions] = this turn's tool sentences in order.
String composeCarSpeech(
  String text,
  List<CarTurnAction> actions,
  String language,
) {
  final pt = language.toLowerCase().startsWith('pt');
  final pending = [...actions];
  final segs = <(String, CarTurnAction?)>[];
  var rest = text.trim();
  while (rest.isNotEmpty) {
    final i = pending.indexWhere((a) => rest.startsWith(a.say));
    if (i >= 0) {
      final a = pending.removeAt(i);
      segs.add((a.say, a));
      rest = rest.substring(a.say.length).trimLeft();
      continue;
    }
    final m = RegExp(r'^.*?[.!?](?:\s+|$)', dotAll: true).firstMatch(rest);
    final piece = m?.group(0) ?? rest;
    segs.add((piece.trim(), null));
    rest = rest.substring(piece.length).trimLeft();
  }
  final out = <String>[];
  for (var i = 0; i < segs.length;) {
    if (segs[i].$2?.merge ?? false) {
      var j = i;
      while (j < segs.length && (segs[j].$2?.merge ?? false)) {
        j++;
      }
      final run = [for (final s in segs.sublist(i, j)) s.$2!];
      final one = run.length >= 2 ? _merged(run, pt) : null;
      out.add(one ?? segs.sublist(i, j).map((s) => s.$1).join(' '));
      i = j;
    } else {
      out.add(segs[i].$1);
      i++;
    }
  }
  return out.join(' ');
}
