import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/services/internal_download_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../model/user_access_model.dart';
import '../state/access_control_providers.dart';

class UpdateRequiredScreen extends ConsumerWidget {
  final UserAccessInfo accessInfo;

  const UpdateRequiredScreen({
    super.key,
    required this.accessInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final updateInfo = ref.watch(latestUpdateInfoProvider).valueOrNull;
    final currentVersion = ref.watch(currentAppVersionProvider).valueOrNull;

    final targetVersion = accessInfo.targetVersionName ?? updateInfo?.versionName ?? 'Nova Versão';
    final currentVerStr = currentVersion != null
        ? 'v${currentVersion.versionName} (${currentVersion.buildNumber})'
        : 'Versão antiga';

    final downloadUrl = (updateInfo?.downloadUrl.isNotEmpty == true)
        ? updateInfo!.downloadUrl
        : 'https://keryx-version.nivaldo-nilngn.workers.dev/download';

    final message = accessInfo.updateNoticeMessage?.isNotEmpty == true
        ? accessInfo.updateNoticeMessage!
        : 'O Administrador solicitou a atualização obrigatória do aplicativo para garantir a segurança e o bom funcionamento dos dados. Atualize seu aplicativo para ter o acesso restaurado imediatamente.';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ícone de Alerta de Atualização
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF59E0B).withValues(alpha: 0.25),
                          const Color(0xFFF59E0B).withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.system_security_update_warning_rounded,
                        color: Color(0xFFF59E0B),
                        size: 46,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Título
                  Text(
                    'Atualização Necessária',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtítulo
                  Text(
                    'Nova versão exigida pelo Administrador',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Card com a Mensagem do Administrador
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.notifications_active_rounded,
                              color: Color(0xFFF59E0B),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AVISO DO ADMINISTRADOR',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Colors.white12),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SUA VERSÃO ATUAL',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentVerStr,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white38),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'VERSÃO REQUERIDA',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  targetVersion,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Botão de Download / Atualização
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.kPrimaryGold,
                        foregroundColor: const Color(0xFF111223),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        ref
                            .read(downloadServiceProvider)
                            .downloadAndInstall(context, downloadUrl);
                      },
                      icon: const Icon(Icons.download_rounded, size: 22),
                      label: Text(
                        kIsWeb ? 'Baixar Atualização (keryxApp.apk)' : 'Baixar e Atualizar Agora',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botão de Verificar Novamente
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        side: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        ref.invalidate(currentUserAccessProvider);
                        ref.invalidate(currentAppVersionProvider);
                        ref.invalidate(latestUpdateInfoProvider);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        'Já atualizei, verificar novamente',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botão de Sair da Conta
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(authServiceProvider).signOut();
                    },
                    icon: Icon(
                      Icons.logout_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    label: Text(
                      'Sair da conta',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
