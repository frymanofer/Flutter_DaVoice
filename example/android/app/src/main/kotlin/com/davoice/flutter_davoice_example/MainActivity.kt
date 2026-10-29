package com.davoice.flutter_davoice_example

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  // Voice cloning's microphone recording and file picker (VoiceRecorder.kt).
  private var voiceRecorder: VoiceRecorder? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val recorder = VoiceRecorder(this)
    voiceRecorder = recorder
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "davoice_example/voice_recorder")
      .setMethodCallHandler(recorder)
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    voiceRecorder?.dispose()
    voiceRecorder = null
    super.cleanUpFlutterEngine(flutterEngine)
  }

  @Deprecated("Deprecated in Java")
  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    if (voiceRecorder?.onActivityResult(requestCode, resultCode, data) == true) return
    super.onActivityResult(requestCode, resultCode, data)
  }
}
