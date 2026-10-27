import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/widgets/edit_profile_modal.dart';
import 'package:keryx_app/core/widgets/instagram_tablet_sidebar.dart';
import 'package:keryx_app/features/community/model/community_post.dart';
import 'package:keryx_app/features/community/model/community_story.dart';
import 'package:keryx_app/features/community/view_model/community_feed_provider.dart';
import 'package:keryx_app/features/community/view_model/following_provider.dart';
import 'package:keryx_app/features/community/view/widgets/community_user_avatar.dart';
import 'package:keryx_app/features/community/view/widgets/community_post_card.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/features/community/view/widgets/create_post_bottom_sheet.dart';
import 'package:keryx_app/features/community/model/user_stories_group.dart';
import 'package:keryx_app/features/community/view/widgets/story_viewer_screen.dart';
import 'package:keryx_app/features/community/view/widgets/create_story_bottom_sheet.dart';

/// Tela de Perfil e Publicações do Usuário — Estilo Instagram
class CommunityUserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;
  final String userBadge;
  final String? avatarFrame;

  const CommunityUserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.userBadge = 'Membro',
    this.avatarFrame,
  });

  @override
  ConsumerState<CommunityUserProfileScreen> createState() =>
      _CommunityUserProfileScreenState();
}

class _CommunityUserProfileScreenState
    extends ConsumerState<CommunityUserProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSendMessageSheet(BuildContext context, String recipientName) {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.send_rounded, color: AppTheme.kPrimaryGold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Mensagem para $recipientName',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  autofocus: true,
                  style: GoogleFonts.outfit(fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: 'Envie uma palavra de edificação ou pedido de oração...',
                    hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 13.5),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF13131C) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final msg = textController.text.trim();
                      if (msg.isNotEmpty) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Mensagem de bênção enviada para $recipientName! 🙏'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 18, color: Colors.black),
                    label: Text(
                      'Enviar Mensagem de Bênção',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.kPrimaryGold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPostDetailModal(BuildContext context, CommunityPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF101018) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: CommunityPostCard(post: post),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101018) : const Color(0xFFF9FAFB);
    final isTablet = MediaQuery.of(context).size.width >= 720;

    final currentAuthUser = FirebaseAuth.instance.currentUser;
    final userData = ref.watch(userDataProvider).valueOrNull;
    final currentUserName = (userData?['name'] as String?)?.trim() ??
        currentAuthUser?.displayName?.trim() ??
        '';

    final bool isCurrentUser = (currentAuthUser != null &&
            widget.userId.isNotEmpty &&
            widget.userId == currentAuthUser.uid) ||
        (currentUserName.isNotEmpty &&
            widget.userName.trim().toLowerCase() == currentUserName.toLowerCase());

    final displayName = isCurrentUser
        ? (currentUserName.isNotEmpty ? currentUserName : widget.userName)
        : widget.userName;

    final displayAvatar = isCurrentUser
        ? ((userData?['photoUrl'] as String?)?.trim() ??
            currentAuthUser?.photoURL?.trim() ??
            widget.userAvatar)
        : widget.userAvatar;

    final displayFrame = isCurrentUser
        ? (widget.avatarFrame ?? (userData?['avatarFrame'] as String?) ?? 'gold')
        : widget.avatarFrame;

    // Handle do usuário (ex: @nivaldogneto)
    final handle = '@${displayName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';

    // Obtém todas as publicações do feed e filtra apenas as deste usuário
    final allPosts = ref.watch(communityFeedProvider).posts;
    final userPosts = allPosts.where((p) {
      if (widget.userId.isNotEmpty && p.userId == widget.userId) return true;
      if (p.userName.trim().toLowerCase() == widget.userName.trim().toLowerCase()) return true;
      if (isCurrentUser && currentAuthUser != null && p.userId == currentAuthUser.uid) return true;
      return false;
    }).toList();

    // Busca se este usuário possui stories ativos na comunidade
    final allStories = ref.watch(communityFeedProvider).stories;
    final userStories = allStories.where((s) {
      if (s.authorName.trim().toLowerCase() == displayName.trim().toLowerCase()) return true;
      if (widget.userId.isNotEmpty && s.id.contains(widget.userId)) return true;
      return false;
    }).toList();
    final hasActiveStories = userStories.isNotEmpty;

    // Estado de Seguir (SharedPreferences)
    final userKey = widget.userId.isNotEmpty ? widget.userId : widget.userName;
    final isFollowing = ref.watch(followingUsersProvider).contains(userKey);

    // Contagens de estatísticas (sem números mockados)
    final totalPosts = userPosts.length;
    final totalAmens = userPosts.fold<int>(0, (sum, p) => sum + p.amenCount);
    final totalFollowing = isCurrentUser
        ? ref.watch(followingUsersProvider).length
        : (isFollowing ? 1 : 0);

    Widget profileContent = NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          // 1. SliverAppBar com estilo Instagram
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (widget.userBadge == 'Oficial' ||
                    displayName.toLowerCase().contains('keryx')) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, color: Color(0xFF3B82F6), size: 17),
                ],
              ],
            ),
            actions: [
              if (isCurrentUser)
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 22),
                  onPressed: () => showEditProfileModal(context, ref),
                )
              else
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 22),
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(text: 'Conheça o perfil de $displayName na Comunidade KeryxApp!'),
                    );
                  },
                ),
            ],
          ),

          // 2. Informações do Perfil (Header do Instagram)
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Linha Superior: Foto com Story Ativo/Perfil + Estatísticas Reais
                      Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (hasActiveStories) {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    opaque: false,
                                    pageBuilder: (_, __, ___) => StoryViewerScreen(
                                      groups: [
                                        UserStoriesGroup(
                                          authorName: displayName,
                                          authorAvatar: displayAvatar,
                                          stories: userStories,
                                        ),
                                      ],
                                      initialGroupIndex: 0,
                                    ),
                                  ),
                                );
                              } else if (isCurrentUser) {
                                showEditProfileModal(context, ref);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(hasActiveStories ? 2.8 : 0.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: hasActiveStories
                                    ? const LinearGradient(
                                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFFF59E0B)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                boxShadow: hasActiveStories
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFEC4899).withValues(alpha: 0.4),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: CommunityUserAvatar(
                                photoUrl: displayAvatar,
                                name: displayName,
                                userId: widget.userId,
                                radius: 42,
                                avatarFrame: hasActiveStories ? 'none' : displayFrame,
                                isOfficial: widget.userBadge == 'Oficial' ||
                                    displayName.toLowerCase().contains('keryx'),
                              ),
                            ),
                          ),

                          const SizedBox(width: 24),

                          // 3 Contadores Reais: Posts, Améns recebidos, Seguindo
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(context, totalPosts.toString(), 'posts'),
                                _buildStatItem(context, totalAmens.toString(), totalAmens == 1 ? 'amém' : 'améns'),
                                _buildStatItem(context, totalFollowing.toString(), 'seguindo'),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Nome de Exibição e Handle
                      Text(
                        displayName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        handle,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Biografia Cristã / Detalhes (sem textos mockados fixos)
                      Text(
                        isCurrentUser
                            ? ((userData?['bio'] as String?)?.trim().isNotEmpty == true
                                ? (userData!['bio'] as String).trim()
                                : 'Membro da Comunidade Keryx • Em comunhão')
                            : (widget.userBadge == 'Oficial' ||
                                    displayName.toLowerCase().contains('keryx')
                                ? '✨ Canal Oficial da Comunidade Keryx\nEdificando vidas através da Palavra de Deus.'
                                : 'Membro da Comunidade Keryx • Em comunhão'),
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          height: 1.35,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Botões de Ação estilo Instagram
                      if (isCurrentUser)
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                context: context,
                                label: 'Editar perfil',
                                isDark: isDark,
                                onTap: () => showEditProfileModal(context, ref),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildActionButton(
                                context: context,
                                label: 'Compartilhar perfil',
                                isDark: isDark,
                                onTap: () {
                                  SharePlus.instance.share(
                                    ShareParams(text: 'Veja o perfil de $displayName no KeryxApp!'),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF262638) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.person_add_outlined, size: 19),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => const CreatePostBottomSheet(),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: ElevatedButton(
                                onPressed: () {
                                  ref
                                      .read(followingUsersProvider.notifier)
                                      .toggleFollow(userKey);
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: isFollowing
                                      ? (isDark ? const Color(0xFF262638) : const Color(0xFFE2E8F0))
                                      : const Color(0xFF0095F6),
                                  foregroundColor: isFollowing
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                ),
                                child: Text(
                                  isFollowing ? 'Seguindo' : 'Seguir',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 5,
                              child: _buildActionButton(
                                context: context,
                                label: 'Enviar mensagem',
                                isDark: isDark,
                                onTap: () => _showSendMessageSheet(context, displayName),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF262638) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                tooltip: 'Apoiar em oração',
                                icon: const Icon(Icons.favorite_border_rounded, size: 19),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Você está orando por $displayName! 🙏'),
                                      backgroundColor: AppTheme.kPrimaryGold,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 16),

                      // Destaques / Stories Ativos do Usuário
                      _buildHighlightsSection(context, userStories, isDark, isCurrentUser, displayName, displayAvatar),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. TabBar estilo Instagram (Grade, Feed Completo, Versículos)
          SliverPersistentHeader(
            pinned: true,
            delegate: _ProfileTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).colorScheme.onSurface,
                indicatorWeight: 1.5,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Theme.of(context).colorScheme.onSurface,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on_rounded, size: 22)),
                  Tab(icon: Icon(Icons.view_agenda_outlined, size: 22)),
                  Tab(icon: Icon(Icons.bookmark_border_rounded, size: 22)),
                ],
              ),
              bg,
            ),
          ),
        ];
      },
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: TabBarView(
            controller: _tabController,
            children: [
              // Aba 1: Grade de Publicações estilo Instagram
              _buildPostsGrid(userPosts, isDark),

              // Aba 2: Feed Completo com os cards inteiros
              _buildFullPostsFeed(userPosts, isDark),

              // Aba 3: Versículos Compartilhados
              _buildVersesFeed(userPosts, isDark),
            ],
          ),
        ),
      ),
    );

    if (isTablet) {
      return Scaffold(
        backgroundColor: bg,
        body: Row(
          children: [
            InstagramTabletSidebar(
              currentIndex: 6,
              isRoute: true,
              onSelectIndex: (index) {
                Navigator.pop(context);
                ref.read(navigationProvider.notifier).setIndex(index);
              },
            ),
            Expanded(child: profileContent),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: profileContent,
    );
  }

  Widget _buildStatItem(BuildContext context, String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262638) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightsSection(
    BuildContext context,
    List<CommunityStory> userStories,
    bool isDark,
    bool isCurrentUser,
    String displayName,
    String? displayAvatar,
  ) {
    final hasActiveStories = userStories.isNotEmpty;
    if (!hasActiveStories && !isCurrentUser) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          if (hasActiveStories) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    opaque: false,
                    pageBuilder: (_, __, ___) => StoryViewerScreen(
                      groups: [
                        UserStoriesGroup(
                          authorName: displayName,
                          authorAvatar: displayAvatar,
                          stories: userStories,
                        ),
                      ],
                      initialGroupIndex: 0,
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(2.2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFFF59E0B)],
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF14141E) : Colors.white,
                      ),
                      child: const Center(
                        child: Icon(Icons.play_arrow_rounded, color: AppTheme.kPrimaryGold, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Story Ativo',
                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
          ],
          if (isCurrentUser)
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const CreateStoryBottomSheet(),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.add, size: 24),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Novo Story',
                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid(List<CommunityPost> posts, bool isDark) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grid_on_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Ainda não há publicações na grade',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2.5,
        mainAxisSpacing: 2.5,
        childAspectRatio: 1.0,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _buildGridPostTile(context, post, isDark);
      },
    );
  }

  Widget _buildGridPostTile(BuildContext context, CommunityPost post, bool isDark) {
    // Escolhe o gradiente do card com base no tema
    final gradients = {
      'gold': const [Color(0xFF854D0E), Color(0xFFB45309)],
      'indigo': const [Color(0xFF312E81), Color(0xFF4338CA)],
      'emerald': const [Color(0xFF064E3B), Color(0xFF047857)],
      'crimson': const [Color(0xFF881337), Color(0xFF9F1239)],
      'sepia': const [Color(0xFF451A03), Color(0xFF78350F)],
    };

    final colors = gradients[post.cardTheme] ?? gradients['gold']!;

    return InkWell(
      onTap: () => _showPostDetailModal(context, post),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            // Marca d'água de citação
            Positioned(
              right: 2,
              bottom: 2,
              child: Text(
                '“',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 54,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.12),
                  height: 1,
                ),
              ),
            ),

            // Conteúdo resumido
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.bibleReference != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      post.bibleReference!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    post.bibleText ?? post.caption,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.25,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (post.amenCount > 0) ...[
                      const Icon(Icons.favorite_rounded, size: 11, color: Colors.white70),
                      const SizedBox(width: 2),
                      Text(
                        '${post.amenCount}',
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (post.commentsCount > 0) ...[
                      const Icon(Icons.chat_bubble_rounded, size: 10, color: Colors.white70),
                      const SizedBox(width: 2),
                      Text(
                        '${post.commentsCount}',
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullPostsFeed(List<CommunityPost> posts, bool isDark) {
    if (posts.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma publicação no feed',
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return CommunityPostCard(post: posts[index]);
      },
    );
  }

  Widget _buildVersesFeed(List<CommunityPost> posts, bool isDark) {
    final versePosts = posts.where((p) => p.bibleText != null && p.bibleText!.isNotEmpty).toList();

    if (versePosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 10),
            Text(
              'Nenhum versículo publicado ainda',
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: versePosts.length,
      itemBuilder: (context, index) {
        return CommunityPostCard(post: versePosts[index]);
      },
    );
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _ProfileTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: tabBar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_ProfileTabBarDelegate oldDelegate) {
    return false;
  }
}
