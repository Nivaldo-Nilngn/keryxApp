import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final String text;
  final String kind; // 'pergunta', 'resposta', 'complemento'
  final String? replyToId;
  final String? replyToAuthorId;
  final String? replyToPreview;
  final bool isAccepted;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhoto,
    required this.text,
    required this.kind,
    this.replyToId,
    this.replyToAuthorId,
    this.replyToPreview,
    this.isAccepted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'authorPhoto': authorPhoto,
    'text': text,
    'kind': kind,
    'replyToId': replyToId,
    'replyToAuthorId': replyToAuthorId,
    'replyToPreview': replyToPreview,
    'isAccepted': isAccepted,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory Comment.fromMap(Map<String, dynamic> m, String docId) => Comment(
    id: docId,
    authorId: m['authorId'] ?? '',
    authorName: m['authorName'] ?? 'Anônimo',
    authorPhoto: m['authorPhoto'],
    text: m['text'] ?? '',
    kind: m['kind'] ?? 'complemento',
    replyToId: m['replyToId'],
    replyToAuthorId: m['replyToAuthorId'],
    replyToPreview: m['replyToPreview'],
    isAccepted: m['isAccepted'] ?? false,
    createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
