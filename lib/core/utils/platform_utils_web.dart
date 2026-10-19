// platform_utils_web.dart
import 'dart:html' as html;
import 'dart:typed_data';

bool isIosClient() {
  final ua = (html.window.navigator.userAgent).toLowerCase();
  final platform = (html.window.navigator.platform ?? '').toLowerCase();
  
  return ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod') ||
      platform.contains('iphone') ||
      platform.contains('ipad') ||
      platform.contains('ipod') ||
      (ua.contains('macintosh') && (html.window.navigator.maxTouchPoints ?? 0) > 1);
}

bool isAndroidClient() {
  final ua = (html.window.navigator.userAgent).toLowerCase();
  final platform = (html.window.navigator.platform ?? '').toLowerCase();
  return ua.contains('android') || platform.contains('android');
}

void downloadFile(String url) {
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", "keryxApp.apk")
    ..style.display = "none";

  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}

void downloadBytes(Uint8List bytes, String fileName, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..style.display = "none";

  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  html.Url.revokeObjectUrl(url);
}
