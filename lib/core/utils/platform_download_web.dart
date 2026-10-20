// platform_download_web.dart
import 'dart:html' as html;

void triggerBrowserDownload(String url, {String? fileName}) {
  final directUrl = url.contains('github.com')
      ? 'https://keryx-version.nivaldo-nilngn.workers.dev/download'
      : url;

  final anchor = html.AnchorElement(href: directUrl)
    ..setAttribute("download", fileName ?? "keryxApp.apk")
    ..target = "_self"
    ..style.display = "none";

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
