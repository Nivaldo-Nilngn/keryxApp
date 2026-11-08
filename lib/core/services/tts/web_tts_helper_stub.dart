import 'dart:ui';

class WebTtsHelper {
  static bool get isSupported => false;

  static void speakQueue({
    required List<String> texts,
    required VoidCallback onStart,
    required VoidCallback onFinished,
    required VoidCallback onError,
  }) {}

  static void stop() {}
}
