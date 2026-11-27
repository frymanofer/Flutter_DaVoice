// What the driver says right after the agent's own question or offer (2026-11-21 reply review; the same rules and lists as the RN
// example's src/car/followUp.ts, tests share test/fixtures/follow_up.json):
//  - an answer to the agent's question goes to the agent WITH the request it answers ("Which window should I open?" -> "The driver's one"
//    = "Open the window, the driver's one"; "Where do you want to go?" -> "The airport" = "Navigate to the airport").
//  - "never mind", "cancel", "stop", "no" with nothing pending: a short "Okay." (with an offer pending they go to the agent core, which
//    declines the offer).
//  - an offer pending: more ways to say yes ("tá bom", "sounds good") reach the core as its plain "yes"; "take me there" / "me leva lá"
//    accepts a navigation offer.
//  - a question about the car ("Is the car locked?", "What's the volume?") is answered from the car (state_answers.dart): the model RAN
//    the action for such questions. A yes to the answer's offer ("Want me to lock it?") sends that request to the agent.
//  - "Say that again" / "What?" / "Repete": the last reply again ("Say that again" re-ran the last action).
//  - requests the model gets wrong every time are said the way it handles them ("Turn on the seat heater" -> "Heat the seat",
//    "Liga o aquecimento do banco" -> "Esquenta o banco", "Max volume" -> "Set the volume to 30"); "Esquenta os bancos" asks which seat.
// Nothing here runs an action. Tuned languages (en, pt-BR) only: the Basic languages have their own yes / no flow.
import 'basic_language.dart';
import 'car_state.dart';
import '../flow/rn_tables.g.dart' show notInDemoTexts;
import 'state_answers.dart';

String? _tuned(String language) => language == 'en' ? 'en' : language == 'pt-BR' ? 'pt' : null;

bool _only(String text, List<String> phrases) {
  final t = foldText(text);
  if (t.isEmpty) return false;
  final alts = [...phrases]..sort((a, b) => b.length - a.length);
  return RegExp('^(?:(?:${alts.join('|')})(?: |\$))+\$', unicode: true).hasMatch(t);
}

bool _containsAny(String text, List<String> phrases) {
  final t = ' ${foldText(text)} ';
  return phrases.any((p) => t.contains(' $p '));
}

const _dismiss = {
  'en': ['never mind', 'nevermind', 'forget it', 'forget about it', 'forget that', 'cancel', 'cancel that', 'cancel it', 'stop', 'stop it',
    'nothing', 'no', 'nope', 'nah', 'no thanks', 'no thank you', 'not now', 'leave it', 'that s all', 'that s it', 'all good', 'i m good',
    'i m fine', 'no worries', 'don t', 'don t bother', 'thanks', 'okay', 'ok', 'oh'],
  'pt': ['deixa pra la', 'deixa para la', 'deixa', 'deixa assim', 'esquece', 'esquece isso', 'cancela', 'cancelar', 'cancela isso', 'para',
    'pare', 'nada', 'nada nao', 'nao', 'nao precisa', 'nao obrigado', 'nao obrigada', 'agora nao', 'melhor nao', 'so isso', 'e so isso',
    'obrigado', 'obrigada', 'valeu', 'ok', 'ta'],
};
const _dismissCore = {
  'en': ['never mind', 'nevermind', 'forget it', 'forget about it', 'forget that', 'cancel', 'cancel that', 'cancel it', 'stop', 'stop it',
    'nothing', 'no', 'nope', 'nah', 'no thanks', 'no thank you', 'not now', 'leave it', 'that s all', 'that s it', 'don t', 'don t bother'],
  'pt': ['deixa pra la', 'deixa para la', 'deixa', 'deixa assim', 'esquece', 'esquece isso', 'cancela', 'cancelar', 'cancela isso', 'para',
    'pare', 'nada', 'nada nao', 'nao', 'nao precisa', 'nao obrigado', 'nao obrigada', 'agora nao', 'melhor nao', 'so isso', 'e so isso'],
};
const _dismissReply = {'en': ['Okay.', 'No problem.'], 'pt': ['Tudo bem, então não vou fazer nada.', 'Sem problema, fica para uma próxima vez.']};
const _yes = {
  'en': ['yes', 'yeah', 'yep', 'yup', 'sure', 'ok', 'okay', 'please', 'go ahead', 'do it', 'sounds good', 'go for it', 'please do',
    'sure thing', 'why not', 'let s do it', 'of course', 'absolutely', 'alright', 'all right', 'perfect', 'great', 'cool',
    'that would be great', 'yes please'],
  'pt': ['sim', 'claro', 'pode', 'isso', 'bora', 'por favor', 'faz isso', 'pode ser', 'com certeza', 'certo', 'quero', 'ta bom', 'ta',
    'beleza', 'fechado', 'manda', 'manda ver', 'vai', 'uhum', 'aham', 'pode sim', 'ok', 'perfeito', 'otimo', 'show', 'demorou',
    'quero sim'],
};
const _goThere = {
  'en': ['take me there', 'go there', 'navigate there', 'let s go there', 'let s go', 'drive there', 'navigate to it', 'take me', 'go',
    'yes take me there', 'sure take me there', 'ok take me there', 'okay take me there', 'yes please take me there'],
  'pt': ['me leva la', 'me leva', 'leva eu la', 'me leve la', 'vamos la', 'vai la', 'navega pra la', 'navega para la', 'bora la', 'quero ir',
    'partiu', 'sim me leva la', 'pode me levar', 'pode me levar la', 'me leva ate la'],
};
final _commandStart = {
  'en': RegExp(r'^(open|close|shut|turn|set|play|lock|unlock|navigate|take|find|raise|lower|increase|decrease|put|make|start|stop|switch|tune|mute|unmute|call|what|how|where|when|who|why|is|are|can|could|do|does|please|i|it|its|undo|cancel|show|tell|give|heat|cool|warm|defrost|avoid|go)( |$)'),
  'pt': RegExp(r'^(abre|abra|abrir|fecha|feche|fechar|liga|ligue|ligar|desliga|desligue|coloca|coloque|poe|bota|toca|toque|tocar|tranca|tranque|destranca|navega|navegue|leva|me|acha|procura|aumenta|abaixa|baixa|diminui|sobe|muda|troca|sintoniza|silencia|o que|como|onde|quando|quem|quanto|quantos|quantas|por que|pode|voce|vc|eu|esta|ta|to|faz|deixa|desfaz|esquenta|esfria|desembaca|evita|vai)( |$)'),
};
const _lowerFirst = {
  'en': {'the', 'a', 'an', 'to', 'my', 'mine', 'both', 'yours', 'your', 'his', 'her', 'our', 'all', 'front', 'rear', 'back', 'left',
    'right', 'passenger', 'driver', 'driver s', 'just', 'only', 'some', 'everyone', 'everybody'},
  'pt': {'o', 'a', 'os', 'as', 'pro', 'pra', 'para', 'pros', 'pras', 'meu', 'minha', 'dois', 'ambos', 'todos', 'todas', 'do', 'da',
    'no', 'na', 'so', 'apenas', 'frente', 'tras', 'esquerdo', 'direito', 'passageiro', 'motorista', 'um', 'uma', 'algum', 'alguma'},
};

/// "Stop" while music plays means the music (en: the model mutes it; pt "Para" alone was "didn't catch that").
const _stopMusic = {
  'en': ['stop', 'stop it', 'pause', 'pause it', 'stop the music', 'pause the music', 'stop music', 'stop playing', 'enough', 'please stop', 'stop please'],
  'pt': ['para', 'pare', 'pausa', 'pausar', 'para a musica', 'para o som', 'pausa a musica', 'para de tocar', 'chega', 'para por favor', 'por favor para'],
};

/// The seat in an answer to "Which seat: yours, the passenger's, or both?" (checked in this order on the folded answer).
final _seatAnswer = {
  'en': [
    (RegExp(r'\b(both|everyone|all|the two|both of us)\b'), 'both'),
    (RegExp(r'\b(passenger|passenger s|his|hers|her|him|the other one|my wife s|my husband s)\b'), 'passenger'),
    (RegExp(r'\b(mine|me|my|myself|driver|driver s|yours)\b'), 'driver'),
  ],
  'pt': [
    (RegExp(r'\b(os dois|ambos|todos|dos dois|nos dois|as duas)\b'), 'both'),
    (RegExp(r'\b(carona|passageiro|dele|dela|o outro)\b'), 'passenger'),
    (RegExp(r'\b(meu|o meu|eu|mim|motorista|o seu)\b'), 'driver'),
  ],
};
const _seatWords = {
  'en': {'driver': "the driver's seat", 'passenger': 'the passenger seat', 'both': 'both front seats'},
  'pt': {'driver': 'o banco do motorista', 'passenger': 'o banco do passageiro', 'both': 'os dois bancos da frente'},
};

/// The request with the seat put in. Turning a seat's heat / cooling ON is said the way the model handles it (measured 2026-11-21:
/// "Heat the driver's seat" runs, "Turn on the driver's seat heater" put the seat in the level; for both seats the verb is said twice).
/// Turning off, or a request with its own level, keeps the driver's words with the seat put in. Null: no seat word to replace.
String? _withSeat(String request, String seat, String lang) {
  final r = request.trim().replaceAll(RegExp(r'[.!?]+$'), '');
  final f = foldText(r);
  final off = lang == 'en'
      ? RegExp(r'\b(off|stop|disable|deactivate)\b').hasMatch(f)
      : RegExp(r'\b(desliga|desligar|desligue|desativa|para)\b').hasMatch(f);
  final level = RegExp(r'\b(low|medium|high|max|maximum|min|minimum|level|baixo|medio|alto|maximo|minimo|nivel|\d+)\b').hasMatch(f);
  final heat = lang == 'en'
      ? RegExp(r'\b(heat|heater|heaters|heated|heating|warm|warmer)\b').hasMatch(f)
      : RegExp(r'\b(esquent\w*|aquec\w*|quent\w*)\b').hasMatch(f);
  final cool = lang == 'en'
      ? RegExp(r'\b(cool|cooler|cooling|vent|ventilate|ventilation|ventilated)\b').hasMatch(f)
      : RegExp(r'\b(ventil\w*|refresc\w*|esfri\w*|fresc\w*)\b').hasMatch(f);
  final words = _seatWords[lang]!;
  if (!off && !level && heat != cool) {
    final verb = lang == 'en' ? (heat ? 'heat' : 'cool') : (heat ? 'esquenta' : 'refresca');
    String one(String k) => '$verb ${words[k]}';
    final said = seat == 'both' ? '${one('driver')} ${lang == 'en' ? 'and' : 'e'} ${one('passenger')}' : one(seat);
    return said[0].toUpperCase() + said.substring(1);
  }
  final w = words[seat]!;
  String? swap(RegExp re, String Function(Match) to) => re.hasMatch(r) ? r.replaceFirstMapped(re, to) : null;
  if (lang == 'en') {
    return swap(RegExp(r'\b(the |my |our )?seats\b', caseSensitive: false), (_) => w) ??
        swap(RegExp(r'\b(the |my )?seat (heaters?|ventilation)\b', caseSensitive: false), (m) {
          final what = m[2]!;
          return seat == 'both'
              ? 'both front seat ${what.startsWith('heater') ? 'heaters' : 'ventilation'}'
              : '$w ${what.replaceAll(RegExp(r's$'), '')}';
        }) ??
        swap(RegExp(r'\b(the |my )?seat\b', caseSensitive: false), (_) => w);
  }
  return swap(RegExp(r'\b(os|o|meus|meu) bancos?\b', caseSensitive: false), (_) => w) ??
      swap(RegExp(r'\bdos? bancos?\b', caseSensitive: false), (_) => seat == 'both' ? 'dos dois bancos da frente' : 'd$w');
}

/// "Say that again": the last reply again.
const _repeat = {
  'en': ['what', 'what did you say', 'what was that', 'say that again', 'say it again', 'repeat', 'repeat that', 'repeat it', 'come again',
    'pardon', 'pardon me', 'sorry what', 'huh', 'i didn t hear you', 'i didn t hear that', 'i didn t catch that', 'can you repeat that',
    'could you repeat that', 'can you say that again', 'could you say that again', 'please repeat', 'one more time', 'what was that again'],
  'pt': ['o que', 'o que voce disse', 'o que vc disse', 'o que foi', 'o que foi que voce disse', 'repete', 'repete ai', 'repete por favor',
    'pode repetir', 'fala de novo', 'fala de novo por favor', 'como', 'como e que e', 'hein', 'nao ouvi', 'nao escutei', 'nao entendi',
    'fala outra vez', 'repete isso'],
};
/// "Next song" while music plays: this demo has no track control (pt "Próxima música" unmuted, "Pula" asked where to go).
const _skip = {
  'en': ['skip', 'skip it', 'skip this', 'skip this song', 'skip the song', 'skip song', 'next', 'next song', 'next track', 'next one',
    'play the next song', 'play the next one', 'previous song', 'previous track', 'go back a song', 'last song'],
  'pt': ['pula', 'pula essa', 'pula essa musica', 'pula a musica', 'proxima', 'proxima musica', 'proxima faixa', 'passa', 'passa essa',
    'passa a musica', 'musica anterior', 'volta a musica', 'toca a proxima'],
};

/// A bare "Turn it off" / "Desliga" with nothing to refer to (pt "Desliga" after a declined request muted the sound).
const _bareOff = {
  'en': ['turn it off', 'turn that off', 'switch it off', 'turn off', 'switch off', 'shut it off', 'off'],
  'pt': ['desliga', 'desliga isso', 'desliga ele', 'desliga ela', 'desligar', 'desliga ai', 'apaga', 'apaga isso'],
};
const _bareOn = {
  'en': ['turn it on', 'turn that on', 'switch it on', 'turn on', 'switch on', 'on'],
  'pt': ['liga', 'liga isso', 'liga ele', 'liga ela', 'ligar', 'liga ai', 'acende', 'acende isso'],
};
const _askWhat = {
  'en': {'off': ('What should I turn off?', 'Turn off'), 'on': ('What should I turn on?', 'Turn on')},
  'pt': {'off': ('O que você quer que eu desligue?', 'Desliga'), 'on': ('O que você quer que eu ligue?', 'Liga')},
};
const _whichSeat = {'en': "Which seat: yours, the passenger's, or both?", 'pt': 'Qual banco: o seu, o do carona ou os dois?'};

/// The driver's words, said the way the model handles them (null: as they are). Measured 2026-11-21 with the app's model.
String? _canonical(String userText, String lang) {
  final f = foldText(userText);
  final t = userText.replaceAll('’', "'");
  if (lang == 'en') {
    if (RegExp(r'^(?:please )?(?:turn |put |set |crank )?(?:the )?(?:volume|music|sound|it) (?:all the way up|(?:up )?to (?:the )?max(?:imum)?|(?:at |on )?max(?:imum)?)(?: please)?$|^(?:please )?max(?:imum)? volume(?: please)?$')
        .hasMatch(f)) {
      return 'Set the volume to 30';
    }
    if (RegExp(r'^(?:please )?turn on (?:the |our )?seat heaters (?:for )?(?:both of us|both|everyone)(?: please)?$').hasMatch(f)) {
      return "Heat the driver's seat and heat the passenger seat";
    }
    // measured 2026-11-21: "Lock up" went remote, "Close everything" / "Turn on the lights" were "didn't catch that", "Warmer" alone
    // invented 18 °C, "Is everything ok with the car?" went remote; the rewritten requests run (lights: "can't control that in this car")
    if (RegExp(r'^(?:please )?lock (?:it )?(?:up|everything)(?: please)?$').hasMatch(f)) return 'Lock the car';
    if (RegExp(r'^(?:please )?close (?:everything|it all|all of it|up everything)(?: please)?$').hasMatch(f)) return 'Close all the windows and the sunroof';
    if (RegExp(r'^(?:please )?turn (?:on|off) the lights(?: please)?$').hasMatch(f)) {
      return f.contains(' off ') ? 'Turn off the cabin lights' : 'Turn on the cabin lights';
    }
    final warm = RegExp(r'^(?:a bit |a little |slightly )?(warmer|hotter|cooler|colder)(?: please)?$').firstMatch(f);
    if (warm != null) return RegExp('warmer|hotter').hasMatch(warm[1]!) ? 'Make it warmer' : 'Make it cooler';
    if (RegExp(r'^(?:is )?(?:everything|all) (?:ok|okay|alright|all right|fine|good) with the car$|^is the car (?:ok|okay|alright|all right|fine)$|^how s the car(?: doing)?$|^car status$')
        .hasMatch(f)) {
      return 'Are there any warning lights?';
    }
    // "No, I said the passenger window" was ignored (no reply at all); "No, the passenger window" runs
    final said = RegExp(r'^(?:no,? |nope,? )?i (?:said|meant|mean)\s+(.+)$', caseSensitive: false).firstMatch(t.trim());
    if (said != null && foldText(said[1]!).split(' ').length <= 8) return 'No, ${said[1]}';
    final seat = RegExp(r"\bturn(ing)? on (the |my |our )?(driver's |drivers |passenger's |passenger )?seat (heater|heating|warmer)(s?)\b", caseSensitive: false);
    if (seat.hasMatch(t) && !RegExp(r'\b(low|medium|high|max|maximum|level|\d+)\b').hasMatch(f)) {
      return t.replaceFirstMapped(seat, (m) {
        final who = m[3];
        final whose = who != null ? (RegExp(r'^driver', caseSensitive: false).hasMatch(who) ? "the driver's " : 'the passenger ') : (m[2] ?? 'the ').toLowerCase();
        return 'heat${m[1] != null ? 'ing' : ''} ${whose}seat${(m[5] ?? '').isNotEmpty && who == null ? 's' : ''}';
      }).replaceFirst(RegExp(r'^heat'), 'Heat');
    }
    return null;
  }
  if (RegExp(r'^(?:coloca |poe |bota |deixa |aumenta )?(?:o )?(?:volume|som)(?: (?:no|ao|ate o|em|pro|para o) (?:maximo|talo)| maximo)(?: por favor)?$|^aumenta (?:o volume |o som |tudo )?(?:no|ao|ate o) (?:maximo|talo)(?: por favor)?$')
      .hasMatch(f)) {
    return 'Coloca o volume em 30';
  }
  // measured 2026-11-21: "Fecha tudo" / "Acende as luzes" were "didn't catch that", "Deixa mais fresco" too (or remote), "Tá tudo
  // certo com o carro?" went remote; the rewritten requests run (lights: "não consigo controlar neste carro")
  if (RegExp(r'^(?:por favor )?fecha tudo(?: por favor)?$').hasMatch(f)) return 'Fecha todos os vidros e o teto solar';
  if (RegExp(r'^(?:por favor )?(?:acende|liga) as luzes(?: por favor)?$').hasMatch(f)) return 'Liga a luz ambiente';
  if (RegExp(r'^(?:da pra |pode |voce pode |vc pode )?deixa(?:r)? (?:o carro |aqui )?(?:um pouco |um pouquinho )?mais fresco(?: por favor)?$').hasMatch(f)) {
    return 'Esfria um pouco';
  }
  if (RegExp(r'^(?:(?:ta|esta) tudo (?:certo|bem|ok|em ordem) com o carro|o carro (?:ta|esta) (?:bem|ok|certo)|como (?:ta|esta) o carro)$').hasMatch(f)) {
    return 'Tem alguma luz de alerta?';
  }
  // the "Você …?" rule runs last, so "Você liga o aquecimento do meu banco?" also loses its question form (as in the RN example)
  final pt = t
      .replaceFirstMapped(RegExp(r'\b(?:liga|ligar|ligue|ativa) o aquecimento do (meu |seu )?banco( do motorista| do passageiro| do carona)?\b', caseSensitive: false),
          (m) => 'esquenta o ${m[1] ?? ''}banco${m[2] != null ? (RegExp('carona', caseSensitive: false).hasMatch(m[2]!) ? ' do passageiro' : m[2]) : ''}')
      .replaceFirst(RegExp(r'\b(?:liga|ligar|ligue) o banco aquecido\b', caseSensitive: false), 'esquenta o banco')
      .replaceFirst(RegExp(r'\b(?:liga|ligar|ligue) o aquecimento dos dois bancos( da frente)?\b|\besquenta os dois bancos( da frente)?\b', caseSensitive: false),
          'esquenta o banco do motorista e esquenta o banco do passageiro')
      .replaceFirstMapped(RegExp(r'^(?:você|voce|vc) (esquenta|refresca)(.*?)\?*$', caseSensitive: false), (m) => '${m[1]}${m[2]}');
  if (pt != t) return pt[0].toUpperCase() + pt.substring(1);
  return null;
}

/// A heat / cool request for "the seats" with no seat said: asked here (pt-BR "Esquenta os bancos" was declined). The request to complete.
String? _pluralSeats(String userText, String lang) {
  if (lang != 'pt') return null;
  final f = foldText(userText).replaceFirst(RegExp(r' por favor$'), '');
  if (RegExp(r'^(?:liga|ligar|ligue|ativa) o aquecimento dos bancos$|^esquenta os bancos$|^(?:liga|ligar) os bancos aquecidos$').hasMatch(f)) {
    return 'Esquenta os bancos';
  }
  if (RegExp(r'^(?:liga|ligar|ligue|ativa) a ventilacao dos bancos$|^refresca os bancos$').hasMatch(f)) return 'Refresca os bancos';
  return null;
}

/// The driver says the offered request short ("Close it", "Lock it", "Turn it on", "Fecha", "Pode trancar"): the offer itself.
final _offerVerbs = {
  'en': [
    (RegExp(r'^close\b', caseSensitive: false), RegExp(r'^(?:close|shut)$')),
    (RegExp(r'^open\b', caseSensitive: false), RegExp(r'^open$')),
    (RegExp(r'^lock\b', caseSensitive: false), RegExp(r'^lock$')),
    (RegExp(r'^(?:heat|cool)\b', caseSensitive: false), RegExp(r'^(?:turn on|switch on|heat|cool|turn on)$')),
  ],
  'pt': [
    (RegExp(r'^fecha\b', caseSensitive: false), RegExp(r'^(?:fecha|fechar|feche|pode fechar)$')),
    (RegExp(r'^abre\b', caseSensitive: false), RegExp(r'^(?:abre|abrir|abra|pode abrir)$')),
    (RegExp(r'^tranca\b', caseSensitive: false), RegExp(r'^(?:tranca|trancar|tranque|pode trancar)$')),
    (RegExp(r'^(?:esquenta|refresca)\b', caseSensitive: false), RegExp(r'^(?:liga|ligar|ligue|pode ligar|esquenta|refresca)$')),
  ],
};
bool _sameRequest(String userText, String request, String lang) {
  RegExp? verb;
  for (final (re, v) in _offerVerbs[lang]!) {
    if (re.hasMatch(request)) {
      verb = v;
      break;
    }
  }
  if (verb == null) return false;
  final f = foldText(userText)
      .replaceFirst(RegExp(r'^(?:yes|yeah|sure|ok|okay|please|sim|claro|pode|ok|beleza) '), '')
      .replaceFirst(RegExp(r' (?:please|por favor|pra mim|para mim)$'), '')
      .replaceFirstMapped(RegExp(r'^(turn|switch) (?:it|them) on$'), (m) => '${m[1]} on')
      .replaceFirst(RegExp(r' (?:it|them|that|ele|eles|ela|elas|isso)$'), '');
  return verb.hasMatch(f);
}

({String kind, String request})? _pending;
var _dismissVariant = 0;
var _lastSpoken = '';

/// For tests.
void resetFollowUp() {
  _pending = null;
  _dismissVariant = 0;
  _lastSpoken = '';
}

/// What the driver last heard (said again for "Say that again").
void noteCarSpoken(String text) {
  if (text.trim().isNotEmpty) _lastSpoken = text.trim();
}

/// What goes to the agent for what the driver said ((text: ..., reply: null)), or the app's own short reply ((text: null, reply: ...)).
/// [offer]: the names of the calls a plain yes would run now (the previous request's offer), or null.
({String? text, String? reply}) carTurnInput(String userText, String language, List<String>? offer,
    {bool musicOn = false, CarState? state, bool? lastActed}) {
  final lang = _tuned(language);
  if (lang == null) return (text: normalizeYesNo(userText, language) ?? withCarHints(userText, language), reply: null);
  final asked = _pending;
  _pending = null;
  // "Say that again": what was said, and the question in it still waits for its answer
  if (_lastSpoken.isNotEmpty && _only(userText, _repeat[lang]!)) {
    _pending = asked;
    return (text: null, reply: _lastSpoken);
  }
  // the app's own offer (an answer about the car: "Want me to lock it?"): a yes is that request
  if (asked != null && asked.kind == 'command' && (_only(userText, _yes[lang]!) || _sameRequest(userText, asked.request, lang))) {
    return (text: asked.request, reply: null);
  }
  // a question about the car: answered from the car (the model ran the action)
  final known = state == null ? null : answerCarQuestion(userText, language, state);
  if (known != null) {
    if (known.offer != null) {
      _pending = (kind: 'command', request: known.offer!);
    } else if (known.askDestination) {
      _pending = (kind: 'destination', request: '');
    }
    return (text: null, reply: known.reply);
  }
  final yes = lang == 'pt' ? 'sim' : 'yes';
  // music playing, "next song": not in this demo (the app's own sentence for that)
  if (musicOn && _only(userText, _skip[lang]!)) return (text: null, reply: notInDemoTexts[language] ?? notInDemoTexts['en']!);
  // music playing: "stop" / "para" means the music (what the model understands: "Stop the music" / "Desliga o som" -> mute)
  if (musicOn && (offer == null || offer.isEmpty) && _only(userText, _stopMusic[lang]!)) {
    return (text: lang == 'pt' ? 'Desliga o som' : 'Stop the music', reply: null);
  }
  if (offer != null && offer.isNotEmpty) {
    if (_only(userText, _yes[lang]!)) return (text: yes, reply: null);
    if (offer.contains('navigate_to') && _only(userText, _goThere[lang]!)) return (text: yes, reply: null);
    if (_only(userText, _dismiss[lang]!) && _containsAny(userText, _dismissCore[lang]!)) return (text: lang == 'pt' ? 'não' : 'no', reply: null);
    return (text: userText, reply: null);
  }
  if (_only(userText, _dismiss[lang]!) && _containsAny(userText, _dismissCore[lang]!)) {
    final list = _dismissReply[lang]!;
    return (text: null, reply: list[_dismissVariant++ % list.length]);
  }
  // "Turn it off" with nothing it can mean (no music, the last request changed nothing): asked, not guessed
  if (!musicOn && lastActed == false && asked == null) {
    final which = _only(userText, _bareOff[lang]!) ? 'off' : _only(userText, _bareOn[lang]!) ? 'on' : null;
    if (which != null) {
      final (question, verb) = _askWhat[lang]![which]!;
      _pending = (kind: 'verb', request: verb);
      return (text: null, reply: question);
    }
  }
  if (asked != null) {
    final a = foldText(userText);
    final words = a.isEmpty ? 0 : a.split(' ').length;
    if (words > 0 && words <= 5 && !_commandStart[lang]!.hasMatch(a) && !_only(userText, _yes[lang]!)) {
      // "The driver's one" -> "the driver's one" inside the request (a name such as "Coldplay" keeps its capital)
      final said = userText.trim().replaceAll(RegExp(r'[.!?]+$'), '');
      final answer = _lowerFirst[lang]!.contains(foldText(said.split(' ').first)) ? said[0].toLowerCase() + said.substring(1) : said;
      if (asked.kind == 'destination') {
        return (
          text: lang == 'pt'
              ? (RegExp(r'^(pra|pro|para|pras|pros)\b', caseSensitive: false).hasMatch(answer) ? 'Navega $answer' : 'Navega para $answer')
              : RegExp(r'^to\b', caseSensitive: false).hasMatch(answer) ? 'Navigate $answer' : 'Navigate to $answer',
          reply: null,
        );
      }
      if (asked.kind == 'media') return (text: '${lang == 'pt' ? 'Toca' : 'Play'} $answer', reply: null);
      if (asked.kind == 'verb') return (text: '${asked.request} $answer', reply: null);
      if (asked.kind == 'seat') {
        // the core asks again unless the request names one seat: the seat goes into the request ("Heat the driver's seat")
        String? seat;
        for (final (re, s) in _seatAnswer[lang]!) {
          if (re.hasMatch(a)) {
            seat = s;
            break;
          }
        }
        final rewritten = seat == null ? null : _withSeat(asked.request, seat, lang);
        if (rewritten != null) return (text: rewritten, reply: null);
      }
      if (asked.kind != 'command') return (text: '${asked.request.trim().replaceAll(RegExp(r'[.!?,;:]+$'), '')}, $answer', reply: null);
    }
  }
  final seats = _pluralSeats(userText, lang);
  if (seats != null) {
    _pending = (kind: 'seat', request: seats);
    return (text: null, reply: _whichSeat[lang]);
  }
  // something the car can't do, with the action it can ("Lock the sunroof" -> close it): asked, nothing runs without a yes
  final near = _nearMiss(userText, lang);
  if (near != null) {
    _pending = (kind: 'command', request: near.request);
    return (text: null, reply: near.reply);
  }
  return (text: _canonical(userText, lang) ?? userText, reply: null);
}

/// "Lock the sunroof" / "Unlock the windows": the car has no such lock (2026-11-25 iPhone: the model declined and the driver heard "not
/// available in this demo"). The app says what it can do instead and asks; a yes ("Yes", "Close it") sends that request to the agent.
({String reply, String request})? _nearMiss(String userText, String lang) {
  final f = foldText(userText);
  if (lang == 'en') {
    final m = RegExp(r'^(?:(?:can|could|would|will) you |please )*(lock|unlock) (?:up )?(?:the |my |our |all the |all )?(sunroof|moonroof|roof|windows)(?: please| for me)?$').firstMatch(f);
    if (m == null) return null;
    final lock = m.group(1) == 'lock';
    final roof = m.group(2) != 'windows';
    final what = roof ? 'the sunroof' : 'the windows';
    final verb = lock ? 'close' : 'open';
    final it = roof ? 'it' : 'them';
    return (
      reply: "I can't ${m.group(1)} $what, but I can $verb $it. Want me to $verb $it?",
      request: roof ? '${lock ? 'Close' : 'Open'} the sunroof' : '${lock ? 'Close' : 'Open'} all the windows',
    );
  }
  // pt-BR: every sentence about six words or more; both tested 2026-11-25 (brv3 voice, 5/5 heard right; "Quer que eu feche..." was 3/5) (car/speech_composer.dart, the pt-BR voice)
  final m = RegExp(r'^(?:(?:voce|vc) pode |pode |por favor )*(tranca|trancar|tranque|destranca|destrancar|destranque) (?:o |os |as |todos os |todas as )?(teto solar|teto|vidros|janelas)(?: do carro)?(?: por favor| pra mim)?$').firstMatch(f);
  if (m == null) return null;
  final lock = !m.group(1)!.startsWith('des');
  final roof = m.group(2)!.startsWith('teto');
  final said = roof ? 'o teto solar do carro' : 'as janelas do carro';
  return (
    reply: 'Não consigo ${lock ? 'trancar' : 'destrancar'} $said. Posso ${lock ? 'fechar' : 'abrir'} ${roof ? 'o teto solar' : 'todas as janelas'} para você?',
    request: roof ? '${lock ? 'Fecha' : 'Abre'} o teto solar' : '${lock ? 'Fecha' : 'Abre'} todos os vidros',
  );
}

/// After the agent's reply: remember a question the next short answer completes. [sent] = what went to the agent for this request.
void noteCarReply(String sent, String reply, String language) {
  _pending = null;
  if (_tuned(language) == null) return;
  final r = reply.trim();
  if (!r.endsWith('?')) return;
  final last = (RegExp(r'[^.!?]*\?$').firstMatch(r)?.group(0) ?? r).trim();
  if (RegExp(r'where (?:do you want|would you like) to go\?$|para onde (?:você |vc )?quer ir\?$', caseSensitive: false).hasMatch(last)) {
    _pending = (kind: 'destination', request: sent);
  } else if (RegExp(r'what (?:do you want|would you like) to (?:hear|listen to)\?$|o que (?:você |vc )?quer ouvir\?$', caseSensitive: false)
      .hasMatch(last)) {
    _pending = (kind: 'media', request: sent);
  } else if (RegExp(r'^(?:which seat|qual banco)\b', caseSensitive: false).hasMatch(last)) {
    _pending = (kind: 'seat', request: sent);
  } else if (RegExp(r'\b(?:which|qual|quais)\b', caseSensitive: false).hasMatch(last) &&
      !RegExp(r'\b(?:again|repetir|de novo)\b', caseSensitive: false).hasMatch(last)) {
    _pending = (kind: 'merge', request: sent);
  }
}
