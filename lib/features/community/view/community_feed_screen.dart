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
  String _selectedCategory = 'all'; // 'all', 'prayer', 'verse', 'testimony'
  bool _joinedDailyPrayer = false;
  int _dailyPrayerCount = 58;

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

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 96),
        child: FloatingActionButton.extended(
          backgroundColor: AppTheme.kPrimaryGold,
          foregroundColor: Colors.black,
          elevation: 5,
          onPressed: _openCreatePostModal,
          icon: const Icon(Icons.edit_note_rounded, size: 22, color: Colors.black),
          label: Text(
            'Compartilhar Bênção',
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
                // 1. SliverAppBar com status vivo
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
                        padding: const EdgeInsets.all(6.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people_alt_rounded, color: Colors.black, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                'Em comunhão • 142 orando hoje',
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

                // 3. Card de Intercessão Coletiva do Dia (Banner Vibrante)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF818CF8).withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF818CF8).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              size: 22,
                              color: Color(0xFF818CF8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'INTERCESSÃO DO DIA',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: const Color(0xFF818CF8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pela paz e restauração das famílias dos nossos irmãos.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$_dailyPrayerCount irmãos unidos em oração hoje',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _joinedDailyPrayer = !_joinedDailyPrayer;
                                _dailyPrayerCount += _joinedDailyPrayer ? 1 : -1;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _joinedDailyPrayer
                                        ? 'Glória a Deus! Você se uniu à intercessão de hoje. 🙏'
                                        : 'Oração retirada.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _joinedDailyPrayer
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF818CF8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _joinedDailyPrayer ? 'Orando 🙏' : 'Orar 🙏',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Barra de Categorias / Filtros
                SliverToBoxAdapter(
                  child: Container(
                    height: 42,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: CommunityPostCard(post: post),
                          ),
                        );
                      },
                      childCount: filteredPosts.length,
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
