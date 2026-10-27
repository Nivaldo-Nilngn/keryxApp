import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/theme/avatar_frame_options.dart';
import 'package:keryx_app/features/community/model/community_story.dart';
import 'package:keryx_app/features/community/model/user_stories_group.dart';
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
    final groups = UserStoriesGroup.fromStories(stories);

    return Container(
      height: 94,
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: groups.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Botão Adicionar Story / Meu Versículo com a foto do usuário atual
            return _buildAddStoryButton(context, ref, isDark);
          }

          final group = groups[index - 1];
          return _buildStoryGroupItem(context, ref, group, groups, index - 1, isDark);
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
    final userFrameId = (userData?['avatarFrame'] as String?) ?? 'gold';
    final frame = AvatarFrameOption.getById(userFrameId);

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
                padding: const EdgeInsets.all(2.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: userFrameId != 'none'
                      ? LinearGradient(
                          colors: frame.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  border: userFrameId == 'none'
                      ? Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1.5,
                        )
                      : null,
                  boxShadow: userFrameId != 'none'
                      ? [
                          BoxShadow(
                            color: frame.shadowColor.withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  padding: const EdgeInsets.all(1.6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF14141E) : Colors.white,
                  ),
                  child: CommunityUserAvatar(
                    photoUrl: userPhoto,
                    name: userName,
                    radius: 24,
                    avatarFrame: 'none',
                  ),
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

  Widget _buildStoryGroupItem(
    BuildContext context,
    WidgetRef ref,
    UserStoriesGroup group,
    List<UserStoriesGroup> allGroups,
    int groupIndex,
    bool isDark,
  ) {
    final isOfficial = group.isOfficial;
    final hasMultipleStories = group.stories.length > 1;

    final currentUser = FirebaseAuth.instance.currentUser;
    final userData = ref.watch(userDataProvider).valueOrNull;
    final currentUserName = (userData?['name'] as String?)?.trim() ??
        currentUser?.displayName?.trim() ??
        '';
    final isCurrentUser = currentUserName.isNotEmpty &&
        group.displayName.trim().toLowerCase() == currentUserName.toLowerCase();

    final userPhoto = (userData?['photoUrl'] as String?)?.trim() ??
        currentUser?.photoURL?.trim();
    final userFrameId = (userData?['avatarFrame'] as String?) ?? 'gold';
    final frame = AvatarFrameOption.getById(userFrameId);

    final effectiveAvatar = isCurrentUser && userPhoto != null && userPhoto.isNotEmpty
        ? userPhoto
        : group.resolvedAvatar;
    final effectiveName = isCurrentUser ? currentUserName : group.displayName;

    final ringGradient = isOfficial
        ? const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFEE5A24)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : (isCurrentUser && userFrameId != 'none'
            ? LinearGradient(
                colors: frame.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => StoryViewerScreen(
              groups: allGroups,
              initialGroupIndex: groupIndex,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2.4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: ringGradient,
                ),
                child: Container(
                  padding: const EdgeInsets.all(1.8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF14141E) : Colors.white,
                  ),
                  child: CommunityUserAvatar(
                    photoUrl: effectiveAvatar,
                    name: effectiveName,
                    radius: 25,
                    isOfficial: isOfficial,
                    avatarFrame: 'none',
                  ),
                ),
              ),

              // Badge sutil se o usuário tiver múltiplos stories ativos
              if (hasMultipleStories)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppTheme.kPrimaryGold,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF14141E) : Colors.white,
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      '${group.stories.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              group.displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isOfficial ? FontWeight.bold : FontWeight.w600,
                color: isOfficial
                    ? AppTheme.kPrimaryGold
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.90),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
