// Screen 1 · Language, "under the hood" (React Native: src/redesign/LanguageHoodScreen.tsx). The hood photo, the selected language glowing on
// the engine, a scrolling module rack of languages and the install button. Title, engine and rack sit on what is painted in the image, so
// they scale with the screen width; only the button is anchored to the bottom.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

const _kHood = 'assets/images/redesign/hood_background_B.jpg';
const _kHoodAspect = 996 / 572;

class HoodLanguage {
  const HoodLanguage({
    required this.id,
    required this.code,
    required this.shortName,
    required this.name,
    required this.sizeMB,
    required this.installed,
  });
  final String id;

  /// "PT-BR"
  final String code;

  /// "Português" on the tile and the engine
  final String shortName;

  /// "Português do Brasil" on the button
  final String name;
  final int sizeMB;
  final bool installed;
}

class LanguageHoodScreen extends StatefulWidget {
  const LanguageHoodScreen({
    super.key,
    required this.languages,
    required this.defaultId,
    required this.onInstall,
  });
  final List<HoodLanguage> languages;
  final String defaultId;
  final ValueChanged<String> onInstall;
  @override
  State<LanguageHoodScreen> createState() => _LanguageHoodScreenState();
}

class _LanguageHoodScreenState extends State<LanguageHoodScreen>
    with TickerProviderStateMixin {
  late String _picked = widget.languages.any((l) => l.id == widget.defaultId)
      ? widget.defaultId
      : widget.languages.first.id;
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);
  final _scroll = ScrollController();

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langs = widget.languages;
    final current = langs.firstWhere(
      (l) => l.id == _picked,
      orElse: () => langs.first,
    );
    // The rack follows the app's language order (flow/app_language.dart, best quality first); the default is preselected, not moved up.
    final rack = langs;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Material(
        color: C.bg,
        child: LayoutBuilder(
          builder: (context, box) {
            final s = box.maxWidth / kDesignWidth;
            double d(double v) => v * s;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: box.maxWidth,
                  height: box.maxWidth * _kHoodAspect,
                  child: Image.asset(_kHood, fit: BoxFit.cover),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: d(560),
                  height: d(120),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x000B0F0E), C.bg],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: d(680),
                  bottom: 0,
                  child: const ColoredBox(color: C.bg),
                ),
                // The photo fades out behind the language list and the button, so the choices carry the lower half of the screen.
                Positioned(
                  left: 0,
                  right: 0,
                  top: d(380),
                  bottom: 0,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00030504),
                            Color(0xCC030504),
                            Color(0xEB030504),
                          ],
                          stops: [0, 0.26, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                // Title, over the one painted in the image
                Positioned(
                  left: d(24),
                  right: d(24),
                  top: d(190),
                  height: d(68),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(d(34)),
                      gradient: const RadialGradient(
                        radius: 1.2,
                        colors: [
                          Color(0xFF080C0B),
                          Color(0xF7080C0B),
                          Color(0x00080C0B),
                        ],
                        stops: [0, 0.62, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: d(202),
                  child: Column(
                    children: [
                      Text(
                        'CHOOSE YOUR LANGUAGE',
                        textAlign: TextAlign.center,
                        style: inter(
                          d(18),
                          FontWeight.w800,
                          C.text,
                          letterSpacing: d(18) * 0.06,
                        ),
                      ),
                      SizedBox(height: d(3)),
                      Text(
                        'Select a voice pack to install on the engine',
                        textAlign: TextAlign.center,
                        style: inter(d(12), FontWeight.w400, C.mintLight),
                      ),
                    ],
                  ),
                ),
                // Selected language on the engine
                Positioned(
                  left: d(132),
                  top: d(263),
                  width: d(132),
                  height: d(132),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -d(10),
                        top: -d(10),
                        width: d(152),
                        height: d(152),
                        child: RotationTransition(
                          turns: _spin,
                          child: CustomPaint(painter: _DashedRingPainter()),
                        ),
                      ),
                      Positioned.fill(
                        child: FadeTransition(
                          opacity: Tween(begin: 0.55, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _pulse,
                              curve: Curves.easeInOut,
                            ),
                          ),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xE634D399),
                                  blurRadius: 26,
                                ),
                                BoxShadow(
                                  color: Color(0x8010B981),
                                  blurRadius: 56,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: C.mint, width: 2),
                            gradient: const RadialGradient(
                              colors: [Color(0xFF0E2A20), Color(0xFF071510)],
                              stops: [0, 0.7],
                            ),
                          ),
                          child: Semantics(
                            liveRegion: true,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'SELECTED',
                                  style: inter(
                                    d(9),
                                    FontWeight.w700,
                                    C.mintLight,
                                    letterSpacing: d(9) * 0.2,
                                  ),
                                ),
                                Text(
                                  current.code,
                                  style:
                                      inter(
                                        d(24),
                                        FontWeight.w800,
                                        C.text,
                                        letterSpacing: d(24) * 0.03,
                                      ).copyWith(
                                        shadows: const [
                                          Shadow(
                                            color: Color(0xE634D399),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                ),
                                Text(
                                  current.shortName,
                                  style: inter(
                                    d(12),
                                    FontWeight.w600,
                                    C.mintPale,
                                  ),
                                ),
                                Text(
                                  current.installed
                                      ? 'Installed'
                                      : '${current.sizeMB} MB',
                                  style: inter(d(11), FontWeight.w400, C.text2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Left caption
                Positioned(
                  left: d(16),
                  top: d(430),
                  width: d(148),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${langs.length} LANGUAGES',
                        style: inter(
                          d(10),
                          FontWeight.w700,
                          C.mintLight,
                          letterSpacing: d(10) * 0.18,
                        ),
                      ),
                      SizedBox(height: d(6)),
                      Text(
                        'Scroll the module rack to pick one. It installs once and runs offline.',
                        style:
                            inter(
                              d(12),
                              FontWeight.w400,
                              C.tag,
                              height: d(12) * 1.4,
                            ).copyWith(
                              shadows: const [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
                // Module rack: the only scrolling part of the screen
                Positioned(
                  left: d(180),
                  right: d(12),
                  top: d(410),
                  bottom: 98,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(d(16)),
                      border: Border.all(color: C.mint, width: 2),
                      // Opaque: the image has a language list painted under the rack.
                      color: const Color(0xFF070C0A),
                      boxShadow: const [
                        BoxShadow(color: Color(0x5910B981), blurRadius: 18),
                        BoxShadow(
                          color: Color(0x99000000),
                          offset: Offset(0, 12),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        RawScrollbar(
                          controller: _scroll,
                          thumbVisibility: true,
                          thumbColor: C.mint,
                          trackColor: const Color(0xFF17211E),
                          trackVisibility: true,
                          thickness: 3,
                          radius: const Radius.circular(2),
                          padding: const EdgeInsets.fromLTRB(0, 12, 4, 12),
                          child: ListView.separated(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(10, 10, 16, 22),
                            itemCount: rack.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final lang = rack[i];
                              final on = lang.id == _picked;
                              return Semantics(
                                inMutuallyExclusiveGroup: true,
                                checked: on,
                                button: true,
                                label: '${lang.code} ${lang.shortName}',
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _picked = lang.id),
                                  child: Container(
                                    height: 54,
                                    padding: const EdgeInsets.only(
                                      left: 10,
                                      right: 30,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: on ? C.mint : C.tileBorder,
                                        width: on ? 2 : 1,
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: on
                                            ? const [
                                                Color(0xFF1F5A44),
                                                Color(0xFF174433),
                                              ]
                                            : const [
                                                Color(0xFF2C3D37),
                                                Color(0xFF1F2C27),
                                              ],
                                      ),
                                      boxShadow: on
                                          ? const [
                                              BoxShadow(
                                                color: Color(0x9910B981),
                                                blurRadius: 14,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Stack(
                                      children: [
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(text: lang.code),
                                                  const TextSpan(
                                                    text: ' • ',
                                                    style: TextStyle(
                                                      color: C.mint,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: lang.shortName,
                                                  ),
                                                ],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: inter(
                                                14,
                                                FontWeight.w700,
                                                Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              lang.installed
                                                  ? 'Installed'
                                                  : '${lang.sizeMB} MB',
                                              style: inter(
                                                11,
                                                FontWeight.w400,
                                                C.text2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Positioned(
                                          right: -22,
                                          top: 17,
                                          child: Icon(
                                            on
                                                ? Icons.check_rounded
                                                : Icons.download_rounded,
                                            size: 17,
                                            color: on ? C.mint : C.mintLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 36,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x00070C0A),
                                    Color(0xFA070C0A),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Install / continue
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24 + MediaQuery.of(context).padding.bottom,
                  child: Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: () => widget.onInstall(current.id),
                      child: Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: kPrimaryGradient,
                          border: Border.all(color: C.mintLight),
                          boxShadow: kPrimaryGlow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!current.installed) ...[
                              const Icon(
                                Icons.download_rounded,
                                size: 22,
                                color: C.onPrimary,
                              ),
                              const SizedBox(width: 10),
                            ],
                            Flexible(
                              child: Text(
                                current.installed
                                    ? 'Continue with ${current.name}'
                                    : 'Install ${current.name} · ${current.sizeMB} MB',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: inter(17, FontWeight.w800, C.onPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x8C6EE7B7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = size.width / 2;
    const dashes = 48;
    for (var i = 0; i < dashes; i++) {
      final a = i * 2 * 3.141592653589793 / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(r, r), radius: r - 1),
        a,
        3.141592653589793 / dashes,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => false;
}
