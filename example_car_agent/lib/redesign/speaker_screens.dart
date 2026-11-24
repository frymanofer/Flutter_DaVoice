// Screens 4 and 5 · Speaker isolation (React Native: src/redesign/SpeakerScreen.tsx, SignatureScreen.tsx, VoiceTestScreen.tsx):
// isolate your voice? -> read five sentences aloud (the voice signature) -> test your voice.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chrome.dart';
import 'theme.dart';

/// Step 3: isolate the driver's voice (create / use the saved voice signature) or answer any voice.
class SpeakerScreen extends StatelessWidget {
  const SpeakerScreen({
    super.key,
    required this.hasSaved,
    required this.busy,
    required this.onUseSaved,
    required this.onCreate,
    required this.onSkip,
    this.notice = '',
  });
  final bool hasSaved;
  final bool busy;
  final VoidCallback onUseSaved;
  final VoidCallback onCreate;
  final VoidCallback onSkip;

  /// Shown above the buttons after a recording failed (svEnrollmentFailedNotice).
  final String notice;

  @override
  Widget build(BuildContext context) => PanelScreen(
    leftTrace: true,
    doubleTrace: true,
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Heading(
                  padding: EdgeInsets.fromLTRB(24, 30, 24, 18),
                  eyebrow: 'Step 3 of 5',
                  title: 'Isolate your voice?',
                  subtitle: 'The agent answers only you.',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (notice.isNotEmpty) ...[
                        Text(notice, style: inter(14, FontWeight.w500, C.warning2)),
                        const SizedBox(height: 14),
                      ],
                      if (hasSaved) ...[
                        PrimaryButton(
                          height: 64,
                          label: 'Use my saved voice signature',
                          icon: const Icon(
                            Icons.verified_user_outlined,
                            color: C.onPrimary,
                          ),
                          onPressed: busy ? null : onUseSaved,
                        ),
                        const SizedBox(height: 12),
                        SecondaryButton(
                          label: 'Record it again',
                          onPressed: busy ? null : onCreate,
                        ),
                      ] else ...[
                        PrimaryButton(
                          height: 64,
                          label: 'Create my voice signature',
                          icon: const Icon(
                            Icons.shield_outlined,
                            color: C.onPrimary,
                          ),
                          onPressed: busy ? null : onCreate,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Footer(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Skip',
                onPressed: busy ? null : onSkip,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Step 3 · voice signature: one sentence per sample, a progress ring and five segment dots.
class SignatureScreen extends StatefulWidget {
  const SignatureScreen({
    super.key,
    required this.collected,
    required this.target,
    required this.sentences,
  });
  final int collected;
  final int target;
  final List<String> sentences;
  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, widget.target);
    final done = widget.collected.clamp(0, total);
    final finished = done >= total;
    final sentence = widget.sentences.isEmpty
        ? ''
        : widget.sentences[math.min(done, widget.sentences.length - 1)];
    return PanelScreen(
      traces: false,
      child: Column(
        children: [
          const Heading(
            eyebrow: 'Step 3 of 5 · Voice signature',
            title: 'Read this aloud',
          ),
          // The sentence is the screen's main message: the brightest card, the largest text.
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.mint, width: 1.5),
              color: C.messageCard,
              boxShadow: kLift,
            ),
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    finished
                        ? 'ALL $total SENTENCES CAPTURED'
                        : 'SENTENCE ${done + 1} OF $total · SAY',
                    style: inter(
                      12,
                      FontWeight.w700,
                      C.mint,
                      letterSpacing: 12 * 0.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // One height for every sentence, so the screen does not jump; a new sentence fades in.
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 150),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: Align(
                        key: ValueKey(done),
                        alignment: finished
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: finished
                            ? Text(
                                'Creating your voice signature…',
                                textAlign: TextAlign.center,
                                style: inter(
                                  20,
                                  FontWeight.w700,
                                  C.mintLight,
                                  height: 28,
                                ),
                              )
                            : Text(
                                '“$sentence”',
                                maxLines: 5,
                                style: inter(
                                  23,
                                  FontWeight.w700,
                                  Colors.white,
                                  height: 31,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i < done
                          ? C.mint
                          : (i == done ? C.mintPale : const Color(0xFF26322E)),
                      boxShadow: i < done
                          ? const [
                              BoxShadow(
                                color: Color(0xB334D399),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Semantics(
                label: '$done of $total sentences captured',
                child: SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(132, 132),
                        painter: _RingPainter(done / total),
                      ),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: C.olive),
                          gradient: const RadialGradient(
                            colors: [Color(0x2910B981), Color(0x000D1210)],
                            stops: [0, 0.7],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FadeTransition(
                              opacity: Tween(begin: 0.55, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: _pulse,
                                  curve: Curves.easeInOut,
                                ),
                              ),
                              child: const Icon(
                                Icons.graphic_eq_rounded,
                                color: C.mint,
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              finished ? 'Saving' : 'Listening',
                              style: inter(12, FontWeight.w600, C.mint),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction);
  final double fraction;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: 56);
    canvas.drawCircle(
      c,
      56,
      Paint()
        ..color = const Color(0xFF1A2421)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * fraction.clamp(0, 1),
        false,
        Paint()
          ..color = C.mint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

/// After the voice signature: the user speaks and sees, live, whether the agent recognises the voice.
class VoiceTestScreen extends StatefulWidget {
  const VoiceTestScreen({
    super.key,
    required this.wakePhrase,
    required this.score,
    required this.isMatch,
    required this.sinceLast,
    required this.canContinue,
    required this.onContinue,
  });
  final String wakePhrase;

  /// The latest verification result; null until the first one arrives.
  final double? score;
  final bool? isMatch;

  /// Time since that result ("1.2s"), or "N/A".
  final String sinceLast;
  final bool canContinue;
  final VoidCallback onContinue;
  @override
  State<VoiceTestScreen> createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends State<VoiceTestScreen> {
  /// How long "It's you" stays after the last matching result, so it can be read between words.
  static const _matchHold = Duration(seconds: 2);
  DateTime _lastMatchAt = DateTime.fromMillisecondsSinceEpoch(0);

  Widget _metric(String label, String value, {Color? tone}) => Expanded(
    child: Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.tileBorder),
        color: C.tile,
        boxShadow: kLift,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: inter(10, FontWeight.w700, C.tag, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: inter(20, FontWeight.w800, tone ?? Colors.white),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final hasResult = widget.score != null && widget.isMatch != null;
    if (widget.isMatch == true) _lastMatchAt = DateTime.now();
    final match =
        hasResult &&
        (widget.isMatch! ||
            DateTime.now().difference(_lastMatchAt) < _matchHold);
    final detail = !match && hasResult ? 'No match' : '';
    return PanelScreen(
      leftTrace: true,
      doubleTrace: true,
      child: Column(
        children: [
          Heading(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
            eyebrow: 'Step 3 of 5 · Voice signature',
            title: 'Test your voice',
            subtitle: 'Say anything. Then let someone else try.',
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: match ? C.mintLight : C.olive,
                        width: 2,
                      ),
                      color: match ? C.mint : const Color(0xFF121A17),
                      boxShadow: match
                          ? const [
                              BoxShadow(
                                color: Color(0xB310B981),
                                blurRadius: 28,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      match ? Icons.check_rounded : Icons.graphic_eq_rounded,
                      size: 54,
                      color: match ? C.onPrimary : C.mint,
                    ),
                  ),
                  Text(
                    match ? "It's you" : 'Listening…',
                    textAlign: TextAlign.center,
                    style: inter(
                      26,
                      FontWeight.w800,
                      match ? C.mintLight : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: inter(14, FontWeight.w500, C.tag, height: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _metric(
                  'Last score',
                  hasResult ? widget.score!.toStringAsFixed(3) : '—',
                ),
                const SizedBox(width: 8),
                _metric(
                  'Match',
                  hasResult ? (widget.isMatch! ? 'Yes' : 'No') : '—',
                  tone: hasResult
                      ? (widget.isMatch! ? C.mintLight : C.warning2)
                      : null,
                ),
                const SizedBox(width: 8),
                _metric(
                  'Since last',
                  widget.sinceLast == 'N/A' ? '—' : widget.sinceLast,
                ),
              ],
            ),
          ),
          Footer(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: widget.canContinue
                      ? 'Continue'
                      : 'Waiting…',
                  onPressed: widget.canContinue ? widget.onContinue : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
