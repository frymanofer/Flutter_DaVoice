import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';

import '../flow/app_language.dart';
import 'car_state.dart';
import 'positions.dart';

// The DaVoice Car tools for the agent (port of the RN example's src/car/carTools.ts): definitions from assets/car/*.json (the same
// files as the RN example), handlers that change the simulated car. Each call is recorded for the car card. The app says what it did
// (ToolReply: a sentence naming the action, position, zone and value - success, already in that state, or refused) and the turn
// ends there; nothing is claimed before the handler returns.

typedef _Args = Map<String, Object?>;

class _Outcome {
  _Outcome(this.summary, this.result, [this.say]);
  final String summary;
  final Map<String, Object?> result;
  final String? say;
}

/// Refused by the app: nothing changes; the message is a full sentence the user hears (the turn ends there).
class _Refused implements Exception {
  _Refused(this.message);
  final String message;
}

bool get _pt => currentAppLanguage == 'pt-BR';
String _l(String en, String pt) => _pt ? pt : en;
String get _lang => _pt ? 'pt-BR' : 'en';

const _ptSeat = {'driver': 'motorista', 'passenger': 'passageiro', 'rear_left': 'traseiro esquerdo', 'rear_right': 'traseiro direito'};
const _ptLevel = {'off': 'desligado', 'low': 'baixo', 'medium': 'médio', 'high': 'alto'};
const _ptPlace = {'gas_station': 'posto de combustível', 'ev_charger': 'carregador', 'parking': 'estacionamento', 'restaurant': 'restaurante', 'coffee': 'café', 'rest_area': 'parada'};
const _ptAvoid = {'tolls': 'pedágios', 'traffic': 'trânsito', 'highways': 'rodovias', 'ferries': 'balsas'};
const _ptAir = {'face': 'rosto', 'feet': 'pés', 'face_and_feet': 'rosto e pés', 'windshield': 'para-brisa'};
const _enSeat = {'driver': "the driver's seat", 'passenger': 'the passenger seat', 'rear_left': 'the rear left seat', 'rear_right': 'the rear right seat'};
const _enPlace = {'gas_station': 'a gas station', 'ev_charger': 'an EV charger', 'parking': 'a parking spot', 'restaurant': 'a restaurant', 'coffee': 'a coffee shop', 'rest_area': 'a rest area'};
const _ptPlaceSay = {'gas_station': 'um posto de combustível', 'ev_charger': 'um carregador', 'parking': 'um estacionamento', 'restaurant': 'um restaurante', 'coffee': 'um café', 'rest_area': 'uma parada'};
const _enAir = {'face': 'your face', 'feet': 'your feet', 'face_and_feet': 'your face and feet', 'windshield': 'the windshield'};

String _words(Object? s) => '$s'.replaceAll('_', ' ');
String _str(Object? v) => v == null ? '' : '$v';

/// A number as the JS app prints it: 22 (not 22.0), 22.5; pt-BR with a comma.
String _n(num v) {
  final s = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  return _pt ? s.replaceAll('.', ',') : s;
}

num? _num(Object? v) => v is num ? v : (v is String ? num.tryParse(v) : null);

_Outcome _done(String summary, [Map<String, Object?> extra = const {}, String? say]) =>
    _Outcome(summary, {'status': 'Done: $summary', ...extra}, say);

/// Nothing to do: the car is already in the requested state (said as such; nothing is claimed as done).
_Outcome _already(String summary, String say, [Map<String, Object?> extra = const {}]) => _Outcome(summary, {'already': true, ...extra}, say);

/// A lookup answered by the app itself (no second model round that could only say "Done.").
_Outcome _answer(String summary, Map<String, Object?> result, String say) => _Outcome(summary, result, say);

CarState get _s => car.state;

/// The positions a window / door argument means in this car (steering-wheel side from the vehicle configuration).
List<String> _positions(Object? target, String obj) {
  final p = resolvePositions(target, _s.steering);
  if (p == null) {
    throw _Refused(_l("I don't know which $obj that is. Which one do you mean?", 'Não sei qual ${obj == 'door' ? 'porta' : 'vidro'} é esse. Qual você quer?'));
  }
  return p;
}

PositionName _nm(Object? target, String obj) => positionName(target, obj, _lang);
String _degrees(num t, String unit) => '${_n(t)}°${unit == 'fahrenheit' ? 'F' : 'C'}';

/// Not while the car moves (the demo's Parked / Driving switch).
final Map<String, bool Function(_Args)> _notWhileDriving = {
  'set_trunk': (_) => true,
  'set_charge_port': (_) => true,
  'rotate_screen': (_) => true,
  'activate_scenario': (a) => a['mode'] == 'car_wash' || a['mode'] == 'rest',
  'set_window': (a) => (a['window'] ?? 'all') == 'all' && a['position'] == 'open',
  'open_door': (_) => true,
};

num _range(Object? value, num min, num max, String what) {
  final n = _num(value);
  if (n == null || n.isNaN || n < min || n > max) {
    throw _Refused(_l("I didn't change it: ${what.toLowerCase()} must be between ${_n(min)} and ${_n(max)}.",
        'Não mudei: ${what.toLowerCase()} precisa ficar entre ${_n(min)} e ${_n(max)}.'));
  }
  return n;
}

_Outcome _lockDoors(Object? door, bool lock) {
  final which = _positions(door, 'door');
  final whole = which.length == 4;
  final n = _nm(door, 'door');
  if (lock) {
    final open = which.where((k) => _s.doors[k] == 'open').toList();
    if (open.isNotEmpty) {
      final on = open.length == 1 ? positionName(open[0], 'door', _lang) : positionName('all', 'door', _lang);
      throw _Refused(open.length == 1
          ? _l("I can't lock it while ${on.text} is open. Close it first?", 'Não consigo trancar com ${on.text} ${adj('abert', on)}. Quer que eu feche primeiro?')
          : _l("I can't lock the car while doors are open. Close them first?", 'Não consigo trancar com portas abertas. Quer que eu feche primeiro?'));
    }
  }
  final stem = lock ? 'trancad' : 'destrancad';
  if (which.every((k) => _s.doorLocks[k] == lock)) {
    return whole
        ? _already(_l('car already ${lock ? 'locked' : 'unlocked'}', 'carro já ${stem}o'),
            _l('The car is already ${lock ? 'locked' : 'unlocked'}.', 'O carro já está ${stem}o.'))
        : _already(_l('${n.text} already ${lock ? 'locked' : 'unlocked'}', '${n.text} já ${adj(stem, n)}'),
            _l('${cap(n.text)} ${be(n, 'en')} already ${lock ? 'locked' : 'unlocked'}.', '${cap(n.text)} já ${be(n, 'pt-BR')} ${adj(stem, n)}.'));
  }
  for (final k in which) {
    _s.doorLocks[k] = lock;
  }
  _s.locked = _s.doorLocks.values.every((v) => v);
  car.changed();
  return whole
      ? _done(_l(lock ? 'car locked' : 'car unlocked', lock ? 'carro trancado' : 'carro destrancado'), {'doors': which},
          _l(lock ? 'I locked the car.' : 'I unlocked the car.', lock ? 'Tranquei o carro.' : 'Destranquei o carro.'))
      : _done(_l('${n.text} ${lock ? 'locked' : 'unlocked'}', '${n.text} ${adj(stem, n)}'), {'doors': which},
          _l('I ${lock ? 'locked' : 'unlocked'} ${n.text}.', '${lock ? 'Tranquei' : 'Destranquei'} ${n.text}.'));
}

final Map<String, _Outcome Function(_Args)> _handlers = {
  'navigate_to': (a) {
    final d = _str(a['destination']);
    final shown = d == 'home' ? _l('home', 'casa') : d == 'work' ? _l('work', 'trabalho') : d;
    _s.destination = shown;
    car.changed();
    return _done(_l('navigating to $shown', 'navegando para $shown'), {'minutes': 24, 'km': 18},
        _l('Navigating to $shown: about 24 minutes, 18 km.', 'Indo para $shown: cerca de 24 minutos, 18 km.'));
  },
  'find_along_route': (a) {
    final p = _str(a['place_type']);
    return _done(_l('found a ${_words(p)} 2.1 km ahead', '${_ptPlace[p] ?? p} encontrado a 2,1 km'), {'name': 'Nearest match', 'km': 2.1},
        _l('I found ${_enPlace[p] ?? _words(p)} 2.1 km ahead.', 'Encontrei ${_ptPlaceSay[p] ?? p} a 2,1 km.'));
  },
  'get_trip_eta': (a) {
    final dest = _s.destination;
    if (dest == null) {
      return _answer(_l('no active route', 'nenhuma rota ativa'), {'navigating': false},
          _l("There's no active route. Where do you want to go?", 'Não há nenhuma rota ativa. Para onde você quer ir?'));
    }
    return _answer(_l('arriving in 24 min', 'chegada em 24 min'), {'destination': dest, 'minutes_left': 24, 'km_left': 18},
        _l("You'll get to $dest in about 24 minutes, 18 km to go.", 'Você chega em $dest em cerca de 24 minutos; faltam 18 km.'));
  },
  'set_route_avoid': (a) {
    final v = _str(a['avoid']);
    if (_s.avoid.contains(v)) {
      return _already(_l('route unchanged', 'rota sem mudança'), _l('The route already avoids ${_words(v)}.', 'A rota já evita ${_ptAvoid[v] ?? v}.'));
    }
    _s.avoid = [..._s.avoid, v];
    car.changed();
    return _done(_l('route avoids $v', 'rota evitando ${_ptAvoid[v] ?? v}'), {}, _l('The route now avoids ${_words(v)}.', 'A rota agora evita ${_ptAvoid[v] ?? v}.'));
  },
  'set_temperature': (a) {
    final u = _str(a['unit'] ?? _s.unit);
    final z = _str(a['zone'] ?? 'all');
    final temperature = _num(a['temperature']), change = _num(a['change']);
    final current = z == 'all' ? _s.temperature['driver']! : (_s.temperature[z] ?? _s.temperature['driver']!);
    if (temperature == null && change == null) throw _Refused(_l('no temperature given', 'nenhuma temperatura informada'));
    final target = temperature ?? current + change!;
    final t = u == 'fahrenheit' ? _range(target, 60, 86, _l('The temperature', 'A temperatura')) : _range(target, 16, 30, _l('The temperature', 'A temperatura'));
    final zones = z == 'all' ? ['driver', 'passenger', 'rear'] : [z];
    if (zones.every((k) => _s.temperature[k] == t) && u == _s.unit) {
      final enZ = {'all': 'The whole cabin is', 'driver': "The driver's side is", 'passenger': 'The passenger side is', 'rear': 'The back is'}[z] ?? '${cap(_words(z))} is';
      final ptZ = {'all': 'A cabine toda já está', 'driver': 'O lado do motorista já está', 'passenger': 'O lado do passageiro já está', 'rear': 'A parte de trás já está'}[z] ?? '$z já está';
      return _already(_l('temperature already ${_degrees(t, u)}', 'temperatura já em ${_degrees(t, u)}'),
          _l('$enZ already at ${_degrees(t, u)}.', '$ptZ em ${_degrees(t, u)}.'), {'temperature': t});
    }
    _s.unit = u;
    for (final k in zones) {
      _s.temperature[k] = t;
    }
    car.changed();
    final zoneText = z == 'all' ? _l('cabin', 'cabine') : _l(_words(z), _ptSeat[z] ?? z);
    final deg = _degrees(t, u);
    final enZone = {'all': 'the whole cabin', 'driver': "the driver's side", 'passenger': 'the passenger side', 'rear': 'the back'}[z] ?? _words(z);
    final ptZone = {'all': 'a cabine toda', 'driver': 'o lado do motorista', 'passenger': 'o lado do passageiro', 'rear': 'a parte de trás'}[z] ?? z;
    final up = temperature == null && change! > 0, down = temperature == null && change! < 0;
    final say = _l('${up ? 'I raised' : down ? 'I lowered' : 'I set'} $enZone to $deg.', '${up ? 'Subi' : down ? 'Baixei' : 'Coloquei'} $ptZone ${up || down ? 'para' : 'em'} $deg.');
    return _done(_l('$zoneText temperature $deg', 'temperatura $zoneText em $deg'), {'temperature': t}, say);
  },
  // Two zones in one request: each value validated; what can't be set is reported, the rest is done (applied zone by zone).
  'set_dual_zone_temperature': (a) {
    final u = _str(a['unit'] ?? _s.unit);
    final (num min, num max) = u == 'fahrenheit' ? (60, 86) : (16, 30);
    num? check(Object? v) {
      final n = _num(v);
      return n != null && n >= min && n <= max ? n : null;
    }

    final d = check(a['driver']), p = check(a['passenger']);
    if (d == null && p == null) {
      throw _Refused(_l("I didn't change the temperature: both values must be between ${_n(min)} and ${_n(max)}.",
          'Não mudei a temperatura: os dois valores precisam ficar entre ${_n(min)} e ${_n(max)}.'));
    }
    if (d == _s.temperature['driver'] && p == _s.temperature['passenger'] && u == _s.unit) {
      return _already(_l('temperatures already set', 'temperaturas já ajustadas'),
          _l("The driver's side is already at ${_degrees(d!, u)} and the passenger side at ${_degrees(p!, u)}.",
              'O lado do motorista já está em ${_degrees(d, u)} e o do passageiro em ${_degrees(p, u)}.'));
    }
    _s.unit = u;
    if (d != null) _s.temperature['driver'] = d;
    if (p != null) _s.temperature['passenger'] = p;
    car.changed();
    final result = {
      'driver': d != null ? {'ok': true, 'temperature': d} : {'ok': false, 'error': 'out of range'},
      'passenger': p != null ? {'ok': true, 'temperature': p} : {'ok': false, 'error': 'out of range'},
      'atomic': false,
    };
    if (d != null && p != null) {
      return _done(_l('driver ${_degrees(d, u)}, passenger ${_degrees(p, u)}', 'motorista ${_degrees(d, u)}, passageiro ${_degrees(p, u)}'), result,
          _l("I set the driver's side to ${_degrees(d, u)} and the passenger side to ${_degrees(p, u)}.",
              'Coloquei o lado do motorista em ${_degrees(d, u)} e o do passageiro em ${_degrees(p, u)}.'));
    }
    final okSide = d != null ? _l("the driver's side", 'o lado do motorista') : _l('the passenger side', 'o lado do passageiro');
    final badSide = d != null ? _l('the passenger side', 'o do passageiro') : _l("the driver's side", 'o do motorista');
    final v = d ?? p!;
    return _done(_l('partly: $okSide ${_degrees(v, u)}', 'parcial: $okSide ${_degrees(v, u)}'), result,
        _l('I set $okSide to ${_degrees(v, u)}, but not $badSide: it must be between ${_n(min)} and ${_n(max)}.',
            'Coloquei $okSide em ${_degrees(v, u)}, mas não $badSide: precisa ficar entre ${_n(min)} e ${_n(max)}.'));
  },
  'comfort_feeling': (a) {
    final cold = a['feeling'] == 'cold';
    _s.temperature['driver'] = (_s.temperature['driver']! + (cold ? 2 : -2)).clamp(16, 30);
    _s.seatHeater['driver'] = cold ? 'medium' : 'off';
    _s.seatVentilation['driver'] = cold ? 'off' : 'medium';
    car.changed();
    return _done(
        cold ? _l('warmer air, seat heater on medium', 'ar mais quente e aquecimento do banco no médio') : _l('cooler air, seat ventilation on medium', 'ar mais frio e ventilação do banco no médio'),
        {},
        cold
            ? _l('I made it warmer: the air is two degrees up and your seat heater is on medium.', 'Deixei mais quente: subi o ar dois graus e liguei o aquecimento do banco no médio.')
            : _l('I cooled it down: the air is two degrees lower and your seat ventilation is on medium.', 'Deixei mais fresco: baixei o ar dois graus e liguei a ventilação do banco no médio.'));
  },
  'set_fan_speed': (a) {
    final level = _num(a['level']), change = _num(a['change']);
    if (level == null && change == null) throw _Refused(_l('no fan level given', 'nenhum nível de ventilação informado'));
    final target = level ?? _s.fan + change!;
    final fan = _range(target.clamp(1, 7), 1, 7, _l('The fan level', 'O nível de ventilação')).toInt();
    // Outside 1-7 the car goes to the nearest end and says so (never a silent clamp, 2026-11-10 round 2).
    final edge = target > 7 ? _l('The fan goes up to level 7', 'A ventilação vai até o nível 7') : target < 1 ? _l('The lowest fan level is 1', 'O nível mínimo da ventilação é 1') : '';
    if (fan == _s.fan) {
      return _already(_l('fan already $fan', 'ventilação já no $fan'),
          edge.isNotEmpty ? _l('$edge, and it is already there.', '$edge, e já está nele.') : _l('The fan is already at level $fan.', 'A ventilação já está no nível $fan.'));
    }
    _s.fan = fan;
    car.changed();
    return _done(_l('fan speed $fan', 'ventilação no nível $fan'), {'fan_level': fan},
        edge.isNotEmpty ? _l('$edge, so I set it to level $fan.', '$edge, então coloquei no nível $fan.') : _l('I set the fan to level $fan.', 'Coloquei a ventilação no nível $fan.'));
  },
  'set_airflow': (a) {
    final m = _str(a['mode']);
    if (_s.airflow == m) return _already(_l('airflow unchanged', 'ar sem mudança'), _l('The air already goes to ${_enAir[m] ?? _words(m)}.', 'O ar já vai para o ${_ptAir[m] ?? m}.'));
    _s.airflow = m;
    car.changed();
    return _done(_l('air to ${_words(m)}', 'ar para ${_ptAir[m] ?? m}'), {}, _l('The air now goes to ${_enAir[m] ?? _words(m)}.', 'O ar agora vai para o ${_ptAir[m] ?? m}.'));
  },
  'set_defrost': (a) {
    final target = _str(a['target']);
    final want = a['on'] != false;
    final what = target == 'rear' ? _l('rear defogger', 'desembaçador traseiro') : _l('windshield defrost', 'desembaçador do para-brisa');
    if (_s.defrost[target] == want) {
      return _already(_l('$what already ${want ? 'on' : 'off'}', '$what já ${want ? 'ligado' : 'desligado'}'),
          _l('The $what is already ${want ? 'on' : 'off'}.', 'O $what já está ${want ? 'ligado' : 'desligado'}.'));
    }
    _s.defrost[target] = want;
    car.changed();
    return _done('$what ${want ? _l('on', 'ligado') : _l('off', 'desligado')}', {},
        _l('I turned the $what ${want ? 'on' : 'off'}.', '${want ? 'Liguei' : 'Desliguei'} o $what.'));
  },
  'set_window': (a) {
    final which = _positions(a['window'], 'window');
    final n = _nm(a['window'], 'window');
    final pos = _str(a['position']);
    final enState = {'open': 'open', 'close': 'closed', 'half': 'half open', 'crack': 'open a crack'}[pos] ?? pos;
    final ptState = {'open': adj('abert', n), 'close': adj('fechad', n), 'half': '${adj('abert', n)} até a metade', 'crack': 'com uma fresta'}[pos] ?? pos;
    if (which.every((k) => _s.windows[k] == pos)) {
      return _already(_l('${n.text} already $enState', '${n.text} já $ptState'),
          _l('${cap(n.text)} ${be(n, 'en')} already $enState.', '${cap(n.text)} já ${be(n, 'pt-BR')} $ptState.'));
    }
    for (final k in which) {
      _s.windows[k] = pos;
    }
    car.changed();
    final say = _l(
        {'open': 'I opened ${n.text}.', 'close': 'I closed ${n.text}.', 'half': 'I opened ${n.text} halfway.', 'crack': 'I opened ${n.text} a crack.'}[pos] ?? '${cap(n.text)}: $enState.',
        {'open': 'Abri ${n.text}.', 'close': 'Fechei ${n.text}.', 'half': 'Abri ${n.text} até a metade.', 'crack': 'Deixei ${n.text} com uma fresta.'}[pos] ?? '${cap(n.text)}: $ptState.');
    return _done(_l('${n.text} $enState', '${n.text} $ptState'), {'windows': which}, say);
  },
  'open_door': (a) {
    final which = _positions(a['door'], 'door');
    final n = _nm(a['door'], 'door');
    // Locked: the app asks; the model never unlocks on its own.
    final lockedNow = which.where((k) => _s.doorLocks[k] == true).toList();
    if (lockedNow.isNotEmpty) {
      if (lockedNow.length == 4) throw _Refused(_l('The car is locked. Should I unlock it?', 'O carro está trancado. Quer que eu destranque?'));
      final ln = lockedNow.length == 1 ? positionName(lockedNow[0], 'door', _lang) : n;
      throw _Refused(_l('${cap(ln.text)} ${be(ln, 'en')} locked. Should I unlock ${ln.plural ? 'them' : 'it'}?',
          '${cap(ln.text)} ${be(ln, 'pt-BR')} ${adj('trancad', ln)}. Quer que eu destranque?'));
    }
    if (which.every((k) => _s.doors[k] == 'open')) {
      return _already(_l('${n.text} already open', '${n.text} já ${adj('abert', n)}'),
          _l('${cap(n.text)} ${be(n, 'en')} already open.', '${cap(n.text)} já ${be(n, 'pt-BR')} ${adj('abert', n)}.'));
    }
    for (final k in which) {
      _s.doors[k] = 'open';
    }
    car.changed();
    return _done(_l('${n.text} open', '${n.text} ${adj('abert', n)}'), {'doors': which}, _l('I opened ${n.text}.', 'Abri ${n.text}.'));
  },
  'close_doors': (a) {
    final which = _positions(a['door'], 'door');
    final n = _nm(a['door'], 'door');
    if (which.every((k) => _s.doors[k] == 'closed')) {
      return _already(_l('${n.text} already closed', '${n.text} já ${adj('fechad', n)}'),
          _l('${cap(n.text)} ${be(n, 'en')} already closed.', '${cap(n.text)} já ${be(n, 'pt-BR')} ${adj('fechad', n)}.'));
    }
    for (final k in which) {
      _s.doors[k] = 'closed';
    }
    car.changed();
    return _done(_l('${n.text} closed', '${n.text} ${adj('fechad', n)}'), {'doors': which}, _l('I closed ${n.text}.', 'Fechei ${n.text}.'));
  },
  // each door separately; no door / all = the whole car
  'lock_car': (a) => _lockDoors(a['door'], true),
  'unlock_car': (a) => _lockDoors(a['door'], false),
  'set_sunroof': (a) {
    final action = _str(a['action']);
    final enA = action == 'close' ? 'closed' : action == 'tilt' ? 'tilted' : 'open';
    final ptA = action == 'close' ? 'fechado' : action == 'tilt' ? 'inclinado' : 'aberto';
    if (_s.sunroof == action) return _already(_l('sunroof unchanged', 'teto sem mudança'), _l('The sunroof is already $enA.', 'O teto solar já está $ptA.'));
    _s.sunroof = action;
    car.changed();
    return _done(_l('sunroof $enA', 'teto solar $ptA'), {},
        _l('I ${action == 'close' ? 'closed' : action == 'tilt' ? 'tilted' : 'opened'} the sunroof.', '${action == 'close' ? 'Fechei' : action == 'tilt' ? 'Inclinei' : 'Abri'} o teto solar.'));
  },
  'set_sunshade': (a) {
    _s.sunshade = _str(a['action']);
    car.changed();
    return _done(_l('sunshade ${a['action'] == 'close' ? 'closed' : 'open'}', 'cortina do teto ${a['action'] == 'close' ? 'fechada' : 'aberta'}'));
  },
  'set_trunk': (a) {
    final which = _str(a['which']), action = _str(a['action']);
    if (which == 'frunk') {
      _s.frunk = action;
    } else {
      _s.trunk = action;
    }
    car.changed();
    return _done(_l('$which ${action == 'close' ? 'closed' : 'open'}', '${which == 'frunk' ? 'porta-malas dianteiro' : 'porta-malas'} ${action == 'close' ? 'fechado' : 'aberto'}'));
  },
  'set_charge_port': (a) {
    _s.chargePort = _str(a['action']);
    car.changed();
    return _done(_l('charging port ${a['action'] == 'close' ? 'closed' : 'open'}', 'tampa de recarga ${a['action'] == 'close' ? 'fechada' : 'aberta'}'));
  },
  'rotate_screen': (a) {
    final next = a['orientation'] != null ? _str(a['orientation']) : (_s.screen == 'landscape' ? 'portrait' : 'landscape');
    _s.screen = next;
    car.changed();
    return _done(_l('screen in $next', 'tela na ${next == 'portrait' ? 'vertical' : 'horizontal'}'));
  },
  'set_seat_climate': (a) {
    final st = _str(a['seat'] ?? 'driver');
    final feature = _str(a['feature']), level = _str(a['level']);
    final map = feature == 'ventilation' ? _s.seatVentilation : _s.seatHeater;
    final enF = feature == 'ventilation' ? 'ventilation' : 'heater';
    if (map[st] == level) {
      final ptF0 = feature == 'ventilation' ? 'A ventilação' : 'O aquecimento';
      return _already(_l('seat unchanged', 'banco sem mudança'), level == 'off'
          ? _l('The $enF in ${_enSeat[st]} is already off.', '$ptF0 do banco do ${_ptSeat[st]} já está ${feature == 'ventilation' ? 'desligada' : 'desligado'}.')
          : _l('The $enF in ${_enSeat[st]} is already on $level.', '$ptF0 do banco do ${_ptSeat[st]} já está no ${_ptLevel[level] ?? level}.'));
    }
    map[st] = level;
    car.changed();
    final ptF = feature == 'ventilation' ? 'a ventilação' : 'o aquecimento';
    return _done(_l('${_words(st)} seat $enF $level', '${feature == 'ventilation' ? 'ventilação' : 'aquecimento'} do banco do ${_ptSeat[st]} ${_ptLevel[level] ?? level}'), {},
        level == 'off'
            ? _l('I turned off the $enF in ${_enSeat[st]}.', 'Desliguei $ptF do banco do ${_ptSeat[st]}.')
            : _l('I set the $enF in ${_enSeat[st]} to $level.', 'Coloquei $ptF do banco do ${_ptSeat[st]} no ${_ptLevel[level] ?? level}.'));
  },
  'set_seat_massage': (a) {
    _s.massageSeat = _str(a['seat'] ?? 'driver');
    _s.massageOn = a['on'] != false;
    if (a['mode'] != null) _s.massageMode = _num(a['mode'])?.toInt() ?? _s.massageMode;
    car.changed();
    return _done(a['on'] == false ? _l('seat massage off', 'massagem desligada') : _l('seat massage on${a['mode'] != null ? ', mode ${a['mode']}' : ''}', 'massagem ligada${a['mode'] != null ? ', modo ${a['mode']}' : ''}'));
  },
  'set_steering_wheel_heater': (a) {
    _s.wheelHeater = a['on'] != false;
    car.changed();
    return _done(_l('steering wheel heater ${a['on'] == false ? 'off' : 'on'}', 'volante aquecido ${a['on'] == false ? 'desligado' : 'ligado'}'));
  },
  'set_cabin_lights': (a) {
    final on = a['on'] != false;
    if (a['light'] == 'reading') {
      _s.readingLights = on;
      car.changed();
      return _done(_l('reading lights ${on ? 'on' : 'off'}', 'luz de leitura ${on ? 'acesa' : 'apagada'}'));
    }
    _s.ambientOn = on;
    if (a['color'] != null) _s.ambientColor = _str(a['color']);
    car.changed();
    final color = a['color'] != null && on ? ', ${a['color']}' : '';
    return _done(_l('ambient lighting ${on ? 'on' : 'off'}$color', 'luz ambiente ${on ? 'acesa' : 'apagada'}$color'));
  },
  'play_media': (a) {
    final q = _str(a['query']);
    _s.media = q;
    _s.radio = null;
    _s.muted = false;
    car.changed();
    return _done(_l('playing $q', 'tocando $q'), {}, _l('Playing $q.', 'Tocando $q.'));
  },
  'tune_radio': (a) {
    final band = _str(a['band']);
    // FM said as digits ("1067", "985") arrives without the decimal point: 875-1080 can only mean 87.5-108.0 MHz.
    final fm = _num(a['frequency']);
    final Object? freq = band != 'am' && fm != null && fm >= 875 && fm <= 1080 ? fm / 10 : a['frequency'];
    final f = freq != null ? (band == 'am' ? _range(freq, 520, 1710, 'AM') : _range(freq, 87.5, 108, 'FM')) : null;
    final station = '${band.toUpperCase()}${f != null ? ' ${_n(f)}' : ''}';
    _s.radio = station;
    _s.media = null;
    _s.source = 'radio';
    car.changed();
    return _done(_l('radio $station', 'rádio $station'), {}, _l('I tuned the radio to $station.', 'Sintonizei a rádio $station.'));
  },
  'set_audio_source': (a) {
    final src = _str(a['source']);
    _s.source = src;
    car.changed();
    final shown = src == 'usb' ? 'USB' : src;
    return _done(_l('audio source $src', 'fonte de áudio: $src'), {}, _l('I switched the audio to $shown.', 'Mudei o áudio para $shown.'));
  },
  'set_audio_focus': (a) {
    final seat = _str(a['seat']);
    _s.audioFocus = seat;
    car.changed();
    return _done(seat == 'all' ? _l('sound for everyone', 'som para todos') : _l('sound focused on ${_words(seat)}', 'som focado no ${_ptSeat[seat] ?? seat}'));
  },
  'set_volume': (a) {
    final action = _str(a['action']);
    final level = a['level'];
    var volume = _s.volume;
    if (action == 'set' || (level != null && action != 'mute' && action != 'unmute')) {
      volume = _range(level, 0, 30, _l('Volume', 'O volume')).toInt();
    } else if (action == 'up') {
      volume = (_s.volume + 3).clamp(0, 30);
    } else if (action == 'down') {
      volume = (_s.volume - 3).clamp(0, 30);
    }
    if (action == 'mute' && _s.muted) return _already(_l('already muted', 'já no mudo'), _l('The sound is already muted.', 'O som já está no mudo.'));
    if (action == 'unmute' && !_s.muted) {
      return _already(_l('sound already on', 'som já ligado'), _l('The sound is already on, volume ${_s.volume}.', 'O som já está ligado, volume ${_s.volume}.'));
    }
    if ((action == 'set' || (action != 'up' && action != 'down' && level != null)) && volume == _s.volume && !_s.muted) {
      return _already(_l('volume already $volume', 'volume já em $volume'), _l('The volume is already at $volume.', 'O volume já está em $volume.'));
    }
    final muted = action == 'mute' ? true : (action == 'unmute' || action == 'up' || action == 'set') ? false : _s.muted;
    _s.volume = volume;
    _s.muted = muted;
    car.changed();
    final say = action == 'mute'
        ? _l('I muted the sound.', 'Deixei o som no mudo.')
        : action == 'unmute'
            ? _l('The sound is back, volume $volume.', 'O som voltou, volume $volume.')
            : action == 'up'
                ? _l('I turned the volume up to $volume.', 'Aumentei o volume para $volume.')
                : action == 'down'
                    ? _l('I turned the volume down to $volume.', 'Abaixei o volume para $volume.')
                    : _l('I set the volume to $volume.', 'Coloquei o volume em $volume.');
    return _done(muted ? _l('muted', 'som mudo') : 'volume $volume', {'volume': volume, 'muted': muted}, say);
  },
  'call_contact': (a) {
    _s.call = _str(a['name']);
    car.changed();
    return _done(_l('calling ${a['name']}${a['number_type'] != null ? ' (${a['number_type']})' : ''}', 'ligando para ${a['name']}'));
  },
  'manage_call': (a) {
    final action = _str(a['action']);
    _s.call = action == 'answer' ? _l('Incoming caller', 'Chamada recebida') : null;
    car.changed();
    final en = {'answer': 'call answered', 'decline': 'call declined', 'hang_up': 'call ended'}[action] ?? action;
    final pt = {'answer': 'chamada atendida', 'decline': 'chamada recusada', 'hang_up': 'chamada encerrada'}[action] ?? action;
    return _done(_l(en, pt));
  },
  'send_message': (a) => _done(_l('message sent to ${a['contact']}: "${a['message']}"', 'mensagem enviada para ${a['contact']}: "${a['message']}"')),
  'read_messages': (a) => _Outcome(_l('read 2 unread messages', '2 mensagens lidas'), {
        'messages': [
          {'from': 'Daniel', 'text': 'Are we still on for dinner?'},
          {'from': 'Mom', 'text': 'Call me when you can.'},
        ],
      }),
  'get_vehicle_status': (a) {
    final item = _str(a['item']);
    final fuel = _s.fuelPercent;
    final value = item == 'fuel'
        ? {'percent': fuel, 'km': (fuel * 5).round()}
        : const {
              'range': {'km': 312},
              'battery': {'percent': 76},
              'energy_consumption': {'km_per_liter': 12.4},
              'tire_pressure': {'front_left_psi': 32, 'front_right_psi': 32, 'rear_left_psi': 31, 'rear_right_psi': 32},
              'warnings': {'warnings': <String>[]},
            }[item] ??
            const <String, Object>{};
    final shown = {
          'range': _l('312 km of range', 'autonomia de 312 km'),
          'fuel': _l('fuel $fuel%', 'combustível em $fuel%'),
          'battery': _l('battery 76%', 'bateria em 76%'),
          'energy_consumption': _l('12.4 km/l average', 'média de 12,4 km/l'),
          'tire_pressure': _l('tires 31–32 psi', 'pneus entre 31 e 32 psi'),
          'warnings': _l('no warnings', 'nenhum alerta'),
        }[item] ??
        item;
    final say = {
      'range': _l('You have about 312 km of range left.', 'Você tem cerca de 312 km de autonomia.'),
      'fuel': _l('The tank is at $fuel%, about ${(fuel * 5).round()} km.', 'O tanque está em $fuel%, cerca de ${(fuel * 5).round()} km.'),
      'battery': _l('The battery is at 76%.', 'A bateria está em 76%.'),
      'energy_consumption': _l('Average consumption is 12.4 km per liter.', 'O consumo médio é de 12,4 km por litro.'),
      'tire_pressure': _l('The tires are fine: 31 to 32 psi.', 'Os pneus estão bem: entre 31 e 32 psi.'),
      'warnings': _l('No warning lights are on.', 'Nenhuma luz de alerta acesa.'),
    }[item];
    final result = {'item': item, ...value};
    return say != null ? _answer(shown, result, say) : _Outcome(shown, result);
  },
  'activate_scenario': (a) {
    final mode = _str(a['mode']);
    const closed = {'front_left': 'close', 'front_right': 'close', 'rear_left': 'close', 'rear_right': 'close'};
    _s.scenario = mode == 'smoking' || mode == 'rest' || mode == 'rain' ? mode : 'car_wash';
    switch (mode) {
      case 'smoking':
        _s.windows[_s.steering == 'right' ? 'front_right' : 'front_left'] = 'crack';
        _s.airflow = 'face';
      case 'rest':
        _s.sunshade = 'close';
        _s.ambientOn = true;
        _s.ambientColor = 'warm white';
        _s.temperature['driver'] = 22;
        _s.temperature['passenger'] = 22;
      default:
        _s.windows = {...closed};
        _s.sunroof = 'close';
    }
    car.changed();
    final ptMode = {'smoking': 'fumante', 'rest': 'descanso', 'rain': 'chuva', 'car_wash': 'lava-rápido'}[mode] ?? mode;
    return _done(_l('${_words(mode)} mode on', 'modo $ptMode ativado'));
  },
};

/// Runs one tool call (the handler the agent calls); returns a ToolReply when the app says the sentence itself.
Object? runCarTool(String name, Map<String, Object?> args) {
  final run = _handlers[name];
  try {
    if (run == null) throw _Refused(_l("Sorry, this car doesn't have that function.", 'Desculpe, este carro não tem essa função.'));
    if (_s.driving && (_notWhileDriving[name]?.call(args) ?? false)) {
      throw _Refused(_l("I can't do that while the car is moving.", 'Não posso fazer isso com o carro em movimento.'));
    }
    final out = run(args);
    car.record(name, args, out.summary);
    // ignore: avoid_print
    print('[Car] $name ${jsonEncode(args)} -> ${out.summary}');
    if (out.say != null) return ToolReply({'ok': true, ...out.result}, out.say!);
    final status = out.result['status'];
    if (status is String && status.startsWith('Done: ')) return ToolReply({'ok': true, ...out.result}, '${cap(out.summary)}.');
    return {'ok': true, ...out.result};
  } on _Refused catch (r) {
    car.record(name, args, r.message, ok: false, blocked: r.message);
    // ignore: avoid_print
    print('[Car] REFUSED $name ${jsonEncode(args)}: ${r.message}');
    // Said by the app, turn ends: the model gets no chance to "fix" it with another action. Nothing changed in the car.
    final text = cap(r.message);
    return ToolReply({'ok': false, 'refused': r.message},
        RegExp(r'[.?!]$').hasMatch(text) ? text : _l("I didn't do that: ${r.message}.", 'Não fiz isso: ${r.message}.'));
  }
}

/// Which tool descriptions the model sees ('v1', 'h2', 'h3' or 'h3d'): a model must get the wording it was trained / benchmarked
/// with. h3d = h3 with corrected descriptions (as the RN example's carToolDefinitions.h3d.json).
const _wordingFiles = {
  'v1': 'assets/car/carToolDefinitions.json',
  'h2': 'assets/car/carToolDefinitions.h2.json',
  'h3': 'assets/car/carToolDefinitions.h3.json',
  'h3d': 'assets/car/carToolDefinitions.h3d.json',
};
final Map<String, Map<String, Object?>> _loaded = {};

/// Loads the definition files (main(), or the tests with [readFile]).
Future<void> loadCarToolDefinitions({Future<String> Function(String path)? readFile}) async {
  final read = readFile ?? rootBundle.loadString;
  for (final e in _wordingFiles.entries) {
    _loaded[e.key] = jsonDecode(await read(e.value)) as Map<String, Object?>;
  }
}

/// The car tools for DavoiceAgent.setTools: the VW Brazil demo's profile (each wording's own) or the whole catalog.
List<ToolDefinition> carTools({String profile = 'vw_demo', String wording = 'v1'}) {
  final file = _loaded[wording] ?? _loaded['v1']!;
  final tools = (file['tools'] as List).cast<Map>();
  final keep = profile == 'all' ? null : ((file['profiles'] as Map)['vw_demo'] as List).cast<String>().toSet();
  return [
    for (final t in tools)
      if (keep == null || keep.contains(t['name']))
        ToolDefinition(
          name: t['name'] as String,
          description: t['description'] as String,
          inputSchema: Map<String, Object?>.from(t['inputSchema'] as Map),
          execution: t['execution'] == null ? null : Map<String, Object?>.from(t['execution'] as Map),
          handler: (args, context) => runCarTool(t['name'] as String, args),
        ),
  ];
}

/// Every car tool name (any wording): these run on the phone (no "online" filler).
Set<String> get carToolNames => {for (final f in _loaded.values) for (final t in (f['tools'] as List).cast<Map>()) t['name'] as String};
