import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_update_service.dart';
import '../services/internal_download_service.dart';
import '../utils/platform_utils.dart';

final isBannerDismissedProvider = StateProvider<bool>((ref) => false);

class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se a versão mudar no servidor, reseta o dismiss para alertar nova versão
    ref.listen<AppUpdateInfo?>(latestUpdateInfoProvider.select((v) => v.valueOrNull), (prev, next) {
      if (next != null && prev?.latestVersion != next.latestVersion) {
        ref.read(isBannerDismissedProvider.notifier).state = false;
      }
    });

    final isDismissed = ref.watch(isBannerDismissedProvider);
    if (isDismissed) return const SizedBox.shrink();

    final updateInfo = ref.watch(latestUpdateInfoProvider).valueOrNull;

    // ── CENÁRIO 1: Navegador Web (kIsWeb) ──────────────────────────────────
    if (kIsWeb) {
      final size = MediaQuery.of(context).size;
      final bool isIOS = isIosClient();
      final bool isAndroid = isAndroidClient();

      // No computador / desktop (largura >= 900 e não for cliente mobile):
      // A versão Web já é a mais recente em tempo real servida da nuvem.
      // Nunca exibe banner de APK nem de atualização no desktop.
      if (!isIOS && !isAndroid && size.width >= 900) {
        return const SizedBox.shrink();
      }

      // No iPhone ou iPad no Safari / Chrome:
      // Orienta a adicionar à Tela de Início como PWA
      if (isIOS) {
        return _buildLayout(
          context: context,
          ref: ref,
          title: 'Aplicativo no seu iPhone / iPad',
          subtitle: 'Adicione à Tela de Início para usar em tela cheia',
          buttonLabel: 'COMO INSTALAR',
          mainColor: const Color(0xFF3B82F6),
          icon: Icons.add_to_home_screen_rounded,
          onTap: () => _showIOSInstructions(context),
        );
      }

      // No Android acessando pelo navegador:
      // Convida a baixar o aplicativo APK oficial
      if (isAndroid) {
        final downloadUrl = (updateInfo?.downloadUrl.isNotEmpty ?? false)
            ? updateInfo!.downloadUrl.trim()
            : 'https://github.com/Nivaldo-Nilngn/keryxApp/releases/download/v2.0.2/keryxApp.apk';

        return _buildLayout(
          context: context,
          ref: ref,
          title: 'Baixe o Aplicativo Oficial',
          subtitle: 'Instale o app oficial no Android para recursos offline',
          buttonLabel: 'BAIXAR APK',
          mainColor: const Color(0xFF10B981),
          icon: Icons.install_mobile_rounded,
          onTap: () {
            downloadFile(downloadUrl);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Download do keryxApp.apk iniciado! Acompanhe na barra de notificações.'),
                backgroundColor: Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      }

      return const SizedBox.shrink();
    }

    // ── CENÁRIO 2: Aplicativo Nativo Instalado (Android/iOS) ───────────────
    final isAvailable = ref.watch(isUpdateAvailableProvider);

    if (isAvailable && updateInfo != null) {
      final versionLabel = updateInfo.versionName.isNotEmpty ? ' v${updateInfo.versionName}' : '';
      return _buildLayout(
        context: context,
        ref: ref,
        title: 'Nova Atualização Disponível$versionLabel',
        subtitle: updateInfo.releaseNotes.isNotEmpty
            ? updateInfo.releaseNotes
            : 'Toque para atualizar agora seu KeryxApp',
        buttonLabel: 'ATUALIZAR',
        mainColor: const Color(0xFF22C55E),
        icon: Icons.system_update_rounded,
        onTap: () => ref.read(downloadServiceProvider).downloadAndInstall(context, updateInfo.downloadUrl),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLayout({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required Color mainColor,
    required IconData icon,
    required VoidCallback onTap,
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
          const SizedBox(width: 2),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            onPressed: () => ref.read(isBannerDismissedProvider.notifier).state = true,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  void _showIOSInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.apple_rounded, size: 24),
            const SizedBox(width: 8),
            Text(
              'Instalar no iPhone / iPad',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para usar o KeryxApp em tela cheia e com acesso rápido no seu iPhone ou iPad:',
              style: GoogleFonts.inter(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            _buildStep('1', 'Toque no botão Compartilhar (ícone com quadrado e seta para cima no Safari).'),
            const SizedBox(height: 10),
            _buildStep('2', 'Role para baixo e selecione "Adicionar à Tela de Início".'),
            const SizedBox(height: 10),
            _buildStep('3', 'Toque em "Adicionar" no canto superior direito.'),
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
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFF3B82F6),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
