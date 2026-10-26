import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/core/services/database_service.dart';
import 'package:keryx_app/core/utils/bible_text_parser.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:http/http.dart' as http;

enum CommentaryCategory { geral, estudo, especifico }

class CommentaryMetadata {
  final String name;
  final String id;
  final String filename;
  final CommentaryCategory category;
  final int?
  bookId; // Usado para destacar o comentário se o usuário estiver no livro certo
  final String?
  storeCategoryName; // Usado para agrupar por pasta de onde veio na loja

  const CommentaryMetadata({
    required this.name,
    required this.id,
    required this.filename,
    required this.category,
    this.bookId,
    this.storeCategoryName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentaryMetadata &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Serviço de Bíblia – prioritariamente SQLite, fallback para Cloudflare D1 e JSON
///
/// SQLite Schema (tabela 'verse'):
///   book_id (int), chapter (int), verse (int), text (string)
class BibleService {
  final DatabaseService _dbService = DatabaseService();

  // Cache em memória de capítulos locais completos (0ms na leitura e scroll)
  static final Map<String, BibleChapter> _chapterMemoryCache = {};
  static final Map<String, String?> _commentaryCache = {};
  static final Map<String, List<BibleVerse>> _cloudChapterCache = {};
  static final Map<String, String> _verseTextCache = {};
  static final Map<String, Future<List<BibleVerse>>> _inFlightChapterRequests = {};
  static final Set<String> _missingLocalDatabases = {};
  static final Set<String> _emptyCloudVersions = {};

  // Pool de conexões limitando chamadas concorrentes à Cloudflare para no máximo 3
  static int _activeCloudRequests = 0;
  static final List<Completer<void>> _cloudRequestQueue = [];

  static Future<T> _runWithCloudflareThrottle<T>(Future<T> Function() action) async {
    while (_activeCloudRequests >= 3) {
      final completer = Completer<void>();
      _cloudRequestQueue.add(completer);
      await completer.future;
    }
    _activeCloudRequests++;
    try {
      return await action();
    } finally {
      _activeCloudRequests--;
      if (_cloudRequestQueue.isNotEmpty) {
        final next = _cloudRequestQueue.removeAt(0);
        next.complete();
      }
    }
  }

  static void notifyDatabaseDownloaded([String? version]) {
    if (version != null && version.isNotEmpty) {
      final key = version.toUpperCase();
      _missingLocalDatabases.remove(key);
      _emptyCloudVersions.remove(key);
    } else {
      _missingLocalDatabases.clear();
      _emptyCloudVersions.clear();
    }
    _verseTextCache.clear();
    _chapterMemoryCache.clear();
  }

  /// Limpa todos os caches de memória do serviço da Bíblia
  static void clearAllCaches() {
    notifyDatabaseDownloaded();
  }

  static const List<String> availableVersions = [
    'NVI',
    'ACF',
    'ARA',
    'ARA_S',
    'BPT',
    'ARC',
    'NVT',
    'NAA',
    'KJA',
    'KJF',
    'NTLH',
    'NBV',
    'AS21',
    'JFAA',
    'TB',
    'LTT2009',
    'BJ',
    'MSG',
  ];

  // Versões que possuem Strong's (Exibirá o ícone de olho)
  static const List<String> versionsWithStrongs = [
    'ARA_S',
    'BHS',
    'BIBLIA HEBRAICA STUTTGARTENSIA (BHS)',
  ];

  // Versões sugeridas para comparação (Mostra as principais para estudo)
  static const List<String> topComparisonVersions = [
    'NVI',
    'ACF',
    'ARA_S',
    'LTT2009',
    'NVT',
    'NAA',
    'ARC',
    'KJA',
    'NTLH',
    'KJF',
    'NBV',
    'BJ',
    'MSG',
  ];

  // Comentários Bíblicos Categorizados
  static const List<CommentaryMetadata> categorizedCommentaries = [
    // --- ESTUDO (Notas de Bíblias de Estudo) ---
    CommentaryMetadata(
      name: 'Notas NVI (Estudo)',
      id: 'Notas Bíblia de Estudo NVI',
      filename: 'Notas Bíblia de Estudo NVI.cmt.mybible',
      category: CommentaryCategory.estudo,
    ),
    CommentaryMetadata(
      name: 'MacArthur',
      id: 'Notas da Bíblia de Estudo Macarthur',
      filename: 'Notas da Bíblia de Estudo Macarthur.cmt.mybible',
      category: CommentaryCategory.estudo,
    ),

    CommentaryMetadata(
      name: 'Shedd',
      id: 'Biblia Sheed',
      filename: 'Biblia Sheed.cmt.mybible',
      category: CommentaryCategory.estudo,
    ),
    CommentaryMetadata(
      name: 'Pentecostal',
      id: 'Bíblia de Estudo Pentecostal',
      filename: 'Bíblia de Estudo Pentencostal .cmt.mybible',
      category: CommentaryCategory.estudo,
    ),
    CommentaryMetadata(
      name: 'Genebra',
      id: 'Comentário Bíblia Genebra',
      filename: 'Comentário Bíblia Genebra.cmt.mybible',
      category: CommentaryCategory.estudo,
    ),

    // --- GERAIS (Comentários que cobrem a bíblia toda) ---
    CommentaryMetadata(
      name: 'Moody',
      id: 'moody',
      filename: 'moody.cmt.mybible',
      category: CommentaryCategory.geral,
    ),
    CommentaryMetadata(
      name: 'Hernandes Dias Lopes',
      id: 'Coleção Comentários Expositivos Hagnos - Hernandes Dias Lopes',
      filename:
          'Coleção Comentários Expositivos Hagnos - Hernandes Dias Lopes.cmt.mybible',
      category: CommentaryCategory.geral,
    ),
    CommentaryMetadata(
      name: 'Wesleyana',
      id: 'Comentário Bíblico Wesleyana',
      filename: 'Comentário Bíblico Wesleyana.cmt.mybible',
      category: CommentaryCategory.geral,
    ),
    CommentaryMetadata(
      name: 'BEACON',
      id: 'BEACON',
      filename: 'BEACON.cmt.mybible',
      category: CommentaryCategory.geral,
    ),
    CommentaryMetadata(
      name: 'Adam Clarke (VT)',
      id: 'Comentário do Velho Testamento de Adam Clarke',
      filename: 'Comentário do Velho Testamento de Adam Clarke.cmt.mybible',
      category: CommentaryCategory.geral,
    ),
    CommentaryMetadata(
      name: 'Wiersbe (VT)',
      id: 'Comentário Exposito - O conhecimento Bíblico John F',
      filename:
          'Comentário Exposito - O conhecimento Bíblico John F.cmt.mybible',
      category: CommentaryCategory.geral,
    ),
    CommentaryMetadata(
      name: 'Diário Viver',
      id: 'Comentários da Bíblia Diario Viver',
      filename: 'Comentários da Bíblia Diario Viver.cmt.mybible',
      category: CommentaryCategory.geral,
    ),

    // --- ESPECÍFICOS (Por Livro) ---
    CommentaryMetadata(
      name: 'Gálatas (Spurgeon)',
      id: 'Gálatas - Spurgeon',
      filename: 'Gálatas - Spurgeon.cmt.mybible',
      category: CommentaryCategory.especifico,
      bookId: 48,
    ),
    CommentaryMetadata(
      name: 'Gálatas (Mensagem)',
      id: 'A Mensagem de Gálatas',
      filename: 'A Mensagem de Gálatas.cmt.mybible',
      category: CommentaryCategory.especifico,
      bookId: 48,
    ),
    CommentaryMetadata(
      name: 'A Epístola aos Gálatas',
      id: 'A Epístola aos Gálatas',
      filename: 'A Epístola aos Gálatas.cmt.mybible',
      category: CommentaryCategory.especifico,
      bookId: 48,
    ),
    CommentaryMetadata(
      name: 'Hebreus (Edwards)',
      id: 'Hebreus - Edwards',
      filename:
          'A Epístola aos Hebreus - THOMAS CHARLES EDWARDS, D.cmt.mybible',
      category: CommentaryCategory.especifico,
      bookId: 58,
    ),
    CommentaryMetadata(
      name: 'Efésios (Estudo)',
      id: 'Estudo da Carta aos Efésios',
      filename: 'Estudo da Carta aos Efésios.cmt.mybible',
      category: CommentaryCategory.especifico,
      bookId: 49,
    ),
    CommentaryMetadata(
      name: 'Romanos',
      id: 'Comentário Bíblico - Romanos',
      filename: 'Comentário Bíblico - Romanos.cmt.mybible',
      category: CommentaryCategory.especifico,
      bookId: 45,
    ),
    CommentaryMetadata(
      name: 'Provérbios (HDL)',
      id: 'Provérbios - H Dias Lopes',
      filename: 'Provérbios - H Dias Lopes.cmt.mybible',
      category: CommentaryCategory.especifico,
      bookId: 20,
    ),
    CommentaryMetadata(
      name: 'Eclesiastes (Kidner)',
      id: 'A Mensagem de Eclesiastes - Derek Kidner',
      filename: 'A Mensagem de Eclesiastes - Derek Kidner.cmt.mybible',
      category: CommentaryCategory.especifico,
      bookId: 21,
    ),
    CommentaryMetadata(
      name: 'Rute (Atkinson)',
      id: 'A Mensagem de Rute - David Atkinson',
      filename: 'A Mensagem de Rute - David Atkinson.cmt.mybible',
      category: CommentaryCategory.especifico,
      bookId: 8,
    ),
    CommentaryMetadata(
      name: 'Atos (Novo Com.)',
      id: 'novo comentário da bíblia - atos',
      filename: 'novo comentário da bíblia - atos.cmt.mybible',
      category: CommentaryCategory.especifico,
      bookId: 44,
    ),
  ];

  // Dicionários Bíblicos
  static const Map<String, String> availableDictionaries = {
    'STRONG (BR)': 'STRONG (BR).dct.mybible',
    'Strong PT': 'Strong-PT Dicionários BDB-Thayer-TVM com Strong.dct.mybible',
    'Almeida': 'Almeida.dct.mybible',
    'Wycliffe': 'Wycliffe.dct.mybible',
    'Davis': 'DAVIS.dct.mybible',
    'Champlim': 'CHAMPLIM.dct.mybible',
  };

  // Legado para compatibilidade
  static Map<String, String> get availableCommentaries {
    final map = <String, String>{};
    for (var c in categorizedCommentaries) {
      map[c.name] = c.filename;
    }
    return map;
  }

  // Versão padrão usada quando nenhuma é especificada
  static const String defaultVersion = 'NVI';

  /// Retorna o banco de dados da versão ou fallback JSON
  Future<Database?> _getDb(String version) async {
    final key = version.toUpperCase();
    if (_missingLocalDatabases.contains(key)) {
      return null;
    }
    try {
      return await _dbService.getDatabase(version);
    } catch (e) {
      _missingLocalDatabases.add(key);
      return null;
    }
  }

  // ─── Mapeamento abreviação → índice (0-based) ────────────────────────────

  /// Retorna o índice (0-based) do livro pelo ID numérico da API antiga
  /// (1 = Gênesis, 66 = Apocalipse) ou pela abreviação (GN, EX, etc).
  int _bookIndex(String bookId) {
    // Tenta encontrar o ID usando a Metadata (suporta nome, abbrev ou ID)
    final id = BibleMetadata.findBookId(bookId);
    return id - 1;
  }

  // ─── UTILS DE TEXTO ────────────────────────────────────────────────────────

  /// Remove tags HTML, marcações Strong e rodapés — delega ao BibleTextParser
  static String _cleanVerseText(String text) =>
      BibleTextParser.cleanToPlainText(text);

  /// Extrai o título e limpa o texto — delega ao BibleTextParser
  static ({String text, String? title}) _extractAndCleanVerseText(String text) =>
      BibleTextParser.extractTitleAndText(text);

  // ─── API PÚBLICA ──────────────────────────────────────────────────────────

  /// Retorna todos os 66 livros com metadados.
  Future<List<BibleBook>> getBooks({String version = defaultVersion}) async {
    final result = <BibleBook>[];

    Map<int, int>? realMaxChapters;
    final db = await _getDb(version);
    if (db != null) {
      try {
        final tablesResult = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
        );
        final tables = tablesResult
            .map((t) => (t['name'] as String).toLowerCase())
            .toList();

        // Suporte a ARA_S (VERSICULOS), MySword (Bible), MyBible (verses) e padrão (verse)
        final String query;
        if (tables.contains('versiculos')) {
          query = 'SELECT VER_LIV_ID as book_id, MAX(VER_CAPITULO) as max_c FROM VERSICULOS GROUP BY VER_LIV_ID';
        } else if (tables.contains('bible') && !tables.contains('verse')) {
          query = 'SELECT Book as book_id, MAX(Chapter) as max_c FROM Bible GROUP BY Book';
        } else if (tables.contains('verses') && !tables.contains('verse')) {
          final columnsResult = await db.rawQuery("PRAGMA table_info(verses)");
          final colNames = columnsResult.map((c) => (c['name'] as String).toLowerCase()).toSet();
          final bookCol = colNames.contains('book_number') ? 'book_number' : (colNames.contains('book_id') ? 'book_id' : 'book');
          query = 'SELECT $bookCol as book_id, MAX(chapter) as max_c FROM verses GROUP BY $bookCol';
        } else {
          query = 'SELECT book_id, MAX(chapter) as max_c FROM verse GROUP BY book_id';
        }

        final res = await db.rawQuery(query);
        if (res.isNotEmpty) {
          realMaxChapters = {};
          for (final row in res) {
            final bId = row['book_id'] as int;
            final mCap = row['max_c'] as int;
            realMaxChapters[bId] = mCap;
          }
        }
      } catch (e) {
        print("Erro ao tentar buscar MAX(chapter): $e");
      }
    }

    for (int i = 1; i <= 66; i++) {
      if (realMaxChapters != null && !realMaxChapters.containsKey(i)) {
        continue; // Pula o livro se ele não existir no banco de dados local
      }

      final metadata = BibleMetadata.getMetadata(i);
      final bookName = BibleMetadata.getBookName(i);

      int chapters;
      if (realMaxChapters != null && realMaxChapters.containsKey(i)) {
        chapters = realMaxChapters[i]!;
      } else {
        chapters = metadata?['chapters'] as int? ?? 0;
      }

      result.add(
        BibleBook(
          id: i,
          abbrev: metadata?['abbrev'] as String? ?? i.toString(),
          name: bookName,
          author: metadata?['author'] as String? ?? 'Desconhecido',
          group: metadata?['group'] as String? ?? 'Bíblia',
          chapters: chapters,
        ),
      );
    }

    return result;
  }

  /// Retorna a lista de números de capítulos (1, 2, 3, …).
  Future<List<int>> getChapters(
    String bookId, {
    String version = defaultVersion,
  }) async {
    final id = int.tryParse(bookId) ?? 1;

    int count = 0;
    if (!kIsWeb) {
      final db = await _getDb(version);
      if (db != null) {
        try {
          final tablesResult = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'",
          );
          final tables = tablesResult
              .map((t) => (t['name'] as String).toLowerCase())
              .toList();
          final String query =
              (tables.contains('bible') && !tables.contains('verse'))
              ? 'SELECT MAX(Chapter) as max_c FROM Bible WHERE Book = ?'
              : 'SELECT MAX(chapter) as max_c FROM verse WHERE book_id = ?';

          final res = await db.rawQuery(query, [id]);
          if (res.isNotEmpty && res.first['max_c'] != null) {
            count = res.first['max_c'] as int;
          }
        } catch (e) {
          print("Erro ao tentar buscar MAX(chapter): $e");
        }
      }
    }

    if (count == 0) {
      final metadata = BibleMetadata.getMetadata(id);
      count = metadata?['chapters'] as int? ?? 0;
    }

    return List.generate(count, (i) => i + 1);
  }

  /// Retorna um capítulo completo com todos os versículos.
  Future<BibleChapter> getChapter(
    String version,
    String bookId,
    int chapter, {
    bool isPrefetch = false,
  }) async {
    final cacheKey = "${version.toUpperCase()}_${bookId}_$chapter";
    if (_chapterMemoryCache.containsKey(cacheKey)) {
      return _chapterMemoryCache[cacheKey]!;
    }

    final bookIndex = _bookIndex(bookId);
    final bookIdInt = bookIndex + 1;
    final bookName = BibleMetadata.getBookName(bookIdInt);
    final metadata = BibleMetadata.getMetadata(bookIdInt);

    // 1. Tenta via SQLite (Rápido - Mobile e Web local)
    final db = await _getDb(version);
    if (db != null) {
      try {
        final tablesResult = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
        );
        final tables = tablesResult
            .map((t) => (t['name'] as String).toLowerCase())
            .toList();

        final List<Map<String, dynamic>> maps;
        final bool isAraS = tables.contains('versiculos');
        final bool isMySword = tables.contains('bible') && !tables.contains('verse');
        final bool isMyBible = tables.contains('verses') && !tables.contains('verse');

        if (isAraS) {
          maps = await db.query(
            'VERSICULOS',
            columns: ['VER_VERSICULO', 'VER_TEXTO'],
            where: 'VER_LIV_ID = ? AND VER_CAPITULO = ?',
            whereArgs: [bookIdInt, chapter],
            orderBy: 'CAST(VER_VERSICULO AS INTEGER) ASC',
          );
        } else if (isMySword) {
          maps = await db.query(
            'Bible',
            columns: ['Verse as verse', 'Scripture as text'],
            where: 'Book = ? AND Chapter = ?',
            whereArgs: [bookIdInt, chapter],
            orderBy: 'CAST(Verse AS INTEGER) ASC',
          );
        } else if (isMyBible) {
          final columnsResult = await db.rawQuery("PRAGMA table_info(verses)");
          final colNames = columnsResult.map((c) => (c['name'] as String).toLowerCase()).toSet();
          final bookCol = colNames.contains('book_number') ? 'book_number' : (colNames.contains('book_id') ? 'book_id' : 'book');
          maps = await db.query(
            'verses',
            columns: ['verse', 'text'],
            where: '$bookCol = ? AND chapter = ?',
            whereArgs: [bookIdInt, chapter],
            orderBy: 'CAST(verse AS INTEGER) ASC',
          );
        } else {
          maps = await db.query(
            'verse',
            columns: ['verse', 'text'],
            where: 'book_id = ? AND chapter = ?',
            whereArgs: [bookIdInt, chapter],
            orderBy: 'CAST(verse AS INTEGER) ASC',
          );
        }

        if (maps.isNotEmpty) {
          // Filtra linhas vazias (Bíblia Católica usa linhas pares vazias como espaçadores)
          final nonEmptyMaps = maps.where((m) {
            final rawText = isAraS
                ? (m['VER_TEXTO'] as String?) ?? ''
                : (m['text'] as String?) ?? '';
            return rawText.trim().isNotEmpty;
          }).toList();

          final verses = nonEmptyMaps.map((m) {
            final rawText = isAraS
                ? m['VER_TEXTO'] as String
                : m['text'] as String;
            final number = isAraS
                ? (m['VER_VERSICULO'] is int
                      ? m['VER_VERSICULO'] as int
                      : int.tryParse(m['VER_VERSICULO'].toString()) ?? 0)
                : (m['verse'] is int
                      ? m['verse'] as int
                      : int.tryParse(m['verse'].toString()) ?? 0);

            final cleaned = _extractAndCleanVerseText(rawText);

            return BibleVerse(
              number: number,
              text: cleaned.text,
              title: cleaned.title,
            );
          }).toList();

          // Re-numeração sequencial se os números estiverem em passos 2 (ex: 2,4,6...)
          final finalVerses = (verses.length >= 2 && verses.first.number == 2)
              ? (() {
                  final reNumbered = <BibleVerse>[];
                  int seq = 1;
                  for (final v in verses) {
                    reNumbered.add(BibleVerse(number: seq++, text: v.text, title: v.title));
                  }
                  return reNumbered;
                })()
              : verses;

          final chapterObj = BibleChapter(
            book: BibleBook(
              abbrev: bookId,
              name: bookName,
              author: metadata?['author'] as String? ?? '',
              group: metadata?['group'] as String? ?? '',
              chapters: metadata?['chapters'] as int? ?? 0,
            ),
            chapterNumber: chapter,
            verses: finalVerses,
          );

          if (_chapterMemoryCache.length > 30) {
            _chapterMemoryCache.remove(_chapterMemoryCache.keys.first);
          }
          _chapterMemoryCache[cacheKey] = chapterObj;

          // Pré-carregamento silencioso do próximo capítulo em background
          if (!isPrefetch) {
            final totalChapters = metadata?['chapters'] as int? ?? 150;
            if (chapter < totalChapters) {
              Future.microtask(() async {
                try {
                  await getChapter(version, bookId, chapter + 1, isPrefetch: true);
                } catch (_) {}
              });
            }
          }

          return chapterObj;
        }
      } catch (e) {
        print("Erro na query SQLite: $e. Tentando Cloudflare.");
      }
    }

    // 2. Tenta via Cloudflare D1 se a versão não estiver marcada como vazia
    if (!_emptyCloudVersions.contains(version.toUpperCase())) {
      try {
        final cloudVerses = await _runWithCloudflareThrottle(() => _fetchFromCloudflare(
          version,
          bookIdInt,
          chapter,
          isPrefetch: isPrefetch,
        ));
        if (cloudVerses.isNotEmpty) {
          final cloudChapter = BibleChapter(
            book: BibleBook(
              abbrev: bookId,
              name: bookName,
              author: metadata?['author'] as String? ?? '',
              group: metadata?['group'] as String? ?? '',
              chapters: metadata?['chapters'] as int? ?? 0,
            ),
            chapterNumber: chapter,
            verses: cloudVerses,
          );
          _chapterMemoryCache[cacheKey] = cloudChapter;
          return cloudChapter;
        } else {
          _emptyCloudVersions.add(version.toUpperCase());
        }
      } catch (e) {
        _emptyCloudVersions.add(version.toUpperCase());
      }
    }

    // 3. Fallback Final (Sem conexão e sem cache local)
    throw 'Não foi possível carregar o capítulo. Verifique se o módulo está baixado na Loja.';
  }

  /// Busca versículos que contenham a [query] na versão informada.
  Future<Map<String, dynamic>> searchByWord(
    String version,
    String query,
  ) async {
    final lowerQuery = query.toLowerCase();

    // 1. Tenta SQLite (Mobile)
    final db = await _getDb(version);
    if (db != null) {
      try {
        final List<Map<String, dynamic>> maps = await db.query(
          'verse',
          where: 'text LIKE ?',
          whereArgs: ['%$query%'],
          limit: 500,
        );

        final results = maps
            .map(
              (m) => {
                'verse_number': m['verse'],
                'text': _cleanVerseText(m['text'] as String),
                'book_name': BibleMetadata.getBookName(m['book_id'] as int),
                'chapter': m['chapter'],
                'book_id': m['book_id'].toString(),
              },
            )
            .toList();

        return {'verses': results, 'total': results.length};
      } catch (e) {
        print("Erro na busca SQLite: $e");
      }
    }

    // 2. Tenta Cloudflare (Web e Fallback Mobile)
    try {
      final results = await _searchCloudflare(version, query);
      if (results != null) return results;
    } catch (e) {
      print("Erro na busca Cloudflare: $e");
    }

    return {'verses': [], 'total': 0};
  }

  // --- MÉTODOS CLOUDFLARE ---

  final String _workerUrl =
      'https://biblia-ia-esboco.nivaldo-nilngn.workers.dev';

  Future<List<BibleVerse>> _fetchFromCloudflare(
    String version,
    int bookId,
    int chapter, {
    bool isPrefetch = false,
  }) async {
    final cacheKey = "${version.toUpperCase()}_${bookId}_$chapter";

    // 1. Memória RAM (0ms)
    if (_cloudChapterCache.containsKey(cacheKey)) {
      return _cloudChapterCache[cacheKey]!;
    }

    // 2. Requisição em voo (deduplica chamadas simultâneas)
    if (_inFlightChapterRequests.containsKey(cacheKey)) {
      return await _inFlightChapterRequests[cacheKey]!;
    }

    // 3. Cache Persistente Local (SharedPreferences / IndexedDB) (0ms)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cf_ch_$cacheKey');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(cachedJson);
        final verses = list.map((m) {
          return BibleVerse(
            number: m['n'] as int,
            text: m['t'] as String,
            title: m['h'] as String?,
          );
        }).toList();
        _cloudChapterCache[cacheKey] = verses;
        for (final v in verses) {
          _verseTextCache["${version.toUpperCase()}_${bookId}_${chapter}_${v.number}"] = v.text;
        }
        return verses;
      }
    } catch (_) {}

    // 4. Executa requisição para a Cloudflare com deduplicação
    final future = _doFetchFromCloudflare(
      version,
      bookId,
      chapter,
      cacheKey,
      isPrefetch: isPrefetch,
    );
    _inFlightChapterRequests[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlightChapterRequests.remove(cacheKey);
    }
  }

  Future<List<BibleVerse>> _doFetchFromCloudflare(
    String version,
    int bookId,
    int chapter,
    String cacheKey, {
    bool isPrefetch = false,
  }) async {
    try {
      final bodyStr = jsonEncode({
        'action': 'getChapter',
        'version': version.toUpperCase(),
        'book_id': bookId,
        'chapter': chapter,
      });

      final resp = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {'Content-Type': 'application/json'},
            body: bodyStr,
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final List<dynamic> results = data['results'] ?? [];
        final verses = results.map((m) {
          final cleaned = _extractAndCleanVerseText(m['text'] as String);
          return BibleVerse(
            number: m['verse'] as int,
            text: cleaned.text,
            title: cleaned.title,
          );
        }).toList();

        _cloudChapterCache[cacheKey] = verses;

        // Popula cache de versículos para Cross References
        for (final v in verses) {
          _verseTextCache["${version.toUpperCase()}_${bookId}_${chapter}_${v.number}"] = v.text;
        }

        // Salva persistentemente de forma assíncrona
        _persistChapterToStorage(cacheKey, verses);

        // Pré-carrega APENAS o próximo capítulo imediato (se não for já uma requisição de prefetch)
        if (!isPrefetch && verses.isNotEmpty) {
          _prefetchAdjacentChapters(version, bookId, chapter);
        }

        return verses;
      }
    } catch (e) {
      debugPrint("Worker Error (getChapter) for $version: $e");
    }
    return [];
  }

  void _persistChapterToStorage(String cacheKey, List<BibleVerse> verses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(verses.map((v) => {
        'n': v.number,
        't': v.text,
        if (v.title != null) 'h': v.title,
      }).toList());
      await prefs.setString('cf_ch_$cacheKey', serialized);
    } catch (_) {}
  }

  void _prefetchAdjacentChapters(String version, int bookId, int currentChapter) {
    final meta = BibleMetadata.getMetadata(bookId);
    final maxChapters = meta?['chapters'] as int? ?? 1;
    if (currentChapter < maxChapters) {
      final nextKey = "${version.toUpperCase()}_${bookId}_${currentChapter + 1}";
      if (!_cloudChapterCache.containsKey(nextKey) && !_inFlightChapterRequests.containsKey(nextKey)) {
        _fetchFromCloudflare(version, bookId, currentChapter + 1, isPrefetch: true);
      }
    }
  }

  Future<Map<String, dynamic>?> _searchCloudflare(
    String version,
    String query,
  ) async {
    try {
      final resp = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'search',
              'version': version.toUpperCase(),
              'query': query,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final List<dynamic> results = data['results'] ?? [];
        final mapped = results
            .map(
              (m) => {
                'verse_number': m['verse'],
                'text': m['text'],
                'book_name': BibleMetadata.getBookName(m['book_id'] as int),
                'chapter': m['chapter'],
                'book_id': m['book_id'].toString(),
              },
            )
            .toList();

        return {'verses': mapped, 'total': mapped.length};
      }
    } catch (e) {
      print("Worker Error (search): $e");
    }
    return null;
  }

  /// Retorna um versículo aleatório da versão.
  Future<Map<String, dynamic>> getRandomVerse(String version) async {
    // 1. Tenta SQLite
    final db = await _getDb(version);
    if (db != null) {
      try {
        final tablesResult = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
        );
        final tables = tablesResult
            .map((t) => (t['name'] as String).toLowerCase())
            .toList();

        final bool isAraS = tables.contains('versiculos');
        final bool isMySword = tables.contains('bible');

        List<Map<String, dynamic>> maps = [];

        if (isAraS) {
          maps = await db.rawQuery(
            'SELECT * FROM VERSICULOS ORDER BY RANDOM() LIMIT 1',
          );
          if (maps.isNotEmpty) {
            final m = maps.first;
            return {
              'verse_number': m['VER_VERSICULO'],
              'text': _cleanVerseText(m['VER_TEXTO'] as String),
              'book_name': BibleMetadata.getBookName(m['VER_LIV_ID'] as int),
              'chapter': m['VER_CAPITULO'],
              'book_id': m['VER_LIV_ID'].toString(),
            };
          }
        } else if (isMySword && !tables.contains('verse')) {
          maps = await db.rawQuery(
            'SELECT * FROM Bible ORDER BY RANDOM() LIMIT 1',
          );
          if (maps.isNotEmpty) {
            final m = maps.first;
            return {
              'verse_number': m['Verse'],
              'text': _cleanVerseText(m['Scripture'] as String),
              'book_name': BibleMetadata.getBookName(m['Book'] as int),
              'chapter': m['Chapter'],
              'book_id': m['Book'].toString(),
            };
          }
        } else {
          maps = await db.rawQuery(
            'SELECT * FROM verse ORDER BY RANDOM() LIMIT 1',
          );
          if (maps.isNotEmpty) {
            final m = maps.first;
            return {
              'verse_number': m['verse'],
              'text': _cleanVerseText(m['text'] as String),
              'book_name': BibleMetadata.getBookName(m['book_id'] as int),
              'chapter': m['chapter'],
              'book_id': m['book_id'].toString(),
            };
          }
        }
      } catch (e) {
        print("Erro ao pegar verso aleatório no SQLite: $e");
      }
    }

    // 2. Tenta Cloudflare
    try {
      final resp = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'getRandom',
          'version': version.toUpperCase(),
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['result'] != null) {
          final m = data['result'];
          return {
            'verse_number': m['verse'],
            'text': _cleanVerseText(m['text'] as String),
            'book_name': BibleMetadata.getBookName(m['book_id'] as int),
            'chapter': m['chapter'],
            'book_id': m['book_id'].toString(),
          };
        }
      }
    } catch (e) {
      print("Worker Error (getRandom): $e");
    }

    // 3. Fallback Final
    return {
      'verse_number': 1,
      'text': "O Senhor é o meu pastor, nada me faltará.",
      'book_name': "Salmos",
      'chapter': 23,
      'book_id': '19',
    };
  }

  Future<List<Map<String, dynamic>>> getVerseAcrossVersions({
    required String bookId,
    required int chapter,
    required List<int> verses,
    required List<String> versions,
  }) async {
    final bookIdInt = _bookIndex(bookId) + 1;
    final sortedVerses = verses.toList()..sort();

    // Processa em lotes de no máximo 3 versões simultâneas para garantir baixa concorrência e zero engasgo
    final crossResults = <Map<String, dynamic>>[];
    const int batchSize = 3;

    for (int i = 0; i < versions.length; i += batchSize) {
      final batch = versions.sublist(
        i,
        (i + batchSize > versions.length) ? versions.length : i + batchSize,
      );

      final batchFutures = batch.map((version) async {
        try {
          final verseTexts = <String>[];
          for (final vNum in sortedVerses) {
            final text = await getVerseText(
              version: version,
              bookId: bookIdInt,
              chapter: chapter,
              verse: vNum,
            );
            if (text != null && text.trim().isNotEmpty) {
              final clean = BibleTextParser.cleanToPlainText(text);
              verseTexts.add(sortedVerses.length == 1 ? clean : '$vNum $clean');
            }
          }

          if (verseTexts.isNotEmpty) {
            return {
              'version': version,
              'text': verseTexts.join('\n\n'),
            };
          }
        } catch (e, stack) {
          debugPrint("Erro ao ler versão $version na comparação: $e\n$stack");
        }
        return null;
      });

      final batchResults = await Future.wait(batchFutures);
      crossResults.addAll(batchResults.whereType<Map<String, dynamic>>());
    }

    crossResults.sort((a, b) {
      final indexA = versions.indexOf(a['version']);
      final indexB = versions.indexOf(b['version']);
      return indexA.compareTo(indexB);
    });

    return crossResults;
  }

  /// Busca o texto de um versículo (Local -> Cloud controlado)
  Future<String?> getVerseText({
    required String version,
    required int bookId,
    required int chapter,
    required int verse,
  }) async {
    final key = version.toUpperCase();
    final vKey = "${key}_${bookId}_${chapter}_$verse";
    if (_verseTextCache.containsKey(vKey)) {
      return _verseTextCache[vKey];
    }

    // 1. Tenta Local
    final local = await _dbService.getVerse(version, bookId, chapter, verse);
    if (local != null && local.isNotEmpty) {
      final res = _cleanVerseText(local);
      _verseTextCache[vKey] = res;
      return res;
    }

    // Se o banco local comprovadamente não existe ou Cloudflare já retornou vazio para esta versão,
    // evitamos chamadas de rede redundantes
    if (_missingLocalDatabases.contains(key) || _emptyCloudVersions.contains(key)) {
      return null;
    }

    // 2. Tenta Cloudflare com pool limitado a no máximo 3 chamadas concorrentes
    try {
      final cloudVerses = await _runWithCloudflareThrottle(
        () => _fetchFromCloudflare(version, bookId, chapter),
      );
      if (cloudVerses.isEmpty) {
        _emptyCloudVersions.add(key);
        return null;
      }
      final match = cloudVerses.where((v) => v.number == verse).firstOrNull;
      if (match?.text != null) {
        _verseTextCache[vKey] = match!.text;
      }
      return match?.text;
    } catch (e) {
      _emptyCloudVersions.add(key);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getCrossVersionsFromCloudflare(
    int bookId,
    int chapter,
    int verse,
    List<String> versions,
  ) async {
    try {
      final resp = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'getCrossVersions',
          'book_id': bookId,
          'chapter': chapter,
          'verse': verse,
          'versions': versions.map((v) => v.toUpperCase()).toList(),
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final List<dynamic> results = data['results'] ?? [];
        return results
            .map(
              (m) => {
                'version': m['version'],
                'text': _cleanVerseText(m['text'] as String),
              },
            )
            .toList();
      }
    } catch (e) {
      print("Worker Error (getCrossVersions): $e");
    }
    return [];
  }

  /// Busca comentário para um versículo (Local -> Cloud + Cache)
  Future<String?> getCommentaryForVerse({
    required String filename,
    required String versionId,
    required int bookId,
    required int chapter,
    required int verse,
  }) async {
    final cacheKey = "$versionId-$bookId-$chapter-$verse";
    if (_commentaryCache.containsKey(cacheKey)) {
      debugPrint('✅ Commentary cache hit: $cacheKey');
      return _commentaryCache[cacheKey];
    }

    debugPrint('🔍 Commentary cache miss: $cacheKey, filename=$filename');

    // Tenta Local (SQLite) - O DatabaseService já procura na pasta 'store' da loja
    final localCom = await _dbService.getCommentary(
      filename,
      bookId,
      chapter,
      verse,
    );
    if (localCom != null) {
      debugPrint('✅ Found commentary in SQLite: ${localCom.length} chars');
      _commentaryCache[cacheKey] = localCom;
      return localCom;
    }
    debugPrint('⚠️ No local commentary (SQLite) for $cacheKey');

    // 2. Tenta Cloudflare
    try {
      final cloudCom = await _getCloudCommentary(
        versionId,
        bookId,
        chapter,
        verse,
      );
      _commentaryCache[cacheKey] =
          cloudCom; // Cacheia mesmo se for null para evitar retry
      return cloudCom;
    } catch (e) {
      print("Erro ao buscar comentário na Cloud ($versionId): $e");
    }
    return null;
  }

  /// Verifica se existe comentário (apenas para mostrar ícone)
  Future<bool> hasCommentaryForVerse({
    required String filename,
    required String versionId,
    required int bookId,
    required int chapter,
    required int verse,
  }) async {
    final com = await getCommentaryForVerse(
      filename: filename,
      versionId: versionId,
      bookId: bookId,
      chapter: chapter,
      verse: verse,
    );
    return com != null && com.trim().isNotEmpty;
  }

  /// Verifica se a obra possui comentários para a seleção de versículos
  Future<bool> hasCommentaryForVerses({
    required String filename,
    required String versionId,
    required int bookId,
    required int chapter,
    required List<int> verses,
  }) async {
    return _dbService.hasCommentaryForVerses(filename, bookId, chapter, verses);
  }

  /// Verifica se a obra comenta qualquer parte do livro
  Future<bool> hasCommentaryForBook({
    required String filename,
    required int bookId,
  }) async {
    return _dbService.hasCommentaryForBook(filename, bookId);
  }

  /// Retorna os IDs dos livros que possuem algum comentário no arquivo especificado.
  Future<Set<int>> getCommentedBooks(String filename) async {
    try {
      final local = await _dbService.getCommentedBooks(filename);
      if (local.isNotEmpty) return local;
    } catch (_) {}

    if (kIsWeb) {
      try {
        final versionId = filename.split('.').first;
        final resp = await http.post(
          Uri.parse(_workerUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'getCommentedBooks',
            'version': versionId.toUpperCase(),
          }),
        );
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final dynamic results = data['results'];
          if (results is List) {
            return results
                .map((id) => id is int ? id : int.tryParse(id.toString()) ?? 0)
                .where((id) => id > 0)
                .toSet();
          }
        }
      } catch (e) {
        print("Erro ao buscar livros comentados (Worker): $e");
      }
    }
    return {};
  }

  Future<List<String>> getCloudSources() async {
    if (!kIsWeb) return [];
    try {
      final resp = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'getSources'}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final List results = data['results'] ?? [];
        return results.map((r) => (r['source_id'] ?? '').toString()).toList();
      }
    } catch (e) {
      print("Erro ao buscar sources na Cloud: $e");
    }
    return [];
  }

  /// Tracks which (versionId-bookId-chapter) have already been bulk-loaded.
  final Set<String> _chapterBulkLoaded = {};

  /// Pré-carrega TODOS os comentários do capítulo em 1 query D1 e povoa o cache.
  Future<void> _bulkLoadChapter(
    String versionId,
    int bookId,
    int chapter,
  ) async {
    final chapterKey = '$versionId-$bookId-$chapter';
    if (_chapterBulkLoaded.contains(chapterKey)) return;
    _chapterBulkLoaded.add(
      chapterKey,
    ); // marca antes da requisição para evitar paralelas

    try {
      debugPrint('📦 Bulk-loading chapter: $chapterKey');
      final resp = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'getChapterCommentaries',
              'version': versionId.toUpperCase(),
              'book_id': bookId,
              'chapter': chapter,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final byVerse = (data['commentaries'] as Map<String, dynamic>?) ?? {};
        for (final e in byVerse.entries) {
          final v = int.tryParse(e.key);
          if (v == null) continue;
          final ck = '$versionId-$bookId-$chapter-$v';
          if (!_commentaryCache.containsKey(ck)) {
            final t = e.value?.toString();
            _commentaryCache[ck] = (t == null || t.isEmpty) ? null : t;
          }
        }
        debugPrint('✅ Bulk-loaded ${byVerse.length} verses for $chapterKey');
      } else {
        debugPrint('⚠️ Bulk load failed ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('❌ Bulk load exception: $e');
      // Remove da lista para permitir retry em uma próxima chamada
      _chapterBulkLoaded.remove(chapterKey);
    }
  }

  /// Retorna o texto do comentário para um versículo específico.
  /// Na Web: pré-carrega o capítulo inteiro em UMA query D1, depois serve do cache.
  /// No mobile: usa SQLite local (loja), fallback para verse-by-verse na nuvem.
  Future<String?> getCommentary({
    required String filename,
    required String versionId,
    required int bookId,
    required int chapter,
    required int verse,
  }) async {
    final cacheKey = '$versionId-$bookId-$chapter-$verse';

    // Cache hit — retorna imediatamente
    if (_commentaryCache.containsKey(cacheKey)) {
      return _commentaryCache[cacheKey];
    }

    // ── Tenta SQLite local (dados da Loja) em TODAS AS PLATAFORMAS ───────
    try {
      final localText = await _dbService.getCommentary(
        filename,
        bookId,
        chapter,
        verse,
      );
      if (localText != null && localText.trim().isNotEmpty) {
        _commentaryCache[cacheKey] = localText;
        return localText;
      }
    } catch (_) {
      // SQLite indisponível ou dados vazios — continua para fallback na nuvem
    }

    // Fallbacks para nuvem caso o arquivo não esteja baixado
    if (!kIsWeb) {
      // Fallback mobile: verse-by-verse
      try {
        final cloud = await _getCloudCommentary(
          versionId,
          bookId,
          chapter,
          verse,
        );
        _commentaryCache[cacheKey] = cloud;
        return cloud;
      } catch (e) {
        debugPrint('Erro commentary cloud mobile: $e');
      }
      return null;
    }

    // ── WEB FALLBACK: bulk-load do capítulo (1 query D1) ─────────────────
    await _bulkLoadChapter(versionId, bookId, chapter);
    // O bulk-load já populou o cache para todos os versículos do capítulo
    if (_commentaryCache.containsKey(cacheKey)) {
      return _commentaryCache[cacheKey];
    }
    // Versículo não tem comentário — marca null para não retry
    _commentaryCache[cacheKey] = null;
    return null;
  }

  /// Retorna o conjunto de versículos do capítulo que possuem comentário
  Future<Uint8List?> getCommentaryImage(
    String commentaryFilename,
    String imageId,
  ) async {
    try {
      final db = await _getDb(commentaryFilename);
      if (db == null) return null;

      final result = await db.query(
        'data',
        columns: ['content'],
        where: 'id = ? OR filename = ?',
        whereArgs: [imageId, imageId],
        limit: 1,
      );

      if (result.isNotEmpty && result.first['content'] != null) {
        return result.first['content'] as Uint8List;
      }
    } catch (e) {
      debugPrint('Erro ao buscar imagem $imageId no comentário: $e');
    }
    return null;
  }

  /// Busca a capa de um livro específico dentro de um comentário
  Future<Uint8List?> getBookCoverImage(String filename, int bookId) async {
    return _dbService.getBookCoverImage(filename, bookId);
  }

  Future<List<Map<String, dynamic>>> getCommentedChaptersDetail(
    String filename,
    int bookId,
  ) async {
    try {
      return await _dbService.getCommentedChaptersDetail(filename, bookId);
    } catch (e) {
      debugPrint('Erro ao buscar capítulos detalhados: $e');
    }
    return [];
  }

  Future<Set<int>> getCommentedVerses({
    required String filename,
    required String versionId,
    required int bookId,
    required int chapter,
  }) async {
    // 1. Tenta Local sempre
    try {
      final localSet = await _dbService.getCommentedVerses(
        filename,
        bookId,
        chapter,
      );
      if (localSet.isNotEmpty) return localSet;
    } catch (_) {
      // Ignora erro SQLite e tenta cloud
    }

    // 2. Tenta Cloudflare
    try {
      return await _getCloudCommentedVerses(versionId, bookId, chapter);
    } catch (e) {
      debugPrint("Erro ao buscar versículos comentados na Cloud: $e");
    }
    return {};
  }

  Future<Set<int>> _getCloudCommentedVerses(
    String versionId,
    int bookId,
    int chapter,
  ) async {
    try {
      debugPrint(
        '📡 Requesting Cloud Commented Verses: $versionId, book=$bookId, cap=$chapter',
      );
      final resp = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'getCommentedVerses',
          'version': versionId.toUpperCase(),
          'book_id': bookId,
          'chapter': chapter,
        }),
      );

      debugPrint('📡 Worker Response Status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        debugPrint('📡 Worker Response Data: $data');
        if (data['results'] is List) {
          final List results = data['results'];
          final Set<int> commented = {};
          for (final row in results) {
            final from = row['from_verse'] as int;
            final to = row['to_verse'] as int;
            for (int i = from; i <= to; i++) {
              commented.add(i);
            }
          }
          return commented;
        }
      } else {
        debugPrint('❌ Worker Error Response: ${resp.body}');
      }
    } catch (e) {
      debugPrint("❌ Worker Exception (getCommentedVerses): $e");
    }
    return {};
  }

  Future<String?> _getCloudCommentary(
    String versionId,
    int bookId,
    int chapter,
    int verse,
  ) async {
    try {
      debugPrint(
        '📡 Requesting Cloud Commentary: $versionId, $bookId:$chapter:$verse',
      );
      final resp = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'getCommentary',
              'version': versionId.toUpperCase(),
              'book_id': bookId,
              'chapter': chapter,
              'verse': verse,
            }),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('📡 Worker Response Status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        debugPrint('📡 Worker Response Data: $data');

        if (data['response'] is List) {
          final List parts = data['response'];
          return parts.map((p) => p['text'] as String).join('');
        }

        return data['response'] as String?;
      } else {
        debugPrint('❌ Worker Error Response: ${resp.body}');
      }
    } catch (e) {
      debugPrint("❌ Worker Exception (getCommentary): $e");
    }
    return null;
  }

  /// Busca significado no dicionário na nuvem
  Future<String?> getDictionaryEntry(String dictId, String word) async {
    try {
      final resp = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'getDictionary',
          'version': dictId.toUpperCase(),
          'word': word,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['result'] is List) {
          final List parts = data['result'];
          return parts.map((p) => p['data'] as String).join('');
        }
        return data['result']?['data'] as String?;
      }
    } catch (e) {
      print("Worker Error (getDictionary): $e");
    }
    return null;
  }

  /// Lista palavras que começam com a letra l
  Future<List<Map<String, dynamic>>> getDictionaryWordsByLetter(
    String dictFile,
    String letter,
  ) async {
    // 1. Tenta Cloudflare (Novo padrão Cloud-first)
    try {
      final resp = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'getDictionaryList',
              'version': dictFile,
              'letter': letter,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['result'] is List) {
          final List list = data['result'];
          return list
              .map(
                (e) => {
                  'word': e['word'] as String,
                  'data': e['data'] as String,
                },
              )
              .toList();
        }
      }
    } catch (e) {
      print("Erro ao buscar lista de dicionário na Cloud: $e");
    }

    // 2. Fallback para Local
    return _dbService.getDictionaryWordsByLetter(dictFile, letter);
  }

  /// Busca palavras no dicionário por termo parcial
  Future<List<Map<String, dynamic>>> searchDictionary(
    String dictFile,
    String query,
  ) async {
    // 1. Tenta Cloudflare
    try {
      final resp = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'getDictionarySearch',
              'version': dictFile,
              'query': query,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['result'] is List) {
          final List list = data['result'];
          return list
              .map(
                (e) => {
                  'word': e['word'] as String,
                  'data': e['data'] as String,
                },
              )
              .toList();
        }
      }
    } catch (e) {
      print("Erro ao buscar no dicionário na Cloud: $e");
    }

    // 2. Fallback para Local
    return _dbService.searchDictionary(dictFile, query);
  }

  /// Retorna o total de termos que começam com a letra l
  Future<int> getDictionaryWordCountByLetter(
    String dictFile,
    String letter,
  ) async {
    // 1. Tenta Cloudflare
    try {
      final resp = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'getDictionaryCount',
              'version': dictFile,
              'letter': letter,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        debugPrint('📄 Count response: $data');

        // Worker retorna { "count": 123 } ou { "response": 123 }
        final count = data['count'] ?? data['response'];
        if (count is int) return count;
        if (count is num) return count.toInt();
        if (count is String) return int.tryParse(count) ?? 0;
      }
    } catch (e) {
      print("Erro ao contar termos na Cloud: $e");
    }

    // 2. Fallback para Local
    return _dbService.getDictionaryWordCountByLetter(dictFile, letter);
  }

  /// Busca referências cruzadas para um versículo
  Future<List<Map<String, dynamic>>> getXRefsForVerse(
    int bookId,
    int chapter,
    int verse,
  ) async {
    try {
      final resp = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'getXRefs',
          'book_id': bookId,
          'chapter': chapter,
          'verse': verse,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final List ids = data['results'] ?? [];
        // Converte IDs MySword de volta para Livro/Cap/Ver se necessário no futuro
        return ids.map((id) => {'id': id}).toList();
      }
    } catch (e) {
      print("Worker Error (getXRefs): $e");
    }
    return [];
  }

  // Compatibilidade com código legado que chamava setToken
  void setToken(String? token) {
    // Agora o sistema é cloud-first via Cloudflare Worker
  }
}
