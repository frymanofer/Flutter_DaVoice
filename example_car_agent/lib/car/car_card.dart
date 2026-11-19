import 'dart:convert';

import 'package:flutter/material.dart';

import '../flow/app_language.dart';
import 'car_state.dart';

// "Car" card for the car demo (port of the RN example's src/car/CarCard.tsx): the latest action the AI took in the simulated car,
// with the exact tool call, the two before it, and a one-line car state. Parked / Driving switch and Reset.

String _callText(CarAction a) {
  final args = a.args.entries.map((e) => '${e.key}: ${e.value is String ? e.value : jsonEncode(e.value)}').join(', ');
  return '${a.tool}($args)';
}

String _num(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

String _windowsText(CarState s) {
  final open = s.windows.entries.where((e) => e.value != 'close').toList();
  if (open.isEmpty) return 'closed';
  if (open.length == 4 && open.every((e) => e.value == open[0].value)) return 'all ${open[0].value}';
  return open.map((e) => '${e.key.replaceAll('_', ' ')} ${e.value}').join(', ');
}

class CarCard extends StatelessWidget {
  const CarCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: car,
      builder: (context, _) {
        final s = car.state;
        final pt = isPortuguese;
        final latest = car.actions.isEmpty ? null : car.actions.last;
        final earlier = car.actions.length < 2 ? <CarAction>[] : car.actions.sublist(0, car.actions.length - 1).reversed.take(2).toList();
        final unit = s.unit == 'fahrenheit' ? '°F' : '°C';
        final openDoors = s.doors.entries.where((e) => e.value == 'open').map((e) => e.key.replaceAll('_', ' ')).toList();
        final lockedDoors = s.doorLocks.entries.where((e) => e.value).map((e) => e.key.replaceAll('_', ' ')).toList();
        final chips = <String?>[
          // two sides: one value when both sides match, else driver | passenger
          s.temperature['driver'] == s.temperature['passenger']
              ? '${_num(s.temperature['driver']!)}$unit'
              : '${pt ? 'mot.' : 'driver'} ${_num(s.temperature['driver']!)}$unit | ${pt ? 'pass.' : 'passenger'} ${_num(s.temperature['passenger']!)}$unit',
          '${pt ? 'vent.' : 'fan'} ${s.fan}',
          '${pt ? 'vidros' : 'windows'} ${_windowsText(s)}',
          openDoors.isNotEmpty ? '${pt ? 'portas' : 'doors'} ${openDoors.join(', ')} ${pt ? 'abertas' : 'open'}' : null,
          s.locked ? (pt ? '🔒 trancado' : '🔒 locked') : lockedDoors.isNotEmpty ? '🔒 ${lockedDoors.join(', ')}' : (pt ? 'destrancado' : 'unlocked'),
          s.sunroof != 'close' ? '${pt ? 'teto' : 'sunroof'} ${s.sunroof}' : null,
          s.seatHeater['driver'] != 'off' ? '${pt ? 'banco' : 'seat heat'} ${s.seatHeater['driver']}' : null,
          s.destination != null ? '→ ${s.destination}' : null,
          s.radio ?? (s.media != null ? '♪ ${s.media}' : null),
          s.muted ? (pt ? 'mudo' : 'muted') : 'vol ${s.volume}',
          s.call != null ? '${pt ? 'ligação' : 'call'}: ${s.call}' : null,
          s.scenario != null ? '${s.scenario!.replaceAll('_', ' ')} mode' : null,
        ].whereType<String>().toList();
        Widget button(String text, VoidCallback onTap, {bool on = false}) => GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: on ? const Color(0x73ff9f0a) : const Color(0x33ffffff),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: on ? const Color(0xccff9f0a) : const Color(0x4dffffff)),
                ),
                child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            );
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0x240a84ff),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x730a84ff)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text((pt ? 'Carro' : 'Car').toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Color(0xa6ffffff))),
                ),
                button(s.driving ? (pt ? 'Em movimento' : 'Driving') : (pt ? 'Parado' : 'Parked'), () => car.setDriving(!s.driving), on: s.driving),
                button(pt ? 'Reiniciar' : 'Reset', car.reset),
              ]),
              if (latest != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${latest.ok ? '✓ ' : (pt ? '⛔ Bloqueado: ' : '⛔ Blocked: ')}${latest.summary.isEmpty ? '' : latest.summary[0].toUpperCase() + latest.summary.substring(1)}',
                  maxLines: 2,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: latest.ok ? Colors.white : const Color(0xffff9f9f)),
                ),
                const SizedBox(height: 3),
                Text(_callText(latest), maxLines: 2, style: const TextStyle(fontSize: 12, color: Color(0xccffffff), fontFamily: 'Courier')),
                for (final a in earlier)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${a.summary}  ·  ${a.tool}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Color(0x99ffffff))),
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    pt
                        ? 'Tente: "coloca o ar em 22 graus", "abre o vidro do motorista", "me leva pra casa", "toca a 98,5", "quanto tem de combustível?"'
                        : 'Try: "set the AC to 22", "open my window", "take me home", "tune to 98.5", "how much fuel do I have?"',
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xb3ffffff)),
                  ),
                ),
              const SizedBox(height: 8),
              Text(chips.join('  ·  '), maxLines: 2, style: const TextStyle(fontSize: 12, color: Color(0xb3ffffff))),
            ],
          ),
        );
      },
    );
  }
}
