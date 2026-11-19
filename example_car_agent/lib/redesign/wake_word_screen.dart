// Screen 6 · Wake word (React Native: src/redesign/WakeWordScreen.tsx): the emblem with pulsing emerald rings, the wake phrase, chips for
// voice / language / speaker check; or the speech-session card while a session runs.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chrome.dart';
import 'theme.dart';

class WakeSession {
  const WakeSession({
    required this.title,
    required this.rows,
    this.onContinue,
    this.onBack,
  });
  final String title;
  final List<(String, String)> rows;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
}

const _bars = [
  4,
  12,
  6,
  20,
  8,
  28,
  14,
  34,
  20,
  38,
  26,
  38,
  20,
  34,
  14,
  28,
  8,
  20,
  6,
  12,
  4,
];
const _emblemBox = 340.0;

class WakeWordScreen extends StatefulWidget {
  const WakeWordScreen({
    super.key,
    required this.wakePhrase,
    required this.message,
    required this.listening,
    required this.heard,
    required this.voice,
    required this.language,
    required this.driverOnly,
    this.onSimulateWakeWord,
    this.session,
  });
  final String wakePhrase;

  /// The app's status line (preparing, initializing, say the wake word…).
  final String message;
  final bool listening;

  /// Briefly true when the wake word was heard.
  final bool heard;
  final String voice;
  final String language;
  final bool driverOnly;
  final VoidCallback? onSimulateWakeWord;
  final WakeSession? session;
  @override
  State<WakeWordScreen> createState() => _WakeWordScreenState();
}

class _WakeWordScreenState extends State<WakeWordScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rings = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  );
  late final AnimationController _barsPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(WakeWordScreen old) {
    super.didUpdateWidget(old);
    if (old.listening != widget.listening) _sync();
  }

  void _sync() {
    if (widget.listening) {
      _rings.repeat();
      _barsPulse.repeat(reverse: true);
    } else {
      _rings.stop();
      _rings.value = 0;
      _barsPulse.stop();
    }
  }

  @override
  void dispose() {
    _rings.dispose();
    _barsPulse.dispose();
    super.dispose();
  }

  Widget _ring(double delay) => AnimatedBuilder(
    animation: _rings,
    builder: (context, _) {
      // three rings, 800 ms apart, each expanding for 2.4 s of a 4 s cycle
      final t = ((_rings.value * 4000 - delay) / 2400);
      final on = widget.listening && t >= 0 && t <= 1;
      final v = Curves.easeOut.transform(t.clamp(0.0, 1.0));
      return Opacity(
        opacity: on ? 0.9 * (1 - v) : 0,
        child: Transform.scale(
          scale: 0.75 + 0.7 * v,
          child: Container(
            width: _emblemBox - 80,
            height: _emblemBox - 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xB334D399), width: 2),
            ),
          ),
        ),
      );
    },
  );

  Widget _chip(String text, {bool on = false}) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: on ? const Color(0x8034D399) : const Color(0xFF46544F),
      ),
      color: on ? const Color(0x1F10B981) : const Color(0xFF1A2420),
    ),
    child: Text(
      text,
      maxLines: 1,
      style: inter(12, FontWeight.w400, on ? C.mint : C.tag),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sb = MediaQuery.of(context).padding.top;
    final p = widget;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Material(
        color: C.bg,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.2),
              radius: 1.0,
              colors: [Color(0xFF0C1512), Color(0xFF040605)],
              stops: [0, 0.6],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: CarbonFill(faint: true)),
              Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, sb + 12, 12, 0),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          'STEP 4 OF 5',
                          style: inter(
                            11,
                            FontWeight.w700,
                            C.mint,
                            letterSpacing: 11 * 0.18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (p.session != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: C.controlBorder, width: 1.5),
                        color: C.messageCard,
                        boxShadow: kLift,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            p.session!.title,
                            textAlign: TextAlign.center,
                            style: inter(22, FontWeight.w700, C.text),
                          ),
                          for (final (label, value) in p.session!.rows) ...[
                            const SizedBox(height: 14),
                            Text(
                              label.toUpperCase(),
                              style: inter(
                                11,
                                FontWeight.w600,
                                C.text2,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              value,
                              style: inter(
                                15,
                                FontWeight.w500,
                                C.text,
                                height: 21,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else ...[
                    SizedBox(
                      width: _emblemBox,
                      height: _emblemBox,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _ring(0),
                          _ring(800),
                          _ring(1600),
                          Container(
                            width: _emblemBox - 40,
                            height: _emblemBox - 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: C.olive),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: p.heard
                                      ? const Color(0xFF34D399)
                                      : const Color(0x8C34D399),
                                  blurRadius: p.heard ? 60 : 30,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              kEmblem,
                              width: 240,
                              height: 240,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    FadeTransition(
                      opacity: p.listening
                          ? Tween(begin: 0.55, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _barsPulse,
                                curve: Curves.easeInOut,
                              ),
                            )
                          : const AlwaysStoppedAnimation(0.25),
                      child: CustomPaint(
                        size: const Size(260, 44),
                        painter: _BarsPainter(),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: p.listening
                              ? [
                                  Text(
                                    'Listening for the wake word',
                                    textAlign: TextAlign.center,
                                    style: inter(16, FontWeight.w500, C.tag),
                                  ),
                                  const SizedBox(height: 8),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '“${p.wakePhrase}”',
                                      maxLines: 1,
                                      style:
                                          inter(
                                            34,
                                            FontWeight.w800,
                                            C.text,
                                            height: 38,
                                            letterSpacing: -0.5,
                                          ).copyWith(
                                            shadows: const [
                                              Shadow(
                                                color: Color(0x7334D399),
                                                blurRadius: 18,
                                              ),
                                            ],
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'then say what you want the car to do',
                                    textAlign: TextAlign.center,
                                    style: inter(15, FontWeight.w500, C.tag),
                                  ),
                                ]
                              : [
                                  Text(
                                    'Wake word · “${p.wakePhrase}”',
                                    textAlign: TextAlign.center,
                                    style: inter(16, FontWeight.w500, C.tag),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    p.message,
                                    textAlign: TextAlign.center,
                                    style: inter(
                                      22,
                                      FontWeight.w700,
                                      Colors.white,
                                      height: 28,
                                    ),
                                  ),
                                ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _chip('Voice · ${p.voice}'),
                        _chip(p.language),
                        _chip(
                          p.driverOnly ? 'Driver only' : 'Anyone',
                          on: p.driverOnly,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24 + MediaQuery.of(context).padding.bottom,
                child: Row(
                  children: [
                    if (p.session?.onBack != null)
                      Expanded(
                        child: SecondaryButton(
                          label: 'Back',
                          onPressed: p.session!.onBack,
                        ),
                      ),
                    if (p.session?.onBack != null &&
                        p.session?.onContinue != null)
                      const SizedBox(width: 10),
                    if (p.session?.onContinue != null)
                      Expanded(
                        flex: 2,
                        child: SecondaryButton(
                          label: 'Continue',
                          onPressed: p.session!.onContinue,
                        ),
                      ),
                    if (p.session == null && p.onSimulateWakeWord != null)
                      Expanded(
                        child: SecondaryButton(
                          label: 'Simulate wake word',
                          textStyle: inter(15, FontWeight.w700, C.tag),
                          onPressed: p.onSimulateWakeWord,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = C.mint.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < _bars.length; i++) {
      final h = _bars[i].toDouble();
      final x = 10.0 + i * 12;
      canvas.drawLine(Offset(x, 22 - h / 2), Offset(x, 22 + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => false;
}
