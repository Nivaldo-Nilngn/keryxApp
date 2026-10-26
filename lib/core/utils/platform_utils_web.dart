// platform_utils_web.dart
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';

const kWorkerBase = 'https://keryx-version.nivaldo-nilngn.workers.dev';

/// Detecta se o cliente é iPad (iPadOS com Safari Desktop-Class ou emulação de iPad)
bool isIpadClient() {
  final ua = (html.window.navigator.userAgent).toLowerCase();
  final platform = (html.window.navigator.platform ?? '').toLowerCase();
  final touchPoints = html.window.navigator.maxTouchPoints ?? 0;

  // 1. Explicitamente contém "ipad" no UserAgent ou Platform
  if (ua.contains('ipad') || platform.contains('ipad')) {
    return true;
  }

  // 2. iPadOS moderno (Safari Desktop-Class que se anuncia como Macintosh)
  // No iPadOS real, a Apple envia platform 'MacIntel' com maxTouchPoints > 0
  if ((ua.contains('macintosh') || platform.contains('macintel')) && touchPoints > 0) {
    return true;
  }

  // 3. Emulação no Chrome DevTools com perfil de iPad / Tablet Apple
  final isApple = ua.contains('macintosh') || platform.contains('macintel') || ua.contains('apple');
  if (isApple && (ua.contains('mobile') || ua.contains('tablet') || touchPoints >= 1)) {
    return true;
  }

  return false;
}

/// Detecta se o cliente é iPhone ou iPod
bool isIphoneClient() {
  final ua = (html.window.navigator.userAgent).toLowerCase();
  final platform = (html.window.navigator.platform ?? '').toLowerCase();

  return ua.contains('iphone') ||
      ua.contains('ipod') ||
      platform.contains('iphone') ||
      platform.contains('ipod');
}

/// Detecta se o cliente é dispositivo Apple (iPhone ou iPad)
bool isIosClient() {
  return isIphoneClient() || isIpadClient();
}

/// Detecta se o cliente é Android
bool isAndroidClient() {
  final ua = (html.window.navigator.userAgent).toLowerCase();
  final platform = (html.window.navigator.platform ?? '').toLowerCase();
  return ua.contains('android') || platform.contains('android');
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

  html.Url.revokeObjectUrl(url);
}
