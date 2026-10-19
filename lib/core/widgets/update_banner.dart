import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_update_service.dart';
import 'pwa_install_guide_modal.dart';

class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateInfoAsync = ref.watch(latestUpdateInfoProvider);
    final isUpdateAvailable = ref.watch(isUpdateAvailableProvider);
    final dismissedVersion = ref.watch(dismissedUpdateVersionProvider);
    final updateInfo = updateInfoAsync.valueOrNull;

    // Se já foi dispensado para esta versão específica, oculta
    if (updateInfo != null && dismissedVersion == updateInfo.latestVersion) {
      return const SizedBox.shrink();
    }

    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final isWebMobile = kIsWeb && MediaQuery.of(context).size.width < 768;

    // Mostra o banner caso haja nova versão ou se for acesso mobile no Web
    final shouldShow = isUpdateAvailable || (kIsWeb && isWebMobile && updateInfo != null);

    if (!shouldShow || updateInfo == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Estilo simples e elegante idêntico ao modelo Peniel Finanças
    const brandGreen = Color(0xFF22C55E);

    String title;
    String subtitle;
    String buttonText;
    IconData icon;

    if (kIsWeb && isIOS) {
      title = 'Instale o Keryx no iPhone';
      subtitle = 'Toque para adicionar à Tela de Início';
      buttonText = 'INSTALAR';
      icon = Icons.apple_rounded;
    } else {
      title = 'Nova Atualização Disponível';
      subtitle = 'Toque para atualizar agora';
      buttonText = 'ATUALIZAR';
      icon = Icons.system_update_rounded;
    }

    final String finalDownloadUrl = updateInfo.downloadUrl.isNotEmpty
        ? updateInfo.downloadUrl
        : 'https://keryx-version.nivaldo-nilngn.workers.dev/download';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D17) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: brandGreen.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícone simples e limpo (Smartphone com seta para baixo)
          Icon(
            icon,
            color: brandGreen,
            size: 28,
          ),
          const SizedBox(width: 12),

          // Textos compactos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.normal,
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Botão pílula verde "ATUALIZAR"
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (kIsWeb && isIOS) {
                  showPwaInstallGuide(context);
                } else {
                  ref
                      .read(appUpdateServiceProvider)
                      .downloadAndInstallApk(context, finalDownloadUrl);
                }
              },
              child: Ink(
                decoration: BoxDecoration(
                  color: brandGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Text(
                  buttonText,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Botão discreto X para fechar / dispensar
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                ref.read(dismissedUpdateVersionProvider.notifier).state =
                    updateInfo.latestVersion;
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
