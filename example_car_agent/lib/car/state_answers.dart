// A question about the car's state is answered from the car itself (port of the RN example's src/car/stateAnswers.ts, 2026-11-21 reply
// review; tests share test/fixtures/state_answers.json): the model RAN the action for a question. "Is the car locked?" locked it,
// "Are the windows closed?" closed them, "Is the sunroof open?" opened it, "O aquecimento do meu banco tá ligado?" turned it on. The
// answer says the state and offers the obvious change ("No, the car is unlocked. Want me to lock it?"): a yes sends that request to
// the agent (follow_up.dart), so the model runs a request it handles; nothing runs here.
// Only a question (question words, a state word and a part of the car together) is answered; anything else goes to the agent as before.
// Pure: the language and the car state are parameters. Tuned languages (en, pt-BR) only.
import 'basic_language.dart';
import 'car_state.dart';
import 'positions.dart';

/// The reply, the request a plain yes sends to the agent (null: nothing offered), and whether the reply asks where to go.
typedef StateAnswer = ({String reply, String? offer, bool askDestination});

StateAnswer _a(String reply, [String? offer]) => (reply: reply, offer: offer, askDestination: false);

bool _has(String f, String re) => RegExp(re).hasMatch(f);

String _list(List<String> items, String lang) {
  if (items.length <= 1) return items.join();
  return '${items.sublist(0, items.length - 1).join(', ')} ${lang == 'en' ? 'and' : 'e'} ${items.last}';
}

/// A position as the driver says it: the driver's / passenger window (door) by the car's steering side, else its place.
String _posName(String p, String obj, String l, CarState s) {
  final driver = resolvePositions('driver', s.steering)!.first;
  final passenger = resolvePositions('passenger', s.steering)!.first;
  return positionName(p == driver ? 'driver' : p == passenger ? 'passenger' : p, obj, l).text;
}

const _filler = r'^(?:(?:hey|so|um|uh|hmm|ok|okay|oi|ei|e ai|hum|entao|tipo) )*';
const _enQ = r'^(?:is|are|was|were|did|do|does|have|has|what|what s|whats|where|how|which|can you (?:check|tell me|see)|could you (?:check|tell me|see)|do you know|i wonder|tell me)\b';
const _ptQ = r'^(?:sera que|voce sabe|vc sabe|sabe|qual|quais|quanto|quantos|em quanto|que|o que|pra onde|para onde|onde|como|eu (?:tranquei|fechei|deixei|travei)|tranquei|fechei|deixei|travei|(?:(?:o|a|os|as) )?(?:meu |minha |meus |minhas )?(?:carro|vidro|vidros|janela|janelas|porta|portas|teto|aquecimento|ventilacao|banco|volume|som|temperatura|ar)\b)';
const _enWh = r'^(?:what s|whats|what is|what|how|which|tell me|can you tell me|could you tell me|do you know)\b';
const _ptWh = r'^(?:qual|quais|em quanto|quanto|como|sera que|voce sabe|vc sabe|sabe|(?:ta|esta) em quanto)\b';

/// A question with a request after it ("What's the temperature? Set it to 22") goes to the agent.
const _enAndDo = r'\b(?:set it|turn it|make it|put it|change it|lock it|close it|open it|close them|open them|and (?:set|turn|make|open|close|lock|unlock|play|raise|lower)|then)\b';
const _ptAndDo = r'\b(?:coloca|poe|bota|muda|aumenta|abaixa|abre|fecha|tranca|destranca|liga|desliga|toca|esquenta|refresca)\b';

/// Polite requests are requests ("Can you open the window?"): not questions about the state.
const _enRequest = r'^(?:can|could|would|will) you (?!check|tell me|see)|^would you mind|^please\b';

bool _isQuestion(String raw, String f, String lang) {
  final t = f.replaceFirst(RegExp(_filler), '');
  final endsQ = RegExp(r'\?\s*$').hasMatch(raw);
  if (lang == 'en') return !_has(t, _enRequest) && (_has(t, _enQ) || endsQ);
  return _has(t, _ptQ) ||
      (endsQ &&
          !_has(t, r'^(?:abre|fecha|tranca|destranca|liga|desliga|deixa|coloca|poe|bota|aumenta|abaixa|esquenta|refresca|pode|voce pode|vc pode|da pra)\b'));
}

String _windowTarget(String f, String lang) {
  if (lang == 'en') {
    if (_has(f, r'\b(my window|my side|driver s|drivers|driver)\b')) return 'driver';
    if (_has(f, r'\b(passenger|passenger s)\b')) return 'passenger';
    if (_has(f, r'\b(rear|back)\b')) return 'rear';
    if (_has(f, r'\bfront\b')) return 'front';
    return 'all';
  }
  if (_has(f, r'\b(meu vidro|minha janela|meu lado|motorista)\b')) return 'driver';
  if (_has(f, r'\b(passageiro|carona)\b')) return 'passenger';
  if (_has(f, r'\b(de tras|traseiros?|traseiras?)\b')) return 'rear';
  if (_has(f, r'\bda frente\b')) return 'front';
  return 'all';
}

String _seatOf(String f, String lang) => _has(f, lang == 'en' ? r'\b(passenger|passenger s)\b' : r'\b(passageiro|carona)\b') ? 'passenger' : 'driver';

const _enLevel = {'low': 'low', 'medium': 'medium', 'high': 'high'};
const _ptLevel = {'low': 'baixo', 'medium': 'médio', 'high': 'alto'};
const _enSeatName = {'driver': "the driver's seat", 'passenger': 'the passenger seat'};
const _ptSeatName = {'driver': 'do banco do motorista', 'passenger': 'do banco do passageiro'};

StateAnswer _lock(CarState s, String lang, bool askedUnlocked) {
  final open = positions.where((p) => s.doorLocks[p] != true).toList();
  final all = open.isEmpty;
  final none = open.length == 4;
  final yes = askedUnlocked ? !all : all;
  if (lang == 'en') {
    const offer = 'Lock the car';
    if (all) return _a('${yes ? 'Yes' : 'No'}, the car is locked.');
    if (none) return _a('${yes ? 'Yes' : 'No'}, the car is unlocked. Want me to lock it?', offer);
    final doors = [for (final p in open) _posName(p, 'door', 'en', s)];
    return _a('Not completely: ${_list(doors, lang)} ${doors.length > 1 ? 'are' : 'is'} unlocked. Want me to lock the car?', offer);
  }
  const offer = 'Tranca o carro';
  if (all) return _a('${yes ? 'Sim' : 'Não'}, o carro está trancado.');
  if (none) return _a('${yes ? 'Sim' : 'Não'}, o carro está destrancado. Quer que eu tranque?', offer);
  final doors = [for (final p in open) _posName(p, 'door', 'pt-BR', s)];
  return _a('Não totalmente: ${_list(doors, lang)} ${doors.length > 1 ? 'estão destrancadas' : 'está destrancada'}. Quer que eu tranque o carro?', offer);
}

String _allThe(String text, String lang) => lang == 'en'
    ? text.replaceFirst(RegExp(r'^the '), 'all the ').replaceFirst('all the all the', 'all the')
    : text.replaceFirst(RegExp(r'^os '), 'todos os ').replaceFirst('todos os todos os', 'todos os');

StateAnswer _windows(CarState s, String lang, String target, bool askedOpen) {
  final l = lang == 'en' ? 'en' : 'pt-BR';
  final ps = resolvePositions(target, s.steering) ?? [];
  final open = ps.where((p) => s.windows[p] != 'close').toList();
  final n = positionName(target, 'window', l);
  if (ps.length == 1) {
    final isOpen = open.length == 1;
    final yes = askedOpen == isOpen;
    if (lang == 'en') {
      return isOpen
          ? _a('${yes ? 'Yes' : 'No'}, ${n.text} is open. Want me to close it?', 'Close ${n.text}')
          : _a('${yes ? 'Yes' : 'No'}, ${n.text} is closed.');
    }
    return isOpen
        ? _a('${yes ? 'Sim' : 'Não'}, ${n.text} está aberto. Quer que eu feche?', 'Fecha ${n.text}')
        : _a('${yes ? 'Sim' : 'Não'}, ${n.text} está fechado.');
  }
  if (open.isEmpty) {
    return lang == 'en'
        ? _a('${askedOpen ? 'No' : 'Yes'}, ${_allThe(n.text, lang)} are closed.')
        : _a('${askedOpen ? 'Não' : 'Sim'}, ${_allThe(n.text, lang)} estão fechados.');
  }
  final names = [for (final p in open) _posName(p, 'window', l, s)];
  final one = open.length == 1;
  final close = one ? '${lang == 'en' ? 'Close' : 'Fecha'} ${names[0]}' : '${lang == 'en' ? 'Close' : 'Fecha'} ${n.text}';
  final allOpen = open.length == ps.length;
  if (lang == 'en') {
    final what = allOpen ? '${_allThe(n.text, lang)} are open' : '${_list(names, lang)} ${one ? 'is' : 'are'} open';
    return _a('${askedOpen ? 'Yes' : 'No'}, $what. Want me to close ${one ? 'it' : 'them'}?', close);
  }
  final what = allOpen ? '${_allThe(n.text, lang)} estão abertos' : '${_list(names, lang)} ${one ? 'está aberto' : 'estão abertos'}';
  return _a('${askedOpen ? 'Sim' : 'Não'}, $what. Quer que eu feche?', close);
}

StateAnswer _doors(CarState s, String lang, bool askedOpen) {
  final open = positions.where((p) => s.doors[p] == 'open').toList();
  if (open.isEmpty) {
    return _a(lang == 'en' ? '${askedOpen ? 'No' : 'Yes'}, all the doors are closed.' : '${askedOpen ? 'Não' : 'Sim'}, todas as portas estão fechadas.');
  }
  final l = lang == 'en' ? 'en' : 'pt-BR';
  final names = [for (final p in open) _posName(p, 'door', l, s)];
  final one = open.length == 1;
  if (lang == 'en') {
    return _a('${askedOpen ? 'Yes' : 'No'}, ${_list(names, lang)} ${one ? 'is' : 'are'} open. Want me to close ${one ? 'it' : 'them'}?', 'Close the doors');
  }
  final n = positionName(open[0], 'door', l);
  return _a('${askedOpen ? 'Sim' : 'Não'}, ${_list(names, lang)} ${one ? 'está ${adj('abert', n)}' : 'estão abertas'}. Quer que eu feche?', 'Fecha as portas');
}

StateAnswer _sunroof(CarState s, String lang, bool askedOpen) {
  final isOpen = s.sunroof != 'close';
  final yes = askedOpen == isOpen;
  if (lang == 'en') {
    if (!isOpen) return _a('${yes ? 'Yes' : 'No'}, the sunroof is closed.');
    return _a('${yes ? 'Yes' : 'No'}, the sunroof is ${s.sunroof == 'tilt' ? 'tilted open' : 'open'}. Want me to close it?', 'Close the sunroof');
  }
  if (!isOpen) return _a('${yes ? 'Sim' : 'Não'}, o teto solar está fechado.');
  return _a('${yes ? 'Sim' : 'Não'}, o teto solar está ${s.sunroof == 'tilt' ? 'inclinado' : 'aberto'}. Quer que eu feche?', 'Fecha o teto solar');
}

StateAnswer _seat(CarState s, String lang, String seat, String feature, bool askedOn) {
  final level = (feature == 'heater' ? s.seatHeater : s.seatVentilation)[seat] ?? 'off';
  final on = level != 'off';
  final yes = askedOn == on;
  if (lang == 'en') {
    final what = '${_enSeatName[seat]} ${feature == 'heater' ? 'heater' : 'ventilation'}';
    if (on) return _a('${yes ? 'Yes' : 'No'}, $what is on ${_enLevel[level]}.');
    return _a('${yes ? 'Yes' : 'No'}, $what is off. Want me to turn it on?', '${feature == 'heater' ? 'Heat' : 'Cool'} ${_enSeatName[seat]}');
  }
  final what = '${feature == 'heater' ? 'o aquecimento' : 'a ventilação'} ${_ptSeatName[seat]}';
  if (on) return _a('${yes ? 'Sim' : 'Não'}, $what está ${feature == 'heater' ? 'ligado' : 'ligada'} no ${_ptLevel[level]}.');
  return _a('${yes ? 'Sim' : 'Não'}, $what está ${feature == 'heater' ? 'desligado' : 'desligada'}. Quer que eu ligue?',
      '${feature == 'heater' ? 'Esquenta' : 'Refresca'} o banco do ${seat == 'driver' ? 'motorista' : 'passageiro'}');
}

String _num(num v, String lang) {
  final t = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  return lang == 'pt' ? t.replaceAll('.', ',') : t;
}

StateAnswer _temperature(CarState s, String lang) {
  final u = s.unit == 'fahrenheit' ? '°F' : '°C';
  final d = s.temperature['driver'] ?? 21;
  final p = s.temperature['passenger'] ?? 21;
  if (d == p) return _a(lang == 'en' ? "It's set to ${_num(d, lang)}$u." : 'Está em ${_num(d, lang)}$u.');
  return _a(lang == 'en'
      ? "The driver's side is set to ${_num(d, lang)}$u and the passenger side to ${_num(p, lang)}$u."
      : 'O lado do motorista está em ${_num(d, lang)}$u e o do passageiro em ${_num(p, lang)}$u.');
}

StateAnswer _media(CarState s, String lang) {
  final muted = s.muted ? (lang == 'en' ? ', but the sound is muted' : ', mas o som está no mudo') : '';
  if (s.media != null) return _a(lang == 'en' ? "You're listening to ${s.media}$muted." : 'Você está ouvindo ${s.media}$muted.');
  if (s.radio != null) return _a(lang == 'en' ? "You're listening to ${s.radio}$muted." : 'Você está ouvindo a rádio ${s.radio}$muted.');
  return _a(lang == 'en' ? "Nothing's playing right now." : 'Não tem nada tocando agora.');
}

StateAnswer _destination(CarState s, String lang) {
  final d = s.destination;
  if (d == null) {
    return (
      reply: lang == 'en' ? "There's no active route. Where do you want to go?" : 'Não há nenhuma rota ativa. Para onde você quer ir?',
      offer: null,
      askDestination: true,
    );
  }
  if (lang == 'en') {
    if (d == 'home') return _a("We're heading home.");
    final p = RegExp(r'^[a-z]').hasMatch(d) && !RegExp(r'^(the|a|an|my|your|our|work|downtown)\b').hasMatch(d) ? 'the $d' : d;
    return _a("We're heading to $p.");
  }
  if (d == 'casa') return _a('Estamos indo para casa.');
  final p = RegExp(r'^[a-zà-ü]').hasMatch(d) && !RegExp(r'^(o|a|os|as|um|uma|meu|minha)\b').hasMatch(d)
      ? '${RegExp(r'(a|ção|dade|gem)$').hasMatch(d.split(' ').first) ? 'a' : 'o'} $d'
      : d;
  return _a('Estamos indo para $p.');
}

/// The answer to a question about the car's state, or null (not such a question: the agent gets it).
StateAnswer? answerCarQuestion(String userText, String language, CarState s) {
  final lang = language == 'en' ? 'en' : language == 'pt-BR' ? 'pt' : null;
  if (lang == null) return null;
  final f = foldText(userText);
  if (f.isEmpty || f.split(' ').length > 14 || !_isQuestion(userText, f, lang)) return null;
  // a second sentence ("Is the car locked? Lock it") or a request in it: the agent decides
  if (RegExp(r'[.?!;]\s*\S').hasMatch(userText.trim().replaceFirst(RegExp(r'[.?!]+$'), '')) || _has(f, lang == 'en' ? _enAndDo : _ptAndDo)) {
    return null;
  }
  final t = f.replaceFirst(RegExp(_filler), '');
  if (lang == 'en') {
    final outside = _has(f, r'\b(outside|outdoors?|out there|weather|today|tomorrow|tonight|forecast)\b');
    if (_has(f, r'\b(locked|unlocked)\b') || _has(f, r'\b(?:did|have) (?:i|you) lock\b')) return _lock(s, lang, _has(f, r'\bunlocked\b'));
    if (_has(f, r'\bwindows?\b') && _has(f, r'\b(open|opened|closed|shut|up|down|cracked)\b')) {
      return _windows(s, lang, _windowTarget(f, lang), _has(f, r'\b(open|opened|down|cracked)\b'));
    }
    if (_has(f, r'\bdoors?\b') && _has(f, r'\b(open|opened|closed|shut|ajar)\b')) return _doors(s, lang, _has(f, r'\b(open|opened|ajar)\b'));
    if (_has(f, r'\bsun ?roof\b') && _has(f, r'\b(open|opened|closed|shut)\b')) return _sunroof(s, lang, _has(f, r'\b(open|opened)\b'));
    if (_has(f, r'\bseats?\b') && _has(f, r'\b(heater|heaters|heating|heated|warmer|warmers)\b') && _has(f, r'\b(on|off|running|working)\b')) {
      return _seat(s, lang, _seatOf(f, lang), 'heater', !_has(f, r'\boff\b'));
    }
    if (_has(f, r'\bseats?\b') && _has(f, r'\b(ventilation|ventilated|cooling|cooler|fans?)\b') && _has(f, r'\b(on|off|running|working)\b')) {
      return _seat(s, lang, _seatOf(f, lang), 'ventilation', !_has(f, r'\boff\b'));
    }
    if (!outside && (_has(f, r'\b(temperature|temp)\b') && _has(t, _enWh) || _has(t, r'^how (?:warm|hot|cold) is it (?:set|in here)\b'))) {
      return _temperature(s, lang);
    }
    if (_has(t, _enWh) && _has(t, r'\bvolume\b|^how loud\b')) return _a(s.muted ? 'The sound is muted.' : 'The volume is at ${s.volume}.');
    if (_has(t, _enWh) && _has(f, r'\bfan\b') && !_has(f, r'\bseat\b')) return _a('The fan is at level ${s.fan}.');
    if (_has(t, r"^(?:what s playing|whats playing|what is playing|what song is (?:this|playing)|what am i listening to|what station is (?:this|on)|what s on the radio|who s (?:singing|playing)|who is (?:singing|playing)|what music is (?:this|playing))\b")) {
      return _media(s, lang);
    }
    if (_has(t, r'^(?:where are we (?:going|headed|heading)|what s (?:my|our|the) destination|what is (?:my|our|the) destination|where am i (?:going|headed|heading))\b')) {
      return _destination(s, lang);
    }
    return null;
  }
  final outside = _has(f, r'\b(la fora|fora|lado de fora|tempo|clima|hoje|amanha|previsao)\b');
  if (_has(f, r'\b(trancad[oa]s?|destrancad[oa]s?|travad[oa]s?|destravad[oa]s?|tranquei|travei|trancou|travou)\b')) {
    return _lock(s, lang, _has(f, r'\b(destrancad|destravad)'));
  }
  if (_has(f, r'\bcarro\b') && _has(f, r'\b(abert[oa]|fechad[oa])\b') && !_has(f, r'\b(vidros?|janelas?|portas?|teto)\b')) {
    return _lock(s, lang, _has(f, r'\babert'));
  }
  if (_has(f, r'\b(vidros?|janelas?)\b') && _has(f, r'\b(abert[oa]s?|fechad[oa]s?|abaixad[oa]s?|levantad[oa]s?|fechei)\b')) {
    return _windows(s, lang, _windowTarget(f, lang), _has(f, r'\b(abert|abaixad)'));
  }
  if (_has(f, r'\bportas?\b') && _has(f, r'\b(abert[oa]s?|fechad[oa]s?|fechei)\b')) return _doors(s, lang, _has(f, r'\babert'));
  if (_has(f, r'\bteto( solar)?\b') && _has(f, r'\b(abert[oa]|fechad[oa])\b')) return _sunroof(s, lang, _has(f, r'\babert'));
  if (_has(f, r'\bbancos?\b') && _has(f, r'\b(aquecimento|aquecid[oa]|esquentando)\b') && _has(f, r'\b(ligad[oa]|desligad[oa]|esquentando|funcionando)\b')) {
    return _seat(s, lang, _seatOf(f, lang), 'heater', !_has(f, r'\bdesligad'));
  }
  if (_has(f, r'\bbancos?\b') && _has(f, r'\b(ventilacao|ventilad[oa])\b') && _has(f, r'\b(ligad[oa]|desligad[oa]|funcionando)\b')) {
    return _seat(s, lang, _seatOf(f, lang), 'ventilation', !_has(f, r'\bdesligad'));
  }
  if (!outside && (_has(f, r'\btemperatura\b') && _has(t, _ptWh) || _has(t, r'^(?:ta|esta) em quantos graus\b|^quantos graus\b'))) {
    return _temperature(s, lang);
  }
  if (_has(f, r'\b(volume|som)\b') && _has(t, _ptWh) && !_has(f, r'\b(musica|tocando)\b')) {
    return _a(s.muted ? 'O som está no mudo.' : 'O volume está em ${s.volume}.');
  }
  if (_has(t, _ptWh) && _has(f, r'\b(ventilacao|ventilador)\b') && !_has(f, r'\bbanco')) return _a('A ventilação está no nível ${s.fan}.');
  if (_has(t, r'^(?:o que (?:ta|esta) tocando|que musica (?:e essa|e esta|ta tocando|esta tocando)|qual (?:e )?(?:a )?musica|que radio (?:e essa|e esta)|qual (?:e )?(?:a )?radio|qual (?:e )?(?:a )?estacao|o que (?:eu )?(?:to|tou|estou) ouvindo|quem (?:ta|esta) cantando|quem canta)\b')) {
    return _media(s, lang);
  }
  if (_has(t, r'^(?:pra onde|para onde|onde) (?:a gente |nos )?(?:ta|esta|estamos|tamos|vamos|vai)(?: indo)?\b|^qual (?:e )?o (?:meu |nosso )?destino\b')) {
    return _destination(s, lang);
  }
  return null;
}
