import 'dart:async';
import 'dart:io';

import 'package:flutter_davoice_example/agent/agent_pack.dart';

/// Loads the agent pack (assets/agent/) from the files before every test file.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAgentPack(readFile: (path) => File(path).readAsString());
  await testMain();
}
