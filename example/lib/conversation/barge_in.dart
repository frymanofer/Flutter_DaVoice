// Interrupt mode: is speech heard while the agent talks the user interrupting, or only the agent's own voice leaking
// past echo cancellation? A word the agent is not saying can only have come from the user, and one is enough; a
// window made only of the agent's words is echo. The same rule and fixture as the React Native apps
// (src/conversation/bargeIn.ts, conversation_barge_in.json).

enum BargeInDecision { interrupt, echo, empty }

final _nonWord = RegExp(r"[^\p{L}\p{N}']+", unicode: true);

List<String> bargeInWords(String text) =>
    text.toLowerCase().replaceAll(_nonWord, ' ').split(' ').where((w) => w.isNotEmpty).toList();

BargeInDecision resolveBargeIn(String heard, String agentText) {
  final words = bargeInWords(heard);
  if (words.isEmpty) return BargeInDecision.empty;
  final agentWords = bargeInWords(agentText).toSet();
  return words.every(agentWords.contains) ? BargeInDecision.echo : BargeInDecision.interrupt;
}
