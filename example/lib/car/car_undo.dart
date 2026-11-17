// Undo for the simulated car (core 2026-11-14, configure "undo"; port of the RN example's src/car/undo.ts): every state-changing car
// call returns, next to its result, how to put the car back exactly as it was before the call: {"undo": {"calls": [...],
// "previous": {...}}}, or {"undo": false} when that can't be done (a new destination, a radio station). The agent keeps it (never
// shows it to the model) and, on "desfaz" / "undo that", runs those calls through these same tools, so every check still applies.
// The calls restore the recorded state; they are not "the opposite action" (volume 12 -> 15 goes back to 12, not down by 3).

import 'dart:convert';

import 'car_state.dart';

const _pos = ['front_left', 'front_right', 'rear_left', 'rear_right'];
const _seats = ['driver', 'passenger', 'rear_left', 'rear_right'];

/// A deep copy of the parts of the car an action can change (CarState is changed in place).
Map<String, Object?> carSnapshot(CarState s) => jsonDecode(jsonEncode({
      'temperature': {...s.temperature, 'unit': s.unit},
      'fan': s.fan,
      'airflow': s.airflow,
      'defrost': s.defrost,
      'windows': s.windows,
      'doors': s.doors,
      'doorLocks': s.doorLocks,
      'sunroof': s.sunroof,
      'sunshade': s.sunshade,
      'seatHeater': s.seatHeater,
      'seatVentilation': s.seatVentilation,
      'volume': s.volume,
      'muted': s.muted,
      'wheelHeater': s.wheelHeater,
      // no way back for these (no "cancel the route" / "previous station" tool in the demo)
      'irreversible': {
        'destination': s.destination, 'avoid': s.avoid, 'radio': s.radio, 'media': s.media, 'source': s.source,
        'audioFocus': s.audioFocus, 'call': s.call, 'scenario': s.scenario, 'trunk': s.trunk, 'frunk': s.frunk,
        'chargePort': s.chargePort, 'screen': s.screen, 'massage': [s.massageSeat, s.massageOn, s.massageMode],
        'ambient': [s.ambientOn, s.ambientColor], 'readingLights': s.readingLights,
      },
    })) as Map<String, Object?>;

/// What changed between two snapshots, as the calls that restore `before`: {calls, previous}; false = something changed that can't
/// be restored; null = nothing changed.
Object? carRestoreCalls(Map<String, Object?> before, Map<String, Object?> after) {
  bool changed(String k) => jsonEncode(before[k]) != jsonEncode(after[k]);
  if (changed('irreversible')) return false;
  final calls = <Map<String, Object?>>[];
  final previous = <String, Object?>{};
  Map<String, Object?> m(String k, Map<String, Object?> s) => (s[k] as Map).cast<String, Object?>();
  void perPosition(String k, Map<String, Object?> Function(String target, Object? value) call) {
    final b = m(k, before), a = m(k, after);
    final changedPos = _pos.where((p) => jsonEncode(b[p]) != jsonEncode(a[p])).toList();
    if (changedPos.isEmpty) return;
    if (changedPos.length == 4 && _pos.every((p) => b[p] == b['front_left'])) {
      calls.add(call('all', b['front_left']));
    } else {
      for (final p in changedPos) {
        calls.add(call(p, b[p]));
      }
    }
  }

  if (changed('temperature')) {
    final t = m('temperature', before), ta = m('temperature', after);
    previous['temperature'] = t;
    if (t['driver'] == t['passenger'] && t['passenger'] == t['rear']) {
      calls.add({'name': 'set_temperature', 'arguments': {'temperature': t['driver'], 'unit': t['unit']}});
    } else {
      if (t['driver'] != ta['driver'] || t['passenger'] != ta['passenger'] || t['unit'] != ta['unit']) {
        calls.add({'name': 'set_dual_zone_temperature', 'arguments': {'driver': t['driver'], 'passenger': t['passenger'], 'unit': t['unit']}});
      }
      if (t['rear'] != ta['rear']) calls.add({'name': 'set_temperature', 'arguments': {'temperature': t['rear'], 'zone': 'rear', 'unit': t['unit']}});
    }
  }
  if (changed('fan')) {
    previous['fan'] = before['fan'];
    calls.add({'name': 'set_fan_speed', 'arguments': {'level': before['fan']}});
  }
  if (changed('airflow')) {
    previous['airflow'] = before['airflow'];
    calls.add({'name': 'set_airflow', 'arguments': {'mode': before['airflow']}});
  }
  if (changed('defrost')) {
    previous['defrost'] = before['defrost'];
    for (final target in ['windshield', 'rear']) {
      if (m('defrost', before)[target] != m('defrost', after)[target]) {
        calls.add({'name': 'set_defrost', 'arguments': {'target': target, 'on': m('defrost', before)[target]}});
      }
    }
  }
  if (changed('windows')) {
    previous['windows'] = before['windows'];
    perPosition('windows', (w, v) => {'name': 'set_window', 'arguments': {'window': w, 'position': v}});
  }
  if (changed('doors')) {
    previous['doors'] = before['doors'];
    perPosition('doors', (d, v) => {'name': v == 'open' ? 'open_door' : 'close_doors', 'arguments': {'door': d}});
  }
  if (changed('doorLocks')) {
    previous['doorLocks'] = before['doorLocks'];
    perPosition('doorLocks', (d, v) => {'name': v == true ? 'lock_car' : 'unlock_car', 'arguments': {'door': d}});
  }
  if (changed('sunroof')) {
    previous['sunroof'] = before['sunroof'];
    calls.add({'name': 'set_sunroof', 'arguments': {'action': before['sunroof']}});
  }
  if (changed('sunshade')) {
    previous['sunshade'] = before['sunshade'];
    calls.add({'name': 'set_sunshade', 'arguments': {'action': before['sunshade']}});
  }
  for (final k in ['seatHeater', 'seatVentilation']) {
    if (!changed(k)) continue;
    previous[k] = before[k];
    for (final seat in _seats) {
      if (m(k, before)[seat] != m(k, after)[seat]) {
        calls.add({'name': 'set_seat_climate', 'arguments': {'seat': seat, 'feature': k == 'seatHeater' ? 'heater' : 'ventilation', 'level': m(k, before)[seat]}});
      }
    }
  }
  if (changed('volume') || changed('muted')) {
    previous['volume'] = before['volume'];
    previous['muted'] = before['muted'];
    if (before['volume'] != after['volume']) calls.add({'name': 'set_volume', 'arguments': {'action': 'set', 'level': before['volume']}});
    if (before['muted'] == true && (after['muted'] != true || before['volume'] != after['volume'])) {
      calls.add({'name': 'set_volume', 'arguments': {'action': 'mute'}});
    } else if (before['muted'] != true && after['muted'] == true) {
      calls.add({'name': 'set_volume', 'arguments': {'action': 'unmute'}});
    }
  }
  if (changed('wheelHeater')) {
    previous['wheelHeater'] = before['wheelHeater'];
    calls.add({'name': 'set_steering_wheel_heater', 'arguments': {'on': before['wheelHeater']}});
  }
  if (calls.isEmpty) return null;
  return {'calls': calls, 'previous': previous};
}
