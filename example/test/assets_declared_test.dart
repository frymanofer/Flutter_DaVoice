import 'dart:io';

import 'package:flutter_davoice_example/agent/agent_pack.dart';
import 'package:flutter_test/flutter_test.dart';

// Flutter asset folders are not recursive: a file is bundled only when its own folder (or the file) is listed in pubspec.yaml.
// The tests read the packs from disk, so check that every file the app loads at startup is really declared.
void main() {
  test('every agent pack file the app loads is declared in pubspec.yaml', () async {
    final declared = RegExp(r'^\s+- (assets/\S+)', multiLine: true)
        .allMatches(File('pubspec.yaml').readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
    final read = <String>[];
    await loadAgentPacks(readFile: (path) {
      read.add(path);
      return File(path).readAsString();
    });
    final missing = read.where((path) => !declared.contains(path) && !declared.contains('${File(path).parent.path}/')).toList();
    expect(missing, isEmpty);
    expect(read, contains('assets/agent_automotive/pt-BR/agent.json'));
  });
}
