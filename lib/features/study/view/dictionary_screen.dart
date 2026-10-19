import 'package:flutter/material.dart';
import 'package:keryx_app/core/widgets/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/bible/strong/view/strong_bottom_sheet.dart';
import 'package:keryx_app/features/bible/strong/view/strong_bottom_sheet.dart' show showStrongBottomSheet;
import 'package:keryx_app/features/study/view/dictionary_detail_screen.dart';

class DictionaryScreen extends ConsumerStatefulWidget {
  final String? initialSearch;
  const DictionaryScreen({super.key, this.initialSearch});

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialSearch,
  );

  String? _selectedLetter;
  bool _isSearching = false;
  final List<String> _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
  final _searchFieldKey = GlobalKey();
  final _letterSearchFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _isSearching = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dictId = ref.watch(selectedDictionaryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      appBar: const MBibliaTopBar(
        title: 'KeryxApp',
        showLogo: true,
        isScrolled: true,
        showBackButton: false,
      ),
      body: Stack(
        children: [
          _buildBodyContent(dictId),

          // Navbar Fixa
          Align(
            alignment: Alignment.bottomCenter,
            child: DictionaryBottomNav(
              currentIndex: 2,
              onBack: () => Navigator.pop(context),
              onTap: (index) {
                Navigator.pop(context);
                ref.read(navigationProvider.notifier).setIndex(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(String dictId) {
    if (_selectedLetter != null) {
      return Column(
        children: [
          _buildLetterHeader(dictId),
          _buildDictionarySelector(),
          _buildLetterSearchSection(),
          Expanded(
            child: _isSearching && _searchController.text.length >= 2
                ? _buildSearchResults(dictId)
                : _buildLetterResults(dictId),
          ),
        ],
      );
    }

    if (_isSearching && _searchController.text.length >= 2) {
      return Column(
        children: [
          _buildWebHeader(),
          _buildDictionarySelector(),
          _buildWebSearchSection(),
          Expanded(child: _buildSearchResults(dictId)),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildWebHeader(),
          _buildDictionarySelector(),
          _buildWebSearchSection(),
          _buildLettersGrid(dictId),
          _buildInfoSection(dictId),
        ],
      ),
    );
  }

  Widget _buildDictionarySelector() {
    final selectedFilename = ref.watch(selectedDictionaryProvider);
    final dictsMap = ref.watch(availableDictionariesListProvider);
    final dicts = dictsMap.entries.toList();

    final isValidSelection = dicts.any((e) => e.value == selectedFilename);
    final effectiveSelection = isValidSelection
        ? selectedFilename
        : (dicts.isNotEmpty ? dicts.first.value : null);

    return GestureDetector(
      onTap: () {
        if (dicts.isNotEmpty) {
          _showDictionarySelectorBottomSheet(
            context,
            ref,
            effectiveSelection,
            dicts,
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(
          top: 16,
          bottom: 16,
          left: 16,
          right: 16,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.translate_rounded,
                size: 18,
                color: const Color(0xFF4F46E5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dicts
                      .firstWhere(
                        (e) => e.value == effectiveSelection,
                        orElse: () => dicts.first,
                      )
                      .key,
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDictionarySelectorBottomSheet(
    BuildContext context,
    WidgetRef ref,
    String? currentFilename,
    List<MapEntry<String, String>> all,
  ) {
    Widget buildContent(ScrollController? sc) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: ResponsiveLayout.isExpanded(context) ? null : const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            if (!ResponsiveLayout.isExpanded(context))
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            if (ResponsiveLayout.isExpanded(context))
              const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.translate_rounded,
                      color: Color(0xFF4F46E5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selecionar Dicionário',
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${all.length} disponíveis',
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ResponsiveLayout.isExpanded(context))
                    IconButton(
                      icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
            Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08), height: 1),
            Expanded(
              child: ListView.builder(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                itemCount: all.length,
                itemBuilder: (context, index) {
                  final entry = all[index];
                  final isSelected = entry.value == currentFilename;
                  return GestureDetector(
                    onTap: () {
                      ref.read(selectedDictionaryProvider.notifier).state = entry.value;
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF4F46E5).withValues(alpha: 0.4)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Color(0xFF4F46E5),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: GoogleFonts.outfit(
                                color: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF4F46E5),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (ResponsiveLayout.isExpanded(context)) {
      showDialog(
        context: context,
        useSafeArea: false,
        builder: (ctx) => Dialog.fullscreen(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          child: buildContent(null),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, sc) => buildContent(sc),
        ),
      );
    }
  }

  Widget _buildWebHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book, size: 16, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                'DICIONÁRIO BÍBLICO',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Termos e Definições',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Consulte milhares de termos com definições completas sobre conceitos bíblicos',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                key: _searchFieldKey,
                controller: _searchController,
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Buscar termo...',
                  hintStyle: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (val) {
                  setState(() {
                    _isSearching = val.length >= 2;
                  });
                },
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = _searchController.text.length >= 2;
                });
              },
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Icon(
                  Icons.search,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ), // blue-500
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLettersGrid(String dictId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ÍNDICE ALFABÉTICO',
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _alphabet.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveLayout.isExpanded(context) ? 6 : 4,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final letter = _alphabet[index];
              final isSelected = _selectedLetter == letter;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedLetter = letter;
                    _searchController.clear();
                    _isSearching = false;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isSelected ? const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ) : null,
                    color: isSelected ? null : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letter,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String dictId) {
    final countAsync = ref.watch(dictionaryTotalTermCountProvider(dictId));
    final countStr = countAsync.when(
      data: (count) {
        if (count == 0) return '---';
        // Formata com pontos de milhares (ex: 8362 -> 8.362)
        return count.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
      },
      loading: () => '...',
      error: (_, __) => '---',
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A).withValues(alpha: 0.2), // blue-900/20
        border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoRow(countStr, 'Termos\nDisponíveis', Icons.menu_book),
          _buildInfoRow('26', 'Letras do\nAlfabeto', Icons.list),
          _buildInfoRow('⚡', 'Busca\nRápida', Icons.search),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String subtitle, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            color: const Color(0xFF60A5FA), // blue-400
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), size: 14),
            const SizedBox(width: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- LETTER VIEW WIDGETS ---

  Widget _buildLetterHeader(String dictId) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedLetter = null;
                _searchController.clear();
                _isSearching = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Voltar',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _selectedLetter ?? '',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 24),
              Consumer(
                builder: (context, ref, _) {
                  final countAsync = ref.watch(
                    dictionaryLetterCountProvider((
                      dictId: dictId,
                      letter: _selectedLetter ?? 'A',
                    )),
                  );
                  return countAsync.when(
                    data: (count) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total de termos',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          count.toString(),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLetterSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                key: _letterSearchFieldKey,
                controller: _searchController,
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Buscar termos na letra $_selectedLetter...',
                  hintStyle: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (val) {
                  setState(() {
                    _isSearching = val.length >= 2;
                  });
                },
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = _searchController.text.length >= 2;
                });
              },
              child: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5), // indigo-600
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Buscar',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(String dictId) {
    final query = _searchController.text;
    if (query.length < 2) return const SizedBox();

    final asyncSearch = ref.watch(
      dictionarySearchWordsProvider((dictId: dictId, query: query)),
    );
    return asyncSearch.when(
      data: (words) {
        var filteredWords = words;
        if (_selectedLetter != null) {
          filteredWords = words
              .where(
                (w) => (w['word'] as String).toUpperCase().startsWith(
                  _selectedLetter!,
                ),
              )
              .toList();
        }
        return _buildWordList(filteredWords);
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      ),
      error: (e, _) => Center(
        child: Text(
          'Erro: $e',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildLetterResults(String dictId) {
    final asyncWords = ref.watch(
      dictionaryLetterWordsProvider((
        dictId: dictId,
        letter: _selectedLetter ?? 'A',
      )),
    );
    return asyncWords.when(
      data: (words) => _buildWordList(words),
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      ),
      error: (e, _) => Center(
        child: Text(
          'Erro: $e',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildWordList(List<Map<String, dynamic>> words) {
    if (words.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Este dicionário está vazio',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nenhum termo encontrado.',
              style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: words.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = words[index];
        final id = item['id']?.toString();
        final word = item['word']?.toString() ?? 'Sem termo';
        final rawData =
            item['data']?.toString() ?? 'Nenhuma definição encontrada.';
        final previewText = rawData.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        final initialLetter = word.isNotEmpty ? word[0].toUpperCase() : 'A';

        return GestureDetector(
          onTap: () {
            if (id != null) {
              showStrongBottomSheet(context, id, word);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DictionaryDetailScreen(
                    word: word,
                    definition: rawData,
                    letter: initialLetter,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              word,
                              style: GoogleFonts.outfit(
                                color: Theme.of(context).colorScheme.onSurface, 
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (item['source_dictionary'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item['source_dictionary'],
                                style: GoogleFonts.outfit(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        previewText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Ver definição completa',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: Theme.of(context).colorScheme.primary,
                            size: 14,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initialLetter,
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
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
}

class _LetterGridItem extends ConsumerWidget {
  final String letter;
  final String dictId;
  final VoidCallback onTap;

  const _LetterGridItem({
    required this.letter,
    required this.dictId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(
      dictionaryLetterCountProvider((dictId: dictId, letter: letter)),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              letter,
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            countAsync.when(
              data: (count) => Text(
                count.toString(),
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
              ),
              loading: () => SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
