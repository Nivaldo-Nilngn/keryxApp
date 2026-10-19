import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/study/model/comment.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:keryx_app/core/services/auth_service.dart';

final commentsStreamProvider = StreamProvider.family<List<Comment>, String>((
  ref,
  annotationId,
) {
  return FirebaseFirestore.instance
      .collection('annotations')
      .doc(annotationId)
      .collection('comments')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => Comment.fromMap(doc.data(), doc.id))
            .toList(),
      );
});

final commentsServiceProvider = Provider<CommentsService>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return CommentsService(
    userId: user?.uid,
    userName: user?.displayName,
    userPhoto: user?.photoURL,
  );
});

class CommentsService {
  final String? userId;
  final String? userName;
  final String? userPhoto;

  CommentsService({this.userId, this.userName, this.userPhoto});

  Future<void> addComment({
    required NoteCard annotation,
    required String text,
    required String kind,
    Comment? replyTo,
  }) async {
    if (userId == null) return;

    final db = FirebaseFirestore.instance;
    final annRef = db.collection('annotations').doc(annotation.id);
    final commentRef = annRef.collection('comments').doc();
    final batch = db.batch();

    batch.set(commentRef, {
      'authorId': userId,
      'authorName': userName ?? 'Anônimo',
      'authorPhoto': userPhoto,
      'text': text,
      'kind': kind,
      'replyToId': replyTo?.id,
      'replyToAuthorId': replyTo?.authorId,
      'replyToPreview': replyTo?.text,
      'isAccepted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(annRef, {
      'commentCount': FieldValue.increment(1),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });

    // Notificar dono da anotação + dono do comentário respondido, sem duplicar e sem ser para mim mesmo
    final targets = {annotation.authorId, if (replyTo != null) replyTo.authorId}
      ..remove(userId)
      ..remove(null); // Just in case any is null

    for (final targetId in targets) {
      if (targetId == null) continue;

      final notifRef = db
          .collection('users')
          .doc(targetId)
          .collection('notifications')
          .doc();
      batch.set(notifRef, {
        'type': targetId == replyTo?.authorId ? 'reply' : 'comment',
        'annotationId': annotation.id,
        'commentId': commentRef.id,
        'fromUserId': userId,
        'fromUserName': userName ?? 'Anônimo',
        'body': text,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> acceptAnswer(String annotationId, String commentId) async {
    final db = FirebaseFirestore.instance;
    await db
        .collection('annotations')
        .doc(annotationId)
        .collection('comments')
        .doc(commentId)
        .update({'isAccepted': true});
  }

  Future<void> deleteComment(String annotationId, String commentId) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    
    final annRef = db.collection('annotations').doc(annotationId);
    final commentRef = annRef.collection('comments').doc(commentId);
    
    batch.delete(commentRef);
    batch.update(annRef, {
      'commentCount': FieldValue.increment(-1),
    });
    
    await batch.commit();
  }
}
