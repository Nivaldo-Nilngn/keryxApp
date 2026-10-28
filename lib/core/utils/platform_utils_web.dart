// platform_utils_web.dart
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';

const kWorkerBase = 'https://keryx-version.nivaldo-nilngn.workers.dev';

typedef DownloadProgressCallback = void Function(double progress, int loaded, int total);

String get _ua => html.window.navigator.userAgent.toLowerCase();
String get _platform => (html.window.navigator.platform ?? '').toLowerCase();
int get _touch => html.window.navigator.maxTouchPoints ?? 0;

/// Detecta se o cliente é iPad (iPadOS 13+ se identifica como "Macintosh", mas tem touch)
bool isIpadClient() {
  if (_ua.contains('ipad')) return true;
  return _ua.contains('macintosh') && _touch >= 1;
}

/// Detecta se o cliente é iPhone ou iPod
bool isIphoneClient() {
  return _ua.contains('iphone') || _ua.contains('ipod');
}

/// Detecta se o cliente é dispositivo Apple (iPhone ou iPad)
bool isIosClient() => isIphoneClient() || isIpadClient();

/// Detecta se o cliente é Android (celular ou tablet)
bool isAndroidClient() {
  // Se for explicitamente Apple, nunca é Android
  if (isIosClient()) return false;

  if (_ua.contains('android') || _platform.contains('android')) return true;

  // Modo "Site para computador" no Android: o UA vira "X11; Linux x86_64",
  // mas a tela continua sendo touch. Chromebook fica de fora (UA tem "cros").
  final linuxLike = _ua.contains('linux') || _platform.contains('linux');
  return linuxLike && _touch >= 1 && !_ua.contains('cros') && !_ua.contains('macintosh');
}

/// Detecta se o PWA já está instalado e aberto pela Tela de Início
bool isStandalonePwa() {
  final media = html.window.matchMedia('(display-mode: standalone)').matches;
  final navigator = js.context['navigator'];
  final iosStandalone = navigator != null && navigator['standalone'] == true;
  return media || iosStandalone;
}

/// Detecta navegadores embutidos (Instagram, Facebook, WhatsApp, TikTok, etc.)
/// que não oferecem "Adicionar à Tela de Início" nativo.
bool isInAppBrowser() {
  final ua = html.window.navigator.userAgent;
  return RegExp(
    r'FBAN|FBAV|Instagram|Line/|WhatsApp|Snapchat|TikTok|MicroMessenger',
    caseSensitive: false,
  ).hasMatch(ua);
}

/// Baixa o arquivo como blob (mesma origem) para o atributo `download`
/// ser respeitado e nenhuma guia nova abrir. Reporta o progresso em tempo real.
Future<bool> downloadFile(
  String url, {
  String fileName = 'keryxApp.apk',
  DownloadProgressCallback? onProgress,
}) async {
  final directUrl = url.contains('github.com') ? '$kWorkerBase/download' : url;

  try {
    final request = html.HttpRequest();
    request.open('GET', directUrl);
    request.responseType = 'blob';

    if (onProgress != null) {
      request.onProgress.listen((event) {
        final total = event.total ?? 0;
        final loaded = event.loaded ?? 0;
        if (event.lengthComputable && total > 0) {
          final progress = (loaded / total).clamp(0.0, 1.0);
          onProgress(progress, loaded, total);
        } else {
          onProgress(-1.0, loaded, 0);
        }
      });
    }

    final completer = Completer<bool>();

    request.onLoad.listen((_) {
      if (request.status == 200) {
        final blob = request.response as html.Blob;
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: blobUrl)
          ..setAttribute('download', fileName)
          ..style.display = 'none';

        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();

        Future<void>.delayed(
          const Duration(seconds: 15),
          () => html.Url.revokeObjectUrl(blobUrl),
        );
        completer.complete(true);
      } else {
        completer.complete(false);
      }
    });

    request.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(false);
    });

    request.onAbort.listen((_) {
      if (!completer.isCompleted) completer.complete(false);
    });

    request.send();
    final success = await completer.future;
    if (success) return true;
    throw Exception('Request failed');
  } catch (_) {
    final frame = html.IFrameElement()
      ..style.display = 'none'
      ..src = url;
    html.document.body?.append(frame);
    Future<void>.delayed(const Duration(minutes: 1), frame.remove);
    return false; // caiu no plano B
  }
}

/// Dispara o download de bytes na Web (ex: PDFs gerados)
void downloadBytes(Uint8List bytes, String fileName, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..target = '_self'
    ..rel = 'noopener'
    ..style.display = 'none';

  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  Future<void>.delayed(
    const Duration(seconds: 15),
    () => html.Url.revokeObjectUrl(url),
  );
}
