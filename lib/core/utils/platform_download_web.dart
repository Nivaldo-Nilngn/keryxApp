// platform_download_web.dart
import 'dart:html' as html;

void triggerBrowserDownload(String url, {String? fileName}) {
  final directUrl = url.contains('github.com')
      ? 'https://keryx-version.nivaldo-nilngn.workers.dev/download'
      : url;

  final iframe = html.IFrameElement()
    ..src = directUrl
    ..style.display = "none";

  html.document.body?.append(iframe);

  Future.delayed(const Duration(seconds: 30), () {
    iframe.remove();
  });
}
