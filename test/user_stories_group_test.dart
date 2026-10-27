import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/features/community/model/community_story.dart';
import 'package:keryx_app/features/community/model/user_stories_group.dart';

void main() {
  group('UserStoriesGroup Tests', () {
    test('Agrupa stories do mesmo autor em um único grupo', () {
      final now = DateTime.now();
      final stories = [
        CommunityStory(
          id: '1',
          authorName: 'Nivaldo G Neto',
          authorAvatar: 'https://example.com/photo.jpg',
          title: 'Salmos 23:1',
          verseText: 'O Senhor é o meu pastor',
          createdAt: now,
        ),
        CommunityStory(
          id: '2',
          authorName: 'Nivaldo G Neto',
          title: 'Teste de Fé',
          verseText: 'Posso todas as coisas em Cristo',
          createdAt: now.add(const Duration(minutes: 5)),
        ),
        CommunityStory(
          id: '3',
          authorName: 'Keryx Oficial',
          title: 'Versículo do Dia',
          verseText: 'No princípio era o Verbo',
          createdAt: now.add(const Duration(minutes: 10)),
        ),
      ];

      final groups = UserStoriesGroup.fromStories(stories);

      expect(groups.length, 2);

      // Primeiro grupo: Nivaldo G Neto com 2 stories
      final nivaldoGroup = groups.firstWhere((g) => g.authorName == 'Nivaldo G Neto');
      expect(nivaldoGroup.stories.length, 2);
      expect(nivaldoGroup.resolvedAvatar, 'https://example.com/photo.jpg');
      expect(nivaldoGroup.isOfficial, false);

      // Segundo grupo: Keryx Oficial com 1 story
      final keryxGroup = groups.firstWhere((g) => g.authorName == 'Keryx Oficial');
      expect(keryxGroup.stories.length, 1);
      expect(keryxGroup.isOfficial, true);
    });

    test('displayName e resolvedAvatar se comportam corretamente com valores vazios', () {
      final group = UserStoriesGroup(
        authorName: '   ',
        stories: [
          CommunityStory(
            id: '1',
            authorName: '',
            title: 'Salmos 91',
            createdAt: DateTime.now(),
          ),
        ],
      );

      expect(group.displayName, 'Comunidade');
      expect(group.resolvedAvatar, isNull);
    });
  });
}
