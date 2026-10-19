import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/home/model/app_notification.dart';
import 'package:keryx_app/core/services/auth_service.dart';

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => AppNotification.fromMap(doc.data(), doc.id)).toList());
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull ?? [];
  return list.where((n) => !n.read).length;
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(authStateProvider).valueOrNull?.uid);
});

class NotificationService {
  final String? userId;
  NotificationService(this.userId);

  Future<void> markAsRead(String notificationId) async {
    if (userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> markAllAsRead() async {
    if (userId == null) return;
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    
    final snap = await db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    for (var doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }

  Future<void> addNotification({required String title, required String message, String? type}) async {
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
        'type': type ?? 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erro ao adicionar notificação no Firestore: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    if (userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteAllNotifications() async {
    if (userId == null) return;
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final snap = await db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .get();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
