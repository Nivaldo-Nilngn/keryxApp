// platform_utils_stub.dart
import 'package:flutter/foundation.dart';

const kWorkerBase = 'https://keryx-version.nivaldo-nilngn.workers.dev';

bool isIpadClient() => false;

bool isIphoneClient() => false;

bool isIosClient() => defaultTargetPlatform == TargetPlatform.iOS;

bool isAndroidClient() => defaultTargetPlatform == TargetPlatform.android;

bool isStandalonePwa() => false;

bool isInAppBrowser() => false;

void downloadFile(String url, {String fileName = 'keryxApp.apk'}) {
  // Em plataformas não-web, tratado nativamente
}

void downloadBytes(Uint8List bytes, String fileName, String mimeType) {
  // Em plataformas não-web, tratado nativamente
}
