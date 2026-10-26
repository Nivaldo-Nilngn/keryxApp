import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_update_service.dart';
import '../services/internal_download_service.dart';
import '../utils/platform_utils.dart';

class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _isDismissedLocally = false;
  String? _currentDismissKey;

  @override
  void initState() {
    super.initState();
    _checkDismissStatus();
  }

  Future<void> _checkDismissStatus({bool isIpad = false}) async {
    final updateInfo = ref.read(latestUpdateInfoProvider).valueOrNull;
    final key = _computeDismissKey(updateInfo, isIpad: isIpad);
    if (key == null) return;

    _currentDismissKey = key;
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(key) ?? false;

    if (mounted && dismissed != _isDismissedLocally) {
      setState(() => _isDismissedLocally = dismissed);
    }
  }

  String? _computeDismissKey(AppUpdateInfo? updateInfo, {bool isIpad = false}) {
    if (kIsWeb) {
      if (isIpad) return 'keryx_banner_dismissed_ipad_pwa';
      if (isIphoneClient() || isIosClient()) return 'keryx_banner_dismissed_iphone_pwa';
      if (isAndroidClient()) {
        final version = updateInfo?.latestVersion ?? 0;
        return 'keryx_banner_dismissed_android_web_$version';
      }
      return null;
    }
    final version = updateInfo?.latestVersion ?? 0;
    return 'keryx_banner_dismissed_native_$version';
  }

  Future<void> _handleDismiss(String? key) async {
    setState(() => _isDismissedLocally = true);
    if (key != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateInfo = ref.watch(latestUpdateInfoProvider).valueOrNull;
    final isForceUpdate = ref.watch(isForceUpdateRequiredProvider);

    // ── CENÁRIO 1: Navegador Web (kIsWeb) ──────────────────────────────────
    if (kIsWeb) {
      // Já instalado como PWA aberto pela Tela de Início: nada a oferecer
      if (isStandalonePwa()) return const SizedBox.shrink();

      final size = MediaQuery.of(context).size;
      final bool detectedIpad = isIpadClient();
      final bool detectedIphone = isIphoneClient();
      final bool isAndroid = isAndroidClient();

      // No modo iPad: detectado por UserAgent/Platform ou se for tablet com tamanho típico
      final bool isIpad = detectedIpad || 
          (!isAndroid && !detectedIphone && (size.width >= 600 && size.width <= 1400));

      final bool isIOS = detectedIphone || isIpad || isIosClient();

      // No Desktop puro (não mobile e tela larga fora dos padrões de tablet Apple): nada a exibir
      if (!isIOS && !isAndroid) return const SizedBox.shrink();

      // Reavalia a chave de persistência com base no dispositivo específico
      final key = _computeDismissKey(updateInfo, isIpad: isIpad);
      if (key != _currentDismissKey) {
        _currentDismissKey = key;
        _checkDismissStatus(isIpad: isIpad);
      }

      // Se o usuário dispensou este banner nesta versão/dispositivo, não exibe
      if (!isForceUpdate && _isDismissedLocally) {
        return const SizedBox.shrink();
      }

      // ── CENÁRIO 1A: iPad (Safari ou PWA) ─────────────────────────────────
      if (isIpad) {
        final inApp = isInAppBrowser();
        return _buildLayout(
          context: context,
          canDismiss: !isForceUpdate,
          title: inApp ? 'Abra no Safari para instalar' : 'Aplicativo no seu iPad',
          subtitle: inApp
              ? 'Este navegador não permite instalar. Abra o link no Safari.'
              : 'Adicione à Tela de Início no Safari para usar em tela cheia',
          buttonLabel: 'COMO INSTALAR',
          mainColor: const Color(0xFF3B82F6),
          icon: Icons.tablet_mac_rounded,
          onTap: () => _showIOSInstructions(context, inApp: inApp, isIpad: true),
          onDismiss: () => _handleDismiss(key),
        );
      }

      // ── CENÁRIO 1B: iPhone (Safari ou PWA) ────────────────────────────────
      if (isIOS) {
        final inApp = isInAppBrowser();
        return _buildLayout(
          context: context,
          canDismiss: !isForceUpdate,
          title: inApp ? 'Abra no Safari para instalar' : 'Aplicativo no seu iPhone',
          subtitle: inApp
              ? 'Este navegador não permite instalar. Abra o link no Safari.'
              : 'Adicione à Tela de Início para usar em tela cheia',
          buttonLabel: 'COMO INSTALAR',
          mainColor: const Color(0xFF3B82F6),
          icon: Icons.phone_iphone_rounded,
          onTap: () => _showIOSInstructions(context, inApp: inApp, isIpad: false),
          onDismiss: () => _handleDismiss(key),
        );
      }

      // ── CENÁRIO 1C: Android no Navegador ──────────────────────────────────
      if (isAndroid) {
        final downloadUrl = (updateInfo?.downloadUrl.isNotEmpty ?? false)
            ? updateInfo!.downloadUrl.trim()
            : 'https://github.com/Nivaldo-Nilngn/keryxApp/releases/download/v2.0.2/keryxApp.apk';

        return _buildLayout(
          context: context,
          canDismiss: !isForceUpdate,
          title: 'Baixe o Aplicativo Oficial',
          subtitle: 'Instale o app oficial no Android para recursos offline',
          buttonLabel: 'BAIXAR APK',
          mainColor: const Color(0xFF10B981),
          icon: Icons.install_mobile_rounded,
          onTap: () {
            downloadFile(downloadUrl, fileName: 'keryxApp.apk');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Download do keryxApp.apk iniciado! Acompanhe na barra de notificações.'),
                backgroundColor: Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          onDismiss: () => _handleDismiss(key),
        );
      }

      return const SizedBox.shrink();
    }

    // ── CENÁRIO 2: Aplicativo Nativo Instalado (Android/iOS) ───────────────
    final key = _computeDismissKey(updateInfo);
    if (key != _currentDismissKey) {
      _currentDismissKey = key;
      _checkDismissStatus();
    }

    if (!isForceUpdate && _isDismissedLocally) {
      return const SizedBox.shrink();
    }

    final isAvailable = ref.watch(isUpdateAvailableProvider);

    if (isAvailable && updateInfo != null) {
      final versionLabel = updateInfo.versionName.isNotEmpty ? ' v${updateInfo.versionName}' : '';
      return _buildLayout(
        context: context,
        canDismiss: !isForceUpdate,
        title: 'Nova Atualização Disponível$versionLabel',
        subtitle: updateInfo.releaseNotes.isNotEmpty
            ? updateInfo.releaseNotes
            : 'Toque para atualizar agora seu KeryxApp',
        buttonLabel: 'ATUALIZAR',
        mainColor: const Color(0xFF22C55E),
        icon: Icons.system_update_rounded,
        onTap: () => ref.read(downloadServiceProvider).downloadAndInstall(context, updateInfo),
        onDismiss: () => _handleDismiss(key),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLayout({
    required BuildContext context,
    required bool canDismiss,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required Color mainColor,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onDismiss,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D17) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mainColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: mainColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: mainColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: mainColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(
                  buttonLabel,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          if (canDismiss) ...[
            const SizedBox(width: 2),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
            ),
          ],
        ],
      ),
    );
  }

  void _showIOSInstructions(BuildContext context, {required bool inApp, required bool isIpad}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isIpad ? Icons.tablet_mac_rounded : Icons.phone_iphone_rounded,
              size: 24,
              color: const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 10),
            Text(
              isIpad ? 'Instalar no iPad' : 'Instalar no iPhone',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              inApp
                  ? 'Navegadores embutidos (Instagram, WhatsApp, etc.) não conseguem instalar apps diretamente:'
                  : (isIpad
                      ? 'Para usar o KeryxApp em tela cheia e com acesso rápido no seu iPad:'
                      : 'Para usar o KeryxApp em tela cheia e com acesso rápido no seu iPhone:'),
              style: GoogleFonts.inter(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (inApp) ...[
              _buildStep('1', 'Toque no menu (⋯ ou Compartilhar) e escolha "Abrir no Safari".'),
              const SizedBox(height: 10),
              _buildStep(
                '2',
                isIpad
                    ? 'No Safari do iPad, toque no botão Compartilhar (no canto superior direito / barra do topo).'
                    : 'No Safari do iPhone, toque no botão Compartilhar (na barra inferior / rodapé da tela).',
              ),
              const SizedBox(height: 10),
              _buildStep('3', 'No menu de opções, role para baixo e selecione "Adicionar à Tela de Início".'),
              const SizedBox(height: 10),
              _buildStep('4', 'Toque em "Adicionar" no canto superior direito para confirmar.'),
            ] else ...[
              _buildStep(
                '1',
                isIpad
                    ? 'Toque no botão Compartilhar (no canto superior direito / topo do Safari no iPad).'
                    : 'Toque no botão Compartilhar (na barra inferior / rodapé do Safari no iPhone).',
              ),
              const SizedBox(height: 10),
              _buildStep('2', 'Role as opções para baixo e selecione "Adicionar à Tela de Início".'),
              const SizedBox(height: 10),
              _buildStep('3', 'Toque em "Adicionar" no canto superior direito da janela.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDI'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF3B82F6),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 12.5, height: 1.35),
          ),
        ),
      ],
    );
  }
}
