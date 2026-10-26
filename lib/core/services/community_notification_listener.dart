import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/notification_service.dart';
import 'package:keryx_app/core/services/push_notification_service.dart';
import 'package:keryx_app/features/home/view_model/notifications_provider.dart' hide NotificationService;

final communityNotificationListenerProvider = Provider(CommunityNotificationListener.new);

/// Monitora em tempo real a chegada de novas notificações da Comunidade (comentários, respostas e curtidas)
/// e dispara alertas locais nativos e in-app para o criador da publicação.
class CommunityNotificationListener {
  CommunityNotificationListener(this._ref);
  final Ref _ref;

  bool _isInitialLoad = true;
  ProviderSubscription? _subscription;

  void startListening() {
    _subscription?.close();

    _subscription = _ref.listen<AsyncValue<dynamic>>(notificationsProvider, (previous, next) {
      next.whenData((notifs) {
        if (notifs is! List) return;

        final pushService = _ref.read(pushNotificationServiceProvider);
        final uiService = _ref.read(notificationUiServiceProvider);

        // Na primeira carga (quando o app é aberto ou restaurado do background):
        if (_isInitialLoad) {
          _isInitialLoad = false;
          // DIRETRIZ DE SEGURANÇA (espelhada do Finanças Peniel):
          // Se houver notificações não lidas recentes (últimas 24h) que AINDA NÃO FORAM NOTIFICADAS
          // neste aparelho, disparamos a notificação no sistema agora!
          // Isso resolve o caso do usuário estar com o app minimizado ou fechado quando a notificação foi enviada.
          final now = DateTime.now();
          for (final n in notifs) {
            if (n.read == true) {
              pushService.checkAndMarkAsNotified(n.id);
              continue;
            }
            final createdAt = n.createdAt ?? now;
            final hoursDiff = now.difference(createdAt).inHours;
            if (hoursDiff <= 24) {
              final alreadyNotified = pushService.checkAndMarkAsNotified(n.id);
              if (!alreadyNotified) {
                _dispatchNotification(n, pushService, uiService, isCatchUp: true);
              }
            } else {
              pushService.checkAndMarkAsNotified(n.id);
            }
          }
          return;
        }

        // Cargas em tempo real (enquanto o app está em execução, aberto ou minimizado):
        for (final n in notifs) {
          if (n.read == true) continue;

          // Se já foi notificado anteriormente, ignora
          final alreadyNotified = pushService.checkAndMarkAsNotified(n.id);
          if (alreadyNotified) continue;

          _dispatchNotification(n, pushService, uiService, isCatchUp: false);
        }
      });
    });
  }

  void _dispatchNotification(
    dynamic n,
    PushNotificationService pushService,
    NotificationService uiService, {
    required bool isCatchUp,
  }) {
    // Notificação genuinely nova!
    final title = n.title ??
        (n.type == 'reply'
            ? 'Nova resposta de ${n.fromUserName}'
            : n.type == 'like'
                ? 'Nova curtida na Comunidade'
                : 'Novo comentário de ${n.fromUserName}');
    final body = n.body.isNotEmpty ? n.body : (n.message ?? '');

    debugPrint('🔔 [Comunidade] Disparando notificação no sistema (catchUp=$isCatchUp): $title - $body');

    // 1. Notificação nativa no sistema (Android, iOS)
    pushService.showLocalNotification(
      id: n.id,
      title: title,
      body: body,
      payload: {
        'notificationId': n.id,
        'annotationId': n.annotationId,
        'commentId': n.commentId,
        'type': n.type,
      },
    );

    // 2. Banner in-app se for em tempo real (não na recuperação inicial de catch-up)
    if (!isCatchUp) {
      uiService.showInfo('$title: $body');
    }
  }

  void dispose() {
    _subscription?.close();
    _subscription = null;
    _isInitialLoad = true;
  }
}
