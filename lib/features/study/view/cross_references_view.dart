import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/services/cross_reference_service.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';

class CrossReferencesView extends ConsumerStatefulWidget {
  final int bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final void Function(int targetBookId, int targetChapter, int targetVerse)?
  onNavigateToVerse;

  const CrossReferencesView({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    this.onNavigateToVerse,
  });

  @override
  ConsumerState<CrossReferencesView> createState() =>
      _CrossReferencesViewState();
}

class _CrossReferencesViewState extends ConsumerState<CrossReferencesView> {
  // 0: Referências Cruzadas (TSK / OpenBible)
  // 1: Cadeias Temáticas (Bíblia Thompson)
  int _selectedSubTab = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentVersion = ref.watch(selectedVersionProvider);

    return Column(
      children: [
        // ─── Sub-Tabs: [ Referências Cruzadas ] | [ Cadeias Thompson ] ───────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(
                  child: _buildSubTabItem(
                    label: 'Referências Cruzadas',
                    icon: Icons.alt_route_rounded,
                    isSelected: _selectedSubTab == 0,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedSubTab = 0),
                  ),
                ),
                Expanded(
                  child: _buildSubTabItem(
                    label: 'Cadeias Thompson',
                    icon: Icons.hub_rounded,
                    isSelected: _selectedSubTab == 1,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedSubTab = 1),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Conteúdo da Aba ─────────────────────────────────────────────────
        Expanded(
          child: _selectedSubTab == 0
              ? _buildCrossReferencesList(currentVersion, isDark)
              : _buildThompsonChainsList(isDark),
        ),
      ],
    );
  }

  Widget _buildSubTabItem({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF262A40) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? (isDark
                        ? AppTheme.kPrimaryGold
                        : Theme.of(context).colorScheme.primary)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrossReferencesList(String version, bool isDark) {
    final asyncRefs = ref.watch(
      crossReferencesForVerseProvider((
        bookId: widget.bookId,
        chapter: widget.chapter,
        verse: widget.verse,
      )),
    );

    return asyncRefs.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.kPrimaryGold,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 14),
            Text(
              'Buscando conexões bíblicas...',
              style: GoogleFonts.outfit(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Erro ao carregar referências: $err',
            style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (refs) {
        if (refs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhuma referência cruzada direta catalogada para este versículo.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: refs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = refs[index];
            return _buildCrossReferenceCard(item, version, isDark);
          },
        );
      },
    );
  }

  Widget _buildCrossReferenceCard(CrossReferenceVerse item, String version, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).cardColor
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header do Card: [ Badge Referência ] [ Votos ] [ Botão Ir ] ────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 13,
                      color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.displayReference,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (item.votes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: Colors.amber.shade600,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${item.votes}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (widget.onNavigateToVerse != null)
                IconButton(
                  tooltip: 'Ir para a passagem',
                  onPressed: () {
                    widget.onNavigateToVerse!(
                      item.targetBookId,
                      item.targetChapter,
                      item.targetVerseStart,
                    );
                  },
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // ─── Texto Bíblico da Passagem Conectada (Carregado sob demanda) ─────
          _LazyVerseTextWidget(
            item: item,
            version: version,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildThompsonChainsList(bool isDark) {
    final asyncChains = ref.watch(
      thompsonChainsForVerseProvider((
        bookId: widget.bookId,
        chapter: widget.chapter,
        verse: widget.verse,
      )),
    );

    return asyncChains.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.kPrimaryGold,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 14),
            Text(
              'Carregando temas da Bíblia Thompson...',
              style: GoogleFonts.outfit(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Erro ao carregar temas Thompson: $err',
            style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (chains) {
        if (chains.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hub_outlined,
                    size: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhum tema da Bíblia Thompson indexado para este versículo.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: chains.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final chain = chains[index];
            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).cardColor
                    : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.tag_rounded,
                          size: 14,
                          color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          chain.topicTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (chain.topicId.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Thompson ${chain.topicId}',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (chain.chainSummary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      chain.chainSummary,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LazyVerseTextWidget extends ConsumerStatefulWidget {
  final CrossReferenceVerse item;
  final String version;
  final bool isDark;

  const _LazyVerseTextWidget({
    super.key,
    required this.item,
    required this.version,
    required this.isDark,
  });

  @override
  ConsumerState<_LazyVerseTextWidget> createState() => _LazyVerseTextWidgetState();
}

class _LazyVerseTextWidgetState extends ConsumerState<_LazyVerseTextWidget> {
  late Future<String?> _verseFuture;

  @override
  void initState() {
    super.initState();
    _verseFuture = _loadVerse();
  }

  @override
  void didUpdateWidget(covariant _LazyVerseTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.version != widget.version ||
        oldWidget.item.targetBookId != widget.item.targetBookId ||
        oldWidget.item.targetChapter != widget.item.targetChapter ||
        oldWidget.item.targetVerseStart != widget.item.targetVerseStart) {
      _verseFuture = _loadVerse();
    }
  }

  Future<String?> _loadVerse() {
    return ref.read(crossReferenceServiceProvider).fetchSingleVerseText(
      version: widget.version,
      bookId: widget.item.targetBookId,
      chapter: widget.item.targetChapter,
      verse: widget.item.targetVerseStart,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _verseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Carregando versículo...',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          );
        }

        final text = snapshot.data;
        if (text != null && text.trim().isNotEmpty) {
          return Text(
            text,
            style: GoogleFonts.merriweather(
              fontSize: 14,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          );
        }

        return Text(
          '(Toque na seta para abrir a passagem no leitor)',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        );
      },
    );
  }
}

