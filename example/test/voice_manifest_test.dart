import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_davoice_example/tts/language_packs.dart';
import 'package:flutter_test/flutter_test.dart';

// The remote voice manifest (lib/tts/language_packs.dart verifyManifest; same rules as the RN example's voiceManifest.test.ts): applied
// only when signed by the right key, of a schema this app reads, and every entry valid; never for built-in or unknown languages.
void main() {
  final algorithm = Ed25519();
  Map<String, Object> entry(String file) => {'file': file, 'bytes': 1000, 'sha256': 'a' * 64};
  final fr = {'model': entry('model_ex2_french_v2.dm'), 'embedder': entry('embedder_fr_v2.dm')};

  Future<(String, String)> keys(int seed) async {
    final pair = await algorithm.newKeyPairFromSeed(List.filled(32, seed));
    final pub = await pair.extractPublicKey();
    return (base64Encode(pub.bytes), seed.toString());
  }

  Future<String> signed(Map<String, Object> payload, int seed) async {
    final text = jsonEncode(payload);
    final pair = await algorithm.newKeyPairFromSeed(List.filled(32, seed));
    final sig = await algorithm.sign(utf8.encode(text), keyPair: pair);
    return jsonEncode({'payload': text, 'signature': base64Encode(sig.bytes)});
  }

  test('a valid signed manifest is applied to downloaded languages only', () async {
    final (pub, _) = await keys(7);
    final m = await verifyManifest(await signed({'schema': 1, 'version': '2026-11-12.1', 'languages': {'fr': fr, 'en': fr, 'xx': fr}}, 7), publicKey: pub);
    expect(m?.version, '2026-11-12.1');
    expect(m!.languages.keys, ['fr']);
    expect(m.languages['fr']!['model']!.filename, 'model_ex2_french_v2.dm');
  });

  test('the wrong key, a changed payload or a missing signature is rejected', () async {
    final (pub, _) = await keys(7);
    expect(await verifyManifest(await signed({'schema': 1, 'version': 'v', 'languages': {'fr': fr}}, 9), publicKey: pub), isNull);
    final good = jsonDecode(await signed({'schema': 1, 'version': 'v', 'languages': {'fr': fr}}, 7)) as Map<String, dynamic>;
    good['payload'] = (good['payload'] as String).replaceFirst('1000', '2000');
    expect(await verifyManifest(jsonEncode(good), publicKey: pub), isNull);
    expect(await verifyManifest(jsonEncode({'payload': '{}'}), publicKey: pub), isNull);
    expect(await verifyManifest('not json', publicKey: pub), isNull);
  });

  test('an unknown schema or any invalid entry rejects the whole manifest', () async {
    final (pub, _) = await keys(7);
    expect(await verifyManifest(await signed({'schema': 2, 'version': 'v', 'languages': {'fr': fr}}, 7), publicKey: pub), isNull);
    Future<VerifiedManifest?> bad(Map<String, Object> x) async =>
        verifyManifest(await signed({'schema': 1, 'version': 'v', 'languages': {'fr': {...fr, ...x}}}, 7), publicKey: pub);
    expect(await bad({'model': entry('../../evil.dm')}), isNull);
    expect(await bad({'model': entry('code.js')}), isNull);
    expect(await bad({'embedder': {'file': 'e.dm', 'bytes': -1, 'sha256': 'a' * 64}}), isNull);
    expect(await bad({'embedder': {'file': 'e.dm', 'bytes': 10, 'sha256': 'xyz'}}), isNull);
  });

  test('the app ships the real public key: a test-signed manifest is rejected, the signing tool output verifies', () async {
    expect(await verifyManifest(await signed({'schema': 1, 'version': 'v', 'languages': {'fr': fr}}, 7)), isNull);
    final tool = File('/tmp/davoice_manifest_test.json');
    if (tool.existsSync()) {
      final m = await verifyManifest(tool.readAsStringSync());
      expect(m?.version, '2026-11-12.1');
      expect(m!.languages.keys.toSet(), {'da', 'de', 'el', 'es', 'fr', 'it', 'nl', 'pt-PT', 'sv'});
    }
  });
}
