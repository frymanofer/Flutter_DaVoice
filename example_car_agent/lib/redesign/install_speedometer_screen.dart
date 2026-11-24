// Screen 2 · Install, a speedometer (React Native: src/redesign/InstallSpeedometerScreen.tsx). Dial 0 -> 100 over a 270° sweep from 135°;
// needle angle = 135 + 2.7 × pct, animated on every progress update; three steps below; cancel / retry / continue.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

const _kHood = 'assets/images/redesign/hood_background_B.jpg';
const _kHoodAspect = 996 / 572;

/// Height of the hood lid (above the painted title), as a fraction of the screen width.
const _kHoodLid = 0.52;

// Dial geometry, in the design's 340 × 320 viewBox.
const _vbW = 340.0;
const _vbH = 320.0;
const _cx = 170.0;
const _cy = 170.0;
const _r = 128.0;
const _start = 135.0;
const _sweep = 270.0;
double _angle(double value) => _start + _sweep * value / 100;
Offset _point(double deg, double r) {
  final a = deg * math.pi / 180;
  return Offset(_cx + r * math.cos(a), _cy + r * math.sin(a));
}

enum _StageState { todo, active, done, failed }

class InstallSpeedometerScreen extends StatelessWidget {
  const InstallSpeedometerScreen({
    super.key,
    required this.name,
    required this.code,
    required this.sizeMB,
    required this.pct,
    required this.mbDone,
    required this.mbTotal,
    required this.stage,
    required this.installed,
    required this.error,
    required this.onCancel,
    required this.onRetry,
    required this.onContinue,
  });
  final String name;
  final String code;
  final int sizeMB;
  final int pct;
  final int mbDone;
  final int mbTotal;

  /// 'download' | 'verify' | null (not started)
  final String? stage;
  final bool installed;
  final String? error;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final value = pct.clamp(0, 100).toDouble();
    final downloadState = installed || stage == 'verify'
        ? _StageState.done
        : error != null
        ? _StageState.failed
        : _StageState.active;
    final verifyState = installed
        ? _StageState.done
        : stage == 'verify'
        ? (error != null ? _StageState.failed : _StageState.active)
        : _StageState.todo;
    final stages = [
      (
        'Downloading',
        stage != null
            ? '$mbDone / $mbTotal MB'
            : (error != null ? '' : 'starting…'),
        downloadState,
      ),
      (
        'Checking the download',
        verifyState == _StageState.active ? 'verifying…' : '',
        verifyState,
      ),
      (
        'Installed on the engine',
        installed ? 'ready' : '',
        installed ? _StageState.done : _StageState.todo,
      ),
    ];
    final topPad = math.max(34.0, MediaQuery.of(context).padding.top + 14);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Material(
        color: const Color(0xFF050807),
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            final dialW = math.min(_vbW, math.max(0.0, width - 50));
            final k = dialW / _vbW;
            return Stack(
              children: [
                // Only the hood lid with the emblem: lower down, the image has language-screen text painted in.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: width * _kHoodLid,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          width: width,
                          height: width * _kHoodAspect,
                          child: Image.asset(_kHood, fit: BoxFit.cover),
                        ),
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x8C050807),
                                  Color(0xD1050807),
                                  Color(0xFF050807),
                                ],
                                stops: [0, 0.55, 1],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, topPad, 24, 0),
                      child: Column(
                        children: [
                          Text(
                            installed
                                ? 'INSTALLED'
                                : 'INSTALLING LANGUAGE PACK',
                            textAlign: TextAlign.center,
                            style: inter(
                              11,
                              FontWeight.w700,
                              C.mintLight,
                              letterSpacing: 11 * 0.22,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              name,
                              maxLines: 1,
                              style: inter(
                                26,
                                FontWeight.w800,
                                Colors.white,
                                letterSpacing: 26 * 0.02,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$code voice pack · $sizeMB MB',
                            textAlign: TextAlign.center,
                            style: inter(14, FontWeight.w500, C.tag),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Semantics(
                      label: '${value.round()} percent installed',
                      child: SizedBox(
                        width: dialW,
                        height: _vbH * k,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: value),
                          duration: const Duration(milliseconds: 350),
                          curve: const Cubic(0.3, 1.25, 0.5, 1),
                          builder: (context, v, _) => Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _DialPainter(
                                    value: value,
                                    needle: v,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 216 * k,
                                child: Column(
                                  children: [
                                    Text(
                                      '${value.round()}',
                                      style:
                                          inter(
                                            46 * k,
                                            FontWeight.w800,
                                            C.text,
                                            letterSpacing: -0.9,
                                          ).copyWith(
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                            shadows: const [
                                              Shadow(
                                                color: Color(0xB334D399),
                                                blurRadius: 16,
                                              ),
                                            ],
                                          ),
                                    ),
                                    Text(
                                      'KM/H',
                                      style: inter(
                                        12,
                                        FontWeight.w700,
                                        C.mintLight,
                                        letterSpacing: 12 * 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x9910B981)),
                        color: const Color(0xFF17211D),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < stages.length; i++)
                            Container(
                              height: 46,
                              decoration: i < stages.length - 1
                                  ? const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFF1A2421),
                                        ),
                                      ),
                                    )
                                  : null,
                              child: Row(
                                children: [
                                  _StageDot(stages[i].$3),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      stages[i].$1,
                                      style: inter(
                                        14,
                                        FontWeight.w500,
                                        stages[i].$3 == _StageState.todo
                                            ? C.text2
                                            : C.text,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    stages[i].$2,
                                    style: inter(12, FontWeight.w400, C.text2)
                                        .copyWith(
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: Text(
                          error!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: inter(13, FontWeight.w500, C.warning2),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24 + MediaQuery.of(context).padding.bottom,
                  child: installed
                      ? _PrimaryWide(
                          label: 'Continue',
                          arrow: true,
                          onTap: onContinue,
                        )
                      : error != null
                      ? Row(
                          children: [
                            Expanded(
                              child: _SecondaryWide(
                                label: 'Cancel',
                                onTap: onCancel,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PrimaryWide(
                                label: 'Retry',
                                onTap: onRetry,
                              ),
                            ),
                          ],
                        )
                      : _SecondaryWide(
                          label: 'Cancel',
                          onTap: onCancel,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot(this.state);
  final _StageState state;
  @override
  Widget build(BuildContext context) {
    final border = switch (state) {
      _StageState.done || _StageState.active => C.mint,
      _StageState.failed => C.warning,
      _StageState.todo => C.olive,
    };
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
        color: state == _StageState.done ? C.mint : null,
        boxShadow: switch (state) {
          _StageState.active => const [
            BoxShadow(color: Color(0xCC34D399), blurRadius: 8),
          ],
          _StageState.failed => const [
            BoxShadow(color: Color(0xB3F59E0B), blurRadius: 8),
          ],
          _ => null,
        },
      ),
      child: state == _StageState.done
          ? const Icon(Icons.check_rounded, size: 14, color: C.onPrimary)
          : null,
    );
  }
}

class _PrimaryWide extends StatelessWidget {
  const _PrimaryWide({
    required this.label,
    required this.onTap,
    this.arrow = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool arrow;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: kPrimaryGradient,
          border: Border.all(color: C.mintLight),
          boxShadow: kPrimaryGlow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: inter(
                  arrow ? 16 : 17,
                  FontWeight.w800,
                  C.onPrimary,
                  letterSpacing: arrow ? 0.32 : null,
                ),
              ),
            ),
            if (arrow) ...[
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: C.onPrimary,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SecondaryWide extends StatelessWidget {
  const _SecondaryWide({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.controlBorder, width: 1.5),
          color: C.carbon,
        ),
        child: Text(label, style: inter(16, FontWeight.w700, Colors.white)),
      ),
    ),
  );
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.value, required this.needle});
  final double value;
  final double needle;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _vbW;
    canvas.save();
    canvas.scale(k);
    const c = Offset(_cx, _cy);
    canvas.drawCircle(c, 152, Paint()..color = const Color(0xD9060C0A));
    canvas.drawCircle(
      c,
      152,
      Paint()
        ..color = C.titanium
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      c,
      146,
      Paint()
        ..color = const Color(0xFF2C3331)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    void arc(double from, double to, Color color, double width) {
      if (to - from < 0.5) to = from + 0.5;
      final start = _angle(from) * math.pi / 180;
      final sweep = (to - from) * _sweep / 100 * math.pi / 180;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: _r),
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    arc(0, 100, const Color(0xFF17211E), 12);
    arc(0, math.max(value, 0.5), C.mint.withValues(alpha: 0.22), 22);
    arc(0, math.max(value, 0.5), C.mint, 12);
    for (var i = 0; i <= 100; i += 5) {
      final major = i % 10 == 0;
      canvas.drawLine(
        _point(_angle(i.toDouble()), major ? 104 : 110),
        _point(_angle(i.toDouble()), 116),
        Paint()
          ..color = i <= value ? C.mintLight : C.titanium
          ..strokeWidth = major ? 3 : 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i <= 100; i += 10) {
      final p = _point(_angle(i.toDouble()), 88);
      final tp = TextPainter(
        text: TextSpan(
          text: '$i',
          style: inter(
            13,
            FontWeight.w700,
            i <= value ? C.text : const Color(0xFF6B7470),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
    }
    // needle
    canvas.save();
    canvas.translate(_cx, _cy);
    canvas.rotate(_angle(needle) * math.pi / 180);
    canvas.translate(-_cx, -_cy);
    canvas.drawPath(
      Path()
        ..moveTo(170, 163)
        ..lineTo(286, 168.5)
        ..lineTo(286, 171.5)
        ..lineTo(170, 177)
        ..close(),
      Paint()..color = C.mint.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      Path()
        ..moveTo(170, 166)
        ..lineTo(284, 169)
        ..lineTo(284, 171)
        ..lineTo(170, 174)
        ..close(),
      Paint()..color = C.text,
    );
    canvas.drawPath(
      Path()
        ..moveTo(170, 167)
        ..lineTo(146, 169)
        ..lineTo(146, 171)
        ..lineTo(170, 173)
        ..close(),
      Paint()..color = const Color(0xFF59625F),
    );
    canvas.restore();
    canvas.drawCircle(c, 16, Paint()..color = const Color(0xFF1A2421));
    canvas.drawCircle(
      c,
      16,
      Paint()
        ..color = const Color(0xFF59625F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(c, 9, Paint()..color = C.mint.withValues(alpha: 0.25));
    canvas.drawCircle(c, 5, Paint()..color = C.mint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.value != value || old.needle != needle;
}
