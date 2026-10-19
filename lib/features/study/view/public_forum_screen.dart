import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:keryx_app/features/study/view_model/public_annotations_provider.dart';
import 'package:keryx_app/features/study/view/public_annotation_detail_screen.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/features/study/view/note_detail_screen.dart';
import 'package:keryx_app/core/services/auth_service.dart';

class PublicForumScreen extends ConsumerStatefulWidget {
  const PublicForumScreen({super.key});

  @override
  ConsumerState<PublicForumScreen> createState() => _PublicForumScreenState();
}

class _PublicForumScreenState extends ConsumerState<PublicForumScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'recentes'; // 'recentes' ou 'populares'
  static const _gold = AppTheme.kPrimaryGold;
  
  

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final isVisible = ref.read(navbarVisibleProvider);
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (isVisible) ref.read(navbarVisibleProvider.notifier).state = false;
      } else if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (!isVisible) ref.read(navbarVisibleProvider.notifier).state = true;
      }
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(publicAnnotationsProvider.notifier).loadNextPage();
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(publicAnnotationsProvider);

    // Garante que a navbar não venha oculta da tela anterior
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(navbarVisibleProvider)) {
        ref.read(navbarVisibleProvider.notifier).state = true;
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const MBibliaTopBar(
        title: 'KeryxApp',
        showLogo: true,
        showBackButton: false,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton.extended(
          backgroundColor: Theme.of(context).colorScheme.primary,
          onPressed: () => _createNewTopic(context, ref),
          icon: Icon(Icons.add_comment_rounded, color: Theme.of(context).colorScheme.onPrimary),
          label: Text('Novo Tópico',
              style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: _gold,
            backgroundColor: Theme.of(context).cardColor,
            onRefresh: () => ref.read(publicAnnotationsProvider.notifier).refresh(),
        child: state.when(
          data: (notes) {
            if (notes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum estudo público ainda.\nSeja o primeiro a compartilhar!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            var filteredNotes = notes.where((n) {
              if (_searchQuery.isEmpty) return true;
              final q = _searchQuery.toLowerCase();
              return n.title.toLowerCase().contains(q) ||
                  n.plainTextBody.toLowerCase().contains(q);
            }).toList();

            if (_sortBy == 'populares') {
              filteredNotes.sort((a, b) => b.likeCount.compareTo(a.likeCount));
            } else {
              // recentes
              filteredNotes.sort((a, b) => (b.lastActivityAt ?? b.updatedAt).compareTo(a.lastActivityAt ?? a.updatedAt));
            }

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredNotes.length + 2, // +1 pro titulo/busca, +1 pro loading
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fórum da Comunidade',
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Estudos, perguntas e devocionais compartilhados',
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Barra de Pesquisa
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Pesquisar tópicos...',
                              hintStyle: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Filtros
                        Row(
                          children: [
                            _buildFilterChip('Recentes', 'recentes'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Populares', 'populares'),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                final noteIndex = index - 1;

                if (noteIndex == filteredNotes.length) {
                  if (ref.watch(publicAnnotationsProvider.notifier).hasMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(color: _gold),
                      ),
                    );
                  }
                  return const SizedBox(height: 100);
                }

                return _ForumCard(note: filteredNotes[noteIndex]);
              },
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _gold)),
          error: (err, _) => Center(
            child: Text(
              'Erro ao carregar estudos.',
              style: GoogleFonts.outfit(color: Colors.redAccent),
            ),
          ),
        ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomBottomNav(
              currentIndex: 6, // Index não correspondente para não realçar nenhum botão
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
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.kPrimaryGold.withValues(alpha: 0.2) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          border: Border.all(color: isSelected ? AppTheme.kPrimaryGold : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Future<void> _createNewTopic(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final authUser = ref.read(authServiceProvider).currentUser;
    final card = NoteCard(
      id: 'note_${now.millisecondsSinceEpoch}',
      title: 'Novo Tópico',
      body: '',
      createdAt: now,
      updatedAt: now,
      isPublic: true,
      isCommunityOnly: true,
      authorId: authUser?.uid,
      authorName: authUser?.displayName ?? 'Anônimo',
      authorPhoto: authUser?.photoURL,
    );
    if (context.mounted) {
      final updatedNote = await Navigator.push<NoteCard>(
        context,
        MaterialPageRoute(builder: (_) => NoteDetailScreen(note: card, isCommunity: true)),
      );
      ref.read(publicAnnotationsProvider.notifier).refresh();
      
      if (updatedNote != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PublicAnnotationDetailScreen(note: updatedNote)),
        );
      }
    }
  }
}

class _ForumCard extends ConsumerWidget {
  final NoteCard note;
  const _ForumCard({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicAnnotationDetailScreen(note: note),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                ref.read(publicAnnotationsProvider.notifier).toggleLike(note);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: note.isLikedByMe ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 28,
                    ),
                    Text(
                      '${note.likeCount}',
                      style: GoogleFonts.outfit(
                        color: note.isLikedByMe ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (note.plainTextBody.isNotEmpty) ...[
                    Text(
                      note.plainTextBody,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lora(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      Text(
                        '${note.commentCount}',
                        style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                      ),
                      Text('•', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
                      Text(
                        note.authorName ?? 'Anônimo',
                        style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                      ),
                      Text('•', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
                      Text(
                        _fmtDate(note.lastActivityAt ?? note.createdAt),
                        style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                      ),
                      if (note.isLocked) ...[
                        Text('•', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
                        Icon(Icons.lock, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 12),
                      ],
                      if (note.verses.isNotEmpty) ...[
                        Text('•', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
                        Text(
                          note.verses.first.reference,
                          style: GoogleFonts.outfit(color: AppTheme.kPrimaryGold.withValues(alpha: 0.7), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${d.day}/${d.month}/${d.year}';
  }
}
