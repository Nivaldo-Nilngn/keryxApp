import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/core/utils/bible_text_parser.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/bible/reading/providers/reading_state_provider.dart';
import 'package:keryx_app/features/bible/reading/view/commentary_reader_screen.dart';
import 'package:keryx_app/features/store/view/store_screen.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:flutter/services.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:keryx_app/features/study/view_model/note_cards_provider.dart';
import 'package:keryx_app/features/study/view/annotations_screen.dart';
import 'package:keryx_app/features/bible/reading/view/text_settings_bottom_sheet.dart';

// ─── Providers de Estado do Hub de Estudos ────────────────────────────────────
// 0: Comentários Bíblicos (Módulos MyBible)
// 1: Minhas Anotações (Caderno de Estudo do Versículo)
// 2: Análise Teológica com IA
final _studyHubTabProvider = StateProvider.autoDispose<int>((ref) => 0);

final _selectedSheetCommentaryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final _aiAnalysisRequestedProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

Future<void> showStudyHubScreen(
  BuildContext context, {
  int initialTab = 0,
  void Function(int targetBookId, int targetChapter, int targetVerse)?
  onNavigateToVerse,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => StudyHubPanel(
        initialTab: initialTab,
        onNavigateToVerse: onNavigateToVerse,
        isFullScreen: true,
      ),
    ),
  );
}

class StudyHubPanel extends ConsumerStatefulWidget {
  final int initialTab;
  final bool isFullScreen;
  final void Function(int targetBookId, int targetChapter, int targetVerse)?
  onNavigateToVerse;

  const StudyHubPanel({
    super.key,
    this.initialTab = 0,
    this.isFullScreen = false,
    this.onNavigateToVerse,
  });

  @override
  ConsumerState<StudyHubPanel> createState() => _StudyHubPanelState();
}

class _StudyHubPanelState extends ConsumerState<StudyHubPanel> {
  late TextEditingController _notesController;
  bool _isNoteDirty = false;
  String? _lastVerseKey;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _notesController.addListener(_onNoteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_studyHubTabProvider.notifier).state = widget.initialTab;
    });
  }

  void _onNoteChanged() {
    if (!_isNoteDirty && mounted) {
      setState(() => _isNoteDirty = true);
    }
  }

  @override
  void deactivate() {
    _flushNotesIfDirty();
    super.deactivate();
  }

  void _flushNotesIfDirty() {
    if (_isNoteDirty && _lastVerseKey != null) {
      _isNoteDirty = false;
      final text = _notesController.text.trim();
      ref.read(annotationsProvider.notifier).saveAnnotation(_lastVerseKey!, text);
      if (text.isNotEmpty) {
        ref.read(noteCardsProvider.notifier).save(NoteCard.fromLegacy(_lastVerseKey!, text));
      } else {
        ref.read(noteCardsProvider.notifier).delete(_lastVerseKey!);
      }
    }
  }

  @override
  void dispose() {
    _notesController.removeListener(_onNoteChanged);
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectionState = ref.watch(readingSelectionProvider);
    final currentBook = selectionState.book;
    final currentChapter = selectionState.chapter;
    final selectedVerseNumbers = selectionState.selectedVerses;

    if (currentBook == null || selectedVerseNumbers.isEmpty) {
      return const SizedBox.shrink();
    }

    final version = ref.watch(selectedVersionProvider);
    final asyncChapter = ref.watch(
      currentChapterProvider((
        abbrev: currentBook.abbrev,
        chapter: currentChapter,
        version: version,
      )),
    );

    final chapterData = asyncChapter.value;
    if (chapterData == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.kPrimaryGold));
    }

    final verseNums = selectedVerseNumbers.toList()..sort();
    final verses = verseNums
        .map((v) => chapterData.verses.firstWhere((element) => element.number == v))
        .toList();

    final verseKey = "${currentBook.name}_${currentChapter}_${verses.first.number}";
    if (_lastVerseKey != verseKey) {
      _lastVerseKey = verseKey;
      final savedNote = ref.read(annotationsProvider)[verseKey] ?? '';
      _notesController.text = savedNote;
      _isNoteDirty = false;
    }

    final bookIdInt = BibleMetadata.findBookId(currentBook.abbrev);
    final allMetas = ref.watch(
      availableCommentariesProvider((
        abbrev: currentBook.abbrev,
        bookId: bookIdInt,
        bookName: currentBook.name,
      )),
    );

    final storeState = ref.watch(downloadedStorePackagesProvider);
    final downloadedMetas = allMetas.where((meta) {
      return storeState.isDownloaded(meta.filename);
    }).toList();

    final startV = verseNums.first;
    final endV = verseNums.last;

    // ─── Filtro Inteligente por Cobertura de Versículo ───────────────────────
    // Retorna apenas as obras baixadas que realmente contêm anotações para este versículo
    final relevantMetasAsync = ref.watch(
      relevantCommentariesForVersesProvider((
        abbrev: currentBook.abbrev,
        bookId: bookIdInt,
        bookName: currentBook.name,
        chapter: currentChapter,
        startVerse: startV,
        endVerse: endV,
      )),
    );

    final relevantMetas = relevantMetasAsync.value ?? [];
    final isCheckingCoverage = relevantMetasAsync.isLoading && !relevantMetasAsync.hasValue;

    // Estado da aba ativa
    final activeTab = ref.watch(_studyHubTabProvider);
    final selectedId = ref.watch(_selectedSheetCommentaryProvider);

    // Resolve o comentário ativo (prioriza comentários que têm notas neste versículo)
    CommentaryMetadata? activeMeta;
    if (relevantMetas.isNotEmpty) {
      activeMeta = relevantMetas.firstWhere(
        (m) => m.id == selectedId,
        orElse: () => relevantMetas.first,
      );
    } else if (downloadedMetas.isNotEmpty) {
      activeMeta = downloadedMetas.firstWhere(
        (m) => m.id == selectedId,
        orElse: () => downloadedMetas.first,
      );
    }

    final verseTitle = verses.length == 1
        ? '${currentBook.name} $currentChapter:${verses.first.number}'
        : '${currentBook.name} $currentChapter:${verses.first.number}-${verses.last.number}';

    final surfaceBase = Theme.of(context).scaffoldBackgroundColor;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = textPrimary.withValues(alpha: 0.6);

    final Widget contentBody = Column(
      children: [
        if (!widget.isFullScreen) ...[
          // ─── 1. Handle de Arraste ──────────────────────────────────────────
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(top: 14, bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ─── 2. Top Header com Referência e Fechar ─────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.explore_rounded,
                            size: 13,
                            color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'HUB DE ESTUDOS',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.2,
                              color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        verseTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => showTextSettingsBottomSheet(context),
                  tooltip: 'Ajuste de Leitura & Fonte',
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Fechar',
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          const SizedBox(height: 12),
        ],

          // ─── 3. Segmented Tabs: [ Comentários Bíblicos ] | [ Análise com IA ] ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Container(
                  height: 46,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  // Aba 0: Comentários Bíblicos
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(_studyHubTabProvider.notifier).state = 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: activeTab == 0
                              ? (isDark ? const Color(0xFF23263A) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: activeTab == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_stories_rounded,
                                size: 15,
                                color: activeTab == 0
                                    ? AppTheme.kPrimaryGold
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Comentários',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: activeTab == 0
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              if (downloadedMetas.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: activeTab == 0
                                        ? AppTheme.kPrimaryGold.withValues(alpha: 0.2)
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isCheckingCoverage
                                        ? '...'
                                        : '${relevantMetas.length}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: activeTab == 0
                                          ? AppTheme.kPrimaryGold
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Aba 1: Minhas Anotações
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(_studyHubTabProvider.notifier).state = 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: activeTab == 1
                              ? (isDark ? const Color(0xFF23263A) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: activeTab == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                size: 16,
                                color: activeTab == 1
                                    ? AppTheme.kPrimaryGold
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Anotações',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                                  color: activeTab == 1
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              if (ref.watch(annotationsProvider)[verseKey]?.trim().isNotEmpty == true) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.kPrimaryGold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Aba 2: Análise com IA
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(_studyHubTabProvider.notifier).state = 2,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: activeTab == 2
                              ? (isDark ? const Color(0xFF23263A) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: activeTab == 2
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 15,
                                color: activeTab == 2
                                    ? AppTheme.kPrimaryGold
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'IA Teológica',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: activeTab == 2 ? FontWeight.bold : FontWeight.w500,
                                  color: activeTab == 2
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

          const SizedBox(height: 14),

          // ─── 4. Corpo do Painel ─────────────────────────────────────────────
          Expanded(
            child: activeTab == 1
                ? _buildAnnotationsTab(
                    context,
                    ref,
                    currentBook,
                    currentChapter,
                    verses,
                    verseKey,
                    activeMeta,
                  )
                : activeTab == 2
                    ? _buildAIContent(context, ref, currentBook, currentChapter, verses)
                    : _buildCommentariesTab(
                        context,
                        ref,
                        downloadedMetas,
                        relevantMetas,
                        activeMeta,
                        isCheckingCoverage,
                        currentBook,
                        currentChapter,
                        verses,
                        bookIdInt,
                      ),
          ),
        ],
      );

    if (widget.isFullScreen) {
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
                verseTitle,
                style: GoogleFonts.plusJakartaSans(
                  color: textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'HUB DE ESTUDOS BÍBLICOS',
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
                if (cur < 34) {
                  ref.read(fontSettingsProvider.notifier).setFontSize(cur + 1.5);
                }
              },
            ),
            // Botão: Ajustes completos de leitura
            IconButton(
              icon: Icon(Icons.tune_rounded, color: textSecondary, size: 20),
              tooltip: 'Configurações de Leitura',
              onPressed: () => showTextSettingsBottomSheet(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: contentBody,
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: contentBody,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // ABA 0: COMENTÁRIOS BÍBLICOS (INTELIGENTE: APENAS COM COBERTURA DO VERSÍCULO)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildCommentariesTab(
    BuildContext context,
    WidgetRef ref,
    List<CommentaryMetadata> downloadedMetas,
    List<CommentaryMetadata> relevantMetas,
    CommentaryMetadata? activeMeta,
    bool isCheckingCoverage,
    BibleBook currentBook,
    int currentChapter,
    List<BibleVerse> verses,
    int bookIdInt,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Se ainda estiver checando a cobertura inicial de notas no SQLite
    if (isCheckingCoverage) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.kPrimaryGold, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text(
              'Localizando comentários com notas neste versículo...',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    // 1. Caso o usuário não tenha NENHUM comentário baixado no app
    if (downloadedMetas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.library_books_rounded,
                  size: 36,
                  color: AppTheme.kPrimaryGold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Nenhum comentário baixado',
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Acesse a Loja Keryx para baixar comentários bíblicos e consultar análises exegéticas versículo a versículo.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StoreScreen()),
                      );
                    },
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text('Explorar Loja'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.kPrimaryGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(_studyHubTabProvider.notifier).state = 1;
                    },
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Usar Assistente IA'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 2. O usuário possui comentários instalados, mas NENHUM cobre este versículo específico
    // (Ex: O usuário está em Gênesis 1:1, mas seus comentários baixados são apenas do Novo Testamento)
    if (relevantMetas.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  size: 32,
                  color: AppTheme.kPrimaryGold,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Sem notas para ${currentBook.name} $currentChapter:${verses.first.number}',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Você possui ${downloadedMetas.length} ${downloadedMetas.length == 1 ? "comentário instalado" : "comentários instalados"}, porém nenhum deles possui notas registradas para este livro ou versículo (eles cobrem outros livros bíblicos).',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(_studyHubTabProvider.notifier).state = 1;
                    },
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Análise com IA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.kPrimaryGold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StoreScreen(
                            initialCategory: StoreCategory.commentaries,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text('Baixar na Loja'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                      foregroundColor: AppTheme.kPrimaryGold,
                      elevation: 0,
                      side: BorderSide(color: AppTheme.kPrimaryGold.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openCommentarySelectorModal(
                      context,
                      ref,
                      relevantCommentaries: relevantMetas,
                      allCommentaries: downloadedMetas,
                      activeMeta: activeMeta ?? downloadedMetas.first,
                      currentBook: currentBook,
                      chapter: currentChapter,
                      verse: verses.first.number,
                    ),
                    icon: const Icon(Icons.library_books_rounded, size: 18),
                    label: Text('Ver Obras (${downloadedMetas.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 3. Há comentários disponíveis com notas confirmadas para este versículo!
    final effectiveActiveMeta = activeMeta ?? relevantMetas.first;

    return Column(
      children: [
        // ─── Seletor Elegante de Comentários (Mostra apenas os que têm notas) ─
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _openCommentarySelectorModal(
                    context,
                    ref,
                    relevantCommentaries: relevantMetas,
                    allCommentaries: downloadedMetas,
                    activeMeta: effectiveActiveMeta,
                    currentBook: currentBook,
                    chapter: currentChapter,
                    verse: verses.first.number,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2132)
                          : const Color(0xFFF3F5FA),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.kPrimaryGold.withValues(alpha: 0.35)
                            : AppTheme.kPrimaryGold.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: AppTheme.kPrimaryGold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'FONTE DE ESTUDO',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${relevantMetas.length} com notas',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.kPrimaryGold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                effectiveActiveMeta.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.kPrimaryGold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Trocar',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoreScreen(
                        initialCategory: StoreCategory.commentaries,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2132) : const Color(0xFFF3F5FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.kPrimaryGold.withValues(alpha: 0.35)
                          : AppTheme.kPrimaryGold.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_shopping_cart_rounded, color: AppTheme.kPrimaryGold, size: 20),
                      const SizedBox(height: 2),
                      Text(
                        'Loja',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─── Conteúdo do Comentário para o Versículo ─────────────────────────
        Expanded(
          child: _buildCommentaryContent(
            context,
            ref,
            effectiveActiveMeta,
            relevantMetas,
            downloadedMetas,
            currentBook,
            currentChapter,
            verses,
            bookIdInt,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // MODAL DE SELEÇÃO ESCALÁVEL (COM FILTRO DE RELEVÂNCIA E BUSCA EM TEMPO REAL)
  // ══════════════════════════════════════════════════════════════════════════════
  void _openCommentarySelectorModal(
    BuildContext context,
    WidgetRef ref, {
    required List<CommentaryMetadata> relevantCommentaries,
    required List<CommentaryMetadata> allCommentaries,
    required CommentaryMetadata activeMeta,
    required BibleBook currentBook,
    required int chapter,
    required int verse,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return _CommentaryPickerModal(
          relevantCommentaries: relevantCommentaries,
          allCommentaries: allCommentaries,
          selectedId: activeMeta.id,
          bookName: currentBook.name,
          chapter: chapter,
          verse: verse,
          onSelected: (meta) {
            ref.read(_selectedSheetCommentaryProvider.notifier).state = meta.id;
            Navigator.pop(modalCtx);
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // CARREGA E RENDERIZA O TEXTO DO COMENTÁRIO DO VERSÍCULO
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildCommentaryContent(
    BuildContext context,
    WidgetRef ref,
    CommentaryMetadata meta,
    List<CommentaryMetadata> relevantMetas,
    List<CommentaryMetadata> allDownloadedMetas,
    BibleBook currentBook,
    int currentChapter,
    List<BibleVerse> verses,
    int bookIdInt,
  ) {
    final asyncContent = ref.watch(
      verseCommentaryProvider((
        id: meta.id,
        filename: meta.filename,
        bookId: bookIdInt,
        chapter: currentChapter,
        verse: verses.first.number,
      )),
    );

    return asyncContent.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.kPrimaryGold),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Erro ao carregar comentário: $e',
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (text) {
        if (text == null || text.trim().isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      size: 32,
                      color: AppTheme.kPrimaryGold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sem notas neste comentário',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A obra "${meta.name}" não possui notas para ${currentBook.name} $currentChapter:${verses.first.number}.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      if (relevantMetas.length > 1)
                        OutlinedButton.icon(
                          onPressed: () => _openCommentarySelectorModal(
                            context,
                            ref,
                            relevantCommentaries: relevantMetas,
                            allCommentaries: allDownloadedMetas,
                            activeMeta: meta,
                            currentBook: currentBook,
                            chapter: currentChapter,
                            verse: verses.first.number,
                          ),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Trocar Comentário'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.kPrimaryGold,
                            side: BorderSide(
                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(_studyHubTabProvider.notifier).state = 1;
                        },
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Analisar com IA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.kPrimaryGold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        // Comentário encontrado! Renderiza o card e opções de anotação/leitor completo
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _renderCommentaryCard(context, ref, meta, text),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final verseKey = "${currentBook.name}_${currentChapter}_${verses.first.number}";
                        final currentNote = ref.read(annotationsProvider)[verseKey] ?? '';
                        final cleanSnippet = text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
                        final newNote = currentNote.isEmpty
                            ? '--- [${meta.name}] ---\n$cleanSnippet'
                            : '$currentNote\n\n--- [${meta.name}] ---\n$cleanSnippet';

                        ref.read(annotationsProvider.notifier).saveAnnotation(verseKey, newNote);
                        ref.read(noteCardsProvider.notifier).save(NoteCard.fromLegacy(verseKey, newNote));
                        _notesController.text = newNote;
                        setState(() => _isNoteDirty = false);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Comentário salvo em suas Anotações!'),
                            backgroundColor: const Color(0xFF10B981),
                            action: SnackBarAction(
                              label: 'Ver Anotação',
                              textColor: Colors.white,
                              onPressed: () {
                                ref.read(_studyHubTabProvider.notifier).state = 1;
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: const Text('Salvar em Anotações'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.kPrimaryGold,
                        side: BorderSide(color: AppTheme.kPrimaryGold.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommentaryReaderScreen(
                              initialMetadata: meta,
                              book: currentBook,
                              chapter: currentChapter,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: const Text('Ler em E-book'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.kPrimaryGold,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // ABA 1: ASSISTENTE DE ESTUDO COM IA
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildAIContent(
    BuildContext context,
    WidgetRef ref,
    BibleBook currentBook,
    int currentChapter,
    List<BibleVerse> verses,
  ) {
    final hasRequested = ref.watch(_aiAnalysisRequestedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final verseTextJoined = verses
        .map((v) => '${v.number}. ${BibleTextParser.cleanToPlainText(v.text)}')
        .join('\n');

    if (!hasRequested) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 36,
                  color: AppTheme.kPrimaryGold,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Assistente Teológico IA',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Gere uma análise teológica profunda, com estudo de termos no original (hebraico/grego), contexto histórico e aplicações práticas para o texto.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
                  ),
                ),
                child: Text(
                  verseTextJoined,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(_aiAnalysisRequestedProvider.notifier).state = true;
                },
                icon: const Icon(Icons.psychology_rounded),
                label: const Text('Gerar Análise Completa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.kPrimaryGold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final aiAsync = ref.watch(
      aiAnalysisProvider((
        bookName: currentBook.name,
        abbrev: currentBook.abbrev,
        chapter: currentChapter,
        verses: verses.map((v) => v.number).toList(),
      )),
    );

    return aiAsync.when(
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.kPrimaryGold),
            const SizedBox(height: 20),
            Text(
              'Gerando análise teológica...',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Examinando termos originais e contexto bíblico',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                'Não foi possível concluir a análise: $e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(
                    aiAnalysisProvider((
                      bookName: currentBook.name,
                      abbrev: currentBook.abbrev,
                      chapter: currentChapter,
                      verses: verses.map((v) => v.number).toList(),
                    )),
                  );
                },
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
      data: (text) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _renderCommentaryCard(
                context,
                ref,
                const CommentaryMetadata(
                  id: 'GPT_THEO',
                  name: 'Análise Teológica com IA',
                  filename: '',
                  category: CommentaryCategory.geral,
                ),
                text,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final verseKey = "${currentBook.name}_${currentChapter}_${verses.first.number}";
                        final currentNote = ref.read(annotationsProvider)[verseKey] ?? '';
                        final cleanText = text.trim();
                        final newNote = currentNote.isEmpty
                            ? '--- [Análise Teológica IA] ---\n$cleanText'
                            : '$currentNote\n\n--- [Análise Teológica IA] ---\n$cleanText';

                        ref.read(annotationsProvider.notifier).saveAnnotation(verseKey, newNote);
                        ref.read(noteCardsProvider.notifier).save(NoteCard.fromLegacy(verseKey, newNote));
                        _notesController.text = newNote;
                        setState(() => _isNoteDirty = false);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Insights da IA salvos em Anotações!'),
                            backgroundColor: const Color(0xFF10B981),
                            action: SnackBarAction(
                              label: 'Ver Anotação',
                              textColor: Colors.white,
                              onPressed: () {
                                ref.read(_studyHubTabProvider.notifier).state = 1;
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                        foregroundColor: AppTheme.kPrimaryGold,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AppTheme.kPrimaryGold.withValues(alpha: 0.3)),
                        ),
                      ),
                      icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                      label: const Text(
                        'Salvar em Anotações',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Regerar Análise',
                    onPressed: () {
                      ref.invalidate(
                        aiAnalysisProvider((
                          bookName: currentBook.name,
                          abbrev: currentBook.abbrev,
                          chapter: currentChapter,
                          verses: verses.map((v) => v.number).toList(),
                        )),
                      );
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // RENDERIZAÇÃO ESTILIZADA DO CARD DE TEXTO
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _renderCommentaryCard(
    BuildContext context,
    WidgetRef ref,
    CommentaryMetadata meta,
    String text,
  ) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Limpeza e Formatação (Markdown -> HTML)
    String cleanText = text.replaceAll(
      RegExp(r'^[=\-*_]{3,}\s*$', multiLine: true),
      '',
    );
    cleanText = cleanText.replaceAll(RegExp(r'[=\-*_]{5,}'), '');
    cleanText = cleanText.replaceAllMapped(
      RegExp(r'^###\s+(.*)$', multiLine: true),
      (match) => '<h3>${match[1]}</h3>',
    );
    cleanText = cleanText.replaceAllMapped(
      RegExp(r'^##\s+(.*)$', multiLine: true),
      (match) => '<h2>${match[1]}</h2>',
    );
    cleanText = cleanText.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*'),
      (match) => '<strong>${match[1]}</strong>',
    );
    cleanText = cleanText.replaceAllMapped(
      RegExp(r'\*(.*?)\*'),
      (match) => '<em>${match[1]}</em>',
    );
    cleanText = cleanText.replaceAllMapped(
      RegExp(r'^\*\s+(.*)$', multiLine: true),
      (match) => '<li>${match[1]}</li>',
    );
    cleanText = cleanText.trim().replaceAll(RegExp(r'\n{2,}'), '<br><br>');
    cleanText = cleanText.replaceAll('\n', '<br>');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E).withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header do Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      meta.id == 'GPT_THEO'
                          ? Icons.auto_awesome
                          : (meta.category == CommentaryCategory.especifico
                              ? Icons.auto_stories
                              : Icons.history_edu),
                      size: 15,
                      color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meta.name.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Conteúdo do Texto
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Html(
                  data: cleanText,
                  style: {
                    "body": Style(
                      fontSize: FontSize(fontSettings.fontSize - 1.5),
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.95),
                      fontFamily: CustomFontLoader.loadedFontFamilies.contains(fontSettings.fontFamily)
                          ? fontSettings.fontFamily
                          : GoogleFonts.getFont(fontSettings.fontFamily).fontFamily ?? 'Outfit',
                      lineHeight: LineHeight.em(1.75),
                      margin: Margins.zero,
                      textAlign: TextAlign.justify,
                    ),
                    "strong": Style(
                      color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: FontSize(fontSettings.fontSize - 0.5),
                    ),
                    "h2": Style(
                      fontSize: FontSize(fontSettings.fontSize + 3),
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      margin: Margins.only(top: 20, bottom: 10),
                    ),
                    "h3": Style(
                      fontSize: FontSize(fontSettings.fontSize + 1.5),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                      margin: Margins.only(top: 16, bottom: 8),
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    "li": Style(
                      margin: Margins.only(bottom: 10, left: 0),
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88),
                      padding: HtmlPaddings.only(left: 4),
                    ),
                    "em": Style(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                      fontStyle: FontStyle.italic,
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // ABA 1: MINHAS ANOTAÇÕES (ÁREA DE ESTUDOS DO VERSÍCULO)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildAnnotationsTab(
    BuildContext context,
    WidgetRef ref,
    BibleBook currentBook,
    int currentChapter,
    List<BibleVerse> verses,
    String verseKey,
    CommentaryMetadata? activeMeta,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryGold = AppTheme.kPrimaryGold;
    final verseNum = verses.first.number;
    final verseNumText = verses.length == 1
        ? '$verseNum'
        : '${verses.first.number}-${verses.last.number}';
    final verseCleanText = verses.length == 1
        ? BibleTextParser.cleanToPlainText(verses.first.text)
        : verses
            .map((v) => '${v.number}. ${BibleTextParser.cleanToPlainText(v.text)}')
            .join(' ');

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── 1. Card com o Versículo Citado ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${currentBook.name} $currentChapter:$verseNumText',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryGold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        final quote = '> "$verseCleanText"\n— ${currentBook.name} $currentChapter:$verseNumText\n\n';
                        if (_notesController.text.contains(verseCleanText)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Este versículo já está citado na anotação.'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          return;
                        }
                        final newText = quote + _notesController.text;
                        _notesController.text = newText;
                        setState(() => _isNoteDirty = true);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.format_quote_rounded, size: 14, color: primaryGold),
                            const SizedBox(width: 4),
                            Text(
                              'Citar no texto',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: primaryGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '"$verseCleanText"',
                  style: GoogleFonts.merriweather(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ─── 2. Barra de Status da Anotação ────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isNoteDirty
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : (_notesController.text.trim().isNotEmpty
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isNoteDirty
                            ? const Color(0xFFF59E0B)
                            : (_notesController.text.trim().isNotEmpty
                                ? const Color(0xFF10B981)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isNoteDirty
                          ? 'Modificações não salvas'
                          : (_notesController.text.trim().isNotEmpty
                              ? 'Anotação salva'
                              : 'Nova anotação'),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isNoteDirty
                            ? const Color(0xFFF59E0B)
                            : (_notesController.text.trim().isNotEmpty
                                ? const Color(0xFF10B981)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_notesController.text.trim().isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copiar anotação',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _notesController.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Anotação copiada para a área de transferência!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  tooltip: 'Excluir anotação',
                  onPressed: () => _confirmDeleteAnnotation(context, ref, verseKey),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // ─── 3. Área de Edição (Caderno de Estudo) ─────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF161822)
                  : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isNoteDirty
                    ? primaryGold.withValues(alpha: 0.4)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: TextField(
              controller: _notesController,
              maxLines: null,
              minLines: 8,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                height: 1.55,
              ),
              decoration: InputDecoration(
                hintText: 'Escreva aqui suas reflexões, anotações de estudo, orações, comentários pessoais ou sermões sobre este versículo...',
                hintStyle: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  fontSize: 14,
                  height: 1.5,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── 4. Botão de Salvar Anotação ───────────────────────────────────
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                final text = _notesController.text.trim();
                ref.read(annotationsProvider.notifier).saveAnnotation(verseKey, text);
                if (text.isNotEmpty) {
                  final card = NoteCard.fromLegacy(verseKey, text);
                  ref.read(noteCardsProvider.notifier).save(card);
                } else {
                  ref.read(noteCardsProvider.notifier).delete(verseKey);
                }
                setState(() => _isNoteDirty = false);
                FocusScope.of(context).unfocus();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Anotação salva com sucesso!'),
                    backgroundColor: Color(0xFF10B981),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(
                _isNoteDirty ? Icons.save_rounded : Icons.check_circle_rounded,
                size: 20,
              ),
              label: Text(
                _isNoteDirty ? 'Salvar Anotação' : 'Anotação Salva',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isNoteDirty ? primaryGold : const Color(0xFF10B981),
                foregroundColor: Colors.black,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ─── 5. Acesso ao Caderno Geral de Anotações ───────────────────────
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnnotationsScreen()),
                );
              },
              icon: Icon(
                Icons.collections_bookmark_outlined,
                size: 16,
                color: isDark ? primaryGold : Theme.of(context).colorScheme.primary,
              ),
              label: Text(
                'Abrir todas as Minhas Anotações',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? primaryGold : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAnnotation(BuildContext context, WidgetRef ref, String verseKey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir Anotação?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Tem certeza que deseja apagar a anotação deste versículo?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(annotationsProvider.notifier).removeAnnotation(verseKey);
              ref.read(noteCardsProvider.notifier).delete(verseKey);
              _notesController.clear();
              setState(() => _isNoteDirty = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Anotação excluída.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODAL DE SELEÇÃO ESCALÁVEL (COM FILTRO "APENAS COM NOTAS" E BUSCA INSTANTÂNEA)
// ══════════════════════════════════════════════════════════════════════════════
class _CommentaryPickerModal extends StatefulWidget {
  final List<CommentaryMetadata> relevantCommentaries;
  final List<CommentaryMetadata> allCommentaries;
  final String selectedId;
  final String bookName;
  final int chapter;
  final int verse;
  final ValueChanged<CommentaryMetadata> onSelected;

  const _CommentaryPickerModal({
    required this.relevantCommentaries,
    required this.allCommentaries,
    required this.selectedId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.onSelected,
  });

  @override
  State<_CommentaryPickerModal> createState() => _CommentaryPickerModalState();
}

class _CommentaryPickerModalState extends State<_CommentaryPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  late bool _onlyWithNotes;

  @override
  void initState() {
    super.initState();
    // Se houver obras com notas para este versículo, filtra por elas por padrão
    _onlyWithNotes = widget.relevantCommentaries.isNotEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Base de itens dependendo do filtro "Apenas com notas"
    final sourceList = _onlyWithNotes ? widget.relevantCommentaries : widget.allCommentaries;

    // Extrai categorias únicas disponíveis na lista atual
    final categories = <String>['Todos'];
    for (final c in sourceList) {
      final cat = c.storeCategoryName;
      if (cat != null && cat.isNotEmpty && !categories.contains(cat)) {
        categories.add(cat);
      }
    }

    // Filtra comentários por busca e categoria
    final filtered = sourceList.where((meta) {
      final matchesQuery = _searchQuery.isEmpty ||
          meta.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Todos' ||
          meta.storeCategoryName == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header do Modal
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECIONAR COMENTÁRIO',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.bookName} ${widget.chapter}:${widget.verse}',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Baixar na Loja',
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StoreScreen(
                          initialCategory: StoreCategory.commentaries,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.shopping_bag_outlined,
                    color: AppTheme.kPrimaryGold,
                    size: 20,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          // Toggle Inteligente: [ Com notas neste versículo ] vs [ Todas as instaladas ]
          if (widget.relevantCommentaries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _onlyWithNotes = true;
                          _selectedCategory = 'Todos';
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: _onlyWithNotes
                                ? (isDark ? const Color(0xFF23263A) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _onlyWithNotes
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Com notas no versículo (${widget.relevantCommentaries.length})',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: _onlyWithNotes ? FontWeight.bold : FontWeight.w500,
                                color: _onlyWithNotes
                                    ? AppTheme.kPrimaryGold
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _onlyWithNotes = false;
                          _selectedCategory = 'Todos';
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: !_onlyWithNotes
                                ? (isDark ? const Color(0xFF23263A) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: !_onlyWithNotes
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Todas instaladas (${widget.allCommentaries.length})',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: !_onlyWithNotes ? FontWeight.bold : FontWeight.w500,
                                color: !_onlyWithNotes
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Campo de Busca em Tempo Real
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: _onlyWithNotes
                    ? 'Buscar entre as ${sourceList.length} obras com notas...'
                    : 'Buscar entre as ${sourceList.length} obras instaladas...',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.kPrimaryGold, width: 1.5),
                ),
              ),
            ),
          ),

          // Filtro por Categorias (se houver mais de uma)
          if (categories.length > 2)
            Container(
              height: 44,
              margin: const EdgeInsets.only(top: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: categories.length,
                itemBuilder: (ctx, i) {
                  final cat = categories[i];
                  final isCatSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isCatSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: isCatSelected ? FontWeight.bold : FontWeight.w500,
                        color: isCatSelected
                            ? Colors.black
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      selectedColor: AppTheme.kPrimaryGold,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide.none,
                      showCheckmark: false,
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),
          Divider(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
            height: 1,
          ),

          // Lista Filtrada de Comentários
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 44,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhum comentário encontrado',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Tente pesquisar com outro termo.'
                              : 'Nenhuma obra nesta categoria possui notas para este versículo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StoreScreen(
                                  initialCategory: StoreCategory.commentaries,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                          label: const Text('Procurar na Loja Keryx'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.kPrimaryGold,
                            side: BorderSide(color: AppTheme.kPrimaryGold.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final meta = filtered[i];
                      final isSelected = meta.id == widget.selectedId;
                      final hasNotesForVerse = widget.relevantCommentaries.any((c) => c.id == meta.id);

                      return InkWell(
                        onTap: () => widget.onSelected(meta),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.kPrimaryGold.withValues(alpha: 0.12)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.02)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.kPrimaryGold.withValues(alpha: 0.5)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.kPrimaryGold.withValues(alpha: 0.2)
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.book_rounded,
                                  size: 18,
                                  color: isSelected
                                      ? AppTheme.kPrimaryGold
                                      : (hasNotesForVerse
                                          ? AppTheme.kPrimaryGold.withValues(alpha: 0.8)
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            meta.name,
                                            style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                              color: isSelected
                                                  ? (isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary)
                                                  : Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        if (hasNotesForVerse)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Com notas',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.kPrimaryGold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (meta.storeCategoryName != null && meta.storeCategoryName!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          meta.storeCategoryName!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.kPrimaryGold,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Rodapé com atalho direto para a Loja de Comentários
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161824) : const Color(0xFFF0F2F8),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoreScreen(
                        initialCategory: StoreCategory.commentaries,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text('Baixar Mais Comentários na Loja'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                  foregroundColor: AppTheme.kPrimaryGold,
                  elevation: 0,
                  side: BorderSide(color: AppTheme.kPrimaryGold.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
