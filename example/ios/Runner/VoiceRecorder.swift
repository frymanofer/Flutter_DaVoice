// The voice sample for voice cloning (createVoiceClone), the RN example's
// VoiceRecorder.m. Dart: MethodChannel('davoice_example/voice_recorder').
//
// Records the microphone to a 16-bit mono WAV file:
// start(path) -> path; status() -> {recording, seconds, peak 0..1};
// stop() -> {path, seconds}; cancel() deletes the file.
//
// pickAudioFile() -> {path, name} (a copy in the app's caches) or nil when the
// user cancels: the system file picker, audio files only.
//
// The audio session the DaVoice libraries set up (play and record) is kept;
// it is changed only when it cannot record.

import AVFoundation
import Flutter
import UIKit
import UniformTypeIdentifiers

final class VoiceRecorder: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private var recorder: AVAudioRecorder?
  private var pickResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "davoice_example/voice_recorder",
                                       binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(VoiceRecorder(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      start((call.arguments as? [String: Any])?["path"] as? String, result: result)
    case "status":
      var peak = 0.0
      if let recorder, recorder.isRecording {
        recorder.updateMeters()
        peak = pow(10.0, Double(recorder.peakPower(forChannel: 0)) / 20.0)
      }
      result([
        "recording": recorder?.isRecording ?? false,
        "seconds": recorder?.currentTime ?? 0,
        "peak": min(1.0, max(0.0, peak)),
      ])
    case "stop":
      guard let recorder else {
        result(FlutterError(code: "NOT_RECORDING", message: "Nothing is being recorded.", details: nil))
        return
      }
      let seconds = recorder.currentTime
      recorder.stop()
      self.recorder = nil
      result(["path": recorder.url.path, "seconds": seconds])
    case "cancel":
      let recorder = self.recorder
      self.recorder = nil
      recorder?.stop()
      recorder?.deleteRecording()
      result(nil)
    case "pickAudioFile":
      pickAudioFile(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(_ path: String?, result: @escaping FlutterResult) {
    guard let path, !path.isEmpty else {
      result(FlutterError(code: "INVALID_ARGS", message: "start(path)", details: nil))
      return
    }
    if recorder?.isRecording == true {
      result(FlutterError(code: "BUSY", message: "Already recording.", details: nil))
      return
    }
    let session = AVAudioSession.sharedInstance()
    if session.recordPermission != .granted {
      result(FlutterError(code: "NO_PERMISSION", message: "Microphone permission is not granted.", details: nil))
      return
    }
    if session.category != .playAndRecord && session.category != .record {
      try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
    }
    try? session.setActive(true)

    let filePath = path.hasPrefix("file://") ? String(path.dropFirst(7)) : path
    try? FileManager.default.createDirectory(atPath: (filePath as NSString).deletingLastPathComponent,
                                             withIntermediateDirectories: true)
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
    ]
    let recorder: AVAudioRecorder
    do {
      recorder = try AVAudioRecorder(url: URL(fileURLWithPath: filePath), settings: settings)
    } catch {
      result(FlutterError(code: "RECORD_FAILED", message: error.localizedDescription, details: nil))
      return
    }
    recorder.isMeteringEnabled = true
    guard recorder.prepareToRecord(), recorder.record() else {
      result(FlutterError(code: "MIC_UNAVAILABLE", message: "The microphone could not be opened.", details: nil))
      return
    }
    self.recorder = recorder
    result(filePath)
  }

  private func pickAudioFile(result: @escaping FlutterResult) {
    if pickResult != nil {
      result(FlutterError(code: "BUSY", message: "The file picker is already open.", details: nil))
      return
    }
    guard let presenter = Self.topViewController() else {
      result(FlutterError(code: "NO_PRESENTER", message: "The file picker could not be shown.", details: nil))
      return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    pickResult = result
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pickResult else { return }
    pickResult = nil
    guard let picked = urls.first else {
      result(nil)
      return
    }
    let files = FileManager.default
    let caches = files.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let folder = caches.appendingPathComponent("voice_clone_upload")
    try? files.removeItem(at: folder)
    try? files.createDirectory(at: folder, withIntermediateDirectories: true)
    let name = picked.lastPathComponent.isEmpty ? "voice_sample" : picked.lastPathComponent
    let target = folder.appendingPathComponent(name)
    do {
      try files.copyItem(at: picked, to: target)
      result(["path": target.path, "name": name])
    } catch {
      result(FlutterError(code: "PICK_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = pickResult
    pickResult = nil
    result?(nil)
  }

  private static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
