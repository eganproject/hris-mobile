# TensorFlow Lite (tflite_flutter): delegate GPU tidak dipakai, tapi R8 mencarinya.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
# Google ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
