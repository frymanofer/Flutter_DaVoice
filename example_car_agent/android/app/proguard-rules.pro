# Release builds shrink and rename Java classes (R8, Flutter's default). The DaVoice native libraries call back into Java by
# class name from C++ (JNI): ONNX Runtime throws ai.onnxruntime.OrtException, the speech / wake word / LLM libraries call their
# own listener classes. Renamed or removed, the app aborts ("JNI DETECTED ERROR ... java_class == null", 2026-11-12: wake word
# start on a Galaxy S20 when NNAPI was not available). Keep them as they are.
-keep class ai.onnxruntime.** { *; }
-keep class com.davoice.** { *; }
-dontwarn ai.onnxruntime.**
