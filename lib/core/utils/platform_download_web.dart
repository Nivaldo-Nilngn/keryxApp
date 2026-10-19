// platform_download_web.dart
import 'dart:html' as html;

void triggerBrowserDownload(String url, {String? fileName}) {
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName ?? "keryxApp.apk")
    ..style.display = "none";

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
