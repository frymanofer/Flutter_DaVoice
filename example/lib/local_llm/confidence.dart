// Local confidence (agent core configure "confidence", 2026-11-19): an application-developer choice, adjustable at runtime.
//
// The on-device model's tool call carries a score (the product of the probabilities of the tokens it wrote). With the filter ON, a call
// scoring below the threshold does not run, and the fallback decides what happens instead:
//   - clarify: the user is asked to say it again;
//   - remote:  the request goes to the text-only remote assistant (it never runs car tools);
//   - decline: the user hears that nothing was changed.
// With the filter OFF the threshold is ignored. Either way the core's deterministic checks (scope, call guards, never-act, seat rule)
// still apply, and the score of each action is shown. The score is model-derived, NOT a guaranteed probability of being right.
// Same behaviour as the React Native examples (src/local_llm/confidence.ts).

import 'package:flutter/material.dart';
import '../car/basic_language.dart';

const confidenceFallbacks = ['clarify', 'remote', 'decline'];
const confidenceFallbackLabels = {'clarify': 'Clarify', 'remote': 'Remote', 'decline': 'Decline'};
const confidenceFallbackDetails = {
  'clarify': 'ask the driver to say it again',
  'remote': 'text-only answer, never a car action',
  'decline': 'say nothing was changed',
};
const confidenceStep = 0.05;

class ConfidenceSettings {
  const ConfidenceSettings({this.enabled = false, this.threshold = 0.9, this.fallback = 'clarify'});

  /// OFF by default (the existing behaviour), threshold 0.90, CLARIFY (needs no remote assistant).
  static const defaults = ConfidenceSettings();

  final bool enabled;
  final double threshold;
  final String fallback;

  ConfidenceSettings copyWith({bool? enabled, double? threshold, String? fallback}) => ConfidenceSettings(
        enabled: enabled ?? this.enabled,
        threshold: snapThreshold(threshold ?? this.threshold),
        fallback: fallback ?? this.fallback,
      );

  Map<String, Object?> toJson() => {'enabled': enabled, 'threshold': threshold, 'fallback': fallback};

  /// A stored value of any earlier form. 2026-11-17 stored {"min": x} (0 = off, > 0 = on with that minimum, remote).
  static ConfidenceSettings parse(Object? raw) {
    if (raw is Map) {
      if (raw.containsKey('enabled') || raw.containsKey('threshold')) {
        final t = raw['threshold'];
        final f = raw['fallback'];
        return ConfidenceSettings(
          enabled: raw['enabled'] == true,
          threshold: t is num ? snapThreshold(t.toDouble()) : defaults.threshold,
          fallback: confidenceFallbacks.contains(f) ? f as String : defaults.fallback,
        );
      }
      final m = raw['min'];
      if (m is num && m > 0) return ConfidenceSettings(enabled: true, threshold: snapThreshold(m.toDouble()), fallback: 'remote');
    }
    return defaults;
  }

  @override
  bool operator ==(Object other) =>
      other is ConfidenceSettings && other.enabled == enabled && other.threshold == threshold && other.fallback == fallback;

  @override
  int get hashCode => Object.hash(enabled, threshold, fallback);
}

/// Rounds to the 0.05 grid and clamps to 0..1 (no float noise: 0.9 stays 0.9).
double snapThreshold(double value) {
  if (value.isNaN || value.isInfinite) return ConfidenceSettings.defaults.threshold;
  final v = value.clamp(0.0, 1.0);
  return (v / confidenceStep).round() * 5 / 100;
}

/// "0.90 / 90%"
String formatThreshold(double value) {
  final v = snapThreshold(value);
  return '${v.toStringAsFixed(2)} / ${(v * 100).round()}%';
}

const _messages = {
  'en': {
    'clarify': "I'm not sure I understood that. Could you say it again in other words?",
    'decline': "I'm not sure enough about that one, so I didn't change anything.",
    'noRemote': "I'm not sure enough to do that here, and no remote assistant is set up, so I didn't change anything.",
  },
  'pt-BR': {
    'clarify': 'Não tenho certeza se entendi. Pode repetir de outro jeito?',
    'decline': 'Não tenho certeza suficiente sobre esse comando, então não mudei nada.',
    'noRemote': 'Não tenho certeza suficiente para fazer isso aqui e não há um assistente remoto configurado, então não mudei nada.',
  },
};

/// What the agent core gets (configure {"confidence": ...}); the threshold is sent even when OFF, so switching ON restores it.
Map<String, Object?> toCoreConfidence(ConfidenceSettings s, String language) => {
      'enabled': s.enabled,
      'min': snapThreshold(s.threshold),
      'fallback': s.fallback,
      'messages': {
        for (final e in (language.toLowerCase().startsWith('pt') ? _messages['pt-BR'] : _messages['en'])!.entries)
          // Basic languages (car/basic_language.dart) have their own sentences
          e.key: basicMessage(language, {'clarify': 'lowClarify', 'decline': 'lowDecline', 'noRemote': 'lowNoRemote'}[e.key]!) ?? e.value,
      },
    };

const outcomeLabels = {
  'executed': 'Executed',
  'clarified': 'Clarified',
  'declined': 'Declined',
  'remote': 'Routed to remote',
  'ignored': 'Ignored',
  'answered': 'Answered',
};

/// What happened to a request and the model's score for its action (core result "outcome" / "confidence"; older cores have neither).
class TurnInfo {
  const TurnInfo({this.outcome, this.value, this.low = false, this.unavailable = false, this.measured = false});
  final String? outcome;
  final double? value;
  final bool low;
  final bool unavailable;
  final bool measured;

  static TurnInfo read(Map<String, Object?> json) {
    final o = json['outcome'];
    final c = json['confidence'];
    final outcome = o is String && outcomeLabels.containsKey(o) ? o : null;
    if (c is Map) {
      final v = c['value'];
      return TurnInfo(outcome: outcome, value: v is num ? v.toDouble() : null, low: c['low'] == true, unavailable: c['unavailable'] == true, measured: true);
    }
    return TurnInfo(outcome: outcome);
  }

  /// "Model score 0.93 (93%)" / "Model score unavailable" / ""
  String get score {
    if (!measured) return '';
    if (value == null) return unavailable ? 'Model score unavailable' : '';
    return 'Model score ${value!.toStringAsFixed(2)} (${(value! * 100).round()}%)';
  }

  /// "Executed · Model score 0.93 (93%)"
  String get line {
    if (outcome == null) return '';
    final parts = [outcomeLabels[outcome]!, if (low) 'held back by Local confidence', if (score.isNotEmpty) score];
    return parts.join(' · ');
  }
}

/// ON / OFF, the threshold (0.00 .. 1.00 in 0.05 steps, shown as "0.90 / 90%"), and the fallback. OFF keeps today's behaviour; the
/// safety checks apply either way.
class ConfidenceControls extends StatelessWidget {
  const ConfidenceControls({super.key, required this.value, required this.onChanged, this.disabled = false});

  final ConfidenceSettings value;
  final ValueChanged<ConfidenceSettings> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(color: Color(0xFFF9FAFB), fontSize: 14, fontWeight: FontWeight.w700);
    const muted = TextStyle(color: Color(0xFFAAB2BA), fontSize: 12);
    final off = !value.enabled;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF0D1411), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Local confidence', style: label),
                Text(value.enabled ? 'On · ${formatThreshold(value.threshold)}' : 'Off · every command is checked by the safety rules only', style: muted),
              ]),
            ),
            Semantics(
              label: 'Local confidence on or off',
              child: Switch(value: value.enabled, onChanged: disabled ? null : (v) => onChanged(value.copyWith(enabled: v))),
            ),
          ]),
          Opacity(
            opacity: off ? 0.45 : 1,
            child: Row(children: [
              Expanded(
                child: Slider(
                  value: snapThreshold(value.threshold),
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: formatThreshold(value.threshold),
                  semanticFormatterCallback: formatThreshold,
                  onChanged: disabled ? null : (v) => onChanged(value.copyWith(threshold: v)),
                ),
              ),
              SizedBox(
                width: 86,
                child: Text(formatThreshold(value.threshold), textAlign: TextAlign.right, style: label.copyWith(fontSize: 13)),
              ),
            ]),
          ),
          Opacity(
            opacity: off ? 0.45 : 1,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Below the threshold the action does not run:', style: muted),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                for (final f in confidenceFallbacks)
                  ChoiceChip(
                    label: Text(confidenceFallbackLabels[f]!),
                    selected: value.fallback == f,
                    onSelected: disabled ? null : (_) => onChanged(value.copyWith(fallback: f)),
                  ),
              ]),
              Text(confidenceFallbackDetails[value.fallback] ?? '', style: muted),
            ]),
          ),
          const SizedBox(height: 6),
          const Text(
            "The score is the model's own estimate, not a guaranteed probability that the action is right. Unsafe or unsupported commands "
            'are blocked whatever this setting is.',
            style: TextStyle(color: Color(0xFFAAB2BA), fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }
}
