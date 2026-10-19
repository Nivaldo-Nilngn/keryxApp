import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type; // 'comment', 'reply', 'download', 'system'
  final String annotationId;
  final String commentId;
  final String fromUserId;
  final String fromUserName;
  final String body;
  final String? title;   // Para notificações de download/sistema
  final String? message; // Para notificações de download/sistema
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.annotationId,
    required this.commentId,
    required this.fromUserId,
    required this.fromUserName,
    required this.body,
    this.title,
    this.message,
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m, String id) => AppNotification(
        id: id,
        type: m['type'] ?? 'comment',
        annotationId: m['annotationId'] ?? '',
        commentId: m['commentId'] ?? '',
        fromUserId: m['fromUserId'] ?? '',
        fromUserName: m['fromUserName'] ?? 'Alguém',
        body: m['body'] ?? m['message'] ?? '',
        title: m['title'] as String?,
        message: m['message'] as String?,
        read: m['read'] ?? false,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  bool get isSystemNotification =>
      type == 'download' || type == 'system' || type == 'delete';
}
