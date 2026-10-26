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
    // 1. Ouvinte em tempo real: Se a versão mudar, reseta o "fechar" (X)
    // para que o banner apareça novamente para a NOVA atualização.
    ref.listen<AppUpdateInfo?>(latestUpdateInfoProvider.select((v) => v.valueOrNull), (prev, next) {
      if (next != null && prev?.latestVersion != next.latestVersion) {
        ref.read(isBannerDismissedProvider.notifier).state = false;
      }
    });

    final isDismissed = ref.watch(isBannerDismissedProvider);
    if (isDismissed) return const SizedBox.shrink();

    final isAvailable = ref.watch(isUpdateAvailableProvider);
    final updateInfo = ref.watch(latestUpdateInfoProvider).valueOrNull;

    // Se houver atualização disponível (APK mais recente que o instalado),
    // sempre exibe o banner em qualquer dispositivo (celulares, tablets, PWA).
    if (isAvailable) {
      return _buildLayout(context, ref, isAvailable, updateInfo);
    }

    // Se não houver atualização nova, mas estiver no Web/PWA:
    // Exibe banner de convite para instalar APK / PWA nos dispositivos móveis ou tablets
    if (kIsWeb) {
      final isMobileOrTablet = defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          isIosClient() ||
          isAndroidClient() ||
          MediaQuery.of(context).size.width < 900;

      if (!isMobileOrTablet) return const SizedBox.shrink();
      return _buildLayout(context, ref, isAvailable, updateInfo);
    }

    return const SizedBox.shrink();
  }

  Widget _buildLayout(BuildContext context, WidgetRef ref, bool isUpdateAvailable, AppUpdateInfo? updateInfo) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Detectamos se é iOS pelo platform ou userAgent no navegador
    final bool isIOS = isIosClient();

    // Caso 1: Atualização disponível (Celular, Tablet ou Web)
    final versionLabel = updateInfo?.versionName.isNotEmpty ?? false ? ' v${updateInfo!.versionName}' : '';
    String title = 'Nova Atualização Disponível$versionLabel';
    String subtitle = (updateInfo?.releaseNotes.isNotEmpty ?? false)
        ? updateInfo!.releaseNotes
        : 'Toque para atualizar agora seu KeryxApp';
    String buttonLabel = 'ATUALIZAR';
    Color mainColor = const Color(0xFF22C55E); // Verde padrão de atualização
    IconData icon = Icons.system_update_rounded;

    // Caso 2: Acessando via Navegador Web (kIsWeb) e não há atualização pendente
    if (kIsWeb && !isUpdateAvailable) {
      if (isIOS) {
        // iPhone no Safari / Chrome
        title = 'Aplicativo no seu iPhone';
        subtitle = 'Toque e adicione à Tela de Início';
        buttonLabel = 'INSTALAR';
        mainColor = Colors.blue;
        icon = Icons.add_to_home_screen_rounded;
      } else {
        // Android no Navegador (não está instalado via APK)
        title = 'Baixe o Aplicativo Oficial';
        subtitle = 'Para uma experiência completa e mais rápida';
        buttonLabel = 'BAIXAR';
        mainColor = Colors.blue;
        icon = Icons.install_mobile_rounded;
      }
    }

    // Se estiver no app nativo instalado e já estiver na versão mais recente, não exibe
    final bool shouldShow = kIsWeb || isUpdateAvailable;
    if (!shouldShow) return const SizedBox.shrink();

    final String url = (updateInfo?.downloadUrl.isNotEmpty ?? false)
        ? updateInfo!.downloadUrl.trim()
        : 'https://keryx-version.nivaldo-nilngn.workers.dev/download';

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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
              onTap: () {
                if (kIsWeb && isIOS) {
                  _showIOSInstructions(context);
                } else {
                  ref.read(downloadServiceProvider).downloadAndInstall(context, url);
                }
              },
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
              'Instalar no iPhone',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para usar o KeryxApp em tela cheia e offline no seu iPhone:',
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
            color: Colors.blue,
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
