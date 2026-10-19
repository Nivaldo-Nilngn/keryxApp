import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:keryx_app/features/study/view_model/note_cards_provider.dart';
import 'package:keryx_app/features/study/view/note_detail_screen.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';

// ─── Provider ────────────────────────────────────────────────────────────────
final selectedCommentaryVersionProvider =
    StateProvider<CommentaryMetadata?>((ref) => null);

// ─── Screen ──────────────────────────────────────────────────────────────────
class CommentaryReaderScreen extends ConsumerStatefulWidget {
  final CommentaryMetadata initialMetadata;
  final BibleBook book;
  final int chapter;

  const CommentaryReaderScreen({
    super.key,
    required this.initialMetadata,
    required this.book,
    required this.chapter,
  });

  @override
  ConsumerState<CommentaryReaderScreen> createState() =>
      _CommentaryReaderScreenState();
}

class _CommentaryReaderScreenState
    extends ConsumerState<CommentaryReaderScreen> {
  late BibleBook _currentBook;
  late int _currentChapter;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ─── Temas de Leitura Estilo E-book ───────────────────────────────────────
  // 0: Claro, 1: Sépia, 2: Escuro, 3: Preto AMOLED
  int _currentTheme = 2;
  double _fontSize = 17.0;

  // ─── TTS (Áudio Leitura) ───────────────────────────────────────────────────
  FlutterTts? _flutterTts;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _currentBook = widget.book;
    _currentChapter = widget.chapter;

    _loadPreferences();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(selectedCommentaryVersionProvider) == null) {
        ref.read(selectedCommentaryVersionProvider.notifier).state =
            widget.initialMetadata;
      }
      _saveState();
    });
  }

  Future<FlutterTts> _getTts() async {
    if (_flutterTts != null) return _flutterTts!;
    final tts = FlutterTts();
    try {
      await tts.setLanguage("pt-BR");
      await tts.setSpeechRate(0.5);
      await tts.setPitch(1.0);
    } catch (e) {
      debugPrint("TTS init error: $e");
    }
    tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
    tts.setErrorHandler((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    _flutterTts = tts;
    return tts;
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentTheme = prefs.getInt('cmt_reader_theme') ?? 2;
        _fontSize = prefs.getDouble('cmt_reader_font_size') ?? 17.0;
      });
    } catch (_) {}
  }

  Future<void> _setTheme(int theme) async {
    setState(() => _currentTheme = theme);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cmt_reader_theme', theme);
    } catch (_) {}
  }

  Future<void> _setFontSize(double size) async {
    setState(() => _fontSize = size);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('cmt_reader_font_size', size);
    } catch (_) {}
  }

  void _saveState() {
    final meta =
        ref.read(selectedCommentaryVersionProvider) ?? widget.initialMetadata;
    ref
        .read(lastCommentaryReadProvider.notifier)
        .save(_currentBook, _currentChapter, meta);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    try {
      _flutterTts?.stop();
    } catch (_) {}
    super.dispose();
  }

  void _goToChapter(int target) {
    if (_isPlaying) {
      try {
        _flutterTts?.stop();
      } catch (_) {}
      _isPlaying = false;
    }
    setState(() {
      _currentChapter = target;
    });
    _saveState();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _toggleTts(List<({int fromVerse, int toVerse, String text})> blocks) async {
    if (_isPlaying) {
      try {
        await _flutterTts?.stop();
      } catch (_) {}
      if (mounted) setState(() => _isPlaying = false);
    } else {
      if (blocks.isEmpty) return;
      final fullHtml = blocks.map((b) => b.text).join(' ');
      final plainText =
          html_parser.parse(fullHtml).documentElement?.text ?? '';
      if (plainText.trim().isNotEmpty) {
        setState(() => _isPlaying = true);
        final tts = await _getTts();
        await tts.speak(plainText.trim());
      }
    }
  }

  Future<void> _saveBookmark() async {
    final meta =
        ref.read(selectedCommentaryVersionProvider) ?? widget.initialMetadata;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'bkm_commentary_${meta.filename}',
        jsonEncode({
          'bookId': _currentBook.id,
          'chapter': _currentChapter,
          'time': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
    _saveState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.bookmark_added_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Marcador salvo: ${_currentBook.name} ${_currentChapter == 0 ? "Introdução" : "Capítulo $_currentChapter"}!',
                style: GoogleFonts.outfit(),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // Cores dinâmicas de acordo com o tema de leitura escolhido
  Color get _pageBgColor {
    switch (_currentTheme) {
      case 0: // Claro
        return const Color(0xFFFDFDFD);
      case 1: // Sépia
        return const Color(0xFFFBF0D9);
      case 3: // Preto AMOLED
        return const Color(0xFF000000);
      case 2: // Escuro
      default:
        return const Color(0xFF0F0F1A);
    }
  }

  Color get _textColor {
    switch (_currentTheme) {
      case 0:
        return const Color(0xFF1A1A1A);
      case 1:
        return const Color(0xFF4A3525);
      case 3:
        return const Color(0xFFEDEDED);
      case 2:
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  Color get _mutedColor {
    switch (_currentTheme) {
      case 0:
        return const Color(0xFF64748B);
      case 1:
        return const Color(0xFF7D6B58);
      case 3:
        return const Color(0xFF888888);
      case 2:
      default:
        return const Color(0xFF8A8A9D);
    }
  }

  Color get _cardBgColor {
    switch (_currentTheme) {
      case 0:
        return const Color(0xFFF1F5F9);
      case 1:
        return const Color(0xFFF4E7CB);
      case 3:
        return const Color(0xFF121212);
      case 2:
      default:
        return const Color(0xFF1E1E2C);
    }
  }

  Color get _accentGold {
    switch (_currentTheme) {
      case 0:
        return const Color(0xFF6B46C1);
      case 1:
        return const Color(0xFF8C531B);
      default:
        return const Color(0xFFD4AF37);
    }
  }

  bool get _isDarkTheme => _currentTheme == 2 || _currentTheme == 3;

  @override
  Widget build(BuildContext context) {
    final meta =
        ref.watch(selectedCommentaryVersionProvider) ?? widget.initialMetadata;
    final bookId = BibleMetadata.findBookId(_currentBook.abbrev);

    final chaptersDetailAsync = ref.watch(commentedChaptersDetailProvider((
      filename: meta.filename,
      bookId: bookId,
    )));

    final blockListAsync = ref.watch(chapterCommentariesProvider((
      filename: meta.filename,
      id: meta.id,
      bookId: bookId,
      chapter: _currentChapter,
      verse: 1,
    )));

    final blockList = blockListAsync.value ?? [];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _pageBgColor,
      // Gaveta com o Índice do Livro (Capítulos disponíveis)
      endDrawer: _buildChapterIndexDrawer(meta, bookId),
      body: SafeArea(
        child: Column(
          children: [
            // Topbar Minimalista de Leitura E-book
            _buildReaderTopBar(meta, blockList),

            // Canvas de Leitura Contínua
            Expanded(
              child: blockListAsync.when(
                data: (blocks) {
                  if (blocks.isEmpty) return _buildEmpty(meta.name);
                  return _buildContinuousReader(meta, bookId, blocks);
                },
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: _accentGold,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Erro ao carregar comentários: $e',
                    style: TextStyle(color: _mutedColor),
                  ),
                ),
              ),
            ),

            // Barra Inferior de Navegação Estilo E-book
            _buildBottomReaderBar(meta, bookId, chaptersDetailAsync),
          ],
        ),
      ),
    );
  }

  // ─── TOPBAR MINIMALISTA ────────────────────────────────────────────────────
  Widget _buildReaderTopBar(
    CommentaryMetadata meta,
    List<({int fromVerse, int toVerse, String text})> blocks,
  ) {
    final chapterLabel = _currentChapter == 0
        ? 'Introdução'
        : 'Capítulo $_currentChapter';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _pageBgColor,
        border: Border(
          bottom: BorderSide(
            color: _isDarkTheme
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          // Botão Voltar
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textColor,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Voltar',
          ),

          // Título e Subtítulo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentBook.name} • ${meta.name.replaceAll("Comentários Expositivos/", "")}',
                  style: GoogleFonts.outfit(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$chapterLabel de ${_currentBook.chapters}',
                  style: GoogleFonts.outfit(
                    color: _mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Ajuste de Tamanho da Fonte
          IconButton(
            icon: Icon(Icons.format_size_rounded, color: _textColor, size: 22),
            onPressed: _showFontSettingsDialog,
            tooltip: 'Tamanho da fonte',
          ),

          // Paleta de Temas (Claro, Sépia, Escuro, AMOLED)
          IconButton(
            icon: Icon(Icons.palette_outlined, color: _textColor, size: 22),
            onPressed: _showThemeSelectorSheet,
            tooltip: 'Tema de leitura',
          ),

          // Ouvir (TTS Áudio)
          IconButton(
            icon: Icon(
              _isPlaying
                  ? Icons.stop_circle_rounded
                  : Icons.volume_up_rounded,
              color: _isPlaying ? Colors.redAccent : _accentGold,
              size: 24,
            ),
            onPressed: () => _toggleTts(blocks),
            tooltip: _isPlaying ? 'Parar leitura' : 'Ouvir capítulo',
          ),

          // Índice de Capítulos
          IconButton(
            icon: Icon(Icons.menu_book_rounded, color: _textColor, size: 22),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            tooltip: 'Índice de Capítulos',
          ),
        ],
      ),
    );
  }

  // ─── CORPO DE LEITURA CONTÍNUA (ESTILO LIVRO EBOOK) ────────────────────────
  Widget _buildContinuousReader(
    CommentaryMetadata meta,
    int bookId,
    List<({int fromVerse, int toVerse, String text})> blocks,
  ) {
    final coverAsync = ref.watch(commentaryBookCoverProvider((
      filename: meta.filename,
      bookId: bookId,
    )));

    final showHeroCover = _currentChapter == 0;

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Apresentação da Capa Centralizada (quando for introdução ou capítulo 0)
          if (showHeroCover) ...[
            Center(
              child: coverAsync.when(
                data: (coverBytes) {
                  if (coverBytes != null && coverBytes.isNotEmpty) {
                    return Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 20),
                      constraints: const BoxConstraints(
                        maxWidth: 240,
                        maxHeight: 340,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: _isDarkTheme ? 0.6 : 0.25,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Image.memory(
                              coverBytes,
                              fit: BoxFit.contain,
                            ),
                            // Lombada 3D
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              width: 16,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.45),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Título elegante no início do livro
            Text(
              _currentBook.name.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _textColor,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              meta.name,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: _accentGold,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Divider(
              color: _mutedColor.withValues(alpha: 0.2),
              thickness: 1,
            ),
            const SizedBox(height: 16),
          ],

          // Fluxo Contínuo de Textos de Comentário
          for (int i = 0; i < blocks.length; i++) ...[
            _buildContinuousBlock(meta, bookId, blocks[i], i == 0),
          ],
        ],
      ),
    );
  }

  Widget _buildContinuousBlock(
    CommentaryMetadata meta,
    int bookId,
    ({int fromVerse, int toVerse, String text}) block,
    bool isFirst,
  ) {
    final fromVerse = block.fromVerse;
    final toVerse = block.toVerse;

    String verseLabel;
    if (fromVerse == 0 && toVerse == 0) {
      verseLabel = 'Introdução';
    } else if (fromVerse == toVerse) {
      verseLabel = 'Versículo $fromVerse';
    } else {
      verseLabel = 'Versículos $fromVerse a $toVerse';
    }

    return GestureDetector(
      onLongPress: () => _showBlockContextMenu(meta, block, verseLabel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Divisor elegante de versículos (não caixas cinzas!)
          if (!isFirst || _currentChapter > 0) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: _accentGold.withValues(alpha: 0.25),
                      thickness: 0.8,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _cardBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _accentGold.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      verseLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _accentGold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: _accentGold.withValues(alpha: 0.25),
                      thickness: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Renderização Rica do HTML do Comentário
          Html(
            data: _cleanAndFormat(block.text),
            extensions: [
              ImageExtension(
                builder: (extensionContext) {
                  final src = extensionContext.attributes['src'];
                  if (src != null) {
                    if (src.startsWith('http')) {
                      return Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(src),
                        ),
                      );
                    } else if (src.startsWith('data:image')) {
                      final base64String = src.split(',').last;
                      try {
                        return Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(base64Decode(base64String)),
                          ),
                        );
                      } catch (_) {
                        return Icon(Icons.broken_image, color: _mutedColor);
                      }
                    } else {
                      return FutureBuilder<Uint8List?>(
                        future: ref
                            .read(bibleServiceProvider)
                            .getCommentaryImage(meta.filename, src),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (snapshot.hasData && snapshot.data != null) {
                            return Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: _isDarkTheme ? 0.4 : 0.15,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(snapshot.data!),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            onLinkTap: (url, _, __) {
              if (url != null) _handleReferenceTap(url);
            },
            style: {
              'body': Style(
                fontSize: FontSize(_fontSize),
                color: _textColor,
                fontFamily: GoogleFonts.lora().fontFamily,
                lineHeight: LineHeight.em(1.85),
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
              'strong': Style(
                color: _accentGold,
                fontWeight: FontWeight.bold,
              ),
              'b': Style(
                color: _textColor,
                fontWeight: FontWeight.bold,
              ),
              'em': Style(
                fontStyle: FontStyle.italic,
                color: _textColor.withValues(alpha: 0.85),
              ),
              'a': Style(
                color: const Color(0xFF60A5FA),
                textDecoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
              'p': Style(
                margin: Margins.only(bottom: 12),
              ),
              'h1': Style(
                color: _textColor,
                fontWeight: FontWeight.w900,
                fontSize: FontSize(_fontSize * 1.3),
                margin: Margins.symmetric(vertical: 10),
              ),
              'h2': Style(
                color: _textColor,
                fontWeight: FontWeight.bold,
                fontSize: FontSize(_fontSize * 1.2),
                margin: Margins.symmetric(vertical: 8),
              ),
              'h3': Style(
                color: _accentGold,
                fontWeight: FontWeight.bold,
                fontSize: FontSize(_fontSize * 1.1),
                margin: Margins.symmetric(vertical: 6),
              ),
            },
          ),
        ],
      ),
    );
  }

  // ─── BARRA INFERIOR DE NAVEGAÇÃO ESTILO E-BOOK ─────────────────────────────
  Widget _buildBottomReaderBar(
    CommentaryMetadata meta,
    int bookId,
    AsyncValue<List<Map<String, dynamic>>> chaptersDetailAsync,
  ) {
    return chaptersDetailAsync.when(
      data: (chapters) {
        int? prevChapter;
        int? nextChapter;
        String currentLabel = '$_currentChapter';

        if (chapters.isNotEmpty) {
          final sortedChapters = chapters
              .map((e) => e['chapter'] as int)
              .toList()
            ..sort();
          final currentIndex = sortedChapters.indexOf(_currentChapter);

          if (currentIndex != -1) {
            if (currentIndex > 0) {
              prevChapter = sortedChapters[currentIndex - 1];
            }
            if (currentIndex < sortedChapters.length - 1) {
              nextChapter = sortedChapters[currentIndex + 1];
            }

            final currentBlock =
                chapters.firstWhere((e) => e['chapter'] == _currentChapter);
            if (currentBlock['marker'] != null) {
              currentLabel = currentBlock['marker'];
            } else if (_currentChapter == 0) {
              currentLabel = 'Introdução';
            } else {
              currentLabel = 'Capítulo $_currentChapter';
            }
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _cardBgColor,
            border: Border(
              top: BorderSide(
                color: _isDarkTheme
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Row(
            children: [
              // Botão Capítulo Anterior
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: prevChapter != null
                      ? _textColor
                      : _textColor.withValues(alpha: 0.25),
                  size: 20,
                ),
                onPressed: prevChapter != null
                    ? () => _goToChapter(prevChapter!)
                    : null,
                tooltip: 'Capítulo anterior',
              ),

              // Indicador Central e Seletor Rápido de Capítulo
              Expanded(
                child: GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _pageBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isDarkTheme
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            currentLabel,
                            style: GoogleFonts.outfit(
                              color: _textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 16,
                          color: _accentGold,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Botão Próximo Capítulo
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: nextChapter != null
                      ? _textColor
                      : _textColor.withValues(alpha: 0.25),
                  size: 20,
                ),
                onPressed: nextChapter != null
                    ? () => _goToChapter(nextChapter!)
                    : null,
                tooltip: 'Próximo capítulo',
              ),

              // Marcador (Bookmark)
              IconButton(
                icon: Icon(Icons.bookmark_add_outlined, color: _textColor),
                onPressed: _saveBookmark,
                tooltip: 'Salvar marcador',
              ),

              // Trocar de Comentário
              IconButton(
                icon: Icon(Icons.swap_horiz_rounded, color: _accentGold),
                onPressed: () => _showCommentarySelector(meta, bookId),
                tooltip: 'Mudar comentário',
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── GAVETA DE ÍNDICE DE CAPÍTULOS (ESTILO ÍNDICE DO E-BOOK) ───────────────
  Widget _buildChapterIndexDrawer(CommentaryMetadata meta, int bookId) {
    final chaptersDetailAsync = ref.watch(commentedChaptersDetailProvider((
      filename: meta.filename,
      bookId: bookId,
    )));

    return Drawer(
      backgroundColor: _cardBgColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Icon(Icons.auto_stories_rounded, color: _accentGold, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Índice de Capítulos',
                          style: GoogleFonts.outfit(
                            color: _textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currentBook.name,
                          style: GoogleFonts.outfit(
                            color: _mutedColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: _mutedColor.withValues(alpha: 0.15), height: 1),
            Expanded(
              child: chaptersDetailAsync.when(
                data: (chapters) {
                  if (chapters.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhum capítulo encontrado.',
                        style: TextStyle(color: _mutedColor),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final item = chapters[index];
                      final ch = item['chapter'] as int;
                      final marker = item['marker'] as String?;
                      final isSelected = ch == _currentChapter;

                      final label = marker ??
                          (ch == 0 ? 'Introdução / Capa' : 'Capítulo $ch');

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: _accentGold.withValues(alpha: 0.12),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _accentGold
                                : _pageBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              ch == 0 ? 'I' : '$ch',
                              style: GoogleFonts.outfit(
                                color: isSelected ? Colors.black : _textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          label,
                          style: GoogleFonts.outfit(
                            color: isSelected ? _accentGold : _textColor,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context); // Fecha Drawer
                          if (ch != _currentChapter) {
                            _goToChapter(ch);
                          }
                        },
                      );
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: _accentGold),
                ),
                error: (e, _) => Center(child: Text('Erro: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DIÁLOGOS DE CONFIGURAÇÃO (FONTE E TEMAS) ──────────────────────────────
  void _showFontSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tamanho da Fonte',
                    style: GoogleFonts.outfit(
                      color: _textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'A',
                        style: TextStyle(
                          fontSize: 14,
                          color: _textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 12.0,
                          max: 32.0,
                          divisions: 10,
                          activeColor: _accentGold,
                          inactiveColor: _mutedColor.withValues(alpha: 0.3),
                          onChanged: (val) {
                            setModalState(() => _fontSize = val);
                            _setFontSize(val);
                          },
                        ),
                      ),
                      Text(
                        'A',
                        style: TextStyle(
                          fontSize: 24,
                          color: _textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: Text(
                      '${_fontSize.toInt()} pt',
                      style: GoogleFonts.outfit(
                        color: _mutedColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showThemeSelectorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cor da Página',
                style: GoogleFonts.outfit(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _themeOptionButton(0, 'Claro', const Color(0xFFFDFDFD),
                      const Color(0xFF1A1A1A)),
                  _themeOptionButton(1, 'Sépia', const Color(0xFFFBF0D9),
                      const Color(0xFF4A3525)),
                  _themeOptionButton(2, 'Escuro', const Color(0xFF0F0F1A),
                      const Color(0xFFE2E8F0)),
                  _themeOptionButton(3, 'AMOLED', const Color(0xFF000000),
                      const Color(0xFFEDEDED)),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _themeOptionButton(
      int mode, String name, Color bg, Color fg) {
    final isSelected = _currentTheme == mode;
    return GestureDetector(
      onTap: () {
        _setTheme(mode);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _accentGold : Colors.white12,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Aa',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: GoogleFonts.outfit(
              color: isSelected ? _accentGold : _mutedColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockContextMenu(
    CommentaryMetadata meta,
    ({int fromVerse, int toVerse, String text}) block,
    String label,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _mutedColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    '${_currentBook.name} $_currentChapter ($label)',
                    style: GoogleFonts.outfit(
                      color: _textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Colors.blueAccent),
                  title: Text('Copiar trecho', style: TextStyle(color: _textColor)),
                  onTap: () {
                    Navigator.pop(ctx);
                    final cleanText = _stripHtml(block.text);
                    Clipboard.setData(ClipboardData(text: cleanText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Trecho copiado!', style: GoogleFonts.outfit()),
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF065F46),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.note_add_rounded, color: _accentGold),
                  title: Text('Adicionar à anotação', style: TextStyle(color: _textColor)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _createNewNoteAndGo(
                      context,
                      block.text,
                      block.fromVerse,
                      block.toVerse,
                      meta.id,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.volume_up_rounded, color: Colors.greenAccent),
                  title: Text('Ouvir este trecho', style: TextStyle(color: _textColor)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleTts([block]);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── HELPERS E TRATAMENTOS DE TEXTO ────────────────────────────────────────
  String _cleanAndFormat(String text) {
    String cleaned =
        text.replaceAll(RegExp(r'^[=\-*_]{3,}\s*$', multiLine: true), '');
    final refRegex = RegExp(
        r'\b(([123]\s)?[A-ZÀ-Ÿ][a-zà-ÿ]{1,12})\s(\d+)([\.:](​\d+))?\b');
    cleaned = cleaned.replaceAllMapped(refRegex, (m) {
      final full = m.group(0)!;
      if (text.contains('href="') && text.contains(full)) return full;
      return '<a href="bref:$full">$full</a>';
    });
    cleaned = cleaned.trim().replaceAll(RegExp(r'\n{2,}'), '<br><br>');
    cleaned = cleaned.replaceAll('\n', '<br>');
    return cleaned;
  }

  String _stripHtml(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').replaceAll('&nbsp;', ' ').trim();
  }

  Widget _buildEmpty(String commentaryName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_rounded,
            color: _mutedColor.withValues(alpha: 0.3),
            size: 72,
          ),
          const SizedBox(height: 20),
          Text(
            'Sem comentários neste capítulo',
            style: GoogleFonts.outfit(
              color: _mutedColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            commentaryName,
            style: GoogleFonts.outfit(
              color: _mutedColor.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _showCommentarySelector(
              ref.read(selectedCommentaryVersionProvider) ??
                  widget.initialMetadata,
              BibleMetadata.findBookId(_currentBook.abbrev),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Mudar comentário'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accentGold,
              side: BorderSide(color: _accentGold, width: 1),
            ),
          ),
        ],
      ),
    );
  }

  void _createNewNoteAndGo(
    BuildContext context,
    String cleanText,
    int fromVerse,
    int toVerse,
    String versionId,
  ) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final verseLabel =
        fromVerse == toVerse ? '$fromVerse' : '$fromVerse-$toVerse';
    final newNote = NoteCard(
      id: newId,
      title:
          'Comentário em ${_currentBook.name} $_currentChapter:$verseLabel',
      body: '',
      isAiGenerated: false,
      isPublic: false,
      isCollapsed: false,
      verses: [
        LinkedVerse(
          bookAbbrev: '',
          bookName: _currentBook.name,
          chapter: _currentChapter,
          verse: fromVerse,
          text: '',
          version: versionId,
        )
      ],
      commentaryKeys: [cleanText],
      lexicalTerms: [],
      tags: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    ref.read(noteCardsProvider.notifier).save(newNote);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteDetailScreen(note: newNote),
      ),
    );
  }

  void _handleReferenceTap(String url) {
    try {
      if (url.startsWith('#b')) {
        final match = RegExp(r'^#b(\d+)\.(\d+)\.(\d+)').firstMatch(url);
        if (match != null) {
          final bookId = int.tryParse(match.group(1)!) ?? 1;
          final chapter = int.tryParse(match.group(2)!) ?? 1;
          final verse = int.tryParse(match.group(3)!) ?? 1;
          ref.read(booksProvider).whenData((books) {
            final book = books.firstWhere(
              (b) => b.id == bookId,
              orElse: () => books.first,
            );
            _showReferencePreview(book, chapter, verse);
          });
          return;
        }
      }

      final cleanUrl = url
          .replaceAll('bref:', '')
          .replaceAll('mysword:', '')
          .replaceAll('?', '');
      final mainRegex = RegExp(
          r'^((?:[123]\s)?[A-ZÀ-Ÿa-zà-ÿ\s\.]+?)[\s\.](\d+)(?:[\.:](​\d+))?');
      final match = mainRegex.firstMatch(cleanUrl.trim());
      if (match != null) {
        final bookAbbrev = match.group(1)?.trim();
        final chapter = int.tryParse(match.group(2) ?? '1') ?? 1;
        final verse = int.tryParse(match.group(3) ?? '1') ?? 1;
        final bookId = BibleMetadata.findBookId(bookAbbrev ?? '');
        ref.read(booksProvider).whenData((books) {
          final book = books.firstWhere(
            (b) => b.id == bookId,
            orElse: () => books.first,
          );
          _showReferencePreview(book, chapter, verse);
        });
      }
    } catch (e) {
      debugPrint('Erro ao processar referência: $e');
    }
  }

  void _showReferencePreview(BibleBook book, int chapter, int verse) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      backgroundColor: _cardBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReferencePreviewSheet(
        book: book,
        chapter: chapter,
        initialVerse: verse,
      ),
    );
  }

  void _showCommentarySelector(CommentaryMetadata current, int bookId) {
    final all = ref.read(availableCommentariesProvider((
      abbrev: _currentBook.abbrev,
      bookId: BibleMetadata.findBookId(_currentBook.abbrev),
      bookName: _currentBook.name,
    )));
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.15),
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
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.38),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.07),
                height: 1,
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final selectedId =
                        ref.watch(selectedCommentaryVersionProvider)?.id ??
                            current.id;

                    final Map<String, List<CommentaryMetadata>> grouped = {};
                    for (final cm in all) {
                      final isEstudo =
                          cm.category == CommentaryCategory.estudo;
                      final isGeral =
                          cm.category == CommentaryCategory.geral;
                      final defaultCat = isEstudo
                          ? 'Bíblias de Estudo'
                          : isGeral
                              ? 'Comentários Gerais'
                              : 'Comentários Específicos';
                      final groupName = cm.storeCategoryName ?? defaultCat;
                      grouped.putIfAbsent(groupName, () => []).add(cm);
                    }

                    final groupKeys = grouped.keys.toList()..sort();

                    return ListView.builder(
                      controller: sc,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: groupKeys.length,
                      itemBuilder: (_, i) {
                        final groupName = groupKeys[i];
                        final items = grouped[groupName]!;

                        return Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            title: Text(
                              groupName,
                              style: GoogleFonts.outfit(
                                color:
                                    Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            iconColor: Theme.of(context).colorScheme.primary,
                            collapsedIconColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.54),
                            childrenPadding:
                                const EdgeInsets.only(bottom: 12),
                            children: items.map((cm) {
                              final isSelected = cm.id == selectedId;
                              final isEstudo =
                                  cm.category == CommentaryCategory.estudo;
                              final isGeral =
                                  cm.category == CommentaryCategory.geral;
                              final badgeText = isEstudo
                                  ? 'Estudo'
                                  : isGeral
                                      ? 'Geral'
                                      : 'Específico';
                              final badgeColor = isEstudo
                                  ? const Color(0xFF34D399)
                                  : isGeral
                                      ? const Color(0xFF60A5FA)
                                      : Theme.of(context)
                                          .colorScheme
                                          .primary;

                              return GestureDetector(
                                onTap: () async {
                                  Navigator.pop(ctx);

                                  // Verifica se o novo comentário possui o livro atual
                                  final allowedBooks = await ref.read(
                                    commentedBooksProvider(cm.filename).future,
                                  );

                                  if (allowedBooks.isNotEmpty &&
                                      !allowedBooks
                                          .contains(_currentBook.id)) {
                                    final firstAllowed = allowedBooks.first;
                                    final newBookDetails =
                                        BibleMetadata.bookDetails[firstAllowed];

                                    if (newBookDetails != null) {
                                      final bookObj = BibleBook(
                                        id: firstAllowed,
                                        abbrev: newBookDetails['abbrev'],
                                        name: BibleMetadata
                                            .bookNames[firstAllowed]!,
                                        chapters:
                                            newBookDetails['chapters'],
                                        author: newBookDetails['author'] ??
                                            'Desconhecido',
                                        group: newBookDetails['group'] ??
                                            'Antigo Testamento',
                                      );

                                      final chapters = await ref.read(
                                        commentedChaptersDetailProvider((
                                          filename: cm.filename,
                                          bookId: firstAllowed,
                                        )).future,
                                      );
                                      int firstChapter = 1;
                                      if (chapters.isNotEmpty) {
                                        final sorted = chapters
                                            .map((e) => e['chapter'] as int)
                                            .toList()
                                          ..sort();
                                        firstChapter = sorted.first;
                                      }

                                      setState(() {
                                        _currentBook = bookObj;
                                        _currentChapter = firstChapter;
                                      });
                                    }
                                  } else if (allowedBooks.isNotEmpty) {
                                    final chapters = await ref.read(
                                      commentedChaptersDetailProvider((
                                        filename: cm.filename,
                                        bookId: _currentBook.id ?? 1,
                                      )).future,
                                    );
                                    if (chapters.isNotEmpty) {
                                      final sorted = chapters
                                          .map((e) => e['chapter'] as int)
                                          .toList()
                                        ..sort();
                                      if (!sorted.contains(_currentChapter)) {
                                        setState(() {
                                          _currentChapter = sorted.first;
                                        });
                                      }
                                    }
                                  }

                                  ref
                                      .read(
                                        selectedCommentaryVersionProvider
                                            .notifier,
                                      )
                                      .state = cm;
                                  _saveState();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(
                                    bottom: 10,
                                    left: 4,
                                    right: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.08)
                                        : Theme.of(context)
                                            .colorScheme
                                            .surfaceContainer,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.4)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.06),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: badgeColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: badgeColor
                                                .withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.library_books_rounded,
                                          color: badgeColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cm.name,
                                              style: GoogleFonts.outfit(
                                                color: isSelected
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                          alpha: 0.7,
                                                        ),
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: badgeColor
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                badgeText,
                                                style: TextStyle(
                                                  color: badgeColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
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
}

// ═══════════════════════════════════════════════════════════════════════════
// Reference Preview Sheet
// ═══════════════════════════════════════════════════════════════════════════
class _ReferencePreviewSheet extends ConsumerStatefulWidget {
  final BibleBook book;
  final int chapter;
  final int initialVerse;

  const _ReferencePreviewSheet({
    required this.book,
    required this.chapter,
    required this.initialVerse,
  });

  @override
  ConsumerState<_ReferencePreviewSheet> createState() =>
      _ReferencePreviewSheetState();
}

class _ReferencePreviewSheetState extends ConsumerState<_ReferencePreviewSheet> {
  final _scrollController = ScrollController();
  final _targetKey = GlobalKey();
  late BibleBook _book;
  late int _chapter;
  late int _verse;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _chapter = widget.chapter;
    _verse = widget.initialVerse;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToVerse() async {
    if (!mounted || !_scrollController.hasClients) return;
    if (_verse > 1) {
      _scrollController.jumpTo(
        ((_verse - 1) * 80.0)
            .clamp(0, _scrollController.position.maxScrollExtent),
      );
    }
    await Future.delayed(const Duration(milliseconds: 200));
    if (_targetKey.currentContext != null) {
      Scrollable.ensureVisible(
        _targetKey.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(selectedVersionProvider);
    final chapterAsync = ref.watch(currentChapterProvider((
      abbrev: _book.abbrev,
      chapter: _chapter,
      version: version,
    )));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_book.name} $_chapter',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReadingScreen(
                          book: _book,
                          initialChapter: _chapter,
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.open_in_full_rounded,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.54),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.07),
            height: 1,
          ),
          Expanded(
            child: chapterAsync.when(
              data: (bibleChapter) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToVerse());
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  itemCount: bibleChapter.verses.length,
                  itemBuilder: (_, i) {
                    final v = bibleChapter.verses[i];
                    final isTarget = v.number == _verse;
                    return AnimatedContainer(
                      key: isTarget ? _targetKey : null,
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isTarget
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isTarget
                            ? Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.25),
                              )
                            : null,
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: CustomFontLoader.loadedFontFamilies.contains(
                            ref.watch(fontSettingsProvider).fontFamily,
                          )
                              ? TextStyle(
                                  fontFamily: ref
                                      .watch(fontSettingsProvider)
                                      .fontFamily,
                                  fontSize: ref
                                      .watch(fontSettingsProvider)
                                      .fontSize,
                                  color: isTarget
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.75),
                                  height: 1.8,
                                )
                              : GoogleFonts.getFont(
                                  ref.watch(fontSettingsProvider).fontFamily,
                                  fontSize: ref
                                      .watch(fontSettingsProvider)
                                      .fontSize,
                                  color: isTarget
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.75),
                                  height: 1.8,
                                ),
                          children: [
                            TextSpan(
                              text: '${v.number} ',
                              style: GoogleFonts.outfit(
                                color: isTarget
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.4),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            TextSpan(
                              text: v.text
                                  .replaceAll(RegExp(r'<[^>]+>'), '')
                                  .trim(),
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
                  strokeWidth: 2,
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Erro: $e',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.38),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
