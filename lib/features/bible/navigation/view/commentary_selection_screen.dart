import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/features/bible/reading/view/commentary_reader_screen.dart';
import 'package:keryx_app/features/store/view/store_screen.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:flutter/foundation.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';

class CommentarySelectionScreen extends ConsumerWidget {
  const CommentarySelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    final searchQuery = ref.watch(bookSearchQueryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escolha uma Obra',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Associe o conhecimento teológico aos textos sagrados.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 32),

                _buildLastReadCard(ref, context),

                // Seletor de Versão de Comentário
                _buildSectionLabel(context, 'FONTE DE COMENTÁRIO'),
                const SizedBox(height: 8),
                _CommentaryVersionDropdown(),

                const SizedBox(height: 32),
                // Pesquisa de Livros
                _buildSectionLabel(context, 'FILTRAR LIVROS'),
                const SizedBox(height: 8),
                _buildBookSearch(context, ref),
                const SizedBox(height: 32),

                // Lista de Livros (Estilo Bíblia)
                booksAsync.when(
                  data: (books) {
                    final selectedMeta = ref.watch(
                      selectedCommentaryVersionProvider,
                    );
                    if (selectedMeta == null) return const SizedBox.shrink();

                    final commentedBooksAsync = ref.watch(
                      commentedBooksProvider(selectedMeta.filename),
                    );

                    return commentedBooksAsync.when(
                      data: (commentedIds) {
                        final filteredBooks = books.where((b) {
                          final matchesSearch =
                              b.name.toLowerCase().contains(
                                searchQuery.toLowerCase(),
                              ) ||
                              b.abbrev.toLowerCase().contains(
                                searchQuery.toLowerCase(),
                              );

                          // Filtra estritamente pelos IDs que possuem comentário no banco
                          return matchesSearch && commentedIds.contains(b.id);
                        }).toList();

                        if (filteredBooks.isEmpty && searchQuery.isEmpty) {
                          return _buildEmptyState(context, ref);
                        }

                        // Agrupamento igual à Bíblia
                        final oldTestament = filteredBooks
                            .where((b) => (b.id ?? 0) <= 39)
                            .toList();
                        final newTestament = filteredBooks
                            .where((b) => (b.id ?? 0) >= 40)
                            .toList();

                        return _CommentaryGrid(
                          oldTestament: oldTestament,
                          newTestament: newTestament,
                          searchQuery: searchQuery,
                          selectedMeta: selectedMeta,
                          onBookTap: (book) =>
                              _showChapterSelection(context, ref, book),
                        );
                      },
                      loading: () => Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      error: (e, _) =>
                          Center(child: Text('Erro ao carregar livros: $e')),
                    );
                  },
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  error: (e, _) => Center(child: Text('Erro: $e')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 64),
          Icon(
            Icons.auto_stories_rounded,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.05),
            size: 120,
          ),
          const SizedBox(height: 32),
          Text(
            'Sua estante está vazia',
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Baixe comentários e obras de estudo na Loja Premium para começar sua jornada.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.38),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(isLibraryModeProvider.notifier).state = false;
              ref.read(selectedCategoryProvider.notifier).state = null;
              ref.read(searchQueryProvider.notifier).state = '';
              ref.read(navigationProvider.notifier).setIndex(5);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.store_rounded),
            label: Text(
              'Explorar Loja Premium',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastReadCard(WidgetRef ref, BuildContext context) {
    final lastRead = ref.watch(lastCommentaryReadProvider);
    if (lastRead == null) return const SizedBox.shrink();

    // No mobile, só mostra se a obra ainda estiver baixada
    if (!kIsWeb) {
      final storeState = ref.watch(storeProvider);
      if (!storeState.isDownloaded(lastRead.metadata.filename)) {
        return const SizedBox.shrink();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: GestureDetector(
        onTap: () {
          ref.read(selectedCommentaryVersionProvider.notifier).state =
              lastRead.metadata;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommentaryReaderScreen(
                initialMetadata: lastRead.metadata,
                book: lastRead.book,
                chapter: lastRead.chapter,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.bookmark_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continuar de onde parou',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lastRead.book.name} ${lastRead.chapter == 0 ? "(Introdução)" : lastRead.chapter}',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastRead.metadata.name,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildBookSearch(BuildContext context, WidgetRef ref) {
    return TextField(
      onChanged: (v) => ref.read(bookSearchQueryProvider.notifier).state = v,
      style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: 'Digite o nome do livro...',
        hintStyle: GoogleFonts.outfit(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
        prefixIcon: Icon(
          Icons.search,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _CommentaryVersionDropdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMeta = ref.watch(selectedCommentaryVersionProvider);
    // Para a tela de seleção, mostramos todos os baixados + hardcoded (limitado a Gênesis apenas para popular a lista inicial)
    // Mas na verdade queremos todos os disponíveis na Loja + Hardcoded
    final available = ref.watch(
      availableCommentariesProvider((
        abbrev: 'Gn',
        bookId: 1,
        bookName: 'Gênesis',
      )),
    );

    // Garantir que o valor selecionado realmente exista na lista atual para evitar crash
    final value = available.contains(selectedMeta)
        ? selectedMeta
        : (available.isNotEmpty ? available.first : null);

    // Sincroniza o estado inicial se estiver nulo ou se o item selecionado foi desinstalado
    if (value != selectedMeta) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedCommentaryVersionProvider.notifier).state = value;
      });
    }

    if (available.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.cloud_download_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nenhuma obra baixada',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Vá até a Loja para baixar comentários.',
                    style: GoogleFonts.outfit(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                ref.read(isLibraryModeProvider.notifier).state = false;
                ref.read(selectedCategoryProvider.notifier).state = null;
                ref.read(searchQueryProvider.notifier).state = '';
                ref
                    .read(navigationProvider.notifier)
                    .setIndex(5); // Vai pra Loja
              },
              child: Text(
                'Ir para Loja',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (value != null) {
          _showCommentarySelectorBottomSheet(context, ref, value, available);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              value?.category == CommentaryCategory.especifico
                  ? Icons.stars
                  : Icons.auto_stories,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value?.name ?? 'Selecione um comentário',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget colapsável para uma categoria de comentários
class _CommentaryCategorySection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<CommentaryMetadata> items;
  final String selectedFilename;
  final void Function(CommentaryMetadata) onSelect;

  const _CommentaryCategorySection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.selectedFilename,
    required this.onSelect,
  });

  @override
  State<_CommentaryCategorySection> createState() =>
      _CommentaryCategorySectionState();
}

class _CommentaryCategorySectionState extends State<_CommentaryCategorySection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _ctrl;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    // Abre automaticamente se um item desta categoria está selecionado
    _expanded = widget.items.any((c) => c.filename == widget.selectedFilename);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _expanded ? 1.0 : 0.0,
    );
    _rotation = Tween(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da seção
        GestureDetector(
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.outfit(
                          color: widget.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        '${widget.items.length} ${widget.items.length == 1 ? "item" : "itens"}',
                        style: GoogleFonts.outfit(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.38),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                RotationTransition(
                  turns: _rotation,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: widget.color,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Itens da seção
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? Column(
                  children: widget.items.map((cm) {
                    final isSelected = cm.filename == widget.selectedFilename;
                    return GestureDetector(
                      onTap: () => widget.onSelect(cm),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.08)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.4)
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: widget.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: widget.color.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Icon(
                                Icons.library_books_rounded,
                                color: widget.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                cm.name,
                                style: GoogleFonts.outfit(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

void _showCommentarySelectorBottomSheet(
  BuildContext context,
  WidgetRef ref,
  CommentaryMetadata current,
  List<CommentaryMetadata> all,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF065F46),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mudar Comentário',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${all.length} disponíveis',
                        style: GoogleFonts.outfit(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.38),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.07),
              height: 1,
            ),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final selectedFilename =
                      ref.watch(selectedCommentaryVersionProvider)?.filename ??
                      current.filename;
                  // Agrupar por categoria
                  final Map<String, List<CommentaryMetadata>> grouped = {};

                  for (final c in all) {
                    final groupName =
                        c.storeCategoryName ??
                        (c.category == CommentaryCategory.estudo
                            ? 'BÍBLIAS DE ESTUDO'
                            : c.category == CommentaryCategory.geral
                            ? 'COMENTÁRIOS GERAIS'
                            : 'COMENTÁRIOS ESPECÍFICOS');

                    if (!grouped.containsKey(groupName)) {
                      grouped[groupName] = [];
                    }
                    grouped[groupName]!.add(c);
                  }

                  return ListView(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    children: grouped.entries.map((entry) {
                      // Pick color/icon based on name
                      Color cColor = Theme.of(context).colorScheme.primary;
                      IconData cIcon = Icons.auto_stories_rounded;

                      if (entry.key.contains('ESTUDO')) {
                        cColor = const Color(0xFF34D399);
                        cIcon = Icons.school_rounded;
                      } else if (entry.key.contains('ESPECÍFICOS')) {
                        cColor = Theme.of(context).colorScheme.primary;
                        cIcon = Icons.stars_rounded;
                      } else if (entry.key.contains('VERSÍCULO')) {
                        cColor = const Color(0xFF60A5FA);
                        cIcon = Icons.menu_book_rounded;
                      } else if (entry.key.contains('EXPOSITIVOS')) {
                        cColor = const Color(0xFFFBBF24);
                        cIcon = Icons.library_books_rounded;
                      } else if (entry.key.contains('HOMILÉTICA')) {
                        cColor = const Color(0xFFF472B6);
                        cIcon = Icons.record_voice_over_rounded;
                      } else if (entry.key.contains('CULTURA')) {
                        cColor = const Color(0xFFA78BFA);
                        cIcon = Icons.public_rounded;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CommentaryCategorySection(
                          title: entry.key.toUpperCase(),
                          icon: cIcon,
                          color: cColor,
                          items: entry.value,
                          selectedFilename: selectedFilename,
                          onSelect: (cm) {
                            ref
                                    .read(
                                      selectedCommentaryVersionProvider
                                          .notifier,
                                    )
                                    .state =
                                cm;
                            Navigator.pop(ctx);
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showChapterSelection(
  BuildContext context,
  WidgetRef ref,
  BibleBook book,
) {
  final selectedMeta = ref.read(selectedCommentaryVersionProvider);
  if (selectedMeta == null) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: double.infinity), // Borda a Borda
    builder: (context) => Consumer(
      builder: (context, ref, child) {
        final chaptersAsync = ref.watch(
          commentedChaptersDetailProvider((
            filename: selectedMeta.filename,
            bookId: book.id ?? 1,
          )),
        );

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  '${book.name.toUpperCase()} - ESCOLHA O CAPÍTULO', // Corrigido typo
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Expanded(
                child: chaptersAsync.when(
                  data: (chapters) {
                    if (chapters.isEmpty) {
                      return Center(
                        child: Text(
                          'Nenhum conteúdo encontrado.',
                          style: GoogleFonts.outfit(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.54),
                          ),
                        ),
                      );
                    }
                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 350, // Permite 2 ou mais no Tablet, 1 no Mobile
                        mainAxisExtent: 80, // Altura fixa para cada item de capítulo
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        final chapterInfo = chapters[index];
                        final chapter = chapterInfo['chapter'] as int;
                        final marker = chapterInfo['marker'] as String?;

                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CommentaryReaderScreen(
                                  initialMetadata: selectedMeta,
                                  book: book,
                                  chapter: chapter,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        marker ??
                                            (chapter == 0
                                                ? 'Introdução / Capa'
                                                : 'Capítulo $chapter'),
                                        style: GoogleFonts.outfit(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (marker != null)
                                        Text(
                                          'Capítulo inicial: $chapter',
                                          style: GoogleFonts.outfit(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.54),
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.24),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Erro: $e',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _CommentaryGrid extends StatefulWidget {
  final List<BibleBook> oldTestament;
  final List<BibleBook> newTestament;
  final String searchQuery;
  final CommentaryMetadata selectedMeta;
  final Function(BibleBook) onBookTap;

  const _CommentaryGrid({
    required this.oldTestament,
    required this.newTestament,
    required this.searchQuery,
    required this.selectedMeta,
    required this.onBookTap,
  });

  @override
  State<_CommentaryGrid> createState() => _CommentaryGridState();
}

class _CommentaryGridState extends State<_CommentaryGrid> {
  // 0: Todos, 1: Antigo Testamento, 2: Novo Testamento
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.oldTestament.isEmpty && widget.newTestament.isNotEmpty) {
      _selectedIndex = 2;
    } else if (widget.oldTestament.isNotEmpty && widget.newTestament.isEmpty) {
      _selectedIndex = 1;
    } else {
      _selectedIndex = 0; // Mostra todos por padrão para ver a obra inteira
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = widget.searchQuery.isNotEmpty;
    final allBooks = [...widget.oldTestament, ...widget.newTestament];
    final showTabs =
        !isSearching &&
        widget.oldTestament.isNotEmpty &&
        widget.newTestament.isNotEmpty;

    List<BibleBook> currentBooks;
    if (isSearching) {
      currentBooks = allBooks;
    } else if (!showTabs) {
      currentBooks = widget.oldTestament.isNotEmpty
          ? widget.oldTestament
          : widget.newTestament;
    } else {
      if (_selectedIndex == 0) {
        currentBooks = allBooks;
      } else if (_selectedIndex == 1) {
        currentBooks = widget.oldTestament;
      } else {
        currentBooks = widget.newTestament;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTabs) ...[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildSwitcherTab(0, 'Todos (${allBooks.length})'),
                _buildSwitcherTab(1, 'Antigo (${widget.oldTestament.length})'),
                _buildSwitcherTab(2, 'Novo (${widget.newTestament.length})'),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisExtent: 228,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
          ),
          itemCount: currentBooks.length,
          itemBuilder: (context, index) {
            final book = currentBooks[index];
            final bookId = book.id ?? 1;
            final abbrev =
                (BibleMetadata.getMetadata(bookId)?['abbrev'] as String? ??
                        book.abbrev)
                    .toUpperCase();

            return _CommentaryBookCard(
              book: book,
              abbrev: abbrev,
              name: book.name,
              chapters: book.chapters,
              commentaryFilename: widget.selectedMeta.filename,
              onTap: () => widget.onBookTap(book),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSwitcherTab(int index, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentaryBookCard extends ConsumerWidget {
  final BibleBook book;
  final String abbrev;
  final String name;
  final int chapters;
  final String commentaryFilename;
  final VoidCallback onTap;

  const _CommentaryBookCard({
    required this.book,
    required this.abbrev,
    required this.name,
    required this.chapters,
    required this.commentaryFilename,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverAsync = ref.watch(
      commentaryBookCoverProvider((
        filename: commentaryFilename,
        bookId: book.id ?? 1,
      )),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookId = book.id ?? 1;
    final isOldTestament = bookId <= 39;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Capa do Livro (Estilo E-book)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    coverAsync.when(
                      data: (bytes) {
                        if (bytes != null && bytes.isNotEmpty) {
                          return Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildFallbackCover(context, isOldTestament),
                          );
                        }
                        return _buildFallbackCover(context, isOldTestament);
                      },
                      loading: () => Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      error: (_, __) =>
                          _buildFallbackCover(context, isOldTestament),
                    ),

                    // Gradiente de lombada de livro físico na borda esquerda
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.38),
                              Colors.black.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Badge de Sigla do Livro no topo direito
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          abbrev,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Título e detalhes do Livro
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$chapters ${chapters == 1 ? "capítulo" : "capítulos"}',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCover(BuildContext context, bool isOldTestament) {
    final gradientColors = isOldTestament
        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
        : [const Color(0xFF311042), const Color(0xFF1B0726)];
    final accentColor = isOldTestament
        ? const Color(0xFFF59E0B)
        : const Color(0xFFC084FC);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_rounded,
            color: accentColor.withValues(alpha: 0.85),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            abbrev,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

