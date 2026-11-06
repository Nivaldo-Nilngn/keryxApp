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

  Future<void> _checkDismissStatus() async {
    final updateInfo = ref.read(latestUpdateInfoProvider).valueOrNull;
    final key = _computeDismissKey(updateInfo);
    if (key == null) return;

    _currentDismissKey = key;
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(key) ?? false;

    // ignora resultado de uma chave que já foi trocada
    if (!mounted || key != _currentDismissKey) return;
    if (dismissed != _isDismissedLocally) {
      setState(() => _isDismissedLocally = dismissed);
    }
  }

  String? _computeDismissKey(AppUpdateInfo? updateInfo) {
    if (kIsWeb) {
      final version = updateInfo?.latestVersion ?? 0;
      if (isIpadClient()) return 'keryx_banner_dismissed_ipad_pwa_$version';
      if (isIphoneClient()) return 'keryx_banner_dismissed_iphone_pwa_$version';
      if (isAndroidClient()) {
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
    final isForceUpdate = !kIsWeb && ref.watch(isForceUpdateRequiredProvider);
    final downloadState = ref.watch(updateDownloadProvider);

    // ── CENÁRIO 1: Navegador Web (kIsWeb) ──────────────────────────────────
    if (kIsWeb) {
      // Já instalado como PWA aberto pela Tela de Início: nada a oferecer
      if (isStandalonePwa()) return const SizedBox.shrink();

      final bool isIpad = isIpadClient();
      final bool isIphone = isIphoneClient();
      final bool isAndroid = isAndroidClient();
      final bool isIOS = isIpad || isIphone;

      // Desktop ou outro sistema: nada a exibir
      if (!isIOS && !isAndroid) return const SizedBox.shrink();

      // Reavalia a chave de persistência com base no dispositivo específico
      final key = _computeDismissKey(updateInfo);
      if (key != _currentDismissKey) {
        _currentDismissKey = key;
        _checkDismissStatus();
      }

      // Se o usuário dispensou este banner nesta versão/dispositivo, não exibe
      if (!isForceUpdate && _isDismissedLocally && !downloadState.isDownloading) {
        return const SizedBox.shrink();
      }

      // ── CENÁRIO 1A: iPad (Safari ou PWA) ─────────────────────────────────
      if (isIpad) {
        final inApp = isInAppBrowser();
        return _buildLayout(
          context: context,
          canDismiss: !isForceUpdate,
          title: inApp ? 'Abra no Safari' : 'KeryxApp no iPad',
          subtitle: inApp
              ? 'Abra no Safari para instalar'
              : 'Adicione à Tela de Início',
          buttonLabel: 'INSTALAR',
          mainColor: const Color(0xFF3B82F6),
          icon: Icons.tablet_mac_rounded,
          onTap: () => _showIOSInstructions(context, inApp: inApp, isIpad: true),
          onDismiss: () => _handleDismiss(key),
        );
      }

      // ── CENÁRIO 1B: iPhone (Safari ou PWA) ────────────────────────────────
      if (isIphone) {
        final inApp = isInAppBrowser();
        return _buildLayout(
          context: context,
          canDismiss: !isForceUpdate,
          title: inApp ? 'Abra no Safari' : 'KeryxApp no iPhone',
          subtitle: inApp
              ? 'Abra no Safari para instalar'
              : 'Adicione à Tela de Início',
          buttonLabel: 'INSTALAR',
          mainColor: const Color(0xFF3B82F6),
          icon: Icons.phone_iphone_rounded,
          onTap: () => _showIOSInstructions(context, inApp: inApp, isIpad: false),
          onDismiss: () => _handleDismiss(key),
        );
      }

      // ── CENÁRIO 1C: Android no Navegador (Celular ou Tablet) ─────────────
      if (isAndroid) {
        final isTablet = MediaQuery.of(context).size.width >= 720;
        final downloadUrl = (updateInfo?.downloadUrl.isNotEmpty ?? false)
            ? updateInfo!.downloadUrl.trim()
            : 'https://github.com/Nivaldo-Nilngn/keryxApp/releases/latest/download/keryxApp.apk';

        final isDownloading = downloadState.isDownloading;
        final isCompleted = downloadState.isCompleted;
        final hasError = downloadState.hasError;

        String buttonLabel = 'BAIXAR';
        if (isDownloading) {
          buttonLabel = 'BAIXANDO...';
        } else if (isCompleted) {
          buttonLabel = 'BAIXADO';
        } else if (hasError) {
          buttonLabel = 'TENTAR';
        }

        String subtitle = isTablet
            ? 'Instale o app oficial no seu Tablet • Recursos offline'
            : 'Para Android • Recursos offline';

        if (isDownloading && downloadState.progressText != null) {
          subtitle = downloadState.progressText!;
        } else if (isCompleted) {
          subtitle = 'Download concluído! Verifique seus downloads.';
        } else if (hasError && downloadState.errorMessage != null) {
          subtitle = downloadState.errorMessage!;
        }

        return _buildLayout(
          context: context,
          canDismiss: !isForceUpdate && !isDownloading,
          title: isTablet ? 'KeryxApp para Tablet Android' : 'Baixar KeryxApp Oficial',
          subtitle: subtitle,
          buttonLabel: buttonLabel,
          mainColor: hasError ? Colors.redAccent : const Color(0xFF10B981),
          icon: isTablet ? Icons.tablet_android_rounded : Icons.install_mobile_rounded,
          isDownloading: isDownloading,
          downloadProgress: downloadState.progress,
          progressText: downloadState.progressText,
          onTap: isDownloading
              ? () {}
              : () => ref.read(updateDownloadProvider.notifier).startDownload(
                    downloadUrl: downloadUrl,
                    versionName: updateInfo?.versionName,
                    context: context,
                  ),
          onCancel: isDownloading
              ? () => ref.read(updateDownloadProvider.notifier).cancel()
              : null,
          onDismiss: () => _handleDismiss(key),
        );
      }

      return const SizedBox.shrink();
    }

    // ── CENÁRIO 2: Aplicativo Nativo Instalado (Android/iOS) ───────────────
    final key = _computeDismissKey(updateInfo);
    if (key != _currentDismissKey) {
      _currentDismissKey = key;
      _isDismissedLocally = true; // esconde até ler o prefs
      _checkDismissStatus();
    }

    // Se estiver baixando ou concluído, mantém o card visível para acompanhar ou instalar
    if (!isForceUpdate &&
        _isDismissedLocally &&
        !downloadState.isDownloading &&
        !downloadState.isCompleted) {
      return const SizedBox.shrink();
    }

    final isAvailable = ref.watch(isUpdateAvailableProvider);

    if ((isAvailable || downloadState.isDownloading || downloadState.isCompleted) &&
        updateInfo != null) {
      final versionLabel =
          updateInfo.versionName.isNotEmpty ? ' v${updateInfo.versionName}' : '';

      final bool isDownloading = downloadState.isDownloading;
      final bool isCompleted = downloadState.isCompleted;
      final bool hasError = downloadState.hasError;

      String buttonLabel = 'ATUALIZAR';
      if (isDownloading) {
        buttonLabel = 'BAIXANDO...';
      } else if (isCompleted) {
        buttonLabel = 'INSTALAR';
      } else if (hasError) {
        buttonLabel = 'TENTAR';
      }

      String subtitle = updateInfo.releaseNotes.isNotEmpty
          ? updateInfo.releaseNotes
          : 'Toque para atualizar agora';

      if (isDownloading && downloadState.progressText != null) {
        subtitle = downloadState.progressText!;
      } else if (isCompleted) {
        subtitle = 'Download concluído! Toque para instalar o KeryxApp.';
      } else if (hasError && downloadState.errorMessage != null) {
        subtitle = 'Falha: ${downloadState.errorMessage} (Toque para tentar)';
      }

      IconData bannerIcon = Icons.system_update_rounded;
      if (isCompleted) {
        bannerIcon = Icons.check_circle_rounded;
      } else if (hasError) {
        bannerIcon = Icons.error_outline_rounded;
      } else if (isDownloading) {
        bannerIcon = Icons.downloading_rounded;
      }

      final Color mainColor = hasError
          ? Colors.redAccent
          : (isCompleted ? const Color(0xFF10B981) : const Color(0xFF22C55E));

      return _buildLayout(
        context: context,
        canDismiss: !isForceUpdate && !isDownloading,
        title: 'Nova Atualização$versionLabel',
        subtitle: subtitle,
        buttonLabel: buttonLabel,
        mainColor: mainColor,
        icon: bannerIcon,
        isDownloading: isDownloading,
        downloadProgress: downloadState.progress,
        progressText: downloadState.progressText,
        onTap: () {
          if (isDownloading) return;
          if (isCompleted && downloadState.downloadedFilePath != null) {
            ref.read(downloadServiceProvider).openInstaller(
                  downloadState.downloadedFilePath!,
                  context: context,
                );
          } else {
            ref.read(downloadServiceProvider).downloadAndInstall(
                  context,
                  updateInfo,
                );
          }
        },
        onCancel: isDownloading
            ? () => ref.read(updateDownloadProvider.notifier).cancel()
            : null,
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
    VoidCallback? onCancel,
    bool isDownloading = false,
    double downloadProgress = 0.0,
    String? progressText,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displaySubtitle = (isDownloading && progressText != null)
        ? progressText
        : subtitle;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Color.alphaBlend(mainColor.withValues(alpha: 0.10), theme.colorScheme.surface)
            : Color.alphaBlend(mainColor.withValues(alpha: 0.07), Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: mainColor.withValues(alpha: 0.30),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, color: mainColor, size: 18),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (displaySubtitle.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              displaySubtitle,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: isDownloading ? FontWeight.w600 : FontWeight.normal,
                                color: isDownloading
                                    ? mainColor
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.70),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: isDownloading ? mainColor.withValues(alpha: 0.75) : mainColor,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: isDownloading ? null : onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                        child: Text(
                          isDownloading ? 'BAIXANDO...' : buttonLabel,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isDownloading && onCancel != null) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.50),
                      ),
                      tooltip: 'Cancelar download',
                      onPressed: onCancel,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      splashRadius: 12,
                    ),
                  ] else if (canDismiss && !isDownloading) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.40),
                      ),
                      onPressed: onDismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      splashRadius: 12,
                    ),
                  ],
                ],
              ),
            ),
            if (isDownloading) ...[
              SizedBox(
                height: 2.5,
                width: double.infinity,
                child: downloadProgress >= 0
                    ? LinearProgressIndicator(
                        value: downloadProgress,
                        backgroundColor: mainColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                      )
                    : LinearProgressIndicator(
                        backgroundColor: mainColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                      ),
              ),
            ],
          ],
        ),
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
