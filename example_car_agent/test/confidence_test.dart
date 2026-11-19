import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_davoice_car_agent/local_llm/confidence.dart';

void main() {
  test('defaults: OFF, 0.90, clarify', () {
    expect(ConfidenceSettings.defaults, const ConfidenceSettings(enabled: false, threshold: 0.9, fallback: 'clarify'));
  });

  test('snaps to 0.05 steps and clamps to 0..1', () {
    expect(snapThreshold(0.9), 0.9);
    expect(snapThreshold(0.87), 0.85);
    expect(snapThreshold(0.88), 0.9);
    expect(snapThreshold(-1), 0.0);
    expect(snapThreshold(3), 1.0);
    expect(snapThreshold(double.nan), 0.9);
  });

  test('shows the threshold as a decimal and a percentage', () {
    expect(formatThreshold(0.9), '0.90 / 90%');
    expect(formatThreshold(0), '0.00 / 0%');
    expect(formatThreshold(1), '1.00 / 100%');
  });

  test('reads the 2026-11-17 file and unknown values', () {
    expect(ConfidenceSettings.parse({'min': 0}), ConfidenceSettings.defaults);
    expect(ConfidenceSettings.parse({'min': 0.8}), const ConfidenceSettings(enabled: true, threshold: 0.8, fallback: 'remote'));
    expect(ConfidenceSettings.parse({'enabled': true, 'threshold': 0.62, 'fallback': 'decline'}),
        const ConfidenceSettings(enabled: true, threshold: 0.6, fallback: 'decline'));
    expect(ConfidenceSettings.parse({'enabled': 'yes', 'threshold': 0.9, 'fallback': 'guess'}), ConfidenceSettings.defaults);
    expect(ConfidenceSettings.parse(null), ConfidenceSettings.defaults);
  });

  test('core configuration in the app language; threshold kept when OFF', () {
    final off = toCoreConfidence(const ConfidenceSettings(enabled: false, threshold: 0.8, fallback: 'remote'), 'pt-BR');
    expect(off['enabled'], false);
    expect(off['min'], 0.8);
    expect((off['messages'] as Map)['clarify'], contains('Pode repetir'));
  });

  test('reads the turn outcome and score; older cores give neither', () {
    final t = TurnInfo.read({'outcome': 'executed', 'confidence': {'value': 0.934, 'low': false}});
    expect(t.line, 'Executed · Model score 0.93 (93%)');
    final held = TurnInfo.read({'outcome': 'declined', 'confidence': {'value': null, 'low': true, 'unavailable': true}});
    expect(held.line, 'Declined · held back by Local confidence · Model score unavailable');
    expect(TurnInfo.read({'text': 'Done.'}).line, '');
  });
}
