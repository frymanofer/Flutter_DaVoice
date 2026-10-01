/// Coordinates narration skip with native stop completion. A skip while the
/// model is loading is remembered without sending stop into initialization.
class StartupNarration {
  bool skipped = false;
  bool _speaking = false;
  Future<void>? _stop;

  Future<void> skip(Future<void> Function() stopSpeaking) async {
    if (skipped) {
      await _stop;
      return;
    }
    skipped = true;
    if (!_speaking) return;
    _stop = Future<void>.sync(stopSpeaking);
    await _stop;
  }

  Future<void> speak(
    List<String> lines, {
    required Future<void> Function(String) speakLine,
    required bool Function() isActive,
  }) async {
    for (final line in lines) {
      if (skipped || !isActive()) break;
      _speaking = true;
      try {
        await speakLine(line);
      } catch (_) {
        if (!skipped) rethrow;
      } finally {
        // The public speak waiter may resolve before native stop finishes.
        try {
          await _stop;
        } finally {
          _speaking = false;
        }
      }
    }
  }
}
