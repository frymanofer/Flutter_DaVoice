/// Coalesces Android partial/final results with the same overlap and punctuation
/// policy as the reference example's src/stt/index.ts.
String mergeTranscript(String previous, String current) {
  final prev = previous.trim();
  final curr = current.trim();
  if (prev.isEmpty) return curr;
  if (curr.isEmpty) return prev;
  if (curr.startsWith(prev)) return curr;
  if (prev.startsWith(curr)) return prev;
  String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^A-Za-z0-9\s]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final np = normalize(prev), nc = normalize(curr);
  if (nc.startsWith(np)) return curr;
  final words = RegExp(r'[A-Za-z0-9]+');
  final pw = words
      .allMatches(prev)
      .map((m) => m.group(0)!.toLowerCase())
      .toList();
  final spans = words.allMatches(curr).toList();
  final cw = spans.map((m) => m.group(0)!.toLowerCase()).toList();
  for (var k = pw.length < cw.length ? pw.length : cw.length; k >= 2; k--) {
    if (List.generate(
      k,
      (i) => pw[pw.length - k + i] == cw[i],
    ).every((v) => v)) {
      final tail = curr.substring(spans[k - 1].end);
      var left = prev;
      final last = RegExp(r'[?!]+$').firstMatch(prev);
      final first = RegExp(r'^[?!]+').firstMatch(tail);
      if (last != null &&
          first != null &&
          last.group(0)![0] == first.group(0)![0]) {
        left = prev.substring(0, last.start);
      }
      final space =
          RegExp(r'[A-Za-z0-9]$').hasMatch(left) &&
          RegExp(r'^[A-Za-z0-9]').hasMatch(tail);
      return '$left${space ? ' ' : ''}$tail';
    }
  }
  return nc.length >= np.length ? curr : prev;
}

/// Preserves existing sentence boundaries when normalizing model output for TTS.
String normalizeTextForSpeech(String text) {
  return text
      .replaceAllMapped(RegExp(r'\s*\n+\s*'), (match) {
        final before = text.substring(0, match.start).trimRight();
        final after = text.substring(match.end).trimLeft();
        return RegExp(r'[.!?,:;]$').hasMatch(before) ||
                RegExp(r'^[.!?,:;]').hasMatch(after)
            ? ' '
            : '. ';
      })
      .replaceAllMapped(RegExp(r'\s+([.!?,:;])'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'([.!?,:;]){2,}'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}
