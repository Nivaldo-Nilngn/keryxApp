import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:keryx_app/core/services/auth_service.dart';

// ─── Provider ───────────────────────────────────────────────────────────────

final noteCardsProvider =
    StateNotifierProvider<NoteCardsNotifier, List<NoteCard>>((ref) {
      final user = ref.watch(authStateProvider).valueOrNull;
      return NoteCardsNotifier(user?.uid, user?.displayName, user?.photoURL);
    });

// ─── Notifier ────────────────────────────────────────────────────────────────

class NoteCardsNotifier extends StateNotifier<List<NoteCard>> {
  final String? userId;
  final String? userName;
  final String? userPhoto;

  NoteCardsNotifier(this.userId, this.userName, this.userPhoto) : super([]) {
    _load();
  }

  CollectionReference? get _col {
    if (userId == null) return null;
    return FirebaseFirestore.instance.collection('annotations');
  }

  Future<void> _load() async {
    if (_col == null) return;
    try {
      final snap = await _col!
          .where('authorId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .get();
      state = snap.docs
          .map(
            (d) => NoteCard.fromMap(Map<String, dynamic>.from(d.data() as Map)),
          )
          .where((c) => !c.isCommunityOnly)
          .toList();
    } catch (e) {
      debugPrint('NoteCards load error with orderBy, trying fallback: $e');
      try {
        final snap = await _col!
            .where('authorId', isEqualTo: userId)
            .get();
        final list = snap.docs
            .map((d) => NoteCard.fromMap(Map<String, dynamic>.from(d.data() as Map)))
            .where((c) => !c.isCommunityOnly)
            .toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        state = list;
      } catch (e2) {
        debugPrint('NoteCards fallback load error: $e2');
      }
    }
  }

  Future<void> save(NoteCard card) async {
    if (userId == null) return;
    final updated = card.copyWith(
      updatedAt: DateTime.now(),
      authorId: card.authorId ?? userId,
      authorName: card.authorName ?? userName ?? 'Anônimo',
      authorPhoto: card.authorPhoto ?? userPhoto,
    );
    final idx = state.indexWhere((c) => c.id == updated.id);
    if (idx >= 0) {
      state = [...state]..[idx] = updated;
    } else {
      state = [updated, ...state];
    }
    await _col?.doc(updated.id).set(updated.toMap());
  }

  Future<void> delete(String id) async {
    state = state.where((c) => c.id != id).toList();
    await _col?.doc(id).delete();
  }

  /// Toggles collapsed state locally (no Firestore write needed).
  void toggleCollapse(String id) {
    state = state.map((c) {
      if (c.id != id) return c;
      return c.copyWith(isCollapsed: !c.isCollapsed);
    }).toList();
  }

  /// Toggle public/private and persist.
  Future<void> togglePublic(String id) async {
    final idx = state.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final updated = state[idx].copyWith(isPublic: !state[idx].isPublic);
    state = [...state]..[idx] = updated;
    await _col?.doc(id).update({'isPublic': updated.isPublic});
  }
}
