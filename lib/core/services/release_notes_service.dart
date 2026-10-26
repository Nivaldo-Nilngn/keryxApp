import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/release_notes_catalog.dart';
import '../models/release_notes_model.dart';
import '../widgets/release_notes_dialog.dart';
import 'app_update_service.dart';
import 'push_notification_service.dart';

final releaseNotesServiceProvider = Provider<ReleaseNotesService>((ref) {
  return ReleaseNotesService(ref);
});

class ReleaseNotesService {
  final Ref _ref;
  static const String _lastSeenBuildKey = 'last_seen_release_notes_build';
  static const String _lastSeenVersionNameKey = 'last_seen_release_notes_version';

  ReleaseNotesService(this._ref);

  /// Verifica se o aplicativo acabou de ser atualizado e, em caso positivo,
  /// exibe as notas de versão comemorativas e envia notificação no sistema.
  Future<void> checkAndShowAfterUpdate(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 1;
      final currentVersion = info.version.isNotEmpty ? info.version : '1.0.0';

      final prefs = await SharedPreferences.getInstance();
      final lastSeenBuild = prefs.getInt(_lastSeenBuildKey);

      // Se nunca foi visto (ex: primeiro acesso ou após instalar esta nova versão),
      // ou se o build atual for maior que o último registrado:
      final bool isNewUpdate = lastSeenBuild != null && currentBuild > lastSeenBuild;
      final bool isFirstRunOnThisFeature = lastSeenBuild == null;

      if (isNewUpdate || isFirstRunOnThisFeature) {
        // Atualiza a chave para não disparar novamente a cada reabertura
        await prefs.setInt(_lastSeenBuildKey, currentBuild);
        await prefs.setString(_lastSeenVersionNameKey, currentVersion);

        // Se for um update real (ou primeira execução com as notas prontas), exibe o diálogo
        if (context.mounted) {
          final latestCloudInfo = _ref.read(latestUpdateInfoProvider).valueOrNull;

          // 1. Dispara notificação nativa no sistema do celular (Android / iOS)
          if (!kIsWeb) {
            try {
              final pushService = _ref.read(pushNotificationServiceProvider);
              await pushService.showLocalNotification(
                id: 'whats_new_$currentBuild',
                title: '🎉 KeryxApp Atualizado (v$currentVersion)!',
                body:
                    'Confira os novos recursos: nova Comunidade bíblica, galeria de avatares, molduras no perfil e melhorias de acesso.',
              );
            } catch (e) {
              debugPrint('⚠️ Erro ao disparar notificação local pós-atualização: $e');
            }
          }

          // 2. Abre o modal comemorativo na tela com as notas completas
          await Future.delayed(const Duration(milliseconds: 600));
          if (context.mounted) {
            ReleaseNotesDialog.show(
              context,
              isAfterUpdate: true,
              version: ReleaseNotesCatalog.latest,
              adminReleaseNotes: latestCloudInfo?.releaseNotes,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ ReleaseNotesService: Erro ao verificar notas pós-atualização: $e');
    }
  }

  /// Abre manualmente o modal de notas de versão a pedido do usuário
  void showReleaseNotes(BuildContext context, {ReleaseNoteVersion? version}) {
    final latestCloudInfo = _ref.read(latestUpdateInfoProvider).valueOrNull;
    ReleaseNotesDialog.show(
      context,
      isAfterUpdate: false,
      version: version ?? ReleaseNotesCatalog.latest,
      adminReleaseNotes: latestCloudInfo?.releaseNotes,
    );
  }
}
