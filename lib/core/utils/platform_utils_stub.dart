// platform_utils_stub.dart
import 'package:flutter/foundation.dart';

const kWorkerBase = 'https://keryx-version.nivaldo-nilngn.workers.dev';

bool isIosClient() {
  return defaultTargetPlatform == TargetPlatform.iOS;
}

bool isAndroidClient() {
  return defaultTargetPlatform == TargetPlatform.android;
}

bool isStandalonePwa() => false;

bool isInAppBrowser() => false;

void downloadFile(String url, {String fileName = 'keryxApp.apk'}) {
  // Em plataformas não-web (Android/iOS), o download é gerenciado nativamente
}

void downloadBytes(Uint8List bytes, String fileName, String mimeType) {
  // Em plataformas não-web, tratado por serviços de arquivo locais
}
