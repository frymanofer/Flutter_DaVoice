package com.davoice.flutter_davoice_example

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import kotlin.math.abs

/**
 * The voice sample for voice cloning (createVoiceClone), the RN example's
 * VoiceRecorderModule. Dart: MethodChannel('davoice_example/voice_recorder').
 *
 * Records the microphone to a 16-bit mono WAV file:
 * start(path) -> path; status() -> {recording, seconds, peak 0..1};
 * stop() -> {path, seconds}; cancel() deletes the file.
 * The app pauses the wake word microphone first.
 *
 * pickAudioFile() -> {path, name} (a copy in the app's cache) or null when the
 * user cancels: the system file picker, audio files only.
 */
class VoiceRecorder(private val activity: Activity) : MethodChannel.MethodCallHandler {

  // The microphone hardware's native rate; the TTS library resamples the WAV
  // to the model rate itself (windowed sinc).
  private val sampleRate = 48000
  @Volatile private var recording = false
  @Volatile private var dataBytes = 0L
  @Volatile private var peak = 0f
  private var thread: Thread? = null
  private var record: AudioRecord? = null
  private var file: File? = null
  private var pickResult: MethodChannel.Result? = null
  private val mainHandler = Handler(Looper.getMainLooper())

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "start" -> start(call.argument<String>("path"), result)
      "status" -> result.success(mapOf(
        "recording" to recording,
        "seconds" to dataBytes / 2.0 / sampleRate,
        "peak" to peak.toDouble(),
      ))
      "stop" -> stop(result)
      "cancel" -> {
        val out = file
        try { finish() } catch (_: Throwable) {}
        out?.delete()
        result.success(null)
      }
      "pickAudioFile" -> pickAudioFile(result)
      else -> result.notImplemented()
    }
  }

  private fun pickAudioFile(result: MethodChannel.Result) {
    if (pickResult != null) {
      result.error("BUSY", "The file picker is already open.", null)
      return
    }
    pickResult = result
    try {
      val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
        .addCategory(Intent.CATEGORY_OPENABLE)
        .setType("audio/*")
      activity.startActivityForResult(intent, PICK_AUDIO_REQUEST)
    } catch (t: Throwable) {
      pickResult = null
      result.error("PICK_FAILED", t.message ?: "The file picker could not be opened.", null)
    }
  }

  /** From MainActivity.onActivityResult; true when it was the file picker's. */
  fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode != PICK_AUDIO_REQUEST) return false
    val result = pickResult ?: return true
    pickResult = null
    val uri = data?.data
    if (resultCode != Activity.RESULT_OK || uri == null) {
      result.success(null)
      return true
    }
    Thread {
      try {
        val picked = copyToCache(uri)
        mainHandler.post { result.success(picked) }
      } catch (t: Throwable) {
        mainHandler.post { result.error("PICK_FAILED", t.message ?: "The file could not be read.", null) }
      }
    }.start()
    return true
  }

  private fun copyToCache(uri: Uri): Map<String, String> {
    val resolver = activity.contentResolver
    var name = "voice_sample"
    resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
      if (cursor.moveToFirst() && !cursor.isNull(0)) name = cursor.getString(0)
    }
    val safeName = name.replace(Regex("[^A-Za-z0-9._ -]"), "_")
    val folder = File(activity.cacheDir, "voice_clone_upload").apply {
      deleteRecursively()
      mkdirs()
    }
    val out = File(folder, safeName)
    resolver.openInputStream(uri)?.use { input ->
      FileOutputStream(out).use { output -> input.copyTo(output) }
    } ?: throw IllegalStateException("The file could not be opened.")
    return mapOf("path" to out.absolutePath, "name" to name)
  }

  private fun start(path: String?, result: MethodChannel.Result) {
    if (path.isNullOrBlank()) {
      result.error("INVALID_ARGS", "start(path)", null)
      return
    }
    if (recording) {
      result.error("BUSY", "Already recording.", null)
      return
    }
    if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      result.error("NO_PERMISSION", "Microphone permission is not granted.", null)
      return
    }
    try {
      val minBuffer = AudioRecord.getMinBufferSize(
        sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
      val bufferSize = maxOf(minBuffer, sampleRate / 5 * 2)  // >= 200 ms
      val rec = AudioRecord(
        MediaRecorder.AudioSource.VOICE_RECOGNITION, sampleRate,
        AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, bufferSize)
      if (rec.state != AudioRecord.STATE_INITIALIZED) {
        rec.release()
        result.error("MIC_UNAVAILABLE", "The microphone could not be opened.", null)
        return
      }
      val out = File(path.removePrefix("file://"))
      out.parentFile?.mkdirs()
      val stream = FileOutputStream(out)
      stream.write(ByteArray(44))  // header, written on stop
      record = rec
      file = out
      dataBytes = 0
      peak = 0f
      recording = true
      rec.startRecording()
      thread = Thread {
        val buffer = ShortArray(bufferSize / 2)
        val bytes = ByteArray(buffer.size * 2)
        try {
          while (recording) {
            val n = rec.read(buffer, 0, buffer.size)
            if (n <= 0) continue
            var max = 0
            for (i in 0 until n) {
              val s = buffer[i].toInt()
              max = maxOf(max, abs(s))
              bytes[2 * i] = (s and 0xff).toByte()
              bytes[2 * i + 1] = ((s shr 8) and 0xff).toByte()
            }
            peak = max / 32768f
            stream.write(bytes, 0, n * 2)
            dataBytes += n * 2
          }
        } finally {
          stream.close()
        }
      }.also { it.start() }
      result.success(out.absolutePath)
    } catch (t: Throwable) {
      recording = false
      result.error("RECORD_FAILED", t.message, null)
    }
  }

  private fun stop(result: MethodChannel.Result) {
    val out = file
    if (out == null) {
      result.error("NOT_RECORDING", "Nothing is being recorded.", null)
      return
    }
    try {
      finish()
      writeHeader(out, dataBytes)
      result.success(mapOf("path" to out.absolutePath, "seconds" to dataBytes / 2.0 / sampleRate))
    } catch (t: Throwable) {
      result.error("RECORD_FAILED", t.message, null)
    }
  }

  private fun finish() {
    recording = false
    try { record?.stop() } catch (_: Throwable) {}
    thread?.join(2000)
    record?.release()
    record = null
    thread = null
    file = null
  }

  private fun writeHeader(out: File, data: Long) {
    RandomAccessFile(out, "rw").use { f ->
      fun int(v: Long) = byteArrayOf(v.toByte(), (v shr 8).toByte(), (v shr 16).toByte(), (v shr 24).toByte())
      fun short(v: Int) = byteArrayOf(v.toByte(), (v shr 8).toByte())
      f.seek(0)
      f.write("RIFF".toByteArray()); f.write(int(36 + data)); f.write("WAVE".toByteArray())
      f.write("fmt ".toByteArray()); f.write(int(16)); f.write(short(1)); f.write(short(1))
      f.write(int(sampleRate.toLong())); f.write(int(sampleRate * 2L)); f.write(short(2)); f.write(short(16))
      f.write("data".toByteArray()); f.write(int(data))
    }
  }

  fun dispose() {
    try { finish() } catch (_: Throwable) {}
  }

  private companion object {
    const val PICK_AUDIO_REQUEST = 47211
  }
}
