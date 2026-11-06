import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:keryx_app/core/widgets/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/reading/repository/reading_repository.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/features/bible/navigation/view/bible_selector_bottom_sheet.dart';
import 'package:keryx_app/core/state/navigation_state.dart';

class BookSelectionScreen extends ConsumerStatefulWidget {
  const BookSelectionScreen({super.key});

  @override
  ConsumerState<BookSelectionScreen> createState() =>
      _BookSelectionScreenState();
}

class _BookSelectionScreenState extends ConsumerState<BookSelectionScreen> {
  bool _isOnline = true;
  bool _isCheckingConnection = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _openVersionSelector() async {
    final currentVersion = ref.read(selectedVersionProvider);
    final result =
        await showModalBottomSheet<
          ({BibleBook book, int chapter, int? verse, String version})
        >(
          context: context,
          isScrollControlled: true,
          constraints: const BoxConstraints(maxWidth: double.infinity),
          backgroundColor: Colors.transparent,
          builder: (context) => BibleSelectorBottomSheet(
            initialVersion: currentVersion,
            initialStage: SelectorStage.versions,
          ),
        );

    if (result != null && mounted) {
      if (result.version != currentVersion) {
        ref.read(selectedVersionProvider.notifier).setVersion(result.version);
      }
    }
  }

  Future<void> _checkConnectivity() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _isOnline = true;
          _isCheckingConnection = false;
        });
      }
      return;
    }

    try {
      final socket = await io.Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();

      if (mounted) {
        setState(() {
          _isOnline = true;
          _isCheckingConnection = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOnline = false;
          _isCheckingConnection = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    final selectedVersion = ref.watch(selectedVersionProvider);
    final searchQuery = ref.watch(bookSearchQueryProvider);
    final progressAsync = ref.watch(allReadingProgressProvider);
    final recentBooks = ref.watch(recentBooksProvider);

    final storeState = ref.watch(downloadedStorePackagesProvider);

    // Convert to a mutable map to allow dynamic additions
    final Map<String, String> versionNames = Map.from(
      BibleMetadata.versionNames,
    );
    final availableVersions = versionNames.keys.where((v) {
      return storeState.isDownloaded('$v.sqlite') ||
          storeState.isDownloaded('$v.mybible') ||
          storeState.isDownloaded('$v.bbl.mybible') ||
          storeState.isDownloaded('$v.db') ||
          v == 'NVI' ||
          v == 'ACF' ||
          v == 'ARA_S';
    }).toList();

    // Adicionar bíblias baixadas dinamicamente
    final downloadedBibles = storeState.availablePackages.where(
      (p) =>
          p.category == StoreCategory.bibles &&
          storeState.isDownloaded(p.filename),
    );

    for (var bible in downloadedBibles) {
      String key = bible.filename.split('/').last;
      if (key.contains('ARA+STRONG - ATUALIZADA + STRONG'))
        continue; // Skip duplicate of ARA_S

      if (key.toLowerCase().endsWith('.sqlite')) {
        key = key.substring(0, key.length - 7);
      } else if (key.toLowerCase().endsWith('.bbl.mybible')) {
        key = key.substring(0, key.length - 12);
      } else if (key.toLowerCase().endsWith('.mybible')) {
        key = key.substring(0, key.length - 8);
      } else if (key.toLowerCase().endsWith('.db')) {
        key = key.substring(0, key.length - 3);
      }

      final existingKey = versionNames.keys.cast<String?>().firstWhere(
        (k) => k?.toUpperCase() == key.toUpperCase(),
        orElse: () => null,
      );

      if (existingKey != null) {
        key = existingKey;
      } else {
        key = key.toUpperCase();
        versionNames[key] = bible.name;
      }

      if (!availableVersions.contains(key)) {
        availableVersions.add(key);
      }
    }

    if (!_isOnline && !_isCheckingConnection) {
      if (!availableVersions.contains(selectedVersion)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(selectedVersionProvider.notifier).setVersion('NVI');
        });
      }
    }

    final isTablet = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(24, isTablet ? 24 : 8, 24, 120),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HERO CARD COM NOME DA PÁGINA (ESTILO HOME) ────────────
                _buildBibleHeroCard(context),
                const SizedBox(height: 20),

                // ── CARDS NO PADRÃO HOME: Antigo, Novo Testamento & Plano ─────
                _buildBibleTopCards(context, booksAsync.value ?? []),

                // Versão Selecionável e Busca Lado a Lado Sincronizados
                ResponsiveLayout.isMedium(context) ||
                        ResponsiveLayout.isExpanded(context)
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildVersionSelector(
                              context,
                              versionNames,
                              selectedVersion,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: _buildSearchBar(context)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildVersionSelector(
                            context,
                            versionNames,
                            selectedVersion,
                          ),
                          const SizedBox(height: 16),
                          _buildSearchBar(context),
                        ],
                      ),
                const SizedBox(height: 28),

                // ── CONTINUAR LEITURA NO PADRÃO HOME ──────────────────────────
                _buildBibleContinueReading(
                  context,
                  ref,
                  booksAsync.value ?? [],
                  versionNames,
                  selectedVersion,
                  recentBooks,
                  progressAsync.value ?? {},
                ),

                // Book List
                booksAsync.when(
                  data: (books) {
                    final filteredBooks = books
                        .where(
                          (b) =>
                              b.name.toLowerCase().contains(
                                searchQuery.toLowerCase(),
                              ) ||
                              b.abbrev.toLowerCase().contains(
                                searchQuery.toLowerCase(),
                              ),
                        )
                        .toList();

                    final oldTestament = filteredBooks
                        .where((b) => (b.id ?? 0) <= 39)
                        .toList();
                    final newTestament = filteredBooks
                        .where((b) => (b.id ?? 0) >= 40)
                        .toList();

                    return _TabbedBookList(
                      oldTestament: oldTestament,
                      newTestament: newTestament,
                      searchQuery: searchQuery,
                      filteredBooks: filteredBooks,
                      progressData: progressAsync.value ?? {},
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(64.0),
                      child: CircularProgressIndicator(
                        color: AppTheme.kPrimaryGold,
                      ),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      'Erro: $err',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBibleHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFF4F46E5), const Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -20,
            child: Icon(
              Icons.menu_book_rounded,
              color: Colors.white.withValues(alpha: 0.15),
              size: 110,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'ESCRITURAS SAGRADAS',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Escolha um Livro',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Navegue pelas Escrituras Sagradas, do Gênesis ao Apocalipse com Strong e notas.',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBibleTopCards(BuildContext context, List<BibleBook> books) {
    if (books.isEmpty) return const SizedBox.shrink();

    final isTablet = MediaQuery.of(context).size.width >= 720;

    final cards = [
      _buildTopNavCard(
        title: 'Antigo Testamento',
        subtitle: '39 livros: Lei, História, Poesia e Profetas.',
        badgeText: '39 Livros',
        badgeColor: const Color(0xFF4F46E5),
        icon: Icons.menu_book_rounded,
        onTap: () {
          final gn = books.firstWhere((b) => (b.id ?? 1) == 1, orElse: () => books.first);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReadingScreen(
                book: gn,
                initialChapter: 1,
                openChapterSelector: true,
              ),
            ),
          );
        },
      ),
      _buildTopNavCard(
        title: 'Novo Testamento',
        subtitle: '27 livros: Evangelhos, Atos, Cartas e Apocalipse.',
        badgeText: '27 Livros',
        badgeColor: const Color(0xFF0284C7),
        icon: Icons.auto_stories_rounded,
        onTap: () {
          final mt = books.firstWhere((b) => (b.id ?? 40) == 40, orElse: () => books.last);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReadingScreen(
                book: mt,
                initialChapter: 1,
                openChapterSelector: true,
              ),
            ),
          );
        },
      ),
      _buildTopNavCard(
        title: 'Plano de Leitura',
        subtitle: 'Leitura bíblica cronológica em 1 ano (52 semanas).',
        badgeText: '52 Semanas',
        badgeColor: const Color(0xFFD97706),
        icon: Icons.calendar_month_rounded,
        onTap: () {
          ref.read(navigationProvider.notifier).setIndex(2);
        },
      ),
    ];

    if (isTablet) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 14),
              Expanded(child: cards[1]),
              const SizedBox(width: 14),
              Expanded(child: cards[2]),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => SizedBox(width: 255, child: cards[index]),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTopNavCard({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.outfit(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      icon,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBibleContinueReading(
    BuildContext context,
    WidgetRef ref,
    List<BibleBook> books,
    Map<String, String> versionNames,
    String selectedVersion,
    List<String> recentBooks,
    Map<String, Set<int>> progressData,
  ) {
    final lastRead = ref.watch(lastReadProvider);

    BibleBook? targetBook;
    int targetChapter = 1;

    if (lastRead != null) {
      targetBook = lastRead.book;
      targetChapter = lastRead.chapter;
    } else {
      // Procura primeiro nos recentes
      var recentsList = recentBooks;
      if (recentsList.isEmpty && progressData.isNotEmpty) {
        recentsList = progressData.keys.take(5).toList();
      }

      if (recentsList.isNotEmpty && books.isNotEmpty) {
        final firstRecent = recentsList.first;
        targetBook = books.firstWhere(
          (b) =>
              b.name.toUpperCase() == firstRecent.toUpperCase() ||
              b.abbrev.toUpperCase() == firstRecent.toUpperCase(),
          orElse: () => books.first,
        );
        targetChapter = 1;
      } else if (books.isNotEmpty) {
        targetBook = books.first;
        targetChapter = 1;
      }
    }

    if (targetBook == null) {
      return const SizedBox.shrink();
    }

    // Outros livros recentes além do principal
    final otherBooks = <BibleBook>[];
    for (final r in recentBooks) {
      final found = books.firstWhere(
        (b) =>
            b.name.toUpperCase() == r.toUpperCase() ||
            b.abbrev.toUpperCase() == r.toUpperCase(),
        orElse: () => targetBook!,
      );
      if (found.name != targetBook.name && !otherBooks.any((b) => b.name == found.name)) {
        otherBooks.add(found);
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final versionName = versionNames[selectedVersion] ?? selectedVersion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 16, color: AppTheme.kPrimaryGold),
                const SizedBox(width: 8),
                Text(
                  'CONTINUAR LEITURA',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppTheme.kPrimaryGold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Último Acesso',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.kPrimaryGold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReadingScreen(
                  book: targetBook!,
                  initialChapter: targetChapter,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${targetBook.name} $targetChapter',
                        style: GoogleFonts.outfit(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$versionName • Toque para continuar',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (otherBooks.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: otherBooks.length.clamp(0, 6),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final bItem = otherBooks[idx];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReadingScreen(
                            book: bItem,
                            initialChapter: 1,
                            openChapterSelector: true,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_border_rounded, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            bItem.name,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 24),
        Divider(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildVersionSelector(
    BuildContext context,
    Map<String, String> versionNames,
    String selectedVersion,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.translate_rounded,
              size: 15,
              color: Color(0xFF4F46E5),
            ),
            const SizedBox(width: 8),
            Text(
              'Versão da Bíblia',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openVersionSelector(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 16,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      versionNames[selectedVersion] ?? selectedVersion.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF4F46E5),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 15,
              color: Color(0xFF4F46E5),
            ),
            const SizedBox(width: 8),
            Text(
              'Buscar Livro',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: TextField(
              onChanged: (v) => ref.read(bookSearchQueryProvider.notifier).state = v,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Digite o nome ou sigla (ex: gn, joão)...',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                suffixIcon: Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 5),
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(left: 48, right: 24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  richMessage: TextSpan(
                    children: [
                      TextSpan(
                        text: '🔍 Dicas de busca\n\n',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text:
                            'Digite o nome ou a sigla do livro para encontrar rápido.\n\n'
                            '• "joão" ou "jo" → encontra João\n'
                            '• "gn" → encontra Gênesis\n'
                            '• "1sm" → encontra 1 Samuel\n'
                            '• A busca funciona nos dois testamentos',
                        style: GoogleFonts.manrope(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    size: 20,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabbedBookList extends ConsumerStatefulWidget {
  final List<BibleBook> oldTestament;
  final List<BibleBook> newTestament;
  final String searchQuery;
  final List<BibleBook> filteredBooks;
  final Map<String, Set<int>> progressData;

  const _TabbedBookList({
    required this.oldTestament,
    required this.newTestament,
    required this.searchQuery,
    required this.filteredBooks,
    required this.progressData,
  });

  @override
  ConsumerState<_TabbedBookList> createState() => _TabbedBookListState();
}

class _TabbedBookListState extends ConsumerState<_TabbedBookList> {
  int _selectedIndex = 0;

  Color _getGroupColor(String g) {
    final lower = g.toLowerCase();
    if (lower.contains('pentateuco')) return const Color(0xFFD97706);
    if (lower.contains('históricos')) return const Color(0xFF059669);
    if (lower.contains('poéticos')) return const Color(0xFF2563EB);
    if (lower.contains('profetas maiores')) return const Color(0xFF7C3AED);
    if (lower.contains('profetas menores')) return const Color(0xFF9333EA);
    if (lower.contains('evangelhos')) return const Color(0xFFDC2626);
    if (lower.contains('epístolas')) return const Color(0xFF0D9488);
    if (lower.contains('proféticos')) return const Color(0xFF4F46E5);
    return const Color(0xFF374151);
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = widget.searchQuery.isNotEmpty;
    final currentBooks = isSearching
        ? widget.filteredBooks
        : (_selectedIndex == 0 ? widget.oldTestament : widget.newTestament);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Custom Segmented Switcher (Visible only when NOT searching)
        if (!isSearching) ...[
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                _buildSwitcherTab(0, 'Antigo', '39', Icons.menu_book),
                _buildSwitcherTab(1, 'Novo', '27', Icons.book),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],

        if (currentBooks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Nenhum livro encontrado.',
                style: GoogleFonts.outfit(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
          )
        else
          _buildGroupedBooks(
            context,
            currentBooks,
            isSearching,
            widget.progressData,
          ),
      ],
    );
  }

  Widget _buildSwitcherTab(
    int index,
    String label,
    String number,
    IconData icon,
  ) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          margin: EdgeInsets.only(
            right: index == 0 ? 8 : 0,
            left: index == 1 ? 8 : 0,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.2)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  number,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedBooks(
    BuildContext context,
    List<BibleBook> books,
    bool isSearching,
    Map<String, Set<int>> progressData,
  ) {
    final groupOrder = isSearching
        ? [
            'Pentateuco',
            'Históricos',
            'Poéticos',
            'Profetas maiores',
            'Profetas menores',
            'Evangelhos',
            'Epístolas',
            'Proféticos',
          ]
        : (_selectedIndex == 0
              ? [
                  'Pentateuco',
                  'Históricos',
                  'Poéticos',
                  'Profetas maiores',
                  'Profetas menores',
                ]
              : ['Evangelhos', 'Históricos', 'Epístolas', 'Proféticos']);

    final grouped = <String, List<BibleBook>>{};
    for (final g in groupOrder) {
      final groupBooks = books.where((b) => b.group == g).toList();
      if (groupBooks.isNotEmpty) grouped[g] = groupBooks;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupTitle(context, entry.key, entry.value.length),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: ResponsiveLayout.isExpanded(context)
                    ? 220
                    : 180,
                childAspectRatio: ResponsiveLayout.isExpanded(context)
                    ? 1.4
                    : (ResponsiveLayout.isMedium(context) ? 1.3 : 1.18),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: entry.value.length,
              itemBuilder: (context, index) {
                final book = entry.value[index];
                final bookId = int.tryParse(book.abbrev) ?? 0;
                final abbrevFull =
                    (BibleMetadata.getMetadata(bookId)?['abbrev'] as String? ??
                            book.abbrev)
                        .toUpperCase();

                // Lógica de progresso real do Firebase
                final readChapters = progressData[abbrevFull] ?? {};
                final progressFactor = readChapters.isEmpty
                    ? 0.0
                    : (readChapters.length / book.chapters).clamp(0.0, 1.0);
                final isReading = progressFactor > 0;
                final isCompleted = progressFactor >= 1.0;

                return _BookCard(
                  abbrev: abbrevFull,
                  group: entry.key,
                  name: book.name,
                  chapters: book.chapters,
                  readCount: readChapters.length, // Novo
                  isReading: isReading,
                  isCompleted: isCompleted,
                  progressFactor: progressFactor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReadingScreen(
                        book: book,
                        initialChapter: 1,
                        openChapterSelector: true,
                      ),
                    ),
                  ),
                  onClearProgress: () async {
                    // Feedback de limpar removido conforme pedido
                    final auth = ref.read(authStateProvider).value;
                    if (auth != null) {
                      await ref
                          .read(readingRepositoryProvider)
                          .clearBookProgress(auth.uid, abbrevFull);
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGroupTitle(BuildContext context, String group, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: _getGroupColor(group),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              group.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        Text(
          '$count Livros',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  final String abbrev;
  final String group;
  final String name;
  final int chapters;
  final int readCount; // Novo
  final bool isReading;
  final bool isCompleted;
  final double progressFactor;
  final VoidCallback onTap;
  final VoidCallback? onClearProgress;

  const _BookCard({
    required this.group,
    required this.abbrev,
    required this.name,
    required this.chapters,
    required this.readCount, // Novo
    required this.isReading,
    required this.isCompleted,
    required this.progressFactor,
    required this.onTap,
    this.onClearProgress,
  });

  Color _getGroupColor(String g) {
    final lower = g.toLowerCase();
    if (lower.contains('pentateuco')) return const Color(0xFFD97706);
    if (lower.contains('históricos')) return const Color(0xFF059669);
    if (lower.contains('poéticos')) return const Color(0xFF2563EB);
    if (lower.contains('profetas maiores')) return const Color(0xFF7C3AED);
    if (lower.contains('profetas menores')) return const Color(0xFF9333EA);
    if (lower.contains('evangelhos')) return const Color(0xFFDC2626);
    if (lower.contains('epístolas')) return const Color(0xFF0D9488);
    if (lower.contains('proféticos')) return const Color(0xFF4F46E5);
    return const Color(0xFF374151);
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighted = isReading || isCompleted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _getGroupColor(group),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      abbrev,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            isReading ? '$readCount/$chapters cap.' : '$chapters cap.',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isReading || isCompleted) ...[
                          const SizedBox(width: 4),
                          Text(
                            isCompleted ? "CONCLUÍDO" : "LENDO",
                            style: GoogleFonts.outfit(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isReading || isCompleted) ...[
                      const SizedBox(height: 4),
                      Container(
                        height: 3,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progressFactor,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (isHighlighted && onClearProgress != null)
              Positioned(
                top: -4,
                right: -4,
                child: IconButton(
                  icon: const Icon(Icons.cancel_rounded, size: 24),
                  color: Colors.white.withValues(alpha: 0.6),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    // Confirmação antes de limpar
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          'Limpar progresso?',
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          'Tem certeza de que deseja apagar seu progresso de leitura em $name?',
                          style: GoogleFonts.outfit(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.outfit(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              onClearProgress!();
                            },
                            child: Text(
                              'Sim, Limpar',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
