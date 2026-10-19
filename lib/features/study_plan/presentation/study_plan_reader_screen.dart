import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/utils/keryx_color_contrast.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/features/bible/reading/view/text_settings_bottom_sheet.dart';
import 'package:keryx_app/features/bible/strong/view/strong_bottom_sheet.dart';
import '../data/study_plan_bible_service.dart';
import '../domain/domain.dart';
import '../application/study_plan_providers.dart';

enum ReaderTheme { dark, sepia, light }

class StudyPlanReaderScreen extends ConsumerStatefulWidget {
  final PlanDay planDay;
  final int globalDayNumber;

  const StudyPlanReaderScreen({
    super.key,
    required this.planDay,
    required this.globalDayNumber,
  });

  @override
  ConsumerState<StudyPlanReaderScreen> createState() =>
      _StudyPlanReaderScreenState();
}

class _StudyPlanReaderScreenState
    extends ConsumerState<StudyPlanReaderScreen> {
  ReaderTheme _readerTheme = ReaderTheme.dark;
  final Map<int, List<InlineSpan>> _cachedSpans = {};
  String _lastCacheSignature = '';
  Future<List<StudyVerse>>? _versesFuture;

  @override
  void initState() {
    super.initState();
    _loadVerses();
  }

  void _loadVerses() {
    final service = ref.read(studyPlanBibleServiceProvider);
    _versesFuture = service.loadPassagesVerses(widget.planDay.passages);
  }

  void _cycleTheme() {
    setState(() {
      switch (_readerTheme) {
        case ReaderTheme.dark:
          _readerTheme = ReaderTheme.sepia;
          break;
        case ReaderTheme.sepia:
          _readerTheme = ReaderTheme.light;
          break;
        case ReaderTheme.light:
          _readerTheme = ReaderTheme.dark;
          break;
      }
      _cachedSpans.clear();
    });
  }

  TextStyle _getFontStyle(
    String fontFamily, {
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    if (CustomFontLoader.loadedFontFamilies.contains(fontFamily)) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        height: height,
        decoration: decoration,
        decorationColor: decorationColor,
      );
    } else {
      try {
        return GoogleFonts.getFont(
          fontFamily,
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: height,
          decoration: decoration,
          decorationColor: decorationColor,
        );
      } catch (e) {
        return GoogleFonts.outfit(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: height,
          decoration: decoration,
          decorationColor: decorationColor,
        );
      }
    }
  }

  Color get _bgColor {
    switch (_readerTheme) {
      case ReaderTheme.dark:
        return const Color(0xFF0A0F1D);
      case ReaderTheme.sepia:
        return const Color(0xFFFBF0D9);
      case ReaderTheme.light:
        return const Color(0xFFF8FAFC);
    }
  }

  Color get _textColor {
    switch (_readerTheme) {
      case ReaderTheme.dark:
        return const Color(0xFFE2E8F0);
      case ReaderTheme.sepia:
        return const Color(0xFF2C1E14);
      case ReaderTheme.light:
        return const Color(0xFF0F172A);
    }
  }

  Color get _cardBg {
    switch (_readerTheme) {
      case ReaderTheme.dark:
        return const Color(0xFF131B2E);
      case ReaderTheme.sepia:
        return const Color(0xFFF1E3C8);
      case ReaderTheme.light:
        return const Color(0xFFFFFFFF);
    }
  }

  Color get _accentColor {
    switch (_readerTheme) {
      case ReaderTheme.dark:
        return AppTheme.kPrimaryGold;
      case ReaderTheme.sepia:
        return const Color(0xFF92400E);
      case ReaderTheme.light:
        return const Color(0xFF0284C7);
    }
  }

  Color get _defaultStrongHighlightColor {
    switch (_readerTheme) {
      case ReaderTheme.dark:
        return const Color(0xFF4ADE80);
      case ReaderTheme.sepia:
        return const Color(0xFF166534);
      case ReaderTheme.light:
        return const Color(0xFF15803D);
    }
  }

  Color _resolveTextColor(FontSettings fontSettings, BuildContext context) {
    if (fontSettings.textColor != null) {
      return KeryxColorContrast.ensureReadableTextColor(
        Color(fontSettings.textColor!),
        context,
      );
    }
    return _textColor;
  }

  Color _resolveStrongColor(
    FontSettings fontSettings,
    Color effectiveTextColor,
  ) {
    if (fontSettings.strongHighlightColor != null) {
      if (fontSettings.strongHighlightColor == 0) {
        return effectiveTextColor;
      }
      return Color(fontSettings.strongHighlightColor!);
    }
    return _defaultStrongHighlightColor;
  }

  Color _resolveBadgeColor(FontSettings fontSettings) {
    if (fontSettings.badgeColor != null) {
      return Color(fontSettings.badgeColor!);
    }
    return const Color(0xFF4F46E5);
  }

  IconData get _themeIcon {
    switch (_readerTheme) {
      case ReaderTheme.dark:
        return Icons.dark_mode_rounded;
      case ReaderTheme.sepia:
        return Icons.wb_sunny_outlined;
      case ReaderTheme.light:
        return Icons.light_mode_rounded;
    }
  }

  void _showNotesBottomSheet(BuildContext context) {
    final progress = ref.read(studyPlanProgressProvider);
    final initialNote = progress.getNote(widget.globalDayNumber) ?? '';
    final controller = TextEditingController(text: initialNote);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_note_rounded, color: _accentColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Anotações • Dia ${widget.globalDayNumber}',
                          style: GoogleFonts.plusJakartaSans(
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: _textColor.withValues(alpha: 0.6)),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                Text(
                  widget.planDay.formattedSummary,
                  style: GoogleFonts.manrope(
                    color: _textColor.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(color: _textColor, fontSize: 15),
                    decoration: InputDecoration(
                      hintText:
                          'Escreva suas reflexões, aprendizados e orações da leitura de hoje...',
                      hintStyle: TextStyle(color: _textColor.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: _bgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _accentColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final text = controller.text;
                    await ref
                        .read(studyPlanProgressProvider.notifier)
                        .saveNote(widget.globalDayNumber, text);
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            text.trim().isEmpty
                                ? 'Anotação removida.'
                                : 'Anotação salva com sucesso!',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Salvar Anotação'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: _readerTheme == ReaderTheme.sepia ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildChapterHeader({
    required StudyVerse verse,
    required bool isFirst,
    required Color effectiveTextColor,
  }) {
    final isDark = _readerTheme == ReaderTheme.dark;
    return Container(
      margin: EdgeInsets.only(
        top: isFirst ? 4 : 32,
        bottom: 18,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _accentColor.withValues(alpha: isDark ? 0.3 : 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: _accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  verse.bookName.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: _accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Capítulo ${verse.chapter}',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: effectiveTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(studyPlanProgressProvider);
    final fontSettings = ref.watch(fontSettingsProvider);
    final isCompleted =
        progress.completedDays.contains(widget.globalDayNumber);
    final hasNote = progress.hasNote(widget.globalDayNumber);
    final currentNote = progress.getNote(widget.globalDayNumber);

    final effectiveTextColor = _resolveTextColor(fontSettings, context);
    final effectiveStrongColor =
        _resolveStrongColor(fontSettings, effectiveTextColor);
    final effectiveBadgeColor = _resolveBadgeColor(fontSettings);
    final effectiveFontSize = fontSettings.fontSize;

    final cacheSignature =
        '${fontSettings.fontFamily}_${effectiveFontSize}_${fontSettings.textColor}_${fontSettings.strongHighlightColor}_${fontSettings.strongUnderline}_${fontSettings.strongBold}_${fontSettings.badgeColor}_$_readerTheme';
    if (_lastCacheSignature != cacheSignature) {
      _cachedSpans.clear();
      _lastCacheSignature = cacheSignature;
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: MBibliaTopBar(
        title: widget.planDay.formattedSummary,
        showLogo: false,
        showBackButton: true,
        actions: [
          // Botão Anotações
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                tooltip: 'Anotações do Dia',
                icon: const Icon(Icons.edit_note_rounded),
                onPressed: () => _showNotesBottomSheet(context),
              ),
              if (hasNote)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          // Botão Configurações de Texto e Strong da Bíblia
          IconButton(
            tooltip: 'Configurações de Texto e Strong',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => showTextSettingsBottomSheet(
              context,
              isStrongVersion: true,
            ),
          ),
          // Botão Trocar Tema
          IconButton(
            tooltip: 'Alternar Tema (Escuro / Sépia / Claro)',
            icon: Icon(_themeIcon),
            onPressed: _cycleTheme,
          ),
          // Ajuste de Fonte
          IconButton(
            tooltip: 'Diminuir Fonte',
            icon: const Icon(Icons.text_decrease_rounded),
            onPressed: () {
              ref
                  .read(fontSettingsProvider.notifier)
                  .setFontSize((fontSettings.fontSize - 1.5).clamp(12.0, 40.0));
            },
          ),
          IconButton(
            tooltip: 'Aumentar Fonte',
            icon: const Icon(Icons.text_increase_rounded),
            onPressed: () {
              ref
                  .read(fontSettingsProvider.notifier)
                  .setFontSize((fontSettings.fontSize + 1.5).clamp(12.0, 40.0));
            },
          ),
        ],
      ),
      body: FutureBuilder<List<StudyVerse>>(
        future: _versesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: _accentColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Erro ao carregar o texto bíblico: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: effectiveTextColor),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(_loadVerses),
                      child: const Text('Tentar Novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final verses = snapshot.data ?? [];
          if (verses.isEmpty) {
            return Center(
              child: Text(
                'Nenhum versículo encontrado para este trecho.',
                style: TextStyle(color: effectiveTextColor),
              ),
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                itemCount: verses.length + 1, // +1 para o rodapé
                itemBuilder: (context, index) {
                  if (index == verses.length) {
                    // Rodapé com Card de Anotações e Card de Conclusão
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 32),

                        // Card de Anotações do Dia
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: hasNote
                                  ? _accentColor.withValues(alpha: 0.5)
                                  : effectiveTextColor.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note_rounded,
                                        color: _accentColor,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Reflexão do Dia',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: effectiveTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showNotesBottomSheet(context),
                                    icon: Icon(
                                      hasNote
                                          ? Icons.edit_rounded
                                          : Icons.add_rounded,
                                      size: 16,
                                      color: _accentColor,
                                    ),
                                    label: Text(
                                      hasNote ? 'Editar' : 'Escrever',
                                      style: TextStyle(color: _accentColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (hasNote && currentNote != null)
                                Text(
                                  currentNote,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: effectiveTextColor.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  'Guarde o que Deus falou com você nesta leitura para meditar ao longo do dia.',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: effectiveTextColor.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Card de Conclusão da Leitura
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isCompleted
                                  ? const Color(0xFF10B981)
                                  : _accentColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                isCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.auto_stories_rounded,
                                size: 44,
                                color: isCompleted
                                    ? const Color(0xFF10B981)
                                    : _accentColor,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isCompleted
                                    ? 'Dia Concluído com Sucesso!'
                                    : 'Você terminou a leitura de hoje!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: effectiveTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isCompleted
                                    ? 'Continue firme na leitura diária da Palavra de Deus.'
                                    : 'Toque abaixo para marcar este dia como concluído em seu plano.',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: effectiveTextColor.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () {
                                  ref
                                      .read(studyPlanProgressProvider.notifier)
                                      .toggleDay(widget.globalDayNumber);
                                },
                                icon: Icon(
                                  isCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                ),
                                label: Text(
                                  isCompleted
                                      ? 'Concluído ✓'
                                      : 'Marcar como Lido',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: isCompleted
                                      ? const Color(0xFF10B981)
                                      : _accentColor,
                                  foregroundColor: isCompleted
                                      ? Colors.white
                                      : (_readerTheme == ReaderTheme.sepia
                                          ? Colors.white
                                          : Colors.black),
                                  minimumSize: const Size(200, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    );
                  }

                  final verse = verses[index];
                  final isNewChapter = index == 0 ||
                      verses[index - 1].chapter != verse.chapter ||
                      verses[index - 1].book != verse.book;

                  // Spans com cache por versículo e preferências visuais
                  final spans = _cachedSpans.putIfAbsent(
                    index,
                    () => StudyVerseParser.buildSpans(
                      context: context,
                      rawText: verse.rawScripture,
                      fontSize: effectiveFontSize,
                      textColor: effectiveTextColor,
                      strongColor: effectiveStrongColor,
                      strongUnderline: fontSettings.strongUnderline,
                      strongBold: fontSettings.strongBold,
                      fontFamily: fontSettings.fontFamily,
                      height: 1.68,
                      fontStyleBuilder: _getFontStyle,
                      onStrongTap: (strongCode, word) {
                        showStrongBottomSheet(context, strongCode, word);
                      },
                    ),
                  );

                  return SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isNewChapter)
                          _buildChapterHeader(
                            verse: verse,
                            isFirst: index == 0,
                            effectiveTextColor: effectiveTextColor,
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: RichText(
                            textAlign: TextAlign.start,
                            text: TextSpan(
                              style: _getFontStyle(
                                fontSettings.fontFamily,
                                fontSize: effectiveFontSize,
                                height: 1.68,
                                color: effectiveTextColor,
                              ),
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Container(
                                    margin: const EdgeInsets.only(
                                      right: 10,
                                      bottom: 2,
                                    ),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: effectiveBadgeColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: effectiveBadgeColor.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1.5),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${verse.verse}',
                                      style: GoogleFonts.outfit(
                                        fontSize: verse.verse > 99 ? 10 : 12,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                ...spans,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
