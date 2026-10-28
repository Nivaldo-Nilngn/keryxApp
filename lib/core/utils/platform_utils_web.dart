// platform_utils_web.dart
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';

const kWorkerBase = 'https://keryx-version.nivaldo-nilngn.workers.dev';

String get _ua => html.window.navigator.userAgent.toLowerCase();
String get _platform => (html.window.navigator.platform ?? '').toLowerCase();
int get _touch => html.window.navigator.maxTouchPoints ?? 0;

/// Detecta se o cliente é Android
bool isAndroidClient() {
  if (_ua.contains('android') || _platform.contains('android')) return true;

  // Modo "Site para computador" no Android: o UA vira "X11; Linux x86_64",
  // mas a tela continua sendo touch. Chromebook fica de fora (UA tem "cros").
  final linuxLike = _ua.contains('linux') || _platform.contains('linux');
  return linuxLike && _touch > 1 && !_ua.contains('cros');
}

/// Detecta se o cliente é iPhone ou iPod
bool isIphoneClient() {
  if (isAndroidClient()) return false;
  return _ua.contains('iphone') || _ua.contains('ipod');
}

/// iPadOS 13+ se identifica como "Macintosh", mas tem touch
bool isIpadClient() {
  if (isAndroidClient()) return false;
  return _ua.contains('ipad') || (_ua.contains('macintosh') && _touch > 1);
}

/// Detecta se o cliente é dispositivo Apple (iPhone ou iPad)
bool isIosClient() => isIphoneClient() || isIpadClient();

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

/// Download nativo do navegador (usa o gerenciador do Chrome / navegador Android).
void downloadFile(String url, {String fileName = 'keryxApp.apk'}) {
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..target = '_self' // não abre aba nova
    ..rel = 'noopener'
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
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
