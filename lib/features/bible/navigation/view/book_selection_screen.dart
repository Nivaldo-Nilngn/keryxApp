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
import 'package:keryx_app/features/summaries/view/book_summary_screen.dart';
import 'package:keryx_app/features/reading/repository/reading_repository.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/features/bible/navigation/view/bible_selector_bottom_sheet.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Escolha um Livro',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -1,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Navegue pelas Escrituras Sagradas, do\nGênesis ao Apocalipse.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w300,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            // Versão Selecionável e Busca Lado a Lado
            ResponsiveLayout.isMedium(context) ||
                    ResponsiveLayout.isExpanded(context)
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: _buildVersionSelector(
                          context,
                          versionNames,
                          selectedVersion,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: _buildSearchBar(context)),
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
                      const SizedBox(height: 24),
                      _buildSearchBar(context),
                    ],
                  ),
            const SizedBox(height: 32),

            // Livros Recentes
            Builder(
              builder: (context) {
                var displayRecents = recentBooks;
                // Se a lista de recentes estiver vazia (primeiro acesso após a att),
                // usa os livros do progresso de leitura como fallback
                if (displayRecents.isEmpty) {
                  final prog = progressAsync.value ?? {};
                  final booksList = booksAsync.value ?? [];
                  displayRecents = prog.keys
                      .take(12)
                      .map((idStr) {
                        try {
                          final b = booksList.firstWhere(
                            (book) =>
                                book.abbrev.toUpperCase() ==
                                idStr.toUpperCase(),
                          );
                          return b.name; // Use o nome completo
                        } catch (_) {
                          return idStr;
                        }
                      })
                      .toSet()
                      .take(5) // Limite de 5
                      .toList();
                } else {
                  displayRecents = displayRecents.take(5).toList();
                }

                if (displayRecents.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_filled,
                          color: Color(0xFFFFB300),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Livros Recentes',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: displayRecents.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final String abbrevOrName = entry.value;
                          final bookToOpen = booksAsync.value?.firstWhere(
                            (b) =>
                                b.name.toUpperCase() ==
                                    abbrevOrName.toUpperCase() ||
                                b.abbrev.toUpperCase() ==
                                    abbrevOrName.toUpperCase(),
                            orElse: () => booksAsync.value!.first,
                          );
                          
                          // Formatar sigla (ex: "gn" -> "Gn", "1sm" -> "1Sm")
                          String displayName = bookToOpen?.abbrev ?? abbrevOrName;
                          if (displayName.length >= 2) {
                            displayName = displayName.substring(0, 1).toUpperCase() + displayName.substring(1).toLowerCase();
                          } else {
                            displayName = displayName.toUpperCase();
                          }
                          // Manter abreviação curta (max 4 chars p/ não quebrar Layout)
                          if (displayName.length > 4) {
                            displayName = displayName.substring(0, 3) + '.';
                          }

                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (bookToOpen != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReadingScreen(
                                        book: bookToOpen,
                                        initialChapter: 1,
                                        openChapterSelector: true,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                margin: EdgeInsets.only(
                                  right: index < displayRecents.length - 1 ? 8 : 0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  displayName,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Divider(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
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
    );
  }

  Widget _buildVersionSelector(
    BuildContext context,
    Map<String, String> versionNames,
    String selectedVersion,
  ) {
    return GestureDetector(
      onTap: () => _openVersionSelector(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF4F46E5),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Selecione a Versão Bíblica:',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      versionNames[selectedVersion] ??
                          selectedVersion.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: 0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF4F46E5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buscar Livro',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) =>
              ref.read(bookSearchQueryProvider.notifier).state = v,
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Digite o nome ou sigla...',
            hintStyle: GoogleFonts.outfit(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            suffixIcon: Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 5),
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(left: 48, right: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
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
                      color: Theme.of(context).colorScheme.primary,
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.9),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B85F9)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        letterSpacing: 1.5,
      ),
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
