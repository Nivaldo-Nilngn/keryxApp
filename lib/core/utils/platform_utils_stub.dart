// platform_utils_stub.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

bool isIosClient() {
  return defaultTargetPlatform == TargetPlatform.iOS;
}

bool isAndroidClient() {
  return defaultTargetPlatform == TargetPlatform.android;
}

void downloadFile(String url) {
  // Em plataformas não-web (Android/iOS), este arquivo não faz nada.
}

void downloadBytes(Uint8List bytes, String fileName, String mimeType) {
  // Em plataformas não-web (Android/iOS), este arquivo não faz nada.
}

void downloadFileWithProgress(
  String url, {
  required void Function(int received, int total) onProgress,
  required void Function() onDone,
  required void Function(String error) onError,
}) {
  // Em plataformas não-web, o download nativo é tratado via Dio
}
