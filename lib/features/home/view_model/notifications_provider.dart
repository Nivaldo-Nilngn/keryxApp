import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/features/home/model/app_notification.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/services/app_update_service.dart';

/// Notifier para gerenciar IDs de notificações dispensadas localmente de forma imediata (UI otimista)
class DismissedNotificationIdsNotifier extends StateNotifier<Set<String>> {
  DismissedNotificationIdsNotifier() : super({});

  void dismiss(String id) {
    state = {...state, id};
  }

  void dismissAll(Iterable<String> ids) {
    state = {...state, ...ids};
  }

  void clear() {
    state = {};
  }
}

final dismissedNotificationIdsProvider =
    StateNotifierProvider<DismissedNotificationIdsNotifier, Set<String>>((ref) {
  return DismissedNotificationIdsNotifier();
});

/// Notifier para gerenciar dispensas de itens diários (Devocional do Dia, Hino do Dia)
class DismissedDailyNotifier extends StateNotifier<Set<String>> {
  DismissedDailyNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dismissed_daily_notifs') ?? [];
      state = list.toSet();
    } catch (_) {}
  }

  Future<void> dismiss(String key) async {
    final updated = {...state, key};
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('dismissed_daily_notifs', updated.toList());
    } catch (_) {}
  }

  Future<void> dismissAllDaily(List<String> keys) async {
    final updated = {...state, ...keys};
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('dismissed_daily_notifs', updated.toList());
    } catch (_) {}
  }
}

final dismissedDailyProvider =
    StateNotifierProvider<DismissedDailyNotifier, Set<String>>((ref) {
  return DismissedDailyNotifier();
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
          .toList());
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull ?? [];
  final dismissedIds = ref.watch(dismissedNotificationIdsProvider);
  final isUpdate = ref.watch(isUpdateAvailableProvider);
  return list.where((n) => !n.read && !dismissedIds.contains(n.id)).length + (isUpdate ? 1 : 0);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(authStateProvider).valueOrNull?.uid);
});

class NotificationService {
  final String? userId;
  NotificationService(this.userId);

  Future<void> markAsRead(String notificationId) async {
    if (userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
        'isRead': true,
      });
    } catch (e) {
      debugPrint('❌ Erro ao marcar notificação como lida: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (userId == null) return;
    final db = FirebaseFirestore.instance;
    try {
      final snap = await db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      if (snap.docs.isEmpty) return;
      final batch = db.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {
          'read': true,
          'isRead': true,
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('⚠️ Erro no batch markAllAsRead: $e. Tentando individual...');
      try {
        final snap = await db
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .get();
        for (var doc in snap.docs) {
          await doc.reference.update({
            'read': true,
            'isRead': true,
          }).catchError((_) {});
        }
      } catch (e2) {
        debugPrint('❌ Erro markAllAsRead individual: $e2');
      }
    }
  }

  Future<void> addNotification({
    required String title,
    required String message,
    String? type,
  }) async {
    if (userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'message': message,
        'read': false,
        'isRead': false,
        'type': type ?? 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Erro ao adicionar notificação no Firestore: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    if (userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      debugPrint('🗑️ Notificação $notificationId deletada do Firestore.');
    } catch (e) {
      debugPrint('❌ Erro ao deletar notificação $notificationId: $e');
    }
  }

  Future<void> deleteAllNotifications() async {
    if (userId == null) {
      debugPrint('⚠️ deleteAllNotifications: userId é nulo.');
      return;
    }
    final db = FirebaseFirestore.instance;
    try {
      final snap = await db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      debugPrint('🗑️ Apagando ${snap.docs.length} notificações do usuário $userId...');

      if (snap.docs.isEmpty) return;

      const chunkSize = 400;
      for (var i = 0; i < snap.docs.length; i += chunkSize) {
        final end = (i + chunkSize > snap.docs.length) ? snap.docs.length : i + chunkSize;
        final chunk = snap.docs.sublist(i, end);
        final batch = db.batch();
        for (var doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      debugPrint('✅ Todas as notificações foram apagadas com sucesso do Firestore.');
    } catch (e, stack) {
      debugPrint('⚠️ Erro no batch delete de notificações: $e. Tentando individual...');
      try {
        final snap = await db
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .get();
        await Future.wait(snap.docs.map((d) => d.reference.delete().catchError((_) {})));
        debugPrint('✅ Exclusão individual de notificações concluída.');
      } catch (e2) {
        debugPrint('❌ Erro crítico ao limpar notificações: $e2\n$stack');
      }
    }
  }
}
