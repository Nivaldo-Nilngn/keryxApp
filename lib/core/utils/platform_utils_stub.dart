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
  Map<String, String>? headers,
}) async => false;

void downloadBytes(Uint8List bytes, String fileName, String mimeType) {
  // Em plataformas não-web, tratado nativamente
}

String createBlobUrl(Uint8List bytes, [String mimeType = 'audio/mpeg']) => '';

void revokeBlobUrl(String url) {}
