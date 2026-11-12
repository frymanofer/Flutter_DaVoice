import 'dart:async';
import 'dart:io';

import 'dart:convert';

import 'package:flutter_davoice_example/agent/agent_pack.dart';
import 'package:flutter_davoice_example/tts/language_packs.dart';

/// Loads the agent pack (assets/agent/) and the language-pack config (assets/language_packs.json) from the files before every
/// test file. Downloaded packs go to a temporary folder (none are downloaded: tests never use the network).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAgentPacks(readFile: (path) => File(path).readAsString());
  await loadLanguagePacks(
    config: LanguagePackConfig.fromJson(jsonDecode(File('assets/language_packs.json').readAsStringSync()) as Map<String, dynamic>),
    documents: Directory.systemTemp.createTempSync('davoice_language_packs'),
  );
  await testMain();
}
