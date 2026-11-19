// The shared screen frame of the "VW Emerald" redesign: carbon header with the titanium bar and the emblem, the recessed panel, headings and
// buttons. Same layout and values as the React Native example_car_agent (src/redesign/chrome.tsx).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

const kEmblem = 'assets/images/redesign/DaVoice_emblem.png';

/// Carbon weave: 45° stripes (3 px / 4 px).
class CarbonFill extends StatelessWidget {
  const CarbonFill({super.key, this.faint = false});
  final bool faint;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _CarbonPainter(faint), size: Size.infinite),
  );
}

class _CarbonPainter extends CustomPainter {
  _CarbonPainter(this.faint);
  final bool faint;
  @override
  void paint(Canvas canvas, Size size) {
    if (!faint) canvas.drawRect(Offset.zero & size, Paint()..color = C.bg);
    final stripe = Paint()
      ..color = faint ? const Color(0x05FFFFFF) : C.carbon2
      ..strokeWidth = 3;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // lines at 45°, every 7 px
    final d = size.width + size.height;
    for (double x = -size.height; x < d; x += 7 * math.sqrt2) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stripe,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CarbonPainter old) => old.faint != faint;
}

class _Rivet extends StatelessWidget {
  const _Rivet();
  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF2C3331)),
      gradient: const RadialGradient(
        center: Alignment(-0.3, -0.3),
        colors: [Color(0xFFC9D0CE), Color(0xFF4B5552)],
      ),
    ),
  );
}

double statusBarHeight(BuildContext context) =>
    MediaQuery.of(context).padding.top;

/// Carbon header with the titanium bar and the emblem riding on it.
class EmblemHeader extends StatelessWidget {
  const EmblemHeader({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) {
    final sb = statusBarHeight(context);
    final height = (large ? 262.0 : 150.0) + sb;
    final barTop = (large ? 190.0 : 92.0) + sb;
    final barHeight = large ? 44.0 : 38.0;
    final size = large ? 216.0 : 130.0;
    final emblemTop = (large ? 28.0 : 10.0) + sb;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: CarbonFill()),
          Positioned(
            left: 0,
            right: 0,
            top: barTop,
            height: barHeight,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: C.mint)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF7C8582),
                    Color(0xFF59625F),
                    Color(0xFF4B5552),
                    Color(0xFF2C3331),
                  ],
                  stops: [0, 0.3, 0.55, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4D10B981),
                    offset: Offset(0, -10),
                    blurRadius: 22,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: barTop + (barHeight - 10) / 2 - 2,
            child: const _Rivet(),
          ),
          Positioned(
            right: 14,
            top: barTop + (barHeight - 10) / 2 - 2,
            child: const _Rivet(),
          ),
          // The header is decoration: dimmed, so the title and the buttons below carry the screen.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: kHeaderScrim),
              ),
            ),
          ),
          Positioned(
            top: emblemTop,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x3834D399),
                      blurRadius: large ? 18 : 12,
                    ),
                  ],
                ),
                child: Opacity(
                  opacity: 0.86,
                  child: Image.asset(kEmblem, width: size, height: size),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circuit traces in a panel's top corners.
class Traces extends StatelessWidget {
  const Traces({super.key, this.left = false, this.doubled = false});
  final bool left;
  final bool doubled;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        Positioned(
          right: 8,
          top: 10,
          child: Opacity(
            opacity: 0.5,
            child: CustomPaint(
              size: const Size(90, 70),
              painter: _TracePainter(right: true, doubled: doubled),
            ),
          ),
        ),
        if (left)
          Positioned(
            left: 8,
            top: 10,
            child: Opacity(
              opacity: 0.5,
              child: CustomPaint(
                size: const Size(70, 70),
                painter: _TracePainter(right: false, doubled: false),
              ),
            ),
          ),
      ],
    ),
  );
}

class _TracePainter extends CustomPainter {
  _TracePainter({required this.right, required this.doubled});
  final bool right;
  final bool doubled;
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = C.olive
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final dotFill = Paint()..color = C.panelTop;
    void dot(double x, double y) {
      canvas.drawCircle(Offset(x, y), 2.5, dotFill);
      canvas.drawCircle(Offset(x, y), 2.5, line);
    }

    if (right) {
      canvas.drawPath(
        Path()
          ..moveTo(2, 6)
          ..lineTo(58, 6)
          ..lineTo(72, 20)
          ..lineTo(72, 66),
        line,
      );
      if (doubled) {
        canvas.drawPath(
          Path()
            ..moveTo(24, 14)
            ..lineTo(52, 14)
            ..lineTo(62, 24)
            ..lineTo(62, 50),
          line,
        );
      }
      dot(2, 6);
      dot(72, 66);
      if (doubled) {
        dot(24, 14);
        dot(62, 50);
      }
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(68, 6)
          ..lineTo(22, 6)
          ..lineTo(8, 20)
          ..lineTo(8, 60),
        line,
      );
      dot(68, 6);
      dot(8, 60);
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) => false;
}

/// Screen frame: carbon header + recessed panel, everything on one phone screen.
class PanelScreen extends StatelessWidget {
  const PanelScreen({
    super.key,
    required this.child,
    this.large = false,
    this.traces = true,
    this.leftTrace = false,
    this.doubleTrace = false,
  });
  final Widget child;
  final bool large;
  final bool traces;
  final bool leftTrace;
  final bool doubleTrace;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
    child: Material(
      color: C.bg,
      child: Column(
        children: [
          EmblemHeader(large: large),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -12),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: C.panel,
                  gradient: kPanelGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    top: BorderSide(color: Color(0xFF2C3432), width: 1.5),
                    left: BorderSide(color: Color(0xFF2C3432), width: 1.5),
                    right: BorderSide(color: Color(0xFF2C3432), width: 1.5),
                  ),
                ),
                child: Stack(
                  children: [
                    if (traces)
                      Positioned.fill(
                        child: Traces(left: leftTrace, doubled: doubleTrace),
                      ),
                    Positioned.fill(child: SafeArea(top: false, child: child)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class Heading extends StatelessWidget {
  const Heading({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.padding,
  });
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding ?? const EdgeInsets.fromLTRB(24, 22, 24, 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null && eyebrow!.isNotEmpty) ...[
          Text(
            eyebrow!.toUpperCase(),
            textAlign: TextAlign.center,
            style: inter(11, FontWeight.w700, C.mint, letterSpacing: 11 * 0.18),
          ),
          const SizedBox(height: 6),
        ],
        // The main message of a screen: the brightest, heaviest text on it.
        Text(
          title,
          textAlign: TextAlign.center,
          style: inter(
            27,
            FontWeight.w800,
            Colors.white,
            height: 32,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: inter(15, FontWeight.w500, C.tag, height: 21),
          ),
        ],
      ],
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text.toUpperCase(),
      style: inter(12, FontWeight.w700, C.tag, letterSpacing: 12 * 0.08),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 60,
  });
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double height;
  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: disabled ? null : kPrimaryGradient,
            color: disabled ? const Color(0xFF1A2421) : null,
            border: Border.all(
              color: disabled ? const Color(0xFF2C3432) : C.mintLight,
            ),
            boxShadow: disabled ? null : kPrimaryGlow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 10)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: disabled
                      ? inter(15, FontWeight.w600, C.text2)
                      : inter(17, FontWeight.w800, C.onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 58,
    this.textStyle,
  });
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final TextStyle? textStyle;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    child: GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: C.carbon,
            border: Border.all(color: C.controlBorder, width: 1.5),
            boxShadow: kLift,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle ?? inter(16, FontWeight.w700, Colors.white),
          ),
        ),
      ),
    ),
  );
}

class BackSquare extends StatelessWidget {
  const BackSquare({super.key, required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back',
    child: GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: C.carbon,
            border: Border.all(color: C.controlBorder, width: 1.5),
            boxShadow: kLift,
          ),
          child: const Icon(
            Icons.chevron_left_rounded,
            color: C.text,
            size: 26,
          ),
        ),
      ),
    ),
  );
}

/// The row of buttons at the bottom of a panel.
class Footer extends StatelessWidget {
  const Footer({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          children[i],
        ],
      ],
    ),
  );
}
