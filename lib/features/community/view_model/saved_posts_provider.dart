import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final savedPostsProvider = StateNotifierProvider<SavedPostsNotifier, Set<String>>((ref) {
  return SavedPostsNotifier();
});

class SavedPostsNotifier extends StateNotifier<Set<String>> {
  SavedPostsNotifier() : super({}) {
    _load();
  }

  static const _key = 'saved_community_posts';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      state = list.toSet();
    } catch (_) {}
  }

  Future<bool> toggleSave(String postId) async {
    final next = Set<String>.from(state);
    final isNowSaved = !next.contains(postId);
    if (isNowSaved) {
      next.add(postId);
    } else {
      next.remove(postId);
    }
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, next.toList());
    } catch (_) {}
    return isNowSaved;
  }

  bool isSaved(String postId) => state.contains(postId);
}
