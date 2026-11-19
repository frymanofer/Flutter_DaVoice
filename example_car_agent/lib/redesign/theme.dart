// "VW Emerald" design tokens: the same values as the React Native example_car_agent (src/redesign/theme.ts).
import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF060908);
  static const panel = Color(0xFF080B0A);
  // Controls (secondary buttons, segments, chips): clearly lighter than the panel behind them.
  static const carbon = Color(0xFF26342F);
  static const carbon2 = Color(0xFF101513);
  // Selectable tiles (voices, options): the brightest dark surface, so choices stand out from the background.
  static const tile = Color(0xFF2B3D36);
  static const tileBorder = Color(0xBF34D399); // rgba(52, 211, 153, 0.75)
  static const controlBorder = Color(0xFF8C9995);
  // The panel behind the controls fades from a soft green-grey at the top to near black.
  static const panelTop = Color(0xFF0D1411);
  static const panelMid = Color(0xFF060908);
  static const panelBottom = Color(0xFF020303);
  static const titanium = Color(0xFF4B5552);
  static const olive = Color(0xFF3A4D3F);
  static const emerald = Color(0xFF10B981);
  static const mint = Color(0xFF34D399);
  static const mintLight = Color(0xFF6EE7B7);
  static const mintPale = Color(0xFFD1FAE5);
  static const text = Color(0xFFF9FAFB);
  static const text2 = Color(0xFFAAB2BA);
  static const tag = Color(0xFFD1D5DB);
  static const onPrimary = Color(0xFF04140D);
  static const warning = Color(0xFFF59E0B);
  static const warning2 = Color(0xFFFBBF24);
  static const vent = Color(0xFF60A5FA);

  /// The card that carries the screen's main message.
  static const messageCard = Color(0xFF1E2B26);
}

/// Inter, as in the React Native app (assets/fonts/Inter-*.ttf, one family with five weights in pubspec.yaml).
const kFont = 'Inter';

TextStyle inter(
  double size,
  FontWeight weight,
  Color color, {
  double? height,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: kFont,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height == null ? null : height / size,
  letterSpacing: letterSpacing,
);

const kPrimaryGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF34D399), Color(0xFF10B981)],
);
const kPanelGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF0D1411), Color(0xFF060908), Color(0xFF020303)],
  stops: [0, 0.38, 1],
);

/// Dims the decorative header (carbon weave, bar) so it stays behind the content.
const kHeaderScrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xB8030504), Color(0x80030504)],
);
const kPrimaryGlow = [BoxShadow(color: Color(0xA610B981), blurRadius: 26)];
const kGlow = [BoxShadow(color: Color(0x5910B981), blurRadius: 12)];

/// Lifts a control off the background.
const kLift = [
  BoxShadow(color: Color(0x99000000), offset: Offset(0, 6), blurRadius: 16),
];

/// The designs are drawn on a 390 pt wide phone.
const kDesignWidth = 390.0;
