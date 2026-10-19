import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_update_service.dart';
import '../theme/app_theme.dart';
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

    // No Web, mostramos o banner de PWA ou de download caso haja nova versão ou se for acesso mobile
    final shouldShow = isUpdateAvailable || (kIsWeb && isWebMobile && updateInfo != null);

    if (!shouldShow || updateInfo == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Configuração de texto e ícones dependendo do contexto
    String title;
    String subtitle;
    String buttonText;
    IconData icon;
    Color accentColor;

    if (kIsWeb) {
      if (isIOS) {
        title = isUpdateAvailable
            ? 'Nova Versão Keryx (v${updateInfo.versionName})'
            : 'Instale o Keryx no seu iPhone';
        subtitle = 'Adicione à Tela de Início para usar em tela cheia e offline';
        buttonText = 'Instalar PWA';
        icon = Icons.apple_rounded;
        accentColor = AppTheme.kPrimaryGold;
      } else {
        title = 'Nova Versão Disponível (v${updateInfo.versionName})';
        subtitle = 'Baixe o APK oficial para instalar no seu Android';
        buttonText = 'Baixar APK';
        icon = Icons.android_rounded;
        accentColor = const Color(0xFF10B981);
      }
    } else {
      title = 'Atualização Disponível (v${updateInfo.versionName})';
      subtitle = updateInfo.releaseNotes.isNotEmpty
          ? updateInfo.releaseNotes
          : 'Melhorias de desempenho e novos recursos disponíveis.';
      buttonText = 'Atualizar';
      icon = Icons.system_update_rounded;
      accentColor = AppTheme.kPrimaryGold;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  accentColor.withValues(alpha: 0.16),
                  const Color(0xFF15162B),
                ]
              : [
                  accentColor.withValues(alpha: 0.12),
                  Colors.white,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'NOVO',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: const Color(0xFF111223),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 0,
            ),
            onPressed: () {
              if (kIsWeb && isIOS) {
                showPwaInstallGuide(context);
              } else {
                final url = updateInfo.downloadUrl.isNotEmpty
                    ? updateInfo.downloadUrl
                    : (updateInfo.iosUrl.isNotEmpty ? updateInfo.iosUrl : '');
                if (url.isNotEmpty) {
                  ref.read(appUpdateServiceProvider).downloadAndInstallApk(context, url);
                } else if (kIsWeb) {
                  showPwaInstallGuide(context);
                }
              }
            },
            child: Text(
              buttonText,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              ref.read(dismissedUpdateVersionProvider.notifier).state = updateInfo.latestVersion;
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            tooltip: 'Dispensar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
