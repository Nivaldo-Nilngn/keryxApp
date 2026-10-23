import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================
// PALETAS DE DESIGN DO LEITOR DE EBOOKS
// ==========================================
class ReaderTheme {
  final String name;
  final Color bg;           // Fundo da folha de leitura
  final Color surface;      // Topbar, Drawer, Menus
  final Color border;       // Divisores e bordas
  final Color text;         // Texto principal
  final Color muted;        // Texto secundário / legendas
  final Color accent;       // Dourado / destaque / marcador
  final Color badgeBg;      // Fundo das pílulas e números
  final Color selectedTile; // Item ativo no índice

  const ReaderTheme({
    required this.name,
    required this.bg,
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.badgeBg,
    required this.selectedTile,
  });
}

const List<ReaderTheme> _kReaderThemes = [
  // 0: Claro (Papel Nobre / Creme)
  ReaderTheme(
    name: 'Claro',
    bg: Color(0xFFFAF8F5),
    surface: Color(0xFFF3ECE1),
    border: Color(0xFFE4DAD0),
    text: Color(0xFF23201D),
    muted: Color(0xFF7E7569),
    accent: Color(0xFFB57C1E),
    badgeBg: Color(0xFFEBE0D2),
    selectedTile: Color(0x33B57C1E),
  ),
  // 1: Sépia (Pergaminho Antigo)
  ReaderTheme(
    name: 'Sépia',
    bg: Color(0xFFF4ECD8),
    surface: Color(0xFFEDE0C4),
    border: Color(0xFFDFCFAF),
    text: Color(0xFF3F301D),
    muted: Color(0xFF827056),
    accent: Color(0xFFA66A18),
    badgeBg: Color(0xFFE5D5B3),
    selectedTile: Color(0x40A66A18),
  ),
  // 2: Escuro (Obsidiana Noturna)
  ReaderTheme(
    name: 'Escuro',
    bg: Color(0xFF121217),
    surface: Color(0xFF1B1B24),
    border: Color(0xFF2C2C3A),
    text: Color(0xFFE4E4EB),
    muted: Color(0xFF8B8B9E),
    accent: Color(0xFFE5B842),
    badgeBg: Color(0xFF242434),
    selectedTile: Color(0x22E5B842),
  ),
];

// ==========================================
// MODELO DE ITEM / SEÇÃO DO LIVRO
// ==========================================
class BookSectionItem {
  final int id;
  final String rawTitle;
  final String badge;
  final String title;
  final String subtitle;
  final String htmlContent;
  final bool isTopic;
  final bool isCover;

  BookSectionItem({
    required this.id,
    required this.rawTitle,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.htmlContent,
    this.isTopic = false,
    this.isCover = false,
  });
}

// ==========================================
// TELA PRINCIPAL DO LEITOR
// ==========================================
class HtmlBookReaderScreen extends StatefulWidget {
  final StoreItem book;
  const HtmlBookReaderScreen({super.key, required this.book});

  @override
  State<HtmlBookReaderScreen> createState() => _HtmlBookReaderScreenState();
}

class _HtmlBookReaderScreenState extends State<HtmlBookReaderScreen> {
  bool _isLoadingBook = true;
  Database? _db;
  List<BookSectionItem> _items = [];
  int _currentVisibleIndex = 0;
  final ValueNotifier<int> _currentVisibleIndexNotifier = ValueNotifier<int>(0);
  Timer? _bookmarkDebounceTimer;
  static final String? _loraFontFamily = GoogleFonts.lora().fontFamily;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  // TTS
  late FlutterTts _flutterTts;
  bool _isPlaying = false;
  double _ttsSpeechRate = 0.5;
  final double _ttsPitch = 1.0;
  List<Map<String, String>> _voices = [];
  Map<String, String>? _currentVoice;

  // Customização Visual
  int _themeIndex = 0; // 0: Claro, 1: Sépia, 2: Escuro
  double _baseFontSize = 18.0;
  double _tempScale = 1.0;

  ReaderTheme get _theme => _kReaderThemes[_themeIndex];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initTts();
    _loadPreferences();
    _loadBook();

    _itemPositionsListener.itemPositions.addListener(_onScrollChanged);
  }

  void _onScrollChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty && mounted) {
      // Pega o item mais visível no topo
      final visible = positions
          .where((pos) => pos.itemTrailingEdge > 0)
          .reduce((a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b);

      if (visible.index != _currentVisibleIndex && visible.index >= 0 && visible.index < _items.length) {
        _currentVisibleIndex = visible.index;
        _currentVisibleIndexNotifier.value = visible.index;
        _debounceSaveBookmark(visible.index);
      }
    }
  }

  void _debounceSaveBookmark(int index) {
    _bookmarkDebounceTimer?.cancel();
    _bookmarkDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _saveBookmarkSilently(index);
    });
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("pt-BR");
    _flutterTts.setSpeechRate(_ttsSpeechRate);
    _flutterTts.setPitch(_ttsPitch);

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        if (_isPlaying && _currentVisibleIndex + 1 < _items.length) {
          final nextIdx = _currentVisibleIndex + 1;
          _itemScrollController.scrollTo(
            index: nextIdx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          _speakIndex(nextIdx);
        } else {
          setState(() => _isPlaying = false);
        }
      }
    });

    try {
      final voices = await _flutterTts.getVoices;
      if (voices != null) {
        List<Map<String, String>> parsedVoices = [];
        for (var v in voices) {
          if (v is Map) {
            final locale = v['locale']?.toString() ?? '';
            if (locale.startsWith('pt')) {
              parsedVoices.add({
                'name': v['name']?.toString() ?? '',
                'locale': locale,
              });
            }
          }
        }
        if (mounted && parsedVoices.isNotEmpty) {
          setState(() {
            _voices = parsedVoices;
            _currentVoice = _voices.first;
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar vozes TTS: $e");
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _themeIndex = prefs.getInt('reader_theme') ?? 0;
        _baseFontSize = prefs.getDouble('reader_font_size') ?? 18.0;
      });
    } catch (_) {}
  }

  Future<void> _saveBookmarkSilently(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bkm_${widget.book.name}', jsonEncode({'index': index}));

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final bookKey = widget.book.filename.replaceAll('/', '_').replaceAll('.', '_');
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'book_progress': {
            bookKey: {
              'bookName': widget.book.name,
              'filename': widget.book.filename,
              'index': index,
              'updatedAt': FieldValue.serverTimestamp(),
            }
          }
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _bookmarkDebounceTimer?.cancel();
    _currentVisibleIndexNotifier.dispose();
    _itemPositionsListener.itemPositions.removeListener(_onScrollChanged);
    _db?.close();
    _flutterTts.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ==========================================
  // CARREGAMENTO DO BANCO DE DADOS DO LIVRO
  // ==========================================
  Future<void> _loadBook() async {
    try {
      final filename = widget.book.filename.split('/').last;

      if (kIsWeb) {
        final factory = databaseFactoryFfiWeb;
        final dbPath = await factory.getDatabasesPath();
        final candidates = [
          p.join(dbPath, filename),
          p.join(dbPath, widget.book.filename),
          p.join(dbPath, 'books', filename),
          p.join(dbPath, 'books', widget.book.filename),
          filename,
          widget.book.filename,
        ];

        String? foundPath;
        for (final cand in candidates) {
          try {
            if (await factory.databaseExists(cand)) {
              foundPath = cand;
              break;
            }
          } catch (_) {}
        }

        if (foundPath != null) {
          _db = await factory.openDatabase(
            foundPath,
            options: OpenDatabaseOptions(readOnly: true),
          );
        } else {
          debugPrint("❌ Livro não encontrado no IndexedDB: $filename (candidatos: $candidates)");
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final possiblePaths = [
          p.join(dir.path, 'store', 'books', filename),
          p.join(dir.path, 'store', widget.book.filename),
          p.join(dir.path, 'store', filename),
        ];

        String? foundPath;
        for (final cand in possiblePaths) {
          if (await File(cand).exists()) {
            foundPath = cand;
            break;
          }
        }

        if (foundPath != null) {
          _db = await openDatabase(foundPath, readOnly: true);
        } else {
          debugPrint("❌ Livro não encontrado no sistema de arquivos: $filename");
        }
      }

      if (_db != null) {
        final tablesRes = await _db!.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final tables = tablesRes.map((e) => e['name'].toString().toLowerCase()).toList();

        List<Map<String, dynamic>> res = [];
        if (tables.contains('journal')) {
          try {
            res = await _db!.rawQuery("SELECT rowid as id, title, content FROM journal ORDER BY rowid ASC");
          } catch (_) {
            res = await _db!.query('journal', columns: ['id', 'title', 'content']);
          }
        } else if (tables.contains('stories')) {
          try {
            res = await _db!.rawQuery("SELECT id, title, text as content FROM stories ORDER BY ordering ASC, id ASC");
          } catch (_) {
            res = await _db!.rawQuery("SELECT id, title, text as content FROM stories ORDER BY id ASC");
          }
        } else if (tables.contains('book')) {
          res = await _db!.rawQuery("SELECT id, title, text as content FROM book ORDER BY id ASC");
        } else if (tables.contains('commentary')) {
          res = await _db!.rawQuery("SELECT id, ('Capítulo ' || chapter || ' Versículo ' || fromverse) as title, data as content FROM commentary ORDER BY id ASC");
        } else if (tables.contains('dictionary')) {
          try {
            res = await _db!.rawQuery("SELECT rowid as id, word as title, data as content FROM dictionary ORDER BY rowid ASC");
          } catch (_) {
            try {
              res = await _db!.rawQuery("SELECT relativeorder as id, word as title, data as content FROM dictionary ORDER BY relativeorder ASC");
            } catch (_) {
              res = await _db!.rawQuery("SELECT rowid as id, topic as title, definition as content FROM dictionary ORDER BY rowid ASC");
            }
          }
        }

        final isBookTeses = widget.book.name.toLowerCase().contains('tese') ||
                            widget.book.name.toLowerCase().contains('95 teses');

        List<BookSectionItem> parsedItems = [];
        for (int i = 0; i < res.length; i++) {
          final row = res[i];
          final rawId = row['id'] is int ? row['id'] as int : (i + 1);
          final rawTitle = row['title']?.toString() ?? '';
          final rawContent = row['content']?.toString() ?? '';

          final (badge, title, isCover, isTopic) = _parseTitleAndBadge(
            rawId,
            rawTitle,
            isBookTeses,
            res.length,
          );

          final subtitle = _cleanHtmlToPlainText(rawContent);
          final bodyHtml = _cleanHtmlBody(rawContent, isTopic);

          parsedItems.add(BookSectionItem(
            id: rawId,
            rawTitle: rawTitle,
            badge: badge,
            title: title,
            subtitle: subtitle,
            htmlContent: bodyHtml,
            isTopic: isTopic,
            isCover: isCover,
          ));
        }

        _items = parsedItems;
      }
    } catch (e) {
      debugPrint("Erro ao carregar livro: $e");
    }

    if (mounted) {
      setState(() => _isLoadingBook = false);

      // Restaura marcador anterior (Local + Nuvem)
      if (_items.isNotEmpty) {
        try {
          int savedIdx = -1;
          final prefs = await SharedPreferences.getInstance();
          final bkm = prefs.getString('bkm_${widget.book.name}');
          if (bkm != null) {
            final map = jsonDecode(bkm);
            savedIdx = map['index'] ?? -1;
          }

          // Se o usuário está logado, verifica progresso salvo na nuvem
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            try {
              final bookKey = widget.book.filename.replaceAll('/', '_').replaceAll('.', '_');
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
              final cloudProgress = userDoc.data()?['book_progress']?[bookKey]?['index'];
              if (cloudProgress is int && cloudProgress >= 0 && cloudProgress < _items.length) {
                if (savedIdx == -1 || cloudProgress > savedIdx) {
                  savedIdx = cloudProgress;
                  await prefs.setString('bkm_${widget.book.name}', jsonEncode({'index': savedIdx}));
                }
              }
            } catch (_) {}
          }

          if (savedIdx >= 0 && savedIdx < _items.length) {
            _currentVisibleIndex = savedIdx;
            _currentVisibleIndexNotifier.value = savedIdx;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _itemScrollController.jumpTo(index: savedIdx);
              }
            });
          }
        } catch (_) {}
      }
    }
  }

  // ==========================================
  // PARSERS E SANITIZADORES DE TÍTULOS
  // ==========================================
  (String badge, String title, bool isCover, bool isTopic) _parseTitleAndBadge(
    int rawId,
    String rawTitle,
    bool isBookTeses,
    int totalCount,
  ) {
    final t = rawTitle.trim();
    final upper = t.toUpperCase();

    // Capa
    if (upper == 'CAPA' || upper == '_01_CAPA' || upper == '001_CAPA' || (rawId == 1 && totalCount > 5 && upper.contains('CAPA'))) {
      return ('★', 'Capa', true, false);
    }

    // Livros de Teses (como as 95 Teses)
    if (isBookTeses) {
      final mNum = RegExp(r'^_?0*(\d+)[\._\)\s\-–—:]+\s*(.*)').firstMatch(t);
      if (mNum != null) {
        final num = mNum.group(1)!;
        return (num, 'Tese $num', false, true);
      }
      if (rawId > 1) {
        final num = '${rawId - 1}';
        return (num, 'Tese $num', false, true);
      }
    }

    // Capítulos em Numerais Romanos: "I - O Contexto", "II. O Contexto", "III: O Contexto"
    final mRoman = RegExp(r'^([IVXLCDM]+)\s*[\-–—\.:]\s*(.*)', caseSensitive: false).firstMatch(t);
    if (mRoman != null) {
      final badge = mRoman.group(1)!.toUpperCase();
      final title = mRoman.group(2)!.trim();
      return (badge, title.isNotEmpty ? title : 'Capítulo $badge', false, false);
    }

    // Introdução / Prefácio
    final lower = t.toLowerCase();
    if (lower.startsWith('intro')) {
      return ('Intro', t, false, false);
    }
    if (lower.startsWith('pref')) {
      return ('Pref', t, false, false);
    }

    // Partes do Livro: "PARTE UM - UMA TERRA E SEU POVO", "PARTE I"
    if (upper.contains('PARTE')) {
      final mPart = RegExp(r'PARTE\s+([A-Z0-9]+)\s*[\-–—:]?\s*(.*)', caseSensitive: false).firstMatch(t);
      if (mPart != null) {
        final partNum = mPart.group(1)!.toUpperCase();
        final rest = mPart.group(2)!.trim();
        return ('P.$partNum', rest.isNotEmpty ? rest : t, false, false);
      }
    }

    // Capítulos numerados gerais: "01 Estados modernos...", "1) A Bênção...", "1. CHUVAS DE GRAÇA"
    final mNum = RegExp(r'^_?0*(\d+)[\._\)\s\-–—:]+\s*(.*)').firstMatch(t);
    if (mNum != null) {
      final num = mNum.group(1)!;
      final rest = mNum.group(2)!.trim();
      final isTopic = rest.length > 50 || totalCount > 40;
      return (num, rest.isNotEmpty ? rest : 'Capítulo $num', false, isTopic);
    }

    // Fallback padrão
    final isTopic = totalCount > 40;
    return ('$rawId', t, false, isTopic);
  }

  String _cleanHtmlToPlainText(String html) {
    if (html.isEmpty) return '';
    String t = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
    t = t.replaceAll(RegExp(r'[\s\xa0]+'), ' ').trim();
    t = t.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
    return t;
  }

  String _cleanHtmlBody(String html, bool isTopic) {
    if (html.isEmpty) return '';
    if (!isTopic) return html;
    // Se for tópico (como as 95 teses), remove o "1.    " que fica duplicado com o badge
    return html.replaceFirst(RegExp(r'<p>\s*\d+[\.\)]\s*(?:&nbsp;|\s|\xa0)*', caseSensitive: false), '<p>');
  }

  // ==========================================
  // BUSCA DE IMAGENS EMBUTIDAS NO BANCO
  // ==========================================
  Future<Uint8List?> _loadImageFromDb(String src) async {
    if (_db == null) return null;
    try {
      final res = await _db!.query('data', columns: ['content'], where: 'filename = ?', whereArgs: [src], limit: 1);
      if (res.isNotEmpty && res.first['content'] != null) {
        final content = res.first['content'];
        if (content is Uint8List) return content;
        if (content is List<int>) return Uint8List.fromList(content);
      }
    } catch (e) {
      debugPrint('Erro ao carregar imagem $src: $e');
    }
    return null;
  }

  // ==========================================
  // ÁUDIO (TEXT-TO-SPEECH)
  // ==========================================
  void _toggleTts() async {
    if (_isPlaying) {
      await _flutterTts.stop();
      setState(() => _isPlaying = false);
    } else {
      if (_items.isEmpty) return;
      _speakIndex(_currentVisibleIndex);
    }
  }

  void _speakIndex(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    final text = item.subtitle.isNotEmpty ? item.subtitle : item.title;
    if (text.trim().isNotEmpty) {
      await _flutterTts.speak(text.trim());
      if (mounted) setState(() => _isPlaying = true);
    }
  }

  // ==========================================
  // DIÁLOGO DE CONFIGURAÇÕES VISUAIS
  // ==========================================
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _theme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20, left: 24, right: 24,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Título do modal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Aparência e Leitura",
                          style: GoogleFonts.outfit(
                            color: _theme.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: _theme.muted),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Seleção de Tema
                    Text("Tema de Visualização", style: GoogleFonts.outfit(color: _theme.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(_kReaderThemes.length, (idx) {
                        final th = _kReaderThemes[idx];
                        final isSelected = _themeIndex == idx;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              setSheetState(() => _themeIndex = idx);
                              setState(() => _themeIndex = idx);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setInt('reader_theme', idx);
                            },
                            child: Container(
                              margin: EdgeInsets.only(right: idx < _kReaderThemes.length - 1 ? 10 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: th.bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? _theme.accent : th.border,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(color: _theme.accent.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))
                                ] : null,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    th.name,
                                    style: GoogleFonts.outfit(
                                      color: th.text,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 20),
                    Divider(color: _theme.border, height: 1),
                    const SizedBox(height: 16),

                    // Tamanho da Fonte
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Tamanho do Texto", style: GoogleFonts.outfit(color: _theme.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text("${_baseFontSize.toInt()} pt", style: GoogleFonts.outfit(color: _theme.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.text_decrease_rounded, color: _theme.text),
                          onPressed: () {
                            if (_baseFontSize > 13) {
                              setSheetState(() => _baseFontSize -= 1);
                              setState(() => _baseFontSize -= 1);
                              SharedPreferences.getInstance().then((p) => p.setDouble('reader_font_size', _baseFontSize));
                            }
                          },
                        ),
                        Expanded(
                          child: Slider(
                            value: _baseFontSize,
                            min: 13.0,
                            max: 36.0,
                            activeColor: _theme.accent,
                            inactiveColor: _theme.border,
                            onChanged: (val) {
                              setSheetState(() => _baseFontSize = val);
                              setState(() => _baseFontSize = val);
                            },
                            onChangeEnd: (val) async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setDouble('reader_font_size', val);
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.text_increase_rounded, color: _theme.text),
                          onPressed: () {
                            if (_baseFontSize < 36) {
                              setSheetState(() => _baseFontSize += 1);
                              setState(() => _baseFontSize += 1);
                              SharedPreferences.getInstance().then((p) => p.setDouble('reader_font_size', _baseFontSize));
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Divider(color: _theme.border, height: 1),
                    const SizedBox(height: 16),

                    // Velocidade TTS
                    Row(
                      children: [
                        Icon(Icons.speed_rounded, color: _theme.accent, size: 20),
                        const SizedBox(width: 10),
                        Text("Velocidade da Voz", style: GoogleFonts.outfit(color: _theme.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text("${_ttsSpeechRate.toStringAsFixed(1)}x", style: GoogleFonts.outfit(color: _theme.accent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _ttsSpeechRate,
                      min: 0.2,
                      max: 2.0,
                      activeColor: _theme.accent,
                      inactiveColor: _theme.border,
                      onChanged: (val) {
                        setSheetState(() => _ttsSpeechRate = val);
                        setState(() => _ttsSpeechRate = val);
                        _flutterTts.setSpeechRate(val);
                      },
                    ),
                    if (_voices.length > 1) ...[
                      const SizedBox(height: 12),
                      Text("Voz do Leitor", style: GoogleFonts.outfit(color: _theme.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: List.generate(_voices.length, (vIdx) {
                          final v = _voices[vIdx];
                          final isVSelected = _currentVoice?['name'] == v['name'];
                          return ChoiceChip(
                            label: Text("Voz ${vIdx + 1}", style: GoogleFonts.outfit(fontSize: 12)),
                            selected: isVSelected,
                            selectedColor: _theme.accent.withValues(alpha: 0.2),
                            side: BorderSide(color: isVSelected ? _theme.accent : _theme.border),
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() => _currentVoice = v);
                                setState(() => _currentVoice = v);
                                _flutterTts.setVoice({"name": v['name']!, "locale": v['locale']!});
                              }
                            },
                          );
                        }),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // HEADER DA TOPBAR
  // ==========================================
  String _getCurrentHeaderTitle([int? currentIndex]) {
    if (_items.isEmpty) return widget.book.name;
    final idx = (currentIndex ?? _currentVisibleIndex).clamp(0, _items.length - 1);
    final item = _items[idx];
    if (item.isCover) return 'Capa';
    if (item.isTopic) return item.title;
    return item.title;
  }

  // ==========================================
  // CONSTRUÇÃO DA TELA
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_isLoadingBook) {
      return Scaffold(
        backgroundColor: _theme.bg,
        body: Center(
          child: CircularProgressIndicator(color: _theme.accent),
        ),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        backgroundColor: _theme.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_rounded, color: _theme.muted, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    "Não foi possível abrir o livro.",
                    style: GoogleFonts.outfit(color: _theme.text, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "O formato do arquivo pode ser incompatível ou não contém capítulos legíveis.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: _theme.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _theme.surface,
                      foregroundColor: _theme.text,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Voltar à Biblioteca"),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _theme.bg,

      // ==========================================
      // DRAWER: ÍNDICE ELEGANTE DO LIVRO
      // ==========================================
      endDrawer: Drawer(
        backgroundColor: _theme.surface,
        width: MediaQuery.of(context).size.width * 0.82,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho do Drawer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _theme.badgeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.bookmark_rounded, color: _theme.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sumário do Livro',
                            style: GoogleFonts.outfit(
                              color: _theme.text,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_items.length} ${_items.first.isTopic ? 'tópicos' : 'seções'}',
                            style: GoogleFonts.outfit(
                              color: _theme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: _theme.muted),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
              ),
              Divider(color: _theme.border, height: 1),

              // Lista de Capítulos / Tópicos
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentVisibleIndexNotifier,
                  builder: (context, currentIdx, _) {
                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        final isSelected = (i == currentIdx);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          child: Material(
                            color: isSelected ? _theme.selectedTile : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: isSelected ? BorderSide(color: _theme.accent.withValues(alpha: 0.4), width: 1.2) : BorderSide.none,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              leading: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? _theme.accent : _theme.badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? _theme.accent : _theme.border,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  item.badge,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: isSelected ? (_themeIndex == 2 ? Colors.black : Colors.white) : _theme.text,
                                    fontSize: item.badge.length > 3 ? 10 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: isSelected ? _theme.accent : _theme.text,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: item.subtitle.isNotEmpty
                                  ? Text(
                                      item.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: _theme.muted,
                                        fontSize: 11,
                                      ),
                                    )
                                  : null,
                              trailing: isSelected
                                  ? Icon(Icons.circle, size: 8, color: _theme.accent)
                                  : null,
                              onTap: () {
                                Navigator.pop(context);
                                _currentVisibleIndex = i;
                                _currentVisibleIndexNotifier.value = i;
                                _itemScrollController.scrollTo(
                                  index: i,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                            ),
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

      // ==========================================
      // CORPO DO LEITOR DE EBOOKS
      // ==========================================
      body: SafeArea(
        child: Column(
          children: [
            // TOPBAR HARMONIZADA COM O TEMA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: _theme.surface,
                border: Border(bottom: BorderSide(color: _theme.border, width: 1)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: _theme.text),
                    onPressed: () {
                      _saveBookmarkSilently(_currentVisibleIndex);
                      Navigator.pop(context);
                    },
                    tooltip: 'Voltar',
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.book.name,
                          style: GoogleFonts.outfit(
                            color: _theme.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        ValueListenableBuilder<int>(
                          valueListenable: _currentVisibleIndexNotifier,
                          builder: (context, currentIdx, _) {
                            return Text(
                              _getCurrentHeaderTitle(currentIdx),
                              style: GoogleFonts.lora(
                                color: _theme.text,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Ação: Configurações de Leitura
                  IconButton(
                    icon: Icon(Icons.tune_rounded, color: _theme.text),
                    onPressed: _showSettings,
                    tooltip: 'Aparência',
                  ),
                  // Ação: Leitura em Voz Alta (TTS)
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                      color: _isPlaying ? Colors.redAccent : _theme.accent,
                    ),
                    onPressed: _toggleTts,
                    tooltip: _isPlaying ? 'Parar Áudio' : 'Ouvir Tópico',
                  ),
                  // Ação: Índice do Livro
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: Icon(Icons.menu_book_rounded, color: _theme.text),
                      onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                      tooltip: 'Índice de Tópicos',
                    ),
                  ),
                ],
              ),
            ),

            // SUPERFÍCIE DE LEITURA COM SCROLL CONTÍNUO
            Expanded(
              child: GestureDetector(
                onScaleStart: (_) => _tempScale = 1.0,
                onScaleUpdate: (details) {
                  if (details.pointerCount >= 2) {
                    final newSize = _baseFontSize * (details.scale / _tempScale);
                    if (newSize >= 13.0 && newSize <= 36.0) {
                      setState(() => _baseFontSize = newSize);
                      _tempScale = details.scale;
                    }
                  }
                },
                child: Container(
                  color: _theme.bg,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 760),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: ScrollablePositionedList.builder(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _items.length,
                        itemBuilder: (context, idx) {
                          final item = _items[idx];
                          return RepaintBoundary(
                            child: _buildReaderItem(item, idx),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // RENDERIZAÇÃO INDIVIDUAL DE CADA SEÇÃO/TÓPICO
  // ==========================================
  Widget _buildReaderItem(BookSectionItem item, int index) {
    if (item.isCover) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 36),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _theme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _theme.border),
        ),
        child: Column(
          children: [
            // Se contiver imagem na capa, o HTML vai renderizar
            _buildHtmlView(item.htmlContent),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _theme.badgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Livro Digital • Keryx Loja',
                style: GoogleFonts.outfit(
                  color: _theme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (item.isTopic) {
      // Formato para tópicos (ex: 95 Teses, verbetes)
      return Container(
        margin: const EdgeInsets.only(top: 24, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Badge refinado do tópico
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _theme.badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _theme.accent.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text(
                    item.title.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: _theme.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Divider(color: _theme.border, thickness: 1)),
              ],
            ),
            const SizedBox(height: 14),

            // Conteúdo do Tópico
            _buildHtmlView(item.htmlContent),

            const SizedBox(height: 16),
            Divider(color: _theme.border.withValues(alpha: 0.5), height: 1, thickness: 0.8),
          ],
        ),
      );
    }

    // Formato para Capítulos tradicionais (ex: I, II, III, Introdução)
    return Container(
      margin: const EdgeInsets.only(top: 36, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Editorial do Capítulo
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Divider(color: _theme.accent.withValues(alpha: 0.3), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        item.badge.length <= 4 ? 'CAPÍTULO ${item.badge}' : item.badge,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.2,
                          color: _theme.accent,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: _theme.accent.withValues(alpha: 0.3), thickness: 1)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lora(
                    fontSize: _baseFontSize + 6.0,
                    fontWeight: FontWeight.bold,
                    color: _theme.text,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 8),
                Icon(Icons.diamond_outlined, size: 12, color: _theme.accent.withValues(alpha: 0.6)),
              ],
            ),
          ),

          // Conteúdo do Capítulo
          _buildHtmlView(item.htmlContent),

          const SizedBox(height: 36),
          // Marcador de fim de capítulo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.diamond, size: 6, color: _theme.accent.withValues(alpha: 0.4)),
              const SizedBox(width: 10),
              Icon(Icons.diamond, size: 8, color: _theme.accent),
              const SizedBox(width: 10),
              Icon(Icons.diamond, size: 6, color: _theme.accent.withValues(alpha: 0.4)),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ==========================================
  // RENDERIZADOR HTML COM SUPORTE A IMAGENS
  // ==========================================
  Widget _buildHtmlView(String htmlData) {
    return Html(
      data: htmlData,
      onLinkTap: (url, attributes, element) {
        if (url != null && url.isNotEmpty) {
          final text = element?.text.trim() ?? url;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _theme.surface,
              content: Text(
                'Referência Bíblica: $text',
                style: GoogleFonts.outfit(color: _theme.text, fontWeight: FontWeight.bold),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      extensions: [
        TagExtension(
          tagsToExtend: {"img"},
          builder: (extensionContext) {
            final src = extensionContext.attributes['src'];
            if (src == null) return const SizedBox.shrink();

            if (src.startsWith('data:')) {
              try {
                final base64Str = src.split(',').last;
                return Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(base64Decode(base64Str), fit: BoxFit.contain),
                  ),
                );
              } catch (_) {
                return const SizedBox.shrink();
              }
            }

            return FutureBuilder<Uint8List?>(
              future: _loadImageFromDb(src),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                if (snapshot.hasData && snapshot.data != null) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ],
      style: {
        "body": Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: _theme.text,
          fontSize: FontSize(_baseFontSize),
          fontFamily: _loraFontFamily,
          lineHeight: const LineHeight(1.72),
        ),
        "p": Style(
          margin: Margins.only(bottom: 14),
          lineHeight: const LineHeight(1.72),
          color: _theme.text,
          fontSize: FontSize(_baseFontSize),
          fontFamily: _loraFontFamily,
        ),
        "h1": Style(
          color: _theme.text,
          fontSize: FontSize(_baseFontSize + 5.0),
          fontWeight: FontWeight.bold,
          margin: Margins.only(top: 18, bottom: 10),
        ),
        "h2": Style(
          color: _theme.text,
          fontSize: FontSize(_baseFontSize + 3.0),
          fontWeight: FontWeight.bold,
          margin: Margins.only(top: 16, bottom: 8),
        ),
        "h3": Style(
          color: _theme.text,
          fontSize: FontSize(_baseFontSize + 1.0),
          fontWeight: FontWeight.bold,
        ),
        "strong": Style(
          fontWeight: FontWeight.bold,
          color: _theme.text,
        ),
        "em": Style(
          fontStyle: FontStyle.italic,
          color: _theme.text,
        ),
        "a": Style(
          color: _theme.accent,
          textDecoration: TextDecoration.none,
          fontWeight: FontWeight.w600,
        ),
      },
    );
  }
}
