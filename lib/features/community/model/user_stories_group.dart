import 'package:keryx_app/features/community/model/community_story.dart';

/// Agrupa os stories de um mesmo usuário/autor para exibição estilo Instagram/WhatsApp
class UserStoriesGroup {
  final String authorName;
  final String? authorAvatar;
  final List<CommunityStory> stories;

  UserStoriesGroup({
    required this.authorName,
    this.authorAvatar,
    required this.stories,
  });

  /// Identifica se é o canal institucional/oficial Keryx
  bool get isOfficial {
    final lower = authorName.toLowerCase();
    return lower.contains('keryx') || lower.contains('oficial');
  }

  /// Nome formatado para o badge inferior do círculo
  String get displayName {
    final trimmed = authorName.trim();
    if (trimmed.isEmpty) return 'Comunidade';
    return trimmed;
  }

  /// Pega o avatar mais confiável do grupo
  String? get resolvedAvatar {
    if (authorAvatar != null && authorAvatar!.trim().isNotEmpty) {
      return authorAvatar!.trim();
    }
    for (final s in stories) {
      if (s.authorAvatar != null && s.authorAvatar!.trim().isNotEmpty) {
        return s.authorAvatar!.trim();
      }
    }
    return null;
  }

  /// Agrupa uma lista plana de stories em grupos únicos por autor
  static List<UserStoriesGroup> fromStories(List<CommunityStory> list) {
    final Map<String, List<CommunityStory>> map = {};
    for (final s in list) {
      final key = s.authorName.trim().isEmpty ? 'Keryx Comunidade' : s.authorName.trim();
      map.putIfAbsent(key, () => []).add(s);
    }
    return map.entries.map((e) {
      final firstAvatar = e.value.firstWhere(
        (st) => st.authorAvatar != null && st.authorAvatar!.trim().isNotEmpty,
        orElse: () => e.value.first,
      ).authorAvatar;
      return UserStoriesGroup(
        authorName: e.key,
        authorAvatar: firstAvatar,
        stories: e.value,
      );
    }).toList();
  }
}
