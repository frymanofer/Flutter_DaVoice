// The title to play is the driver's own words when the model copied it wrong (lib/car/media_query.dart). Same cases as the RN car
// app's __tests__/mediaQuery.test.ts (test/fixtures/media_query.json, kept identical).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_davoice_car_agent/car/media_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the RN car app and this app share the same cases', () {
    final rn = File('../../ReactNative_DaVoice/example_car_agent/__tests__/fixtures/media_query.json');
    if (rn.existsSync()) expect(File('test/fixtures/media_query.json').readAsStringSync(), rn.readAsStringSync());
  });

  test('every case of the shared fixture', () {
    final cases = (jsonDecode(File('test/fixtures/media_query.json').readAsStringSync()) as List).cast<Map>();
    final diffs = <String>[];
    for (final c in cases) {
      final got = groundMediaQuery(c['query'] as String, c['user'] as String);
      if (got != c['expect']) diffs.add('"${c['user']}" + "${c['query']}": got "$got", want "${c['expect']}"');
    }
    expect(diffs, isEmpty);
  });
}
