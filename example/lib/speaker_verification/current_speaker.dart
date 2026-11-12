// Who spoke the user's current request, for actions only the car's owner may do (unlock_car, open_door: tool authorization scope
// "door_locks", see agent/local_agent.dart). Port of the RN example's src/speaker_verification/currentSpeaker.ts.
//
// flutter_davoice reports the verified speakers of a sentence in its STT results (speakerIds / speakerId) when speaker
// verification is on. The app records them per request and clears them after each turn.
//
// Policy: with speaker verification on, the enrolled owner's voice must be in the request. With it skipped, there is no way to
// tell voices apart: the demo allows it (logged), so the doors work without enrollment.

bool _gateOn = false;
String? _ownerId;
final Set<String> _heard = {};

/// Called when speaker verification is applied (enrolled or skipped).
void setSpeakerGate(bool enabled, String? enrolledOwnerId) {
  _gateOn = enabled && enrolledOwnerId != null;
  _ownerId = enrolledOwnerId;
  _heard.clear();
  // ignore: avoid_print
  print('[SVGate] ${_gateOn ? 'on: owner "$_ownerId"' : 'off: speaker verification skipped'}');
}

/// Every STT partial and final result.
void noteSpeechResult(List<String> speakerIds, String? speakerId) {
  _heard.addAll(speakerIds);
  if (speakerId != null) _heard.add(speakerId);
}

/// After a turn: the next request starts with nobody heard.
void clearHeardSpeakers() => _heard.clear();

/// May the current request do an owner-only action?
({bool allowed, String reason}) ownerMayAct() {
  if (!_gateOn) return (allowed: true, reason: 'speaker verification is off (demo allows it)');
  if (_ownerId != null && _heard.contains(_ownerId)) return (allowed: true, reason: 'owner "$_ownerId" verified');
  return (allowed: false, reason: _heard.isNotEmpty ? 'heard ${_heard.join(', ')}, not the owner' : 'no verified speaker in this request');
}
