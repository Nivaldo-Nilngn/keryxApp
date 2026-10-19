import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';

/// Formato da tabela de versículos de cada módulo bíblico (descoberto uma vez por banco).
enum _VerseSchema { araS, mySword, standard }

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final Map<String, Database> _databases = {};

  // Cache de estrutura para comentários (evita redescobrir schema em cada clique)
  final Map<
    String,
    ({String table, String book, String from, String to, String data})
  >
  _commentarySchemas = {};

  // Cache do formato de cada Bíblia (evita consultar sqlite_master a cada versículo)
  final Map<String, _VerseSchema> _verseSchemas = {};

  // Cache de "a tabela de comentários tem a coluna marker?" (evita PRAGMA a cada chamada)
  final Map<String, bool> _commentaryHasMarker = {};

  void _ensureWebFactory() {
    // sqflite_sqlcipher não suporta Web.
    // A inicialização do databaseFactory para Web é feita no main.dart
    // via sqflite_common_ffi_web antes de abrir qualquer banco não-cifrado.
  }

  // Remove extensões conhecidas para casar "NVI.bbl.mybible" com a chave "NVI".
  String _stripExt(String name) {
    final lower = name.toLowerCase();
    const exts = [
      '.bbl.mybible',
      '.cmt.mybible',
      '.dct.mybible',
      '.bok.mybible',
      '.mybible',
      '.sqlite',
      '.db',
    ];
    for (final ext in exts) {
      if (lower.endsWith(ext)) return name.substring(0, name.length - ext.length);
    }
    return name;
  }

  /// Fecha e esquece a conexão em cache de um módulo.
  /// Chame antes de excluir o arquivo e depois de baixar uma versão nova,
  /// senão o app continua usando a conexão antiga.
  /// Aceita o nome do arquivo ("BEACON.cmt.mybible") ou a chave da Bíblia ("NVI").
  Future<void> closeDatabase(String nameOrFilename) async {
    final target = nameOrFilename.toLowerCase();
    final targetBase = _stripExt(nameOrFilename).toLowerCase();

    final keys = _databases.keys.where((k) {
      final kl = k.toLowerCase();
      return kl == target || kl == targetBase;
    }).toList();

    for (final k in keys) {
      try {
        await _databases[k]!.close().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Aviso: timeout ao fechar o banco $k - $e');
      }
      _databases.remove(k);
      _commentarySchemas.remove(k);
      _verseSchemas.remove(k);
      _commentaryHasMarker.remove(k);
    }
  }

  Future<Database> getDatabase(String version) async {
    _ensureWebFactory();
    final key = version.toUpperCase();

    if (_databases.containsKey(key)) return _databases[key]!;

    final dbPath = !kIsWeb
        ? await getDatabasesPath()
        : await databaseFactoryFfiWeb.getDatabasesPath();
    String path = join(dbPath, "$key.sqlite");

    bool exists = false;
    if (!kIsWeb) {
      exists = await io.File(path).exists();
      if (exists) {
        final length = await io.File(path).length();
        if (length == 0) {
          exists = false;
          await io.File(path).delete();
        }
      }
      if (!exists) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final storeBaseDir = join(appDocDir.path, 'store');

        final storePaths = [
          join(storeBaseDir, 'bibles', '$key.bbl.mybible'),
          join(storeBaseDir, 'bibles', '$key.sqlite'),
          join(storeBaseDir, 'bibles', '$key.db'),
          join(storeBaseDir, '$key.bbl.mybible'),
          join(storeBaseDir, '$key.sqlite'),
          join(storeBaseDir, '$key.db'),
        ];

        for (final sp in storePaths) {
          if (await io.File(sp).exists()) {
            path = sp;
            exists = true;
            break;
          }
        }

        // Busca case-insensitive caso as tentativas diretas falhem (ex: sistema de arquivos do Linux/Android)
        if (!exists) {
          final dirsToSearch = [
            io.Directory(join(storeBaseDir, 'bibles')),
            io.Directory(storeBaseDir),
          ];

          for (final d in dirsToSearch) {
            if (await d.exists()) {
              final entities = await d.list().toList();
              for (final e in entities) {
                if (e is io.File) {
                  final eName = basename(e.path).toUpperCase();
                  if (eName == '$key.BBL.MYBIBLE' ||
                      eName == '$key.SQLITE' ||
                      eName == '$key.MYBIBLE' ||
                      eName == '$key.DB') {
                    final length = await (e).length();
                    if (length > 0) {
                      path = e.path;
                      exists = true;
                      break;
                    }
                  }
                }
              }
            }
            if (exists) break;
          }
        }
      }
    } else {
      // No web, verificamos se o banco existe no sistema de arquivos virtual do sqflite_ffi_web
      try {
        final factory = databaseFactoryFfiWeb;
        final possibleWebNames = [
          '$key.sqlite',
          '$key.bbl.mybible',
          '$key.db',
          '${version.toLowerCase()}.bbl.mybible',
          '${version.toLowerCase()}.sqlite',
          '${version.toLowerCase()}.db',
          '$version.bbl.mybible',
          '$version.sqlite',
          '$version.db',
        ];

        for (final name in possibleWebNames) {
          final testPath = join(dbPath, name);
          if (await factory.databaseExists(testPath)) {
            path = testPath;
            exists = true;
            break;
          }
        }
      } catch (e) {
        exists = false;
      }
    }

    if (!exists) {
      // Se não existir, copia dos assets
      try {
        if (!kIsWeb) {
          await io.Directory(dirname(path)).create(recursive: true);
        }

        // Caminho nos assets principal
        String assetPath = "assets/bible/sql/$key.sqlite";

        ByteData? data;
        try {
          data = await rootBundle.load(assetPath);
        } catch (_) {
          // Fallback para .db em assets/database/
          try {
            assetPath = "assets/database/${key.toLowerCase()}.db";
            data = await rootBundle.load(assetPath);
          } catch (_) {
            try {
              assetPath = "assets/database/$key.db";
              data = await rootBundle.load(assetPath);
            } catch (_) {
              rethrow;
            }
          }
        }
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        if (!kIsWeb) {
          // Escreve no arquivo local (Mobile/Desktop)
          await io.File(path).writeAsBytes(bytes, flush: true);
        } else {
          // No Web, usamos o factory para escrever no IndexedDB virtual filesystem
          final factory = databaseFactoryFfiWeb;
          await factory.writeDatabaseBytes(path, Uint8List.fromList(bytes));
        }
        print("Banco de dados $key copiado para o armazenamento local.");
      } catch (e) {
        print("Erro ao copiar banco de dados dos assets ($key): $e");
        rethrow;
      }
    }

    // Abre o banco de dados
    final db = kIsWeb
        ? await databaseFactoryFfiWeb.openDatabase(
            path,
            options: OpenDatabaseOptions(readOnly: true),
          )
        : await openDatabase(path, readOnly: true);
    _databases[key] = db;
    return db;
  }

  /// Busca o texto de um versículo específico no banco local
  Future<String?> getVerse(
    String version,
    int bookId,
    int chapter,
    int verse,
  ) async {
    try {
      final db = await getDatabase(version);
      final key = version.toUpperCase();

      // Descobre o formato da Bíblia uma única vez por banco
      var schema = _verseSchemas[key];
      if (schema == null) {
        final tablesResult = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
        );
        final tables = tablesResult
            .map((t) => (t['name'] as String).toLowerCase())
            .toSet();

        if (tables.contains('versiculos')) {
          schema = _VerseSchema.araS;
        } else if (tables.contains('bible') && !tables.contains('verse')) {
          schema = _VerseSchema.mySword;
        } else {
          schema = _VerseSchema.standard;
        }
        _verseSchemas[key] = schema;
      }

      final List<Map<String, dynamic>> maps;

      if (schema == _VerseSchema.araS) {
        maps = await db.query(
          'VERSICULOS',
          columns: ['VER_TEXTO'],
          where: 'VER_LIV_ID = ? AND VER_CAPITULO = ? AND VER_VERSICULO = ?',
          whereArgs: [bookId, chapter, verse],
          limit: 1,
        );
        if (maps.isNotEmpty) {
          return maps.first['VER_TEXTO'] as String?;
        }
      } else if (schema == _VerseSchema.mySword) {
        maps = await db.query(
          'Bible',
          columns: ['Scripture as text'],
          where: 'Book = ? AND Chapter = ? AND Verse = ?',
          whereArgs: [bookId, chapter, verse],
          limit: 1,
        );
        if (maps.isNotEmpty) {
          return maps.first['text'] as String?;
        }
      } else {
        maps = await db.query(
          'verse',
          columns: ['text'],
          where: 'book_id = ? AND chapter = ? AND verse = ?',
          whereArgs: [bookId, chapter, verse],
          limit: 1,
        );
        if (maps.isNotEmpty) {
          return maps.first['text'] as String?;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Erro ao obter versiculo $version: $e');
      return null;
    }
  }

  // Abre o banco de dados de comentários *.cmt.mybible
  Future<Database?> getCommentaryDatabase(String filename) async {
    _ensureWebFactory();
    if (_databases.containsKey(filename)) return _databases[filename]!;

    // 1. Tenta buscar no diretório do 'store' (onde a loja salva os downloads)
    String? storeBaseDir;
    List<String> possibleStorePaths = [];

    if (!kIsWeb) {
      final appDocDir = await getApplicationDocumentsDirectory();
      storeBaseDir = join(appDocDir.path, 'store');

      // Lista de subpastas possíveis (Loja e pastas locais específicas)
      possibleStorePaths = [
        join(appDocDir.path, 'commentary', filename),
        join(appDocDir.path, 'commentaries', filename),
        join(storeBaseDir, filename),
        join(storeBaseDir, 'commentaries', filename),
        join(storeBaseDir, 'Comentários Expositivos', filename),
        join(storeBaseDir, 'Cultura e História', filename),
        join(storeBaseDir, 'Esboços, Homilética e Temas', filename),
      ];
    }

    String? foundPath;
    if (!kIsWeb) {
      for (final p in possibleStorePaths) {
        if (await io.File(p).exists()) {
          foundPath = p;
          debugPrint('📂 Comentário encontrado na loja: $p');
          break;
        }
      }
    }

    // 2. Se não encontrou na loja, usa o diretório padrão de banco de dados
    final dbPath = !kIsWeb
        ? await getDatabasesPath()
        : await databaseFactoryFfiWeb.getDatabasesPath();
    final path = foundPath ?? join(dbPath, filename);

    bool exists = foundPath != null;
    if (!exists) {
      if (!kIsWeb) {
        exists = await io.File(path).exists();
      } else {
        // Na Web, o módulo só existe se foi baixado pela loja (IndexedDB).
        // Sem ele, não carregamos dos assets: os comentários vêm do D1 (Cloud).
        try {
          exists = await databaseFactoryFfiWeb.databaseExists(path);
        } catch (_) {
          exists = false;
        }
        if (!exists) return null;
      }
    }

    if (!exists) {
      try {
        if (!kIsWeb) {
          await io.Directory(dirname(path)).create(recursive: true);
        }

        // Tenta encontrar em diferentes subpastas de assets
        final List<String> possiblePaths = [
          "assets/bible/commentaries/$filename",
          "assets/bible/commentaries/Comentários Expositivos/$filename",
          "assets/bible/commentaries/Cultura e História/$filename",
          "assets/bible/commentaries/Esboços, Homilética e Temas/$filename",
        ];

        ByteData? data;
        String? assetFoundPath;

        for (final assetPath in possiblePaths) {
          try {
            data = await rootBundle.load(assetPath);
            assetFoundPath = assetPath;
            break; // Encontrou!
          } catch (_) {
            continue; // Tenta próxima pasta
          }
        }

        if (data == null) {
          debugPrint(
            '❌ Comentário $filename não encontrado nos assets ou loja.',
          );
          return null;
        }

        debugPrint('✅ Comentário encontrado em assets: $assetFoundPath');
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        if (!kIsWeb) {
          await io.File(path).writeAsBytes(bytes, flush: true);
        } else {
          final factory = databaseFactoryFfiWeb;
          await factory.writeDatabaseBytes(path, Uint8List.fromList(bytes));
        }
        print("Banco de comentários $filename copiado.");
      } catch (e) {
        debugPrint('⚠️ Erro ao carregar commentary: $e');
        return null;
      }
    }

    try {
      final db = kIsWeb
          ? await databaseFactoryFfiWeb.openDatabase(
              path,
              options: OpenDatabaseOptions(readOnly: true),
            )
          : await openDatabase(path, readOnly: true);
      _databases[filename] = db;
      return db;
    } catch (e) {
      return null;
    }
  }

  /// Helper para descobrir e cachear o schema de um banco de comentários
  Future<({String table, String book, String from, String to, String data})?>
  _getCommentarySchema(Database db, String filename) async {
    if (_commentarySchemas.containsKey(filename)) {
      return _commentarySchemas[filename];
    }

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('commentary', 'commentaries')",
    );
    if (tables.isEmpty) {
      debugPrint('❌ Nenhuma tabela de comentário encontrada em $filename');
      return null;
    }
    final tableName = tables.first['name'] as String;

    final columns = await db.rawQuery("PRAGMA table_info($tableName)");
    final colNames = columns.map((c) => c['name'] as String).toList();

    final bookCol = colNames.contains('book')
        ? 'book'
        : (colNames.contains('book_id') ? 'book_id' : 'book');
    final fromCol = colNames.contains('fromverse')
        ? 'fromverse'
        : (colNames.contains('verse') ? 'verse' : 'fromverse');
    final toCol = colNames.contains('toverse') ? 'toverse' : 'verse';
    final dataCol = colNames.contains('data')
        ? 'data'
        : (colNames.contains('text') ? 'text' : 'data');

    final schema = (
      table: tableName,
      book: bookCol,
      from: fromCol,
      to: toCol,
      data: dataCol,
    );
    _commentarySchemas[filename] = schema;
    _commentaryHasMarker[filename] = colNames.contains('marker');
    debugPrint('🎯 Schema cacheado para $filename (Tabela: ${schema.table})');
    return schema;
  }

  /// Retorna a lista de IDs de livros que possuem algum comentário neste arquivo
  Future<Set<int>> getCommentedBooks(String filename) async {
    final db = await getCommentaryDatabase(filename);
    if (db == null) return {};

    final schema = await _getCommentarySchema(db, filename);
    if (schema == null) return {};

    try {
      // Usar o nome da coluna 'book' ou 'book_id' do schema
      final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT DISTINCT ${schema.book} FROM ${schema.table} ORDER BY ${schema.book}',
      );
      return maps.map((m) => m[schema.book] as int).toSet();
    } catch (e) {
      debugPrint('Erro ao buscar livros comentados em $filename: $e');
      return {};
    }
  }

  /// Busca o comentário para um determinado versículo
  Future<String?> getCommentary(
    String filename,
    int bookId,
    int chapter,
    int verse,
  ) async {
    try {
      final db = await getCommentaryDatabase(filename);
      if (db == null) return null;

      // Usa o cache de schema (descoberto apenas uma vez por sessão do App)
      final schema = await _getCommentarySchema(db, filename);
      if (schema == null) return null;

      // Consulta rápida direto no banco
      final List<Map<String, dynamic>> maps = await db.query(
        schema.table,
        where:
            '${schema.book} = ? AND chapter = ? AND ${schema.from} <= ? AND ${schema.to} >= ?',
        whereArgs: [bookId, chapter, verse, verse],
        orderBy: '(${schema.to} - ${schema.from}) ASC',
        limit: 1,
      );

      if (maps.isNotEmpty && maps.first[schema.data] != null) {
        return maps.first[schema.data] as String;
      }
      return null;
    } catch (e) {
      debugPrint("❌ Erro no SQLite: $e");
      return null;
    }
  }

  /// Checa de forma ultra-rápida (SELECT 1 ... LIMIT 1) se o comentário
  /// possui notas para os versículos selecionados
  Future<bool> hasCommentaryForVerses(
    String filename,
    int bookId,
    int chapter,
    List<int> verses,
  ) async {
    if (verses.isEmpty) return false;
    try {
      final db = await getCommentaryDatabase(filename);
      if (db == null) return false;

      final schema = await _getCommentarySchema(db, filename);
      if (schema == null) return false;

      final minV = verses.reduce((a, b) => a < b ? a : b);
      final maxV = verses.reduce((a, b) => a > b ? a : b);

      final maps = await db.rawQuery(
        'SELECT 1 FROM ${schema.table} WHERE ${schema.book} = ? AND chapter = ? AND ${schema.from} <= ? AND ${schema.to} >= ? LIMIT 1',
        [bookId, chapter, maxV, minV],
      );

      return maps.isNotEmpty;
    } catch (e) {
      debugPrint("❌ Erro ao checar hasCommentaryForVerses: $e");
      return false;
    }
  }

  /// Checa de forma ultra-rápida se a obra comenta qualquer parte do livro
  Future<bool> hasCommentaryForBook(
    String filename,
    int bookId,
  ) async {
    try {
      final db = await getCommentaryDatabase(filename);
      if (db == null) return false;

      final schema = await _getCommentarySchema(db, filename);
      if (schema == null) return false;

      final maps = await db.rawQuery(
        'SELECT 1 FROM ${schema.table} WHERE ${schema.book} = ? LIMIT 1',
        [bookId],
      );

      return maps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Retorna todos os blocos de comentário de um capítulo, com seus respectivos ranges
  Future<List<({int fromVerse, int toVerse, String text})>> getChapterCommentaries(
    String filename,
    int bookId,
    int chapter,
  ) async {
    try {
      final db = await getCommentaryDatabase(filename);
      if (db == null) return [];

      final schema = await _getCommentarySchema(db, filename);
      if (schema == null) return [];

      final List<Map<String, dynamic>> maps = await db.query(
        schema.table,
        columns: [schema.from, schema.to, schema.data],
        where: '${schema.book} = ? AND chapter = ?',
        whereArgs: [bookId, chapter],
        orderBy: '${schema.from} ASC',
      );

      return maps.where((m) => m[schema.data] != null).map((map) {
        return (
          fromVerse: (map[schema.from] as num?)?.toInt() ?? 1,
          toVerse: (map[schema.to] as num?)?.toInt() ?? 1,
          text: map[schema.data] as String,
        );
      }).toList();
    } catch (e) {
      debugPrint("❌ Erro ao buscar comentários do capítulo: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCommentedChaptersDetail(
    String filename,
    int bookId,
  ) async {
    try {
      final db = await getCommentaryDatabase(filename);
      if (db == null) return [];

      final schema = await _getCommentarySchema(db, filename);
      if (schema == null) return [];

      final hasMarker = _commentaryHasMarker[filename] ?? false;

      // Agrupa no próprio SQLite (antes lia todas as linhas do livro e filtrava no Dart)
      final sql = hasMarker
          ? 'SELECT chapter, MIN(marker) AS marker FROM ${schema.table} '
                'WHERE ${schema.book} = ? GROUP BY chapter ORDER BY chapter ASC'
          : 'SELECT chapter FROM ${schema.table} '
                'WHERE ${schema.book} = ? GROUP BY chapter ORDER BY chapter ASC';

      final List<Map<String, dynamic>> rows = await db.rawQuery(sql, [bookId]);

      return rows
          .map(
            (row) => {
              'chapter': (row['chapter'] as num).toInt(),
              'marker': hasMarker ? row['marker'] as String? : null,
            },
          )
          .toList();
    } catch (e) {
      debugPrint("❌ Erro ao buscar capítulos detalhados: $e");
      return [];
    }
  }

  /// Retorna o conjunto de versículos que possuem comentário localmente
  Future<Set<int>> getCommentedVerses(
    String filename,
    int bookId,
    int chapter,
  ) async {
    try {
      final db = await getCommentaryDatabase(filename);
      if (db == null) return {};

      final schema = await _getCommentarySchema(db, filename);
      if (schema == null) return {};

      final List<Map<String, dynamic>> maps = await db.query(
        schema.table,
        columns: [schema.from, schema.to],
        where: '${schema.book} = ? AND chapter = ?',
        whereArgs: [bookId, chapter],
      );

      final Set<int> commented = {};
      for (final map in maps) {
        final from = map[schema.from] as int;
        final to = map[schema.to] as int;
        if ((to - from) > 50) continue;

        for (int i = from; i <= (to > 0 ? to : from); i++) {
          if (i > 0) commented.add(i);
        }
      }
      return commented;
    } catch (e) {
      return {};
    }
  }

  /// Busca a imagem de capa de um livro específico dentro de um comentário
  Future<Uint8List?> getBookCoverImage(String filename, int bookId) async {
    try {
      final db = await getCommentaryDatabase(filename);
      if (db == null) return null;

      final schema = await _getCommentarySchema(db, filename);
      if (schema == null) return null;

      // Busca na tabela commentary uma linha deste livro com tag de imagem
      final rows = await db.query(
        schema.table,
        columns: [schema.data],
        where: '${schema.book} = ? AND ${schema.data} LIKE ?',
        whereArgs: [bookId, '%<img%'],
        orderBy: 'chapter ASC, ${schema.from} ASC',
        limit: 1,
      );

      if (rows.isNotEmpty && rows.first[schema.data] != null) {
        final text = rows.first[schema.data] as String;
        final match = RegExp(r'''src=['"]([^'"]+)['"]''').firstMatch(text);
        if (match != null) {
          final imgId = match.group(1);
          if (imgId != null && !imgId.startsWith('http') && !imgId.startsWith('data:')) {
            final tables = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='data';",
            );
            if (tables.isNotEmpty) {
              final imgRows = await db.query(
                'data',
                columns: ['content'],
                where: 'id = ? OR filename = ?',
                whereArgs: [imgId, imgId],
                limit: 1,
              );
              if (imgRows.isNotEmpty && imgRows.first['content'] != null) {
                return imgRows.first['content'] as Uint8List;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Erro ao buscar capa do livro $bookId em $filename: $e");
    }
    return null;
  }

  // Abre o banco de dados de dicionários *.dct.mybible
  Future<Database> getDictionaryDatabase(String filename) async {
    _ensureWebFactory();
    if (_databases.containsKey(filename)) return _databases[filename]!;

    // 1. Tenta buscar no diretório do 'store'
    String? storeBaseDir;
    List<String> possibleStorePaths = [];

    if (!kIsWeb) {
      final appDocDir = await getApplicationDocumentsDirectory();
      storeBaseDir = join(appDocDir.path, 'store');

      possibleStorePaths = [
        join(appDocDir.path, 'dictionaries', filename),
        join(storeBaseDir, filename),
        join(storeBaseDir, 'dictionaries', filename),
        join(storeBaseDir, 'Dicionários', filename),
      ];
    }

    String? foundPath;
    if (!kIsWeb) {
      for (final p in possibleStorePaths) {
        if (await io.File(p).exists()) {
          foundPath = p;
          debugPrint('📂 Dicionário encontrado na loja: $p');
          break;
        }
      }
    }

    final dbPath = !kIsWeb
        ? await getDatabasesPath()
        : await databaseFactoryFfiWeb.getDatabasesPath();
    final path = foundPath ?? join(dbPath, filename);

    bool exists = foundPath != null;
    if (!exists) {
      if (!kIsWeb) {
        exists = await io.File(path).exists();
      } else {
        try {
          final factory = databaseFactoryFfiWeb;
          exists = await factory.databaseExists(path);
        } catch (e) {
          exists = false;
        }
      }
    }

    if (!exists) {
      try {
        if (!kIsWeb) {
          await io.Directory(dirname(path)).create(recursive: true);
        }
        final assetPath = "assets/bible/dictionaries/$filename";
        ByteData data = await rootBundle.load(assetPath);
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        if (!kIsWeb) {
          await io.File(path).writeAsBytes(bytes, flush: true);
        } else {
          final factory = databaseFactoryFfiWeb;
          await factory.writeDatabaseBytes(path, Uint8List.fromList(bytes));
        }
        print("Banco de dicionário $filename copiado.");
      } catch (e) {
        print("Erro ao copiar dicionário dos assets ($filename): $e");
        rethrow;
      }
    }

    final db = kIsWeb
        ? await databaseFactoryFfiWeb.openDatabase(
            path,
            options: OpenDatabaseOptions(readOnly: true),
          )
        : await openDatabase(path, readOnly: true);
    _databases[filename] = db;
    return db;
  }

  /// Busca o verbete num dicionário MySword
  Future<String?> getDictionaryEntry(String filename, String word) async {
    try {
      if (filename.toLowerCase().contains('strong')) {
        final db = await getStrongDatabase();
        final rows = await db.query(
          'STRONG',
          columns: ['DEFINICAO_STRONG'],
          where: 'TRADUCAO LIKE ? OR PALAVRA_ORIGINAL = ?',
          whereArgs: ['$word%', word],
          limit: 1,
        );
        if (rows.isNotEmpty) return rows.first['DEFINICAO_STRONG'] as String?;
      }

      final db = await getDictionaryDatabase(filename);
      // Os dicionários MySword têm uma tabela `dictionary` com `word` e `data`
      final List<Map<String, dynamic>> maps = await db.query(
        'dictionary',
        where:
            'word = ?', // pode ou não ser case-sensitive no sqlite dependendo da collação
        whereArgs: [word],
        limit: 1,
      );

      if (maps.isNotEmpty && maps.first['data'] != null) {
        return maps.first['data'] as String;
      }

      // Fallback: tentar busca case-insensitive (LIKE)
      final List<Map<String, dynamic>> mapsLike = await db.query(
        'dictionary',
        where: 'word LIKE ?',
        whereArgs: [word],
        limit: 1,
      );

      if (mapsLike.isNotEmpty && mapsLike.first['data'] != null) {
        return mapsLike.first['data'] as String;
      }

      return null;
    } catch (e) {
      print("Erro ao buscar verbete: $e");
      return null;
    }
  }

  /// Lista palavras que começam com uma determinada letra num dicionário
  Future<List<Map<String, dynamic>>> getDictionaryWordsByLetter(
    String filename,
    String letter,
  ) async {
    try {
      if (filename.toLowerCase().contains('strong')) {
        final db = await getStrongDatabase();
        final results = await db.query(
          'STRONG',
          where: 'TRADUCAO LIKE ?',
          whereArgs: ['$letter%'],
          orderBy: 'TRADUCAO ASC',
          limit: 100,
        );
        
        return results.map((row) {
          final word = row['TRADUCAO']?.toString() ?? '';
          
          final sb = StringBuffer();
          if (row['DEFINICAO_STRONG'] != null && row['DEFINICAO_STRONG'].toString().isNotEmpty) {
            sb.writeln('**Definição:** ${row['DEFINICAO_STRONG']}');
          }
          if (row['SIGNIFICADO'] != null && row['SIGNIFICADO'].toString().isNotEmpty) {
            sb.writeln('\n**Significado:** ${row['SIGNIFICADO']}');
          }
          if (row['ORIGEM_PALAVRA'] != null && row['ORIGEM_PALAVRA'].toString().isNotEmpty) {
            sb.writeln('\n**Origem:** ${row['ORIGEM_PALAVRA']}');
          }
          if (row['ANOTACAO'] != null && row['ANOTACAO'].toString().isNotEmpty) {
            sb.writeln('\n**Notas:** ${row['ANOTACAO']}');
          }
          
          final data = sb.toString().trim();
          
          return {
            ...row,
            'id': row['CODIGO'],
            'word': word,
            'data': data.isEmpty ? word : data,
          };
        }).toList();
      }

      final db = await getDictionaryDatabase(filename);
      final tableInfo = await _resolvedDictTableInfo(db);
      return await db.query(
        tableInfo['table']!,
        columns: ['${tableInfo['word']} as word', '${tableInfo['data']} as data'],
        where: '${tableInfo['word']} LIKE ?',
        whereArgs: ['$letter%'],
        orderBy: '${tableInfo['word']} ASC',
        limit: 200,
      );
    } catch (e) {
      print("Erro ao listar palavras por letra: $e");
      return [];
    }
  }

  /// Busca palavras no dicionário por termo parcial
  Future<List<Map<String, dynamic>>> searchDictionary(
    String filename,
    String query,
  ) async {
    try {
      if (filename.toLowerCase().contains('strong')) {
        final db = await getStrongDatabase();
        final results = await db.query(
          'STRONG',
          where: 'TRADUCAO LIKE ? OR PALAVRA_ORIGINAL LIKE ?',
          whereArgs: ['%$query%', '%$query%'],
          orderBy: 'TRADUCAO ASC',
          limit: 100,
        );
        
        return results.map((row) {
          final word = row['TRADUCAO']?.toString() ?? '';
          
          // Constrói um texto mais completo para a inserção
          final sb = StringBuffer();
          if (row['DEFINICAO_STRONG'] != null && row['DEFINICAO_STRONG'].toString().isNotEmpty) {
            sb.writeln('**Definição:** ${row['DEFINICAO_STRONG']}');
          }
          if (row['SIGNIFICADO'] != null && row['SIGNIFICADO'].toString().isNotEmpty) {
            sb.writeln('\n**Significado:** ${row['SIGNIFICADO']}');
          }
          if (row['ORIGEM_PALAVRA'] != null && row['ORIGEM_PALAVRA'].toString().isNotEmpty) {
            sb.writeln('\n**Origem:** ${row['ORIGEM_PALAVRA']}');
          }
          if (row['ANOTACAO'] != null && row['ANOTACAO'].toString().isNotEmpty) {
            sb.writeln('\n**Notas:** ${row['ANOTACAO']}');
          }
          
          final data = sb.toString().trim();
          
          return {
            ...row,
            'id': row['CODIGO'],
            'word': word,
            'data': data.isEmpty ? word : data,
          };
        }).toList();
      }

      final db = await getDictionaryDatabase(filename);
      final tableInfo = await _resolvedDictTableInfo(db);
      return await db.query(
        tableInfo['table']!,
        columns: ['${tableInfo['word']} as word', '${tableInfo['data']} as data'],
        where: '${tableInfo['word']} LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: '${tableInfo['word']} ASC',
        limit: 100,
      );
    } catch (e) {
      print("Erro ao buscar no dicionário: $e");
      return [];
    }
  }

  /// Detecta a estrutura real da tabela do dicionário (suporta variações de schema)
  Future<Map<String, String>> _resolvedDictTableInfo(Database db) async {
    // Tenta tabelas conhecidas em ordem de prioridade
    const candidates = [
      {'table': 'dictionary', 'word': 'word', 'data': 'data'},
      {'table': 'topic', 'word': 'word', 'data': 'data'},
      {'table': 'topic', 'word': 'title', 'data': 'body'},
      {'table': 'entry', 'word': 'word', 'data': 'definition'},
      {'table': 'tese', 'word': 'word', 'data': 'data'},
    ];

    for (final candidate in candidates) {
      try {
        final res = await db.rawQuery(
          'SELECT COUNT(*) as count FROM "${candidate['table']}"',
        );
        final count = Sqflite.firstIntValue(res) ?? 0;
        if (count > 0) return candidate;
      } catch (_) {}
    }

    // fallback seguro
    return {'table': 'dictionary', 'word': 'word', 'data': 'data'};
  }

  /// Retorna o total de termos que começam com a letra l
  Future<int> getDictionaryWordCountByLetter(
    String filename,
    String letter,
  ) async {
    try {
      if (filename.toLowerCase().contains('strong')) {
        final db = await getStrongDatabase();
        final res = await db.rawQuery(
          'SELECT COUNT(*) as count FROM STRONG WHERE TRADUCAO LIKE ?',
          ['$letter%'],
        );
        return Sqflite.firstIntValue(res) ?? 0;
      }

      final db = await getDictionaryDatabase(filename);
      final tableInfo = await _resolvedDictTableInfo(db);
      final res = await db.rawQuery(
        'SELECT COUNT(*) as count FROM "${tableInfo['table']}" WHERE ${tableInfo['word']} LIKE ?',
        ['$letter%'],
      );
      return Sqflite.firstIntValue(res) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Retorna o total de termos no dicionário inteiro
  Future<int> getDictionaryTotalWordCount(String filename) async {
    try {
      if (filename.toLowerCase().contains('strong')) {
        final db = await getStrongDatabase();
        final res = await db.rawQuery('SELECT COUNT(*) as count FROM STRONG');
        return Sqflite.firstIntValue(res) ?? 0;
      }

      final db = await getDictionaryDatabase(filename);
      final tableInfo = await _resolvedDictTableInfo(db);
      final res = await db.rawQuery(
        'SELECT COUNT(*) as count FROM "${tableInfo['table']}"',
      );
      return Sqflite.firstIntValue(res) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Abre o banco de dados de livros/estórias *.bok.mybible
  Future<Database?> getBookDatabase(String filename) async {
    _ensureWebFactory();
    if (_databases.containsKey(filename)) return _databases[filename]!;

    String path = filename;
    bool exists = false;

    if (kIsWeb) {
      // Na Web, o módulo só existe se foi baixado pela loja (IndexedDB)
      final dbPath = await databaseFactoryFfiWeb.getDatabasesPath();
      path = join(dbPath, filename);
      try {
        exists = await databaseFactoryFfiWeb.databaseExists(path);
      } catch (_) {
        exists = false;
      }
      if (!exists) return null; // Livros também dependem apenas do IndexedDB na web
    } else {
      // 1. Tenta buscar no diretório do 'store' (para hinos/Harpa baixados)
      final appDocDir = await getApplicationDocumentsDirectory();
      final storePath = join(appDocDir.path, 'store', filename);
      path = storePath;
      exists = await io.File(storePath).exists();
      if (exists) debugPrint('📂 Banco encontrado no store: $storePath');

      // 2. Fallback para diretório padrão de banco de dados
      if (!exists) {
        final dbPath = await getDatabasesPath();
        path = join(dbPath, filename);
        exists = await io.File(path).exists();
        if (exists) debugPrint('📂 Banco encontrado no databases: $path');
      }
    }

    if (!exists) {
      debugPrint('❌ Banco de dados não encontrado em nenhum local: $filename');
      return null;
    }

    try {
      final db = kIsWeb
          ? await databaseFactoryFfiWeb.openDatabase(
              path,
              options: OpenDatabaseOptions(readOnly: true),
            )
          : await openDatabase(path, readOnly: true);
      _databases[filename] = db;
      debugPrint('✅ Banco de dados aberto com sucesso: $path');
      return db;
    } catch (e) {
      debugPrint('❌ Erro ao abrir banco de dados: $e');
      return null;
    }
  }

  /// Busca as estórias/hinos de um livro MyBible
  Future<List<Map<String, dynamic>>> getBookStories(String filename) async {
    try {
      debugPrint('📖 Buscando estórias no arquivo: $filename');
      final db = await getBookDatabase(filename);
      if (db == null) {
        debugPrint('⚠️ DB é nulo, retornando lista vazia');
        return [];
      }

      // Tenta listar as tabelas para debug se falhar
      try {
        final result = await db.query(
          'stories',
          columns: ['id', 'title', 'text', 'ordering'],
          orderBy: 'ordering ASC, id ASC',
        );
        debugPrint('✅ Sucesso (stories): ${result.length} hinos encontrados');
        return result;
      } catch (e) {
        debugPrint(
          '⚠️ Tabela "stories" falhou, tentando fallback para "book"...',
        );
        try {
          // Fallback para tabela 'book' (comum em outros formatos)
          final result = await db.query(
            'book',
            columns: ['id', 'title', 'text'],
            orderBy: 'id ASC',
          );
          debugPrint('✅ Sucesso (book): ${result.length} hinos encontrados');
          return result;
        } catch (e2) {
          debugPrint(
            '⚠️ Tabela "book" falhou, tentando fallback final para "journal"...',
          );
          try {
            // Fallback para tabela 'journal' (encontrado no arquivo Harpa.bok.mybible do usuário)
            // Colunas reais: id, title, content
            final result = await db.rawQuery(
              'SELECT id, title, content as text FROM journal ORDER BY CAST(id AS INTEGER) ASC',
            );
            debugPrint(
              '✅ Sucesso (journal - id/content): ${result.length} hinos encontrados',
            );
            return result;
          } catch (e3) {
            debugPrint('❌ Todas as tabelas (stories/book/journal) falharam.');
            final tables = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table'",
            );
            debugPrint('📊 Tabelas reais no arquivo: $tables');
            return [];
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erro crítico ao buscar estórias: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Strong's Concordance (strongV2.db)
  // ──────────────────────────────────────────────────────────────────────────

  static const _strongKey = 'STRONG_V2';
  static const _strongAsset = 'assets/database/strongV2.db';
  static const _strongFilename = 'strongV2.db';

  /// Copia o banco `strongV2.db` do asset para o diretório de documentos
  /// (apenas na primeira vez) e o abre SEM senha.
  Future<Database> getStrongDatabase() async {
    _ensureWebFactory();
    if (_databases.containsKey(_strongKey)) return _databases[_strongKey]!;

    String destPath;
    if (!kIsWeb) {
      final appDocDir = await getApplicationDocumentsDirectory();
      destPath = join(appDocDir.path, _strongFilename);
    } else {
      final dbPath = await databaseFactoryFfiWeb.getDatabasesPath();
      destPath = join(dbPath, _strongFilename);
    }

    bool exists = false;
    if (!kIsWeb) {
      exists = await io.File(destPath).exists();
    } else {
      try {
        final factory = databaseFactoryFfiWeb;
        exists = await factory.databaseExists(destPath);
      } catch (e) {
        exists = false;
      }
    }

    // Copia uma única vez
    if (!exists) {
      debugPrint('📦 Copiando $_strongFilename dos assets...');
      try {
        final data = await rootBundle.load(_strongAsset);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        if (!kIsWeb) {
          await io.File(destPath).writeAsBytes(bytes, flush: true);
        } else {
          final factory = databaseFactoryFfiWeb;
          await factory.writeDatabaseBytes(destPath, Uint8List.fromList(bytes));
        }
        debugPrint('✅ $_strongFilename copiado para $destPath');
      } catch (e) {
        debugPrint('Erro ao copiar strong db: $e');
      }
    }

    Database db;
    if (!kIsWeb) {
      db = await openDatabase(destPath, readOnly: true);
    } else {
      db = await databaseFactoryFfiWeb.openDatabase(
        destPath,
        options: OpenDatabaseOptions(readOnly: true),
      );
    }

    _databases[_strongKey] = db;


    return db;
  }

  /// Busca um verbete pelo número Strong (ex.: 'G3056' ou 'H430').
  ///
  /// Retorna um Map com as chaves:
  ///   CODIGO, IDIOMA, PALAVRA_ORIGINAL, TRADUCAO, SIGNIFICADO,
  ///   PRONUNCIA, ORIGEM_PALAVRA, CLASSE_GRAMATICAL,
  ///   DEFINICAO_STRONG, USO_BIBLIA, ANOTACAO
  Future<Map<String, dynamic>?> getStrongEntry(String strongNumber) async {
    try {
      final db = await getStrongDatabase();

      final rows = await db.query(
        'STRONG',
        where: 'CODIGO = ?',
        whereArgs: [strongNumber.toUpperCase()],
        limit: 1,
      );

      if (rows.isNotEmpty) return rows.first;
      return null;
    } catch (e) {
      debugPrint('❌ Erro ao buscar Strong "$strongNumber": $e');
      return null;
    }
  }

  /// Fecha todos os bancos de dados abertos
  Future<void> closeAll() async {
    for (var db in _databases.values) {
      await db.close();
    }
    _databases.clear();
    _commentarySchemas.clear();
    _verseSchemas.clear();
    _commentaryHasMarker.clear();
  }
}
