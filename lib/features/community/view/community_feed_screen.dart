import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/view_model/community_feed_provider.dart';
import 'package:keryx_app/features/community/view/widgets/community_stories_tray.dart';
import 'package:keryx_app/features/community/view/widgets/community_post_card.dart';
import 'package:keryx_app/features/community/view/widgets/create_post_bottom_sheet.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/state/navigation_state.dart';

class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  ConsumerState<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        ref.read(communityFeedProvider.notifier).loadMore();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(navbarVisibleProvider)) {
        ref.read(navbarVisibleProvider.notifier).state = true;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePostBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityFeedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101018) : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 96),
        child: FloatingActionButton.extended(
          backgroundColor: AppTheme.kPrimaryGold,
          foregroundColor: Colors.black,
          elevation: 4,
          onPressed: _openCreatePostModal,
          icon: const Icon(Icons.add_rounded, size: 22, color: Colors.black),
          label: Text(
            'Compartilhar Palavra',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppTheme.kPrimaryGold,
            backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
            onRefresh: () => ref.read(communityFeedProvider.notifier).refresh(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // 1. SliverAppBar estilo Instagram / Redes Sociais
                SliverAppBar(
                  floating: true,
                  pinned: false,
                  elevation: 0,
                  backgroundColor: isDark ? const Color(0xFF101018) : const Color(0xFFF9FAFB),
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people_alt_rounded, color: Colors.black, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Comunidade',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.add_box_outlined, size: 24),
                      tooltip: 'Criar Postagem',
                      color: AppTheme.kPrimaryGold,
                      onPressed: _openCreatePostModal,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),

                // 2. Stories Tray no Topo
                SliverToBoxAdapter(
                  child: CommunityStoriesTray(
                    stories: state.stories,
                    onAddStoryTap: _openCreatePostModal,
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Divider(
                      height: 1,
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),

                // 3. Conteúdo Principal do Feed
                if (state.isLoading && state.posts.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.kPrimaryGold),
                    ),
                  )
                else if (state.posts.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.volunteer_activism_outlined,
                            size: 54,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Nenhuma publicação ainda.\nSeja o primeiro a compartilhar uma bênção!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _openCreatePostModal,
                            icon: const Icon(Icons.add, size: 18, color: Colors.black),
                            label: const Text('Publicar Agora'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.kPrimaryGold,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = state.posts[index];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: CommunityPostCard(post: post),
                          ),
                        );
                      },
                      childCount: state.posts.length,
                    ),
                  ),

                  // Espaçador do rodapé para o bottom nav
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 130),
                  ),
                ],
              ],
            ),
          ),

          // Bottom Nav Bar Unificada
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomBottomNav(
              currentIndex: 6, // Não seleciona nenhum para permitir voltar
              onTap: (index) {
                Navigator.pop(context);
                ref.read(navigationProvider.notifier).setIndex(index);
              },
              onBack: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
