// platform_download_web.dart
import 'platform_utils.dart';

void triggerBrowserDownload(String url, {String? fileName}) {
  downloadFile(url, fileName: fileName ?? 'keryxApp.apk');
}
