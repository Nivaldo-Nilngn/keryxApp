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
    ..target = "_blank"
    ..style.display = "none";

  html.document.body?.append(anchor);
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

void downloadFileWithProgress(
  String url, {
  required void Function(int received, int total) onProgress,
  required void Function() onDone,
  required void Function(String error) onError,
}) {
  final directUrl = url.contains('github.com')
      ? 'https://keryx-version.nivaldo-nilngn.workers.dev/download'
      : url;

  try {
    final request = html.HttpRequest();
    request.open('GET', directUrl);
    request.responseType = 'blob';

    request.onProgress.listen((event) {
      final loaded = event.loaded ?? 0;
      final total = event.lengthComputable ? (event.total ?? -1) : -1;
      onProgress(loaded, total);
    });

    request.onLoad.listen((event) {
      if (request.status == 200) {
        try {
          final blob = request.response as html.Blob;
          final blobUrl = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: blobUrl)
            ..setAttribute("download", "keryxApp.apk")
            ..target = "_self"
            ..style.display = "none";

          html.document.body?.append(anchor);
          anchor.click();
          anchor.remove();

          Future.delayed(const Duration(seconds: 15), () {
            html.Url.revokeObjectUrl(blobUrl);
          });

          onDone();
        } catch (e) {
          onError('Erro ao processar arquivo: $e');
        }
      } else {
        onError('Erro no servidor (${request.status}): ${request.statusText}');
      }
    });

    request.onError.listen((event) {
      onError('Falha de conexão durante o download.');
    });

    request.send();
  } catch (e) {
    onError('Erro ao iniciar download: $e');
  }
}

