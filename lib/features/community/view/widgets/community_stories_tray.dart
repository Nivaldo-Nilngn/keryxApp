import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/model/community_story.dart';
import 'package:keryx_app/features/community/view/widgets/story_viewer_screen.dart';

class CommunityStoriesTray extends StatelessWidget {
  final List<CommunityStory> stories;
  final VoidCallback onAddStoryTap;

  const CommunityStoriesTray({
    super.key,
    required this.stories,
    required this.onAddStoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Botão Adicionar Story / Meu Versículo
            return _buildAddStoryButton(context, isDark);
          }

          final story = stories[index - 1];
          return _buildStoryItem(context, story, isDark);
        },
      ),
    );
  }

  Widget _buildAddStoryButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: onAddStoryTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF222234) : const Color(0xFFF1F3F5),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 28,
                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppTheme.kPrimaryGold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, size: 15, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              'Seu Versículo',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryItem(BuildContext context, CommunityStory story, bool isDark) {
    final isOfficial = story.authorName.toLowerCase().contains('keryx') ||
        story.title.toLowerCase().contains('versículo do dia');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => StoryViewerScreen(story: story),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2.8),
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
              padding: const EdgeInsets.all(2.2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF14141E) : Colors.white,
              ),
              child: CircleAvatar(
                radius: 29,
                backgroundColor: isDark ? const Color(0xFF262638) : const Color(0xFFE2E8F0),
                backgroundImage: story.authorAvatar != null && story.authorAvatar!.isNotEmpty
                    ? NetworkImage(story.authorAvatar!)
                    : null,
                child: (story.authorAvatar == null || story.authorAvatar!.isEmpty)
                    ? Icon(
                        isOfficial ? Icons.auto_awesome : Icons.person_rounded,
                        color: isOfficial ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                        size: 24,
                      )
                    : null,
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
