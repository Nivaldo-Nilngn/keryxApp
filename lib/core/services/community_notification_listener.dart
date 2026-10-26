import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/notification_service.dart';
import 'package:keryx_app/core/services/push_notification_service.dart';
import 'package:keryx_app/features/home/view_model/notifications_provider.dart';

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

        // Na primeira carga, marcamos todos como já conhecidos para evitar spam ao abrir o app
        if (_isInitialLoad) {
          _isInitialLoad = false;
          final pushService = _ref.read(pushNotificationServiceProvider);
          for (final n in notifs) {
            pushService.checkAndMarkAsNotified(n.id);
          }
          return;
        }

        final pushService = _ref.read(pushNotificationServiceProvider);
        final uiService = _ref.read(notificationUiServiceProvider);

        for (final n in notifs) {
          if (n.read == true) continue;

          // Se já foi notificado anteriormente, ignora
          final alreadyNotified = pushService.checkAndMarkAsNotified(n.id);
          if (alreadyNotified) continue;

          // Notificação genuinely nova!
          final title = n.title ??
              (n.type == 'reply'
                  ? 'Nova resposta de ${n.fromUserName}'
                  : n.type == 'like'
                      ? 'Nova curtida na Comunidade'
                      : 'Novo comentário de ${n.fromUserName}');
          final body = n.body.isNotEmpty ? n.body : (n.message ?? '');

          debugPrint('🔔 Nova notificação da comunidade detectada: $title - $body');

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

          // 2. Banner in-app se estiver em primeiro plano
          uiService.showInfo('$title: $body');
        }
      });
    });
  }

  void dispose() {
    _subscription?.close();
    _subscription = null;
    _isInitialLoad = true;
  }
}
