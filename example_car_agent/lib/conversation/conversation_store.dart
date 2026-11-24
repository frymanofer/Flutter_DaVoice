import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'conversation_settings.dart';

// The conversation settings survive a restart: one small JSON file in the app's documents folder (the same file name
// and shape as the React Native apps).
Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/conversation_settings.json');

Future<ConversationSettings> loadConversationSettings() async {
  try {
    final file = await _file();
    if (!await file.exists()) return defaultConversationSettings;
    return normalizeConversationSettings(jsonDecode(await file.readAsString()));
  } catch (error) {
    debugPrint('[Conversation] settings could not be read, using the defaults: $error');
    return defaultConversationSettings;
  }
}

Future<void> saveConversationSettings(ConversationSettings settings) async {
  try {
    await (await _file()).writeAsString(jsonEncode(settings.toJson()));
  } catch (error) {
    debugPrint('[Conversation] settings could not be saved: $error');
  }
}
