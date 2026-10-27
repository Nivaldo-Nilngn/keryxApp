import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/model/community_story.dart';
import 'package:keryx_app/features/community/view/widgets/community_user_avatar.dart';
import 'package:keryx_app/features/community/view/widgets/story_viewer_screen.dart';

class CommunityStoriesTray extends ConsumerWidget {
  final List<CommunityStory> stories;
  final VoidCallback onAddStoryTap;

  const CommunityStoriesTray({
    super.key,
    required this.stories,
    required this.onAddStoryTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 94,
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Botão Adicionar Story / Meu Versículo com a foto do usuário atual
            return _buildAddStoryButton(context, ref, isDark);
          }

          final story = stories[index - 1];
          return _buildStoryItem(context, story, index - 1, isDark);
        },
      ),
    );
  }

  Widget _buildAddStoryButton(BuildContext context, WidgetRef ref, bool isDark) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userData = ref.watch(userDataProvider).valueOrNull;
    final userPhoto = (userData?['photoUrl'] as String?)?.trim() ??
        currentUser?.photoURL?.trim() ??
        (currentUser?.providerData.isNotEmpty == true
            ? currentUser!.providerData.first.photoURL?.trim()
            : null);
    final userName = (userData?['name'] as String?)?.trim() ??
        currentUser?.displayName ??
        'Você';

    return GestureDetector(
      onTap: onAddStoryTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF222234) : const Color(0xFFF1F3F5),
                  border: Border.all(
                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.6),
                    width: 1.8,
                  ),
                ),
                child: CommunityUserAvatar(
                  photoUrl: userPhoto,
                  name: userName,
                  radius: 25,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppTheme.kPrimaryGold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, size: 14, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              'Seu Versículo',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryItem(BuildContext context, CommunityStory story, int storyIndex, bool isDark) {
    final isOfficial = story.authorName.toLowerCase().contains('keryx') ||
        story.title.toLowerCase().contains('versículo do dia');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => StoryViewerScreen(
              stories: stories,
              initialIndex: storyIndex,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2.4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isOfficial
                  ? const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFEE5A24)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFFF59E0B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
          ),
          child: Container(
            padding: const EdgeInsets.all(1.8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF14141E) : Colors.white,
            ),
            child: CommunityUserAvatar(
              photoUrl: story.authorAvatar,
              name: story.authorName,
              radius: 25,
              isOfficial: isOfficial,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            story.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isOfficial ? FontWeight.bold : FontWeight.w500,
              color: isOfficial
                  ? AppTheme.kPrimaryGold
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    ),
  );
  }
}
