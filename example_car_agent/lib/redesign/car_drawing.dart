// The live top-down car (React Native: src/redesign/CarDrawing.tsx), in the design's 260 × 460 viewBox, front at the top: the left of the
// drawing is the car's left side. Doors, windows, sunroof, trunk / frunk, charge port, lock, seat heating (amber) / ventilation (blue),
// wheel heater, defrosters, ambient light, the fan's air, audio focus waves; a refused action's part blinks amber.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../car/car_state.dart';
import '../car/positions.dart';
import 'theme.dart';

const kCarVbW = 260.0;
const kCarVbH = 460.0;
const kCarAspect = 254 / 450;

const _windowLevel = {'open': 1.0, 'half': 0.5, 'crack': 0.2, 'close': 0.0};
const _levelAlpha = {'low': 0.35, 'medium': 0.5, 'high': 0.65};
const _seatRect = {
  'front_left': (74.0, 194.0, 52.0),
  'front_right': (142.0, 194.0, 52.0),
  'rear_left': (74.0, 262.0, 50.0),
  'rear_right': (142.0, 262.0, 50.0),
};
const _windowBar = {
  'front_left': (55.0, 170.0, 70.0),
  'front_right': (200.0, 170.0, 70.0),
  'rear_left': (55.0, 250.0, 66.0),
  'rear_right': (200.0, 250.0, 66.0),
};
// x, y, height, rotation (degrees) around (pivotX, pivotY)
const _doorGeom = {
  'front_left': (44.0, 168.0, 72.0, 38.0, 51.0, 168.0),
  'front_right': (209.0, 168.0, 72.0, -38.0, 209.0, 168.0),
  'rear_left': (44.0, 248.0, 70.0, 38.0, 51.0, 248.0),
  'rear_right': (209.0, 248.0, 70.0, -38.0, 209.0, 248.0),
};

final _ambient = <(RegExp, Color)>[
  (RegExp('blue|azul', caseSensitive: false), const Color(0xFF60A5FA)),
  (RegExp('red|vermelh', caseSensitive: false), const Color(0xFFF87171)),
  (
    RegExp('purple|violet|roxo|lilás|lilas', caseSensitive: false),
    const Color(0xFFC084FC),
  ),
  (RegExp('green|verde', caseSensitive: false), const Color(0xFF34D399)),
  (RegExp('orange|laranja', caseSensitive: false), const Color(0xFFFB923C)),
  (RegExp('pink|rosa', caseSensitive: false), const Color(0xFFF472B6)),
  (RegExp('yellow|amarel', caseSensitive: false), const Color(0xFFFACC15)),
  (RegExp('warm|quente', caseSensitive: false), const Color(0xFFFDE68A)),
  (RegExp('white|branc', caseSensitive: false), const Color(0xFFE5E7EB)),
];
Color ambientColor(String color) => _ambient
    .firstWhere(
      (e) => e.$1.hasMatch(color),
      orElse: () => (RegExp(''), const Color(0xFF2DD4BF)),
    )
    .$2;

String _seatPos(String seat, String steering) {
  if (seat == 'driver') {
    return steering == 'right' ? 'front_right' : 'front_left';
  }
  if (seat == 'passenger') {
    return steering == 'right' ? 'front_left' : 'front_right';
  }
  return seat;
}

/// The part of the car a refused tool call was about (blinks amber): 'trunk' | 'frunk' | 'sunroof' | 'chargePort' | 'lock' |
/// ('doors', positions) | ('windows', positions).
Object? _blockedPart(CarAction? action, String steering) {
  if (action == null || action.ok) return null;
  final t = action.tool;
  final a = action.args;
  if (t.contains('trunk')) {
    return a['target'] == 'frunk' || a['which'] == 'frunk' ? 'frunk' : 'trunk';
  }
  if (t.contains('sunroof')) return 'sunroof';
  if (t.contains('charge')) return 'chargePort';
  if (t.contains('lock')) return 'lock';
  final where =
      resolvePositions(
        a['position'] ?? a['target'] ?? a['door'] ?? a['window'],
        steering,
      ) ??
      const <String>[];
  if (t.contains('door')) return ('doors', where);
  if (t.contains('window')) return ('windows', where);
  return null;
}

class CarDrawing extends StatefulWidget {
  const CarDrawing({
    super.key,
    required this.state,
    required this.latest,
    required this.width,
  });
  final CarState state;
  final CarAction? latest;
  final double width;
  @override
  State<CarDrawing> createState() => _CarDrawingState();
}

class _CarDrawingState extends State<CarDrawing> with TickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  late final AnimationController _waves = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();
  int? _blinkId;

  @override
  void didUpdateWidget(CarDrawing old) {
    super.didUpdateWidget(old);
    final l = widget.latest;
    final id = l != null && !l.ok ? l.id : null;
    if (id != null && id != _blinkId) {
      _blinkId = id;
      _blink.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    _waves.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final k = widget.width / kCarVbW;
    final steering = s.steering;
    final blocked = _blockedPart(widget.latest, steering);
    final focusSeat = s.call != null
        ? _seatPos('driver', steering)
        : const [
            'driver',
            'passenger',
            'rear_left',
            'rear_right',
          ].contains(s.audioFocus)
        ? _seatPos(s.audioFocus, steering)
        : null;
    final label =
        'Car seen from above. ${widget.latest != null ? 'Last action: ${widget.latest!.summary}' : 'No action yet'}.';
    return Semantics(
      image: true,
      label: label,
      child: SizedBox(
        width: widget.width,
        height: kCarVbH * k,
        child: AnimatedBuilder(
          animation: Listenable.merge([_blink, _waves]),
          builder: (context, _) {
            // three amber pulses after a refused action: 1 -> 0.35 -> 1, three times
            final t = _blink.value;
            final blinkOpacity = !_blink.isAnimating && t == 0
                ? 0.0
                : (t >= 1
                      ? 1.0
                      : 0.35 +
                            0.65 * (0.5 + 0.5 * math.cos(t * 3 * 2 * math.pi)));
            return CustomPaint(
              painter: _CarPainter(
                s: s,
                blocked: blocked,
                blockedOpacity: blocked == null ? 0 : blinkOpacity,
                focusSeat: focusSeat,
                wave: _waves.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CarPainter extends CustomPainter {
  _CarPainter({
    required this.s,
    required this.blocked,
    required this.blockedOpacity,
    required this.focusSeat,
    required this.wave,
  });
  final CarState s;
  final Object? blocked;
  final double blockedOpacity;
  final String? focusSeat;
  final double wave;

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, double w, {bool round = false}) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = round ? StrokeCap.round : StrokeCap.butt;

  RRect _rr(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  void _dashedRRect(
    Canvas canvas,
    RRect rr,
    Paint paint,
    double dash,
    double gap,
  ) {
    final path = Path()..addRRect(rr);
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash + gap) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
      }
    }
  }

  void _door(Canvas canvas, String pos, Paint fill, Paint stroke) {
    final d = _doorGeom[pos]!;
    canvas.save();
    canvas.translate(d.$5, d.$6);
    canvas.rotate(d.$4 * math.pi / 180);
    canvas.translate(-d.$5, -d.$6);
    final rr = _rr(d.$1, d.$2, 7, d.$3, 3);
    canvas.drawRRect(rr, fill);
    canvas.drawRRect(rr, stroke);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / kCarVbW);
    final steering = s.steering;
    // wheels and mirrors
    for (final (x, y) in const [
      (38.0, 76.0),
      (210.0, 76.0),
      (38.0, 346.0),
      (210.0, 346.0),
    ]) {
      canvas.drawRRect(_rr(x, y, 12, 58, 4), _fill(const Color(0xFF050706)));
    }
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(44, 150), width: 18, height: 10),
      _fill(const Color(0xFF2C3331)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(216, 150), width: 18, height: 10),
      _fill(const Color(0xFF2C3331)),
    );
    // body
    final body = Path()
      ..moveTo(88, 14)
      ..quadraticBezierTo(130, 2, 172, 14)
      ..quadraticBezierTo(206, 24, 208, 70)
      ..lineTo(211, 384)
      ..quadraticBezierTo(211, 444, 168, 452)
      ..lineTo(92, 452)
      ..quadraticBezierTo(49, 444, 49, 384)
      ..lineTo(52, 70)
      ..quadraticBezierTo(54, 24, 88, 14)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1B2321), Color(0xFF3B4542), Color(0xFF1B2321)],
        ).createShader(const Rect.fromLTWH(49, 0, 162, 460)),
    );
    canvas.drawPath(body, _stroke(const Color(0xFF6B7470), 1.5));
    // headlights / tail lights
    canvas.drawPath(
      Path()
        ..moveTo(64, 36)
        ..quadraticBezierTo(78, 22, 102, 18),
      _stroke(C.mint, 4, round: true),
    );
    canvas.drawPath(
      Path()
        ..moveTo(196, 36)
        ..quadraticBezierTo(182, 22, 158, 18),
      _stroke(C.mint, 4, round: true),
    );
    final tail = _stroke(const Color(0xCCF87171), 3, round: true);
    canvas.drawPath(
      Path()
        ..moveTo(62, 438)
        ..quadraticBezierTo(84, 448, 104, 449),
      tail,
    );
    canvas.drawPath(
      Path()
        ..moveTo(198, 438)
        ..quadraticBezierTo(176, 448, 156, 449),
      tail,
    );
    // frunk
    final frunk = Path()
      ..moveTo(70, 40)
      ..quadraticBezierTo(130, 22, 190, 40)
      ..lineTo(192, 116)
      ..lineTo(68, 116)
      ..close();
    if (s.frunk == 'open') {
      canvas.drawPath(frunk, _fill(const Color(0x3834D399)));
    }
    canvas.drawPath(
      frunk,
      _stroke(s.frunk == 'open' ? C.mint : C.titanium, 1.6),
    );
    // windshield
    final glass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2A4A40), Color(0xFF0F1C18)],
      ).createShader(const Rect.fromLTWH(70, 120, 120, 40));
    final ws = Path()
      ..moveTo(70, 120)
      ..lineTo(190, 120)
      ..lineTo(180, 160)
      ..lineTo(80, 160)
      ..close();
    canvas.drawPath(ws, glass);
    canvas.drawPath(ws, _stroke(C.titanium, 1));
    if (s.defrost['windshield'] == true) {
      final p = _stroke(const Color(0xFFFB923C), 1.6, round: true);
      for (final (y, cy) in const [
        (132.0, 126.0),
        (142.0, 136.0),
        (152.0, 146.0),
      ]) {
        canvas.drawPath(
          Path()
            ..moveTo(84, y)
            ..quadraticBezierTo(130, cy, 176, y),
          p,
        );
      }
    }
    // cabin (ambient light on its rim)
    final ambient = s.ambientOn ? ambientColor(s.ambientColor) : null;
    canvas.drawRRect(
      _rr(64, 162, 132, 162, 14),
      _fill(const Color(0xFF0A100E)),
    );
    canvas.drawRRect(
      _rr(64, 162, 132, 162, 14),
      _stroke(ambient ?? const Color(0xFF2C3331), ambient != null ? 3 : 1),
    );
    if (s.airflow == 'face' && s.fan >= 5) {
      final air = _stroke(const Color(0xFF7DD3FC), 1.6, round: true);
      for (final x in const [96.0, 164.0]) {
        for (double y = 166; y < 188; y += 7) {
          canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 3, 188)), air);
        }
      }
    }
    final wheelX = steering == 'right' ? 164.0 : 96.0;
    canvas.drawCircle(
      Offset(wheelX, 178),
      12,
      _stroke(s.wheelHeater ? C.warning : const Color(0xFF59625F), 4),
    );
    // seats
    for (final entry in _seatRect.entries) {
      final seat = const [
        'driver',
        'passenger',
        'rear_left',
        'rear_right',
      ].firstWhere((x) => _seatPos(x, steering) == entry.key);
      final heat = s.seatHeater[seat];
      final vent = s.seatVentilation[seat];
      final color = heat != null && heat != 'off'
          ? C.warning.withValues(alpha: _levelAlpha[heat] ?? 0.6)
          : vent != null && vent != 'off'
          ? C.vent.withValues(alpha: _levelAlpha[vent] ?? 0.5)
          : const Color(0xFF26322E);
      final rr = _rr(entry.value.$1, entry.value.$2, 44, entry.value.$3, 10);
      canvas.drawRRect(rr, _fill(color));
      canvas.drawRRect(rr, _stroke(C.olive, 1));
    }
    // sunroof
    final roof = _rr(114, 198, 32, 104, 8);
    canvas.drawRRect(
      roof,
      _fill(
        s.sunroof == 'open' ? const Color(0x1F34D399) : const Color(0xBF1E3C32),
      ),
    );
    final roofStroke = _stroke(s.sunroof == 'close' ? C.titanium : C.mint, 1.5);
    if (s.sunroof == 'tilt') {
      _dashedRRect(canvas, roof, roofStroke, 4, 3);
    } else {
      canvas.drawRRect(roof, roofStroke);
    }
    // windows: a bar filled by how far each one is open
    for (final entry in _windowBar.entries) {
      final w = entry.value;
      canvas.drawRRect(
        _rr(w.$1, w.$2, 5, w.$3, 2.5),
        _fill(const Color(0xFF2A3632)),
      );
      final level = _windowLevel[s.windows[entry.key]] ?? 0;
      if (level > 0) {
        canvas.drawRRect(
          _rr(w.$1, w.$2, 5, (w.$3 * level).roundToDouble(), 2.5),
          _fill(C.mint),
        );
      }
    }
    // open doors
    for (final pos in _doorGeom.keys) {
      if (s.doors[pos] == 'open') {
        _door(
          canvas,
          pos,
          _fill(const Color(0x4034D399)),
          _stroke(C.mint, 1.5),
        );
      }
    }
    // rear window, rear defroster, trunk, charge port, lock
    final rear = Path()
      ..moveTo(80, 328)
      ..lineTo(180, 328)
      ..lineTo(188, 352)
      ..lineTo(72, 352)
      ..close();
    canvas.drawPath(rear, glass);
    canvas.drawPath(rear, _stroke(C.titanium, 1));
    if (s.defrost['rear'] == true) {
      final p = _stroke(const Color(0xFFFB923C), 1.4);
      canvas.drawLine(const Offset(84, 336), const Offset(176, 336), p);
      canvas.drawLine(const Offset(80, 344), const Offset(180, 344), p);
    }
    final trunk = Path()
      ..moveTo(68, 356)
      ..lineTo(192, 356)
      ..lineTo(196, 420)
      ..quadraticBezierTo(130, 440, 64, 420)
      ..close();
    if (s.trunk == 'open') {
      canvas.drawPath(trunk, _fill(const Color(0x3834D399)));
    }
    canvas.drawPath(
      trunk,
      _stroke(s.trunk == 'open' ? C.mint : C.titanium, 1.8),
    );
    canvas.drawRRect(
      _rr(47, 370, 7, 16, 2),
      _fill(s.chargePort == 'open' ? C.mint : const Color(0xFF2C3331)),
    );
    final locked = s.locked || s.doorLocks.values.any((v) => v);
    if (locked) {
      canvas.drawRRect(_rr(120, 384, 20, 16, 3), _fill(C.mint));
      canvas.drawPath(
        Path()
          ..moveTo(124, 384)
          ..lineTo(124, 379)
          ..arcToPoint(const Offset(136, 379), radius: const Radius.circular(6))
          ..lineTo(136, 384),
        _stroke(C.mint, 2.5),
      );
    }
    // a refused action's part, blinking amber
    if (blocked != null && blockedOpacity > 0) {
      final bf = _fill(C.warning.withValues(alpha: 0.3 * blockedOpacity));
      final bs = _stroke(C.warning.withValues(alpha: blockedOpacity), 2);
      void both(Path p) {
        canvas.drawPath(p, bf);
        canvas.drawPath(p, bs);
      }

      switch (blocked) {
        case 'trunk':
          both(trunk);
        case 'frunk':
          both(frunk);
        case 'sunroof':
          both(Path()..addRRect(roof));
        case 'chargePort':
          both(Path()..addRRect(_rr(45, 368, 11, 20, 3)));
        case 'lock':
          both(Path()..addRRect(_rr(116, 372, 28, 32, 5)));
        case ('doors', final List<String> where):
          for (final pos in where) {
            if (_doorGeom.containsKey(pos)) _door(canvas, pos, bf, bs);
          }
        case ('windows', final List<String> where):
          for (final pos in where) {
            final w = _windowBar[pos];
            if (w != null) {
              both(Path()..addRRect(_rr(w.$1 - 1, w.$2, 7, w.$3, 3)));
            }
          }
      }
    }
    // audio focus / a call: two waves around the seat
    if (focusSeat != null && _seatRect.containsKey(focusSeat)) {
      final r = _seatRect[focusSeat]!;
      final c = Offset(r.$1 + 22, r.$2 + 26);
      for (final phase in [wave, (wave + 0.5) % 1]) {
        final v = Curves.easeOut.transform(phase);
        canvas.drawCircle(
          c,
          34 * (0.8 + 0.7 * v),
          _stroke(C.mint.withValues(alpha: 0.9 * (1 - v)), 1.5),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CarPainter old) => true;
}
