import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/theme/avatar_frame_options.dart';
import 'package:keryx_app/features/community/model/community_story.dart';
import 'package:keryx_app/features/community/model/user_stories_group.dart';
import 'package:keryx_app/features/community/view/community_user_profile_screen.dart';
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

    final currentUser = FirebaseAuth.instance.currentUser;
    final userData = ref.watch(userDataProvider).valueOrNull;
    final currentUserName = (userData?['name'] as String?)?.trim() ??
        currentUser?.displayName?.trim() ??
        '';

    // Separa os stories do usuário atual para unificar no primeiro botão e evitar duplicata
    UserStoriesGroup? myStoriesGroup;
    final otherGroups = <UserStoriesGroup>[];

    for (final group in groups) {
      final gName = group.displayName.trim().toLowerCase();
      final isMe = (currentUserName.isNotEmpty && gName == currentUserName.toLowerCase()) ||
          (currentUser?.displayName != null &&
              gName == currentUser!.displayName!.trim().toLowerCase()) ||
          (currentUser?.email != null &&
              gName == currentUser!.email!.split('@').first.trim().toLowerCase());

      if (isMe) {
        if (myStoriesGroup == null) {
          myStoriesGroup = group;
        } else {
          myStoriesGroup = UserStoriesGroup(
            authorName: myStoriesGroup.authorName,
            authorAvatar: myStoriesGroup.authorAvatar ?? group.authorAvatar,
            stories: [...myStoriesGroup.stories, ...group.stories],
          );
        }
      } else {
        otherGroups.add(group);
      }
    }

    final items = <Widget>[
      _buildUserStoryButton(context, ref, myStoriesGroup, isDark),
      for (int i = 0; i < otherGroups.length; i++) ...[
        const SizedBox(width: 12),
        _buildStoryGroupItem(context, ref, otherGroups[i], otherGroups, i, isDark),
      ],
    ];

    return Container(
      width: double.infinity,
      height: 94,
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items,
        ),
      ),
    );
  }

  Widget _buildUserStoryButton(
    BuildContext context,
    WidgetRef ref,
    UserStoriesGroup? myStoriesGroup,
    bool isDark,
  ) {
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

    final hasActiveStories = myStoriesGroup != null && myStoriesGroup.stories.isNotEmpty;
    final storiesCount = myStoriesGroup?.stories.length ?? 0;

    // Gradiente do story ativo
    const activeStoryRing = LinearGradient(
      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFFF59E0B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    void openUserProfile() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityUserProfileScreen(
            userId: currentUser?.uid ?? '',
            userName: userName,
            userAvatar: userPhoto,
            userBadge: 'Membro',
            avatarFrame: userFrameId,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Clique na foto -> Abre o perfil do usuário
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openUserProfile,
              child: Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(2.4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasActiveStories
                      ? activeStoryRing
                      : (userFrameId != 'none'
                          ? LinearGradient(
                              colors: frame.colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null),
                  border: (!hasActiveStories && userFrameId == 'none')
                      ? Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1.5,
                        )
                      : null,
                  boxShadow: (hasActiveStories || userFrameId != 'none')
                      ? [
                          BoxShadow(
                            color: (hasActiveStories
                                    ? const Color(0xFFEC4899)
                                    : frame.shadowColor)
                                .withValues(alpha: 0.45),
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
            ),

            // Badge com número de stories se houver múltiplos
            if (hasActiveStories && storiesCount > 1)
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
                    '$storiesCount',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),

            // Clique no botão "+" -> Abre publicação do story
            Positioned(
              bottom: -1,
              right: -1,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAddStoryTap,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.kPrimaryGold,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF14141E) : Colors.white,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.add, size: 14, color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: openUserProfile,
          child: SizedBox(
            width: 68,
            child: Text(
              'Seu Versículo',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ],
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
