import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final followingUsersProvider = StateNotifierProvider<FollowingNotifier, Set<String>>((ref) {
  return FollowingNotifier();
});

class FollowingNotifier extends StateNotifier<Set<String>> {
  FollowingNotifier() : super({}) {
    _load();
  }

  static const _key = 'followed_community_users';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      state = list.toSet();
    } catch (_) {}
  }

  Future<bool> toggleFollow(String userKey) async {
    final next = Set<String>.from(state);
    final isNowFollowing = !next.contains(userKey);
    if (isNowFollowing) {
      next.add(userKey);
    } else {
      next.remove(userKey);
    }
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, next.toList());
    } catch (_) {}
    return isNowFollowing;
  }

  bool isFollowing(String userKey) => state.contains(userKey);
}
