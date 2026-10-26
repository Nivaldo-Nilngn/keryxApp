import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/services/cross_reference_service.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/responsive_layout.dart';
import 'package:keryx_app/features/bible/reading/view/text_settings_bottom_sheet.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';

/// Abre a tela completa de Referências Cruzadas e Cadeias Thompson
void showCrossReferencesScreen(
  BuildContext context, {
  required int bookId,
  required String bookName,
  required int chapter,
  required int verse,
  void Function(int targetBookId, int targetChapter, int targetVerse)? onNavigateToVerse,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CrossReferencesScreen(
        bookId: bookId,
        bookName: bookName,
        chapter: chapter,
        verse: verse,
        onNavigateToVerse: onNavigateToVerse,
      ),
    ),
  );
}

/// Tela completa de Referências Cruzadas e Cadeias Thompson
/// Com layout adaptativo em 2 colunas para tablets/widescreen (estilo Léxico)
/// e ajuste dinâmico do tamanho de texto para maior legibilidade e conforto visual.
class CrossReferencesScreen extends ConsumerStatefulWidget {
  final int bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final void Function(int targetBookId, int targetChapter, int targetVerse)? onNavigateToVerse;

  const CrossReferencesScreen({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    this.onNavigateToVerse,
  });

  @override
  ConsumerState<CrossReferencesScreen> createState() => _CrossReferencesScreenState();
}

class _CrossReferencesScreenState extends ConsumerState<CrossReferencesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scRef = ScrollController();
  final ScrollController _scThompson = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scRef.dispose();
    _scThompson.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentVersion = ref.watch(selectedVersionProvider);
    final fontSettings = ref.watch(fontSettingsProvider);
    final userFontSize = fontSettings.fontSize;
    final isExpanded = ResponsiveLayout.isExpanded(context);

    final surfaceBase = Theme.of(context).scaffoldBackgroundColor;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = textPrimary.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: surfaceBase,
      appBar: AppBar(
        backgroundColor: surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 24),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Voltar',
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.bookName} ${widget.chapter}:${widget.verse}',
              style: GoogleFonts.plusJakartaSans(
                color: textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'REFERÊNCIAS CRUZADAS E TEMAS',
              style: GoogleFonts.outfit(
                color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Botão rápido: Diminuir tamanho do texto
          IconButton(
            icon: Icon(Icons.text_decrease_rounded, color: textSecondary, size: 20),
            tooltip: 'Diminuir tamanho da fonte',
            onPressed: () {
              final cur = ref.read(fontSettingsProvider).fontSize;
              if (cur > 12) {
                ref.read(fontSettingsProvider.notifier).setFontSize(cur - 1.5);
              }
            },
          ),
          // Botão rápido: Aumentar tamanho do texto
          IconButton(
            icon: Icon(Icons.text_increase_rounded, color: textSecondary, size: 22),
            tooltip: 'Aumentar tamanho da fonte',
            onPressed: () {
              final cur = ref.read(fontSettingsProvider).fontSize;
              if (cur < 38) {
                ref.read(fontSettingsProvider.notifier).setFontSize(cur + 1.5);
              }
            },
          ),
          // Botão completo de configurações de leitura
          IconButton(
            icon: Icon(Icons.tune_rounded, color: textSecondary, size: 22),
            tooltip: 'Configurações de Leitura & Fonte',
            onPressed: () => showTextSettingsBottomSheet(context),
          ),
          const SizedBox(width: 4),
        ],
        bottom: isExpanded
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: isDark ? const Color(0xFF262A40) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: textPrimary.withValues(alpha: 0.05)),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: textSecondary,
                    labelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.alt_route_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('REFERÊNCIAS'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hub_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('CADEIAS THOMPSON'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: isExpanded
          ? _buildTwoColumnLayout(currentVersion, isDark, userFontSize, textPrimary)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCrossReferencesList(currentVersion, isDark, userFontSize, _scRef),
                _buildThompsonChainsList(isDark, userFontSize, _scThompson),
              ],
            ),
    );
  }

  /// Layout lado a lado em 2 colunas para tablets e telas widescreen (idêntico ao Léxico)
  Widget _buildTwoColumnLayout(
    String currentVersion,
    bool isDark,
    double userFontSize,
    Color textPrimary,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coluna 1: Referências Cruzadas
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.alt_route_rounded,
                        color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'REFERÊNCIAS CRUZADAS',
                      style: GoogleFonts.outfit(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: textPrimary.withValues(alpha: 0.08),
              ),
              Expanded(
                child: _buildCrossReferencesList(currentVersion, isDark, userFontSize, _scRef),
              ),
            ],
          ),
        ),

        // Divisor vertical elegante
        Container(
          width: 1,
          color: textPrimary.withValues(alpha: 0.08),
        ),

        // Coluna 2: Cadeias Thompson
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.hub_rounded,
                        color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'CADEIAS THOMPSON',
                      style: GoogleFonts.outfit(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: textPrimary.withValues(alpha: 0.08),
              ),
              Expanded(
                child: _buildThompsonChainsList(isDark, userFontSize, _scThompson),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrossReferencesList(
    String version,
    bool isDark,
    double userFontSize,
    ScrollController controller,
  ) {
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhuma referência cruzada direta catalogada para este versículo.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: refs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final item = refs[index];
            return _buildCrossReferenceCard(item, version, isDark, userFontSize);
          },
        );
      },
    );
  }

  Widget _buildCrossReferenceCard(
    CrossReferenceVerse item,
    String version,
    bool isDark,
    double userFontSize,
  ) {
    final badgeFontSize = (userFontSize * 0.82).clamp(13.0, 20.0);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).cardColor
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Badge + Votos + Botão Ir
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      size: badgeFontSize,
                      color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.displayReference,
                      style: GoogleFonts.outfit(
                        fontSize: badgeFontSize,
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
                    Navigator.pop(context);
                    widget.onNavigateToVerse!(
                      item.targetBookId,
                      item.targetChapter,
                      item.targetVerseStart,
                    );
                  },
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Texto Bíblico em tamanho customizado pelo usuário
          _CrossReferenceLazyText(
            item: item,
            version: version,
            isDark: isDark,
            fontSize: userFontSize,
          ),
        ],
      ),
    );
  }

  Widget _buildThompsonChainsList(
    bool isDark,
    double userFontSize,
    ScrollController controller,
  ) {
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhum tema da Bíblia Thompson indexado para este versículo.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final titleFontSize = (userFontSize * 0.95).clamp(15.0, 24.0);
        final bodyFontSize = (userFontSize * 0.85).clamp(13.0, 20.0);

        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: chains.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final chain = chains[index];
            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).cardColor
                    : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
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
                            fontSize: titleFontSize,
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
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (chain.chainSummary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      chain.chainSummary,
                      style: GoogleFonts.outfit(
                        fontSize: bodyFontSize,
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

class _CrossReferenceLazyText extends ConsumerStatefulWidget {
  final CrossReferenceVerse item;
  final String version;
  final bool isDark;
  final double fontSize;

  const _CrossReferenceLazyText({
    required this.item,
    required this.version,
    required this.isDark,
    required this.fontSize,
  });

  @override
  ConsumerState<_CrossReferenceLazyText> createState() => _CrossReferenceLazyTextState();
}

class _CrossReferenceLazyTextState extends ConsumerState<_CrossReferenceLazyText> {
  late Future<String?> _verseFuture;

  @override
  void initState() {
    super.initState();
    _verseFuture = _loadVerse();
  }

  @override
  void didUpdateWidget(covariant _CrossReferenceLazyText oldWidget) {
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
              fontSize: widget.fontSize,
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
