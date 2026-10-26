import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';

final publicAnnotationsProvider = StateNotifierProvider<PublicAnnotationsNotifier, AsyncValue<List<NoteCard>>>((ref) {
  return PublicAnnotationsNotifier();
});

class PublicAnnotationsNotifier extends StateNotifier<AsyncValue<List<NoteCard>>> {
  PublicAnnotationsNotifier() : super(const AsyncLoading()) {
    loadFirstPage();
  }

  final _db = FirebaseFirestore.instance;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isFetching = false;
  static const int _limit = 15;

  bool get hasMore => _hasMore;

  Future<void> loadFirstPage() async {
    if (_isFetching) return;
    _isFetching = true;
    state = const AsyncLoading();

    try {
      final snap = await _db
          .collection('annotations')
          .where('isPublic', isEqualTo: true)
          .orderBy('lastActivityAt', descending: true)
          .limit(_limit)
          .get();

      if (snap.docs.isEmpty) {
        _hasMore = false;
        state = const AsyncData([]);
        _isFetching = false;
        return;
      }

      _lastDoc = snap.docs.last;
      _hasMore = snap.docs.length == _limit;
      final items = snap.docs.map((d) => NoteCard.fromMap(d.data())).toList();
      
      final itemsWithLikes = await _checkLikes(items);
      state = AsyncData(itemsWithLikes);
    } catch (e) {
      _hasMore = false;
      state = const AsyncData([]);
    } finally {
      _isFetching = false;
    }
  }

  Future<void> loadNextPage() async {
    if (_isFetching || !_hasMore || _lastDoc == null) return;
    _isFetching = true;

    try {
      final snap = await _db
          .collection('annotations')
          .where('isPublic', isEqualTo: true)
          .orderBy('lastActivityAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(_limit)
          .get();

      if (snap.docs.isEmpty) {
        _hasMore = false;
        _isFetching = false;
        return;
      }

      _lastDoc = snap.docs.last;
      _hasMore = snap.docs.length == _limit;
      final newItems = snap.docs.map((d) => NoteCard.fromMap(d.data())).toList();
      final newItemsWithLikes = await _checkLikes(newItems);
      
      final currentList = state.valueOrNull ?? [];
      state = AsyncData([...currentList, ...newItemsWithLikes]);
    } catch (e) {
      // Falha silenciosa
    } finally {
      _isFetching = false;
    }
  }

  Future<List<NoteCard>> _checkLikes(List<NoteCard> notes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return notes;
    
    final List<NoteCard> updatedNotes = [];
    for (final note in notes) {
      try {
        final likeSnap = await _db
            .collection('annotations')
            .doc(note.id)
            .collection('likes')
            .doc(user.uid)
            .get();
        updatedNotes.add(note.copyWith(isLikedByMe: likeSnap.exists));
      } catch (_) {
        updatedNotes.add(note);
      }
    }
    return updatedNotes;
  }

  Future<void> refresh() async {
    _lastDoc = null;
    _hasMore = true;
    await loadFirstPage();
  }

  Future<void> toggleLike(NoteCard note) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) return;

    final batch = _db.batch();
    final noteRef = _db.collection('annotations').doc(note.id);
    final likeRef = noteRef.collection('likes').doc(user.uid);

    final isLiked = note.isLikedByMe;

    if (isLiked) {
      batch.delete(likeRef);
      batch.update(noteRef, {'likeCount': FieldValue.increment(-1)});
    } else {
      batch.set(likeRef, {'timestamp': FieldValue.serverTimestamp()});
      batch.update(noteRef, {'likeCount': FieldValue.increment(1)});

      if (note.authorId != null && note.authorId != user.uid) {
        final notifRef = _db
            .collection('users')
            .doc(note.authorId)
            .collection('notifications')
            .doc();
        batch.set(notifRef, {
          'type': 'like',
          'title': 'Nova curtida na Comunidade',
          'body': '${user.displayName ?? 'Alguém'} curtiu sua publicação "${note.title}".',
          'message': '${user.displayName ?? 'Alguém'} curtiu sua publicação "${note.title}".',
          'postTitle': note.title,
          'annotationId': note.id,
          'fromUserId': user.uid,
          'fromUserName': user.displayName ?? 'Alguém',
          'read': false,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    try {
      await batch.commit();
      
      final currentList = state.valueOrNull ?? [];
      final index = currentList.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        int newLikeCount = isLiked ? note.likeCount - 1 : note.likeCount + 1;
        if (newLikeCount < 0) newLikeCount = 0; // Trava contra negativos
        
        final updatedNote = currentList[index].copyWith(
          likeCount: newLikeCount,
          isLikedByMe: !isLiked,
        );
        currentList[index] = updatedNote;
        state = AsyncData([...currentList]);
      }
    } catch (e) {
      // Ignorar erro silenciosamente para não quebrar fluxo
    }
  }

}
