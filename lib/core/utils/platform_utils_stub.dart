// platform_utils_stub.dart
import 'package:flutter/foundation.dart';

const kWorkerBase = 'https://keryx-version.nivaldo-nilngn.workers.dev';

bool isIpadClient() => false;

bool isIphoneClient() => false;

bool isIosClient() => defaultTargetPlatform == TargetPlatform.iOS;

bool isAndroidClient() => defaultTargetPlatform == TargetPlatform.android;

bool isStandalonePwa() => false;

bool isInAppBrowser() => false;

typedef DownloadProgressCallback = void Function(double progress, int loaded, int total);

Future<bool> downloadFile(
  String url, {
  String fileName = 'keryxApp.apk',
  DownloadProgressCallback? onProgress,
}) async => false;

void downloadBytes(Uint8List bytes, String fileName, String mimeType) {
  // Em plataformas não-web, tratado nativamente
}
