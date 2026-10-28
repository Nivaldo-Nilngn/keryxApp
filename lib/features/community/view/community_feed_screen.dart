import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/view_model/community_feed_provider.dart';
import 'package:keryx_app/features/community/view/widgets/community_stories_tray.dart';
import 'package:keryx_app/features/community/view/widgets/community_post_card.dart';
import 'package:keryx_app/features/community/view/widgets/create_post_bottom_sheet.dart';
import 'package:keryx_app/features/community/view/widgets/create_story_bottom_sheet.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/widgets/instagram_tablet_sidebar.dart';

class CommunityFeedScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const CommunityFeedScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'all'; // 'all', 'prayer', 'verse', 'testimony'

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

  void _openCreatePostModal({String initialCategory = 'reflection'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePostBottomSheet(initialCategory: initialCategory),
    );
  }

  void _openCreateStoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateStoryBottomSheet(),
    );
  }

  Widget _buildCriarButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _openCreatePostModal,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD97706).withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.black, size: 19),
              const SizedBox(width: 4),
              Text(
                'Criar',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderContent(CommunityFeedState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6.5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Comunidade',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  state.posts.isNotEmpty
                      ? 'Em comunhão • ${state.posts.length} ${state.posts.length == 1 ? "publicação" : "publicações"}'
                      : 'Em comunhão',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityFeedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101018) : const Color(0xFFF9FAFB);

    // Filtragem local por categoria
    final filteredPosts = state.posts.where((p) {
      if (_selectedCategory == 'prayer') {
        return p.caption.toLowerCase().contains('oração') ||
            p.caption.toLowerCase().contains('interced') ||
            p.userBadge == 'Líder';
      }
      if (_selectedCategory == 'verse') {
        return p.bibleText != null && p.bibleText!.isNotEmpty;
      }
      if (_selectedCategory == 'testimony') {
        return p.caption.toLowerCase().contains('testemunh') ||
            p.caption.toLowerCase().contains('glória a deus') ||
            p.caption.toLowerCase().contains('agradeç');
      }
      return true; // 'all'
    }).toList();

    final isTablet = MediaQuery.of(context).size.width >= 720;

    Widget bodyContent = Stack(
      children: [
        RefreshIndicator(
          color: AppTheme.kPrimaryGold,
          backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          onRefresh: () => ref.read(communityFeedProvider.notifier).refresh(),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // 1. SliverAppBar com status vivo
              SliverAppBar(
                floating: true,
                pinned: false,
                elevation: 0,
                backgroundColor: isDark ? const Color(0xFF101018) : const Color(0xFFF9FAFB),
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                leading: (widget.isEmbedded && isTablet)
                    ? null
                    : IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () {
                          if (widget.isEmbedded) {
                            ref.read(navigationProvider.notifier).setIndex(0);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                title: isTablet
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                _buildHeaderContent(state),
                                const Spacer(),
                                _buildCriarButton(),
                              ],
                            ),
                          ),
                        ),
                      )
                    : _buildHeaderContent(state),
                actions: isTablet
                    ? null
                    : [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: _buildCriarButton(),
                          ),
                        ),
                      ],
              ),

              // 2. Stories Tray no Topo (Alinhado com a largura do Feed)
              SliverToBoxAdapter(
                child: Center(
                  child: SizedBox(
                    width: isTablet ? 720 : double.infinity,
                    child: CommunityStoriesTray(
                      stories: state.stories,
                      onAddStoryTap: _openCreateStoryModal,
                    ),
                  ),
                ),
              ),

              // 3. Barra de Categorias / Filtros (Alinhada com a largura do Feed)
              SliverToBoxAdapter(
                child: Center(
                  child: SizedBox(
                    width: isTablet ? 720 : double.infinity,
                    child: Container(
                      width: double.infinity,
                      height: 36,
                      margin: const EdgeInsets.only(top: 2, bottom: 6),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildCategoryChip('✨ Tudo', 'all', isDark),
                            const SizedBox(width: 8),
                            _buildCategoryChip('🙏 Pedidos de Oração', 'prayer', isDark),
                            const SizedBox(width: 8),
                            _buildCategoryChip('📖 Versículos', 'verse', isDark),
                            const SizedBox(width: 8),
                            _buildCategoryChip('🕊️ Testemunhos', 'testimony', isDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

                // 5. Conteúdo Principal do Feed
                if (state.isLoading && state.posts.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.kPrimaryGold),
                    ),
                  )
                else if (filteredPosts.isEmpty)
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
                            'Nenhuma publicação nesta categoria ainda.\nSeja o primeiro a compartilhar uma bênção!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
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
                        final post = filteredPosts[index];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: CommunityPostCard(post: post),
                          ),
                        );
                      },
                      childCount: filteredPosts.length,
                    ),
                  ),

                  // Espaçador do rodapé para o bottom nav apenas se necessário
                  SliverToBoxAdapter(
                    child: SizedBox(height: (widget.isEmbedded || isTablet) ? 40 : 130),
                  ),
                ],
              ],
            ),
          ),

          // Bottom Nav Bar Unificada (Apenas em mobile e quando não embutido)
          if (!widget.isEmbedded && !isTablet)
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
      );

    if (!widget.isEmbedded && isTablet) {
      bodyContent = InstagramTabletSidebar(
        currentIndex: 6,
        isRoute: true,
        body: bodyContent,
        onSelectIndex: (index) {
          Navigator.pop(context);
          ref.read(navigationProvider.notifier).setIndex(index);
        },
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: bodyContent,
    );
  }

  Widget _buildCategoryChip(String label, String value, bool isDark) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.kPrimaryGold
              : (isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.kPrimaryGold
                : (isDark ? Colors.white12 : Colors.black12),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.black
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}
