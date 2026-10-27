import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/navigation/view/bible_selector_bottom_sheet.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/reading/repository/reading_repository.dart';
import 'package:keryx_app/features/reading/model/reading_history_model.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/core/utils/bible_text_parser.dart';
import 'package:keryx_app/core/utils/keryx_color_contrast.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:keryx_app/features/bible/strong/view/strong_bottom_sheet.dart';
import 'package:keryx_app/features/bible/reading/view/text_settings_bottom_sheet.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/features/study/view/study_hub_panel.dart';
import 'package:keryx_app/features/study/view/cross_references_screen.dart';
import 'package:keryx_app/features/bible/reading/view/verse_comparison_screen.dart';
import 'package:keryx_app/features/study/view/annotations_screen.dart'
    as keryx_annotations;
import 'package:keryx_app/features/study/view/favorites_screen.dart'
    as keryx_favorites;
import 'package:keryx_app/features/bible/reading/providers/reading_state_provider.dart';
import 'package:keryx_app/core/services/tts/tts_player_provider.dart';
import 'package:keryx_app/features/bible/view/tts_settings_sheet.dart' as keryx_tts;

import 'package:keryx_app/features/bible/view/tts_settings_sheet.dart' show continuousReadingProvider;

class ReadingScreen extends ConsumerStatefulWidget {
  final BibleBook book;
  final int initialChapter;
  final int? initialVerse;
  final bool openChapterSelector;

  const ReadingScreen({
    super.key,
    required this.book,
    required this.initialChapter,
    this.initialVerse,
    this.openChapterSelector = false,
  });

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  static final RegExp _embeddedVerseNumberRegex = RegExp(
    r'^\s*(?:<[^>]+>\s*)*[\(\[]?(\d+(?:[-|,]\d+)?)[\)\]]?(?:<[^>]+>\s*)*\s+',
  );
  static final RegExp _tagRegex = RegExp(r'<[^>]+>');
  static final RegExp _punctuationRegex = RegExp(r'[.,;]');

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _verseKeys = {};
  late int _currentChapter;
  late BibleBook _currentBook;
  String? _activeStrong;
  bool _pendingAutoPlay = false;
  String? _activeStrongWord;
  int? _activeStrongVerse;
  Timer? _scrollDebouncer;
  Timer? _sessionDebounceTimer;
  bool _isRecordingSession = false;
  String? _lastRecordedSessionKey;
  String? _selectedSubVersion;
  int? _targetVerseToScroll;
  bool _hasPrefetchedNext = false;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.initialChapter;
    _currentBook = widget.book;
    _targetVerseToScroll = widget.initialVerse;
    _scrollController.addListener(_onScroll);
    _updateLastRead();
    if (widget.openChapterSelector) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSelector(initialStage: SelectorStage.chapters);
      });
    }
  }

  void _onScroll() {
    if (!_hasPrefetchedNext && _scrollController.hasClients) {
      final pos = _scrollController.position;
      if (pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent * 0.5) {
        _hasPrefetchedNext = true;
        if (_currentChapter < _currentBook.chapters) {
          final effectiveVersion = _selectedSubVersion ?? ref.read(selectedVersionProvider) ?? BibleService.defaultVersion;
          ref.read(bibleServiceProvider).getChapter(
            effectiveVersion,
            _currentBook.id.toString(),
            _currentChapter + 1,
            isPrefetch: true,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _sessionDebounceTimer?.cancel();
    _scrollDebouncer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateLastRead({int verse = 1}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(lastReadProvider.notifier)
          .save(_currentBook, _currentChapter, verse: verse);
      ref
          .read(readingSelectionProvider.notifier)
          .updateLocation(_currentBook, _currentChapter);
      ref.read(recentBooksProvider.notifier).add(_currentBook.abbrev);

      final sessionKey = '${_currentBook.abbrev}_$_currentChapter';
      if (_lastRecordedSessionKey == sessionKey) return;

      _sessionDebounceTimer?.cancel();
      _sessionDebounceTimer = Timer(const Duration(seconds: 20), () async {
        if (!mounted || _isRecordingSession) return;

        final authUser = ref.read(authStateProvider).value;
        if (authUser == null) return;

        _isRecordingSession = true;
        _lastRecordedSessionKey = sessionKey;

        final now = DateTime.now();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayStr =
            '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

        try {
          final repo = ref.read(readingRepositoryProvider);
          await repo.endReadingSession(
            uid: authUser.uid,
            todayDateString: todayStr,
            yesterdayDateString: yesterdayStr,
            durationSeconds: 60,
            chaptersRead: [
              ChapterRead(
                book: _currentBook.abbrev.toUpperCase(),
                chapter: _currentChapter,
              ),
            ],
          );
        } catch (e) {
          if (!e.toString().contains('permission-denied')) {
            debugPrint('Erro ao salvar histórico de leitura: $e');
          }
        } finally {
          if (mounted) {
            _isRecordingSession = false;
          }
        }
      });
    });
  }

  void _changeChapter(int delta, {bool autoPlay = false}) {
    final next = _currentChapter + delta;
    if (next < 1 || next > _currentBook.chapters) return;

    if (autoPlay) {
      _pendingAutoPlay = true;
    }

    // Stop reading when changing chapter
    final ttsState = ref.read(ttsPlayerProvider);
    if (ttsState.isPlaying && ttsState.bookId == _currentBook.id.toString()) {
      ref.read(ttsPlayerProvider.notifier).stop();
    }

    setState(() {
      _currentChapter = next;
      _hasPrefetchedNext = false;
      ref.read(readingSelectionProvider.notifier).clearSelection();
    });
    _updateLastRead();
  }

  Future<void> _toggleReadChapter(dynamic chapter, {int? startVerseIndex}) async {
    final ttsPlayer = ref.read(ttsPlayerProvider.notifier);
    final ttsState = ref.read(ttsPlayerProvider);

    if (ttsState.isPlaying &&
        ttsState.bookId == _currentBook.id.toString() &&
        ttsState.chapter == _currentChapter) {
      await ttsPlayer.stop();
      return;
    }

    // Identificar a partir de qual versículo começar a ler
    int startIndex = startVerseIndex ?? 0;
    if (startVerseIndex == null) {
      final selectedVerses = ref.read(readingSelectionProvider).selectedVerses;
      if (selectedVerses.isNotEmpty) {
        // Pega o menor versículo selecionado e ajusta para índice (0-based)
        final minVerse = selectedVerses.reduce((a, b) => a < b ? a : b);
        startIndex = (minVerse - 1).clamp(0, chapter.verses.length - 1).toInt();
      }
    }

    List<String> versesText = [];
    for (var verse in chapter.verses) {
      String plainText = BibleTextParser.cleanToPlainText(
        verse.text,
        subVersionFilter: _selectedSubVersion,
      );

      // Add even if empty so indices match exactly with verses.length
      versesText.add(plainText.isNotEmpty ? plainText : " ");
    }

    await ttsPlayer.playChapter(
      _currentBook.id.toString(),
      _currentBook.name,
      _currentChapter,
      versesText,
      startVerseIndex: startIndex,
    );
    
    // Limpar a seleção de versículos ao iniciar a leitura, opcionalmente
    ref.read(readingSelectionProvider.notifier).clearSelection();
  }

  Future<void> _openSelector({SelectorStage? initialStage}) async {
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
            initialBook: _currentBook,
            initialChapter: _currentChapter,
            initialVersion: currentVersion,
            initialStage: initialStage,
          ),
        );

    if (result != null && mounted) {
      if (result.version != currentVersion) {
        ref.read(selectedVersionProvider.notifier).setVersion(result.version);
      }

      final ttsState = ref.read(ttsPlayerProvider);
      if (ttsState.isPlaying && ttsState.bookId == _currentBook.id.toString()) {
        ref.read(ttsPlayerProvider.notifier).stop();
      }

      setState(() {
        _currentBook = result.book;
        _currentChapter = result.chapter;
        _hasPrefetchedNext = false;
        if (result.verse != null) {
          _targetVerseToScroll = result.verse;
        }
        ref.read(readingSelectionProvider.notifier).clearSelection();
      });
      _updateLastRead();
    }
  }

  TextStyle _getFontStyle(
    String fontFamily, {
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) {
    if (CustomFontLoader.loadedFontFamilies.contains(fontFamily)) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        height: height,
      );
    } else {
      try {
        return GoogleFonts.getFont(
          fontFamily,
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: height,
        );
      } catch (e) {
        return GoogleFonts.outfit(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: height,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final version = ref.watch(selectedVersionProvider);
    final asyncChapter = ref.watch(
      currentChapterProvider((
        abbrev: _currentBook.abbrev,
        chapter: _currentChapter,
        version: version,
      )),
    );

    // Watchers para Firebase Sync
    final highlights = ref.watch(highlightsProvider);
    final favorites = ref.watch(favoritesProvider);
    final readingSelection = ref.watch(readingSelectionProvider);
    final selectedVerses = readingSelection.selectedVerses;
    final hasSelection = selectedVerses.isNotEmpty;
    final isNavbarVisible = ref.watch(navbarVisibleProvider) && !hasSelection;
    final highlightVerseSetting = ref.watch(keryx_tts.highlightVerseProvider);

    // Seletor fino de áudio: a tela inteira só rebuilda quando o número do versículo ativo mudar
    final activeAudioVerseNumber = ref.watch(ttsPlayerProvider.select((s) {
      final isCurrentChapterAudio = highlightVerseSetting &&
          s.isPlaying &&
          s.verses.isNotEmpty &&
          s.bookId == _currentBook.id.toString() &&
          s.chapter == _currentChapter;
      return isCurrentChapterAudio ? (s.currentVerseIndex + 1) : null;
    }));

    // Auto-scroll para acompanhar a leitura em áudio
    final autoScroll = ref.watch(keryx_tts.autoScrollProvider);
    ref.listen<TTSPlaybackState>(ttsPlayerProvider, (previous, next) {
      if (autoScroll &&
          next.isPlaying &&
          next.bookId == _currentBook.id.toString() &&
          next.chapter == _currentChapter &&
          (previous?.currentVerseIndex != next.currentVerseIndex)) {
        final verseNumber = next.currentVerseIndex + 1;
        final key = _verseKeys[verseNumber];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            alignment: 0.3, // Tenta manter o versículo na parte de cima/meio
          );
        }
      }
      
      if (previous != null && previous.isPlaying && !next.isPlaying && next.isFinished) {
        if (ref.read(continuousReadingProvider)) {
          _changeChapter(1, autoPlay: true);
        }
      }
    });

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _changeChapter(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _changeChapter(-1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => _changeChapter(1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => _changeChapter(-1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          appBar: const MBibliaTopBar(
            title: 'KeryxApp',
            showLogo: true,
            showBackButton: false,
          ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            asyncChapter.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.kPrimaryGold),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
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
              data: (chapter) {
                if (_pendingAutoPlay) {
                  _pendingAutoPlay = false;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _toggleReadChapter(chapter);
                  });
                }
                
                // Configuração das Sub-versões
                final rawFirstVerse = chapter.verses.firstOrNull?.text ?? '';
                final subVersions = BibleTextParser.getAvailableSubVersions(
                  rawFirstVerse,
                );

                final effectiveSubVersion =
                    _selectedSubVersion ??
                    (subVersions.isNotEmpty ? subVersions.first : null);

                if (_targetVerseToScroll != null) {
                  final target = _targetVerseToScroll;
                  _targetVerseToScroll = null;
                  void tryScroll([int attempts = 0]) {
                    if (!mounted) return;
                    final key = _verseKeys[target];
                    if (key != null && key.currentContext != null) {
                      Scrollable.ensureVisible(
                        key.currentContext!,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        alignment: 0.20,
                      );
                    } else if (attempts < 6) {
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () => tryScroll(attempts + 1),
                      );
                    }
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
                }

                final bottomSafeArea = MediaQuery.of(context).padding.bottom;
                // Calculado dinamicamente para manter o botão de paginação e versículos sempre acima da navbar e painel de áudio
                final bottomScrollPadding = (isNavbarVisible ? (72.0 + 24.0 + 76.0) : 76.0) + bottomSafeArea + 40.0;

                return SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 20, 20, bottomScrollPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopSection(chapter),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildNavigationRow(
                              subVersions,
                              effectiveSubVersion,
                              chapter,
                            ),
                            const SizedBox(height: 24),
                            if (fontSettings.splitPage && MediaQuery.of(context).size.width >= 600)
                              _buildTwoColumnVerses(
                                verses: chapter.verses,
                                version: version,
                                effectiveSubVersion: effectiveSubVersion,
                                fontSettings: fontSettings,
                                activeAudioVerseNumber: activeAudioVerseNumber,
                                selectedVerses: selectedVerses,
                                highlights: highlights,
                                favorites: favorites,
                              )
                            else
                              ...chapter.verses.map((verse) {
                                return _buildVerseItem(
                                  verse: verse,
                                  version: version,
                                  effectiveSubVersion: effectiveSubVersion,
                                  fontSettings: fontSettings,
                                  activeAudioVerseNumber: activeAudioVerseNumber,
                                  selectedVerses: selectedVerses,
                                  highlights: highlights,
                                  favorites: favorites,
                                  isTwoColumn: false,
                                );
                              }),
                            _buildPagination(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            if (ref.watch(readingSelectionProvider).selectedVerses.isNotEmpty)
              asyncChapter.maybeWhen(
                data: (chapter) => _buildFloatingToolkit(chapter),
                orElse: () => const SizedBox.shrink(),
              ),

            // Navbar Fixa no Rodapé
            Align(
              alignment: Alignment.bottomCenter,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                      padding: EdgeInsets.only(
                        bottom: isNavbarVisible
                            ? (72.0 + 24.0 + MediaQuery.of(context).padding.bottom)
                            : MediaQuery.of(context).padding.bottom,
                      ),
                      width: double.infinity,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.white
                          : const Color(0xFF161B2B),
                      child: asyncChapter.maybeWhen(
                        data: (chapter) => _buildAudioController(chapter),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ),
                  BookDetailBottomNav(
                    currentIndex: 1,
                    forceHide: hasSelection,
                    onTap: (index) {
                      if (index == 1) return;
                      if (index == 0) {
                        Navigator.popUntil(context, (route) => route.isFirst);
                        ref.read(navigationProvider.notifier).setIndex(0);
                      } else if (index == 3 || index == 4) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              body: Stack(
                                children: [
                                  if (index == 3)
                                    const keryx_annotations.AnnotationsScreen()
                                  else
                                    const keryx_favorites.FavoritesScreen(),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: CustomBottomNav(
                                      currentIndex: index,
                                      onTap: (newIndex) {
                                        if (newIndex == index) return;
                                        Navigator.pop(context); // Pop this tab
                                        if (newIndex != 1) {
                                          if (newIndex == 0) {
                                            Navigator.popUntil(
                                              context,
                                              (route) => route.isFirst,
                                            );
                                            ref
                                                .read(navigationProvider.notifier)
                                            .setIndex(0);
                                      }
                                    }
                                  },
                                  onBack: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                },
                onBack: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
),
),
);
}

  void _showComparisonSheet(List<int> selectedVerseNumbers) {
    showVerseComparisonScreen(
      context,
      currentBook: _currentBook,
      currentChapter: _currentChapter,
      selectedVerseNumbers: selectedVerseNumbers,
    );
  }

  Widget _buildFloatingToolkit(BibleChapter chapter) {
    if (ref.watch(readingSelectionProvider).selectedVerses.isEmpty)
      return const SizedBox.shrink();

    final versesText =
        ref.watch(readingSelectionProvider).selectedVerses.toList()..sort();
    final textForCopy = versesText
        .map((vNum) {
          final v = chapter.verses.firstWhere((v) => v.number == vNum);
          return '${v.number} ${BibleTextParser.cleanToPlainText(v.text)}';
        })
        .join('\n');

    final firstVerseNum = versesText.first;
    final firstVerse = chapter.verses.firstWhere(
      (v) => v.number == firstVerseNum,
    );

    final actions = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.auto_awesome,
        label: 'Estudar',
        onTap: () => _showCommentarySheet(initialTab: 0),
      ),
      (
        icon: Icons.alt_route_rounded,
        label: 'Referências',
        onTap: () => _showCrossReferencesSheet(firstVerse),
      ),
      (
        icon: Icons.layers_outlined,
        label: 'Comparar',
        onTap: () => _showComparisonSheet(versesText),
      ),
      (
        icon: Icons.favorite_border_rounded,
        label: 'Favoritar',
        onTap: () {
          for (final num in versesText) {
            final key = "${_currentBook.name}_${_currentChapter}_$num";
            ref.read(favoritesProvider.notifier).toggleFavorite(key);
          }
          ref.read(readingSelectionProvider.notifier).clearSelection();
        },
      ),
      (
        icon: Icons.bookmark_border_rounded,
        label: 'Marcar',
        onTap: () => _showHighlightColorsSheet(versesText),
      ),
      (
        icon: Icons.edit_note,
        label: 'Anotar',
        onTap: () => _showCommentarySheet(initialTab: 1),
      ),
      (
        icon: Icons.copy,
        label: 'Copiar',
        onTap: () {
          Clipboard.setData(ClipboardData(text: textForCopy));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Copiado!')));
        },
      ),
      (
        icon: Icons.share,
        label: 'Compartilhar',
        onTap: () => Share.share(textForCopy),
      ),
    ];

    return Positioned(
      bottom: 90,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 12, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${ref.watch(readingSelectionProvider).selectedVerses.length} versículo(s)',
                        style: GoogleFonts.outfit(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              final isStrong = ref.read(isStrongAvailableProvider);
                              showTextSettingsBottomSheet(context, isStrongVersion: isStrong);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF23263A)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.7),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.settings_outlined,
                                    size: 15,
                                    color: AppTheme.kPrimaryGold,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Texto',
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.kPrimaryGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 20,
                            ),
                            onPressed: () {
                              ref
                                  .read(readingSelectionProvider.notifier)
                                  .clearSelection();
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 500;
                    if (isWide) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: actions.map((item) {
                            return Expanded(
                              child: _buildFloatingAction(
                                item.icon,
                                item.label,
                                item.onTap,
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    } else {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: actions.map((item) {
                            return SizedBox(
                              width: 78,
                              child: _buildFloatingAction(
                                item.icon,
                                item.label,
                                item.onTap,
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingAction(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showHighlightColorsSheet(List<int> versesNum) {
    final colors = [
      Colors.yellow.value,
      Colors.greenAccent.value,
      Colors.blueAccent.value,
      Colors.purpleAccent.value,
      Colors.redAccent.value,
      Colors.orangeAccent.value,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cor do Marcador',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 16,
              children: [
                ...colors.map(
                  (c) => GestureDetector(
                    onTap: () {
                      for (final num in versesNum) {
                        final key =
                            "${_currentBook.name}_${_currentChapter}_$num";
                        ref
                            .read(highlightsProvider.notifier)
                            .toggleHighlight(key, c);
                      }
                      ref
                          .read(readingSelectionProvider.notifier)
                          .clearSelection();
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    for (final num in versesNum) {
                      final key =
                          "${_currentBook.name}_${_currentChapter}_$num";
                      final current = ref.read(highlightsProvider)[key];
                      if (current != null) {
                        ref
                            .read(highlightsProvider.notifier)
                            .toggleHighlight(key, current);
                      }
                    }
                    ref
                        .read(readingSelectionProvider.notifier)
                        .clearSelection();
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.format_color_reset_outlined,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _navigateToVerse(int targetBookId, int targetChapter, int targetVerse) {
    final details = BibleMetadata.bookDetails[targetBookId] ?? {
      "abbrev": "gn",
      "group": "Pentateuco",
      "author": "Moisés",
      "chapters": 50,
    };
    final newBook = BibleBook(
      id: targetBookId,
      name: BibleMetadata.getBookName(targetBookId),
      abbrev: details['abbrev'] ?? 'gn',
      author: details['author'] ?? '',
      group: details['group'] ?? '',
      chapters: details['chapters'] ?? 1,
    );
    setState(() {
      _currentBook = newBook;
      _currentChapter = targetChapter;
      _hasPrefetchedNext = false;
    });
    ref.read(readingSelectionProvider.notifier).clearSelection();
  }

  void _showCrossReferencesSheet(BibleVerse verse) {
    final bookIdInt = BibleMetadata.findBookId(_currentBook.abbrev);
    showCrossReferencesScreen(
      context,
      bookId: bookIdInt,
      bookName: _currentBook.name,
      chapter: _currentChapter,
      verse: verse.number,
      onNavigateToVerse: (targetBookId, targetChapter, targetVerse) {
        _navigateToVerse(targetBookId, targetChapter, targetVerse);
      },
    );
  }

  void _showCommentarySheet({int initialTab = 0}) {
    showStudyHubScreen(
      context,
      initialTab: initialTab,
      onNavigateToVerse: (targetBookId, targetChapter, targetVerse) {
        Navigator.pop(context);
        _navigateToVerse(targetBookId, targetChapter, targetVerse);
      },
    );
  }

  Widget _buildTopSection(dynamic chapter) {
    final version = ref.watch(selectedVersionProvider);
    final storeState = ref.watch(downloadedStorePackagesProvider);

    String fullName =
        BibleMetadata.versionNames[version] ?? version.toUpperCase();
    if (!BibleMetadata.versionNames.containsKey(version)) {
      final found = storeState.availablePackages.where(
        (p) =>
            p.category == StoreCategory.bibles &&
            p.filename.toUpperCase().contains(version.toUpperCase()),
      );
      if (found.isNotEmpty) fullName = found.first.name;
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardBg = isLight
        ? Colors.white
        : const Color(0xFF1E1E3F).withValues(alpha: 0.5);
    final inputBg = isLight ? Colors.grey[50]! : const Color(0xFF0F0F1E);
    final borderColor = isLight
        ? Colors.grey[200]!
        : Colors.white.withValues(alpha: 0.05);

    final settingsBtnColor = isLight ? const Color(0xFF4F46E5) : const Color(0xFFD4AF37);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector Caixa
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    color: isLight ? const Color(0xFF4F46E5) : const Color(0xFF818CF8),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Selecione a Versão Bíblica:',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final isStrong = ref.read(isStrongAvailableProvider);
                      showTextSettingsBottomSheet(context, isStrongVersion: isStrong);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: settingsBtnColor.withValues(alpha: isLight ? 0.12 : 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: settingsBtnColor.withValues(alpha: isLight ? 0.25 : 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            color: settingsBtnColor,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Texto',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: settingsBtnColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _openSelector(initialStage: SelectorStage.versions),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          fullName,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF4F46E5),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Os botões grandes foram removidos conforme solicitado.
      ],
    );
  }

  Widget _buildNavigationRow(
    List<String> subVersions,
    String? effectiveSubVersion,
    BibleChapter chapter,
  ) {
    final version = ref.watch(selectedVersionProvider);
    return // Menu de Navegação Superior (Redesenhado)
    Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (subVersions.isNotEmpty) ...[
            _buildTopButton(
              icon: Icons.layers_outlined,
              text: effectiveSubVersion ?? version,
              onTap: () => _showSubVersionSelector(subVersions),
            ),
            const SizedBox(width: 8),
          ],

          _buildTopIconButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => _changeChapter(-1),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildTopButton(
                trailingIcon: Icons.keyboard_arrow_down_rounded,
                text: '${_currentBook.name} $_currentChapter',
                isFlexible: true,
                onTap: () => _openSelector(initialStage: SelectorStage.books),
              ),
            ),
          ),

          _buildTopIconButton(
            icon: Icons.chevron_right_rounded,
            onTap: () => _changeChapter(1),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 24),
      child: Row(
        children: [
          if (_currentChapter > 1)
            Expanded(
              child: _buildPaginationButton(
                'Capítulo Anterior',
                Icons.arrow_back,
                () => _changeChapter(-1),
              ),
            ),
          if (_currentChapter > 1 && _currentChapter < _currentBook.chapters)
            const SizedBox(width: 12),
          if (_currentChapter < _currentBook.chapters)
            Expanded(
              child: _buildPaginationButton(
                'Próximo Capítulo',
                Icons.arrow_forward,
                () => _changeChapter(1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton(
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E3F).withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon == Icons.arrow_back) ...[
              Icon(icon, color: AppTheme.kPrimaryGold, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.85),
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (icon == Icons.arrow_forward) ...[
              const SizedBox(width: 8),
              Icon(icon, color: AppTheme.kPrimaryGold, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerseItem({
    required BibleVerse verse,
    required String version,
    required String? effectiveSubVersion,
    required FontSettings fontSettings,
    required int? activeAudioVerseNumber,
    required Set<int> selectedVerses,
    required Map<String, int> highlights,
    required Set<String> favorites,
    bool isTwoColumn = false,
  }) {
    _verseKeys[verse.number] ??= GlobalKey();
    final isAudioActiveInChapter = activeAudioVerseNumber != null;
    final isAudioHighlighted = activeAudioVerseNumber == verse.number;
    final shouldDimVerse = isAudioActiveInChapter && !isAudioHighlighted;

    final isSelected = selectedVerses.contains(verse.number);
    final verseKey = "${_currentBook.name}_${_currentChapter}_${verse.number}";
    final highlightColorVal = highlights[verseKey];
    final isFavorited = favorites.contains(verseKey);

    return RepaintBoundary(
      key: _verseKeys[verse.number],
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              ref
                  .read(readingSelectionProvider.notifier)
                  .toggleVerse(verse.number);
            },
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: shouldDimVerse ? 0.3 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(
                  vertical: isTwoColumn ? 2 : 4,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isTwoColumn ? 6 : 8,
                  vertical: isTwoColumn ? 8 : 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.05)
                      : isAudioHighlighted
                          ? const Color(0xFF4ADE80).withValues(alpha: 0.15)
                          : (highlightColorVal != null
                              ? Color(highlightColorVal).withValues(alpha: 0.15)
                              : Colors.transparent),
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(
                          color: AppTheme.kPrimaryGold.withValues(alpha: 0.3),
                        )
                      : isAudioHighlighted
                          ? Border.all(
                              color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                            )
                          : (highlightColorVal != null
                              ? Border.all(
                                  color: Color(highlightColorVal).withValues(alpha: 0.3),
                                )
                              : Border.all(color: Colors.transparent)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (verse.title != null && verse.title!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 12.0,
                          top: 8.0,
                        ),
                        child: Text(
                          verse.title!,
                          style: GoogleFonts.outfit(
                            fontSize: isTwoColumn ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.kPrimaryGold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                    // Logic to handle embedded verse numbers (e.g. (1-2))
                    ...(() {
                      String verseText = verse.text;
                      String displayNumber = verse.displayVerse;

                      final match = _embeddedVerseNumberRegex.firstMatch(verseText);
                      if (match != null) {
                        displayNumber = match.group(1)!;
                        verseText = verseText.replaceFirst(match.group(0)!, '');
                      }

                      final verseToRender = verse.copyWith(text: verseText);

                      final badgeBgColor = fontSettings.badgeColor != null
                          ? Color(fontSettings.badgeColor!)
                          : const Color(0xFF4F46E5);

                      final badgeSize = isTwoColumn ? 28.0 : 32.0;
                      final badgeMargin = isTwoColumn ? 8.0 : 12.0;
                      final badgeFontSize = isTwoColumn
                          ? (displayNumber.length > 2 ? 10.0 : 12.0)
                          : (displayNumber.length > 2 ? 12.0 : 14.0);

                      final isRtl = BibleTextParser.isRtlText(verseToRender.text);

                      return [
                        RichText(
                          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                          textAlign: isRtl ? TextAlign.right : TextAlign.left,
                          text: TextSpan(
                            style: _getFontStyle(
                              fontSettings.fontFamily,
                              fontSize: fontSettings.fontSize,
                              height: 1.6,
                              color: KeryxColorContrast.ensureReadableTextColor(
                                fontSettings.textColor != null
                                    ? Color(fontSettings.textColor!)
                                    : null,
                                context,
                              ),
                            ),
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Container(
                                  margin: EdgeInsets.only(
                                    right: isRtl ? 0 : badgeMargin,
                                    left: isRtl ? badgeMargin : 0,
                                  ),
                                  width: badgeSize,
                                  height: badgeSize,
                                  decoration: BoxDecoration(
                                    color: badgeBgColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: badgeBgColor.withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    displayNumber,
                                    style: GoogleFonts.outfit(
                                      fontSize: badgeFontSize,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              ..._buildVerseSpans(
                                verseToRender,
                                version,
                                effectiveSubVersion,
                                fontSettings,
                              ),
                            ],
                          ),
                        ),
                      ];
                    })(),

                    if (_activeStrongVerse == verse.number && _activeStrong != null)
                      _buildFootnoteBox(_activeStrong!),
                  ],
                ),
              ),
            ),
          ),
          if (isFavorited)
            Positioned(
              top: isTwoColumn ? 8 : 12,
              right: isTwoColumn ? 8 : 12,
              child: Icon(
                Icons.favorite_rounded,
                color: Colors.redAccent.withValues(alpha: 0.8),
                size: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTwoColumnVerses({
    required List<dynamic> verses,
    required String version,
    required String? effectiveSubVersion,
    required FontSettings fontSettings,
    required int? activeAudioVerseNumber,
    required Set<int> selectedVerses,
    required Map<String, int> highlights,
    required Set<String> favorites,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    final int total = verses.length;
    final int mid = (total / 2).ceil();
    final col1Verses = verses.sublist(0, mid);
    final col2Verses = verses.sublist(mid);

    return CustomPaint(
      painter: _ColumnDividerPainter(color: dividerColor),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: col1Verses.map((v) => _buildVerseItem(
                  verse: v as BibleVerse,
                  version: version,
                  effectiveSubVersion: effectiveSubVersion,
                  fontSettings: fontSettings,
                  activeAudioVerseNumber: activeAudioVerseNumber,
                  selectedVerses: selectedVerses,
                  highlights: highlights,
                  favorites: favorites,
                  isTwoColumn: true,
                )).toList(),
              ),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: col2Verses.map((v) => _buildVerseItem(
                  verse: v as BibleVerse,
                  version: version,
                  effectiveSubVersion: effectiveSubVersion,
                  fontSettings: fontSettings,
                  activeAudioVerseNumber: activeAudioVerseNumber,
                  selectedVerses: selectedVerses,
                  highlights: highlights,
                  favorites: favorites,
                  isTwoColumn: true,
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói a lista de spans ricos usando o BibleTextParser centralizado.
  /// Suporta Strong's, notas de rodapé (RF/CL), itálico (<i>), negrito (<b>)
  /// e palavras de Jesus (<wj>).
  List<InlineSpan> _buildVerseSpans(
    BibleVerse verse,
    String version,
    String? effectiveSubVersion,
    FontSettings fontSettings,
  ) {
    final vUpper = version.toUpperCase();
    final hasStrongs = BibleService.versionsWithStrongs.contains(vUpper) ||
        vUpper.endsWith('_S') ||
        vUpper.contains('STRONG') ||
        vUpper.contains('BHS') ||
        vUpper.contains('HEBRAICA') ||
        BibleTextParser.isInterlinearText(verse.text);
    return BibleTextParser.buildRichVerseSpans(
      context: context,
      rawVerseText: verse.text,
      verseNumber: verse.number,
      isStrongVersion: hasStrongs,
      subVersionFilter: effectiveSubVersion,
      textColor: KeryxColorContrast.ensureReadableTextColor(
        fontSettings.textColor != null ? Color(fontSettings.textColor!) : null,
        context,
      ),
      strongHighlightColor: fontSettings.strongHighlightColor,
      strongUnderline: fontSettings.strongUnderline,
      strongBold: fontSettings.strongBold,
      onStrongTap: (String tag, String word) {
        showStrongBottomSheet(context, tag, word);
      },
      onFootnoteTap: (String footnoteType, String content, int verseNumber) {
        setState(() {
          _activeStrong = content;
          _activeStrongWord = footnoteType == 'NOTA'
              ? 'Nota de Rodapé'
              : 'Comentário';
          _activeStrongVerse = verseNumber;
        });
      },
    );
  }

  Widget _buildFootnoteBox(String noteContent) {
    return _buildGlassCard(
      title: _activeStrongWord ?? 'Nota',
      content: noteContent.replaceAll(_tagRegex, ''),
      onClose: () => setState(() {
        _activeStrong = null;
        _activeStrongWord = null;
        _activeStrongVerse = null;
      }),
    );
  }

  Widget _buildGlassCard({
    required String title,
    required String content,
    required VoidCallback onClose,
  }) {
    final fontSettings = ref.watch(fontSettingsProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4ADE80).withValues(alpha: 0.15),
                const Color(0xFF4ADE80).withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      title.contains('Nota')
                          ? Icons.info_outline_rounded
                          : Icons.auto_stories_rounded,
                      color: const Color(0xFF4ADE80),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(
                              0xFF4ADE80,
                            ).withValues(alpha: 0.7),
                            letterSpacing: 2,
                          ),
                        ),
                        if (!title.contains('Nota'))
                          Text(
                            _activeStrongWord?.replaceAll(
                                  _punctuationRegex,
                                  '',
                                ) ??
                                '',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.60),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1),
                  height: 1,
                ),
              ),
              Html(
                data: content.replaceAll('### ', '').replaceAll('* ', '• '),
                style: {
                  "body": Style(
                    fontSize: FontSize(fontSettings.fontSize - 2),
                    color: Colors.white.withValues(alpha: 0.85),
                    fontFamily:
                        CustomFontLoader.loadedFontFamilies.contains(
                          fontSettings.fontFamily,
                        )
                        ? fontSettings.fontFamily
                        : GoogleFonts.getFont(
                                fontSettings.fontFamily,
                              ).fontFamily ??
                              'Outfit',
                    lineHeight: LineHeight.em(1.7),
                    letterSpacing: 0.2,
                    margin: Margins.zero,
                  ),
                  "a": Style(
                    color: const Color(0xFF4ADE80),
                    textDecoration: TextDecoration.none,
                    fontWeight: FontWeight.bold,
                  ),
                  "strong": Style(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  "em": Style(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubVersionSelector(List<String> subVersions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Selecione a Tradução',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...subVersions.map(
              (sv) => ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  sv,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing:
                    _selectedSubVersion == sv ||
                        (_selectedSubVersion == null && sv == subVersions.first)
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.kPrimaryGold,
                      )
                    : null,
                onTap: () {
                  setState(() => _selectedSubVersion = sv);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioController(BibleChapter chapter) {
    return Consumer(
      builder: (context, ref, child) {
        final ttsState = ref.watch(ttsPlayerProvider);
        final isCurrentChapterAudio = ttsState.bookId == _currentBook.id.toString() &&
            ttsState.chapter == _currentChapter &&
            ttsState.verses.isNotEmpty;

        final isLight = Theme.of(context).brightness == Brightness.light;
        // Se não for o capítulo atual de áudio, forçamos o isPlaying para falso visualmente
        final isPlaying = isCurrentChapterAudio && ttsState.isPlaying;

        return Container(
          width: double.infinity,
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          // Play/Pause Button
          GestureDetector(
            onTap: () {
              final hasSelection = ref.read(readingSelectionProvider).selectedVerses.isNotEmpty;

              if (hasSelection && !isPlaying) {
                // Força o início da leitura a partir do versículo selecionado
                _toggleReadChapter(chapter);
                return;
              }

              if (!isCurrentChapterAudio) {
                // Inicia a leitura do capítulo atual se o player estava parado ou em outro capítulo
                _toggleReadChapter(chapter);
              } else {
                final notifier = ref.read(ttsPlayerProvider.notifier);
                if (isPlaying) {
                  notifier.pause();
                } else {
                  notifier.resume();
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLight ? Colors.grey[200] : const Color(0xFF2C2C2E),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isLight ? Colors.black87 : Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Chapter navigation pill
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isLight ? Colors.grey[200] : const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (isCurrentChapterAudio) {
                        final ttsState = ref.read(ttsPlayerProvider);
                        if (ttsState.currentVerseIndex == 0) {
                          _changeChapter(-1, autoPlay: true);
                        } else {
                          ref.read(ttsPlayerProvider.notifier).skipPreviousVerse();
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Icon(
                        Icons.skip_previous_rounded,
                        color: isLight ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openSelector(initialStage: SelectorStage.books),
                      child: Consumer(
                        builder: (context, ref, child) {
                          final selectedVerses = ref.watch(readingSelectionProvider).selectedVerses;
                          String displayText;
                          if (selectedVerses.isNotEmpty) {
                            final minSelected = selectedVerses.reduce((a, b) => a < b ? a : b);
                            displayText = '${_currentBook.name} $_currentChapter:$minSelected';
                          } else if (isCurrentChapterAudio) {
                            displayText = '${_currentBook.name} $_currentChapter:${ttsState.currentVerseIndex + 1}';
                          } else {
                            displayText = '${_currentBook.name} $_currentChapter';
                          }

                          return Text(
                            displayText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: isLight ? Colors.black87 : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          );
                        }
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (isCurrentChapterAudio) {
                        final ttsState = ref.read(ttsPlayerProvider);
                        if (ttsState.currentVerseIndex >= ttsState.verses.length - 1) {
                          _changeChapter(1, autoPlay: true);
                        } else {
                          ref.read(ttsPlayerProvider.notifier).skipNextVerse();
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Icon(
                        Icons.skip_next_rounded,
                        color: isLight ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Botão de Configurações de Voz
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const keryx_tts.TtsSettingsSheet(),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLight ? Colors.grey[200] : const Color(0xFF2C2C2E),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.settings_voice_rounded,
                color: isLight ? Colors.black87 : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildTopButton({
    IconData? icon,
    IconData? trailingIcon,
    required String text,
    required VoidCallback onTap,
    bool isFlexible = false,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    Widget textWidget = Text(
      text,
      style: GoogleFonts.outfit(
        color: isLight ? Colors.black87 : Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      overflow: isFlexible ? TextOverflow.ellipsis : null,
    );

    if (isFlexible) {
      textWidget = Flexible(child: textWidget);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF161B2B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLight
                ? Colors.grey[300]!
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isLight ? Colors.black87 : Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
            ],
            textWidget,
            if (trailingIcon != null) ...[
              const SizedBox(width: 4),
              Icon(
                trailingIcon,
                color: isLight ? Colors.black87 : Colors.white,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF161B2B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLight
                ? Colors.grey[300]!
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(
          icon,
          color: isLight ? Colors.black87 : Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _ColumnDividerPainter extends CustomPainter {
  final Color color;
  const _ColumnDividerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    final double x = size.width / 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ColumnDividerPainter oldDelegate) =>
      oldDelegate.color != color;
}

