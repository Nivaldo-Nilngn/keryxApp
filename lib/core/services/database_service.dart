import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Formato da tabela de versículos de cada módulo bíblico (descoberto uma vez por banco).
enum _VerseSchema { araS, mySword, standard, myBibleVerses }

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  static DatabaseService get instance => _instance;
  DatabaseService._internal();

  final Map<String, Database> _databases = {};

  // Trava de concorrência em voo para evitar cópias simultâneas de bancos
  final Map<String, Future<Database>> _inFlightDatabases = {};
  final Map<String, Future<Database?>> _inFlightCommentaries = {};
  final Map<String, Future<Database>> _inFlightDictionaries = {};
  final Map<String, Future<Database?>> _inFlightBooks = {};
  Future<Database>? _inFlightStrongDb;
  Future<Database>? _inFlightReferencesDb;
  Future<Database>? _inFlightEstudosDb;

  // Cache em memória de caminhos de bancos resolvidos (0ms no acesso subsequente)
  final Map<String, String> _resolvedDbPaths = {};

  // Versões que comprovadamente não existem localmente (evita dezenas de databaseExists repetidos)
  final Set<String> _knownMissingVersions = {};

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

  // Cache para capas de livros em comentários (evita 66 full-text scans simultâneos)
  final Map<String, bool> _commentaryHasDataTable = {};
  final Map<String, Uint8List?> _bookCoverCache = {};

  // Cache para capítulos comentados por livro (evita consultas repetidas ao abrir seletor)
  final Map<String, List<Map<String, dynamic>>> _commentedChaptersCache = {};

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

  /// Valida se os bytes correspondem ao cabeçalho padrão de um banco SQLite 3 ("SQLite format 3\0")
  static bool isValidSqliteBytes(List<int> bytes) {
    if (bytes.length < 16) return false;
    const magic = [
      0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66, 0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00
    ];
    for (int i = 0; i < 16; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  /// Verifica se um arquivo SQLite local existe e possui cabeçalho válido
  static Future<bool> isValidSqliteFile(String filePath) async {
    try {
      final f = io.File(filePath);
      if (!await f.exists()) return false;
      if (await f.length() < 16) return false;
      final raf = await f.open(mode: io.FileMode.read);
      final header = await raf.read(16);
      await raf.close();
      return isValidSqliteBytes(header);
    } catch (_) {
      return false;
    }
  }

  /// Verifica se um banco no sistema de arquivos virtual do Sqflite Web existe e é válido
  static Future<bool> isValidSqliteWeb(String path) async {
    try {
      final factory = databaseFactoryFfiWeb;
      if (!await factory.databaseExists(path)) return false;
      final bytes = await factory.readDatabaseBytes(path);
      if (!isValidSqliteBytes(bytes)) return false;
      // Validação real tentando executar consulta teste na engine SQLite
      final testDb = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      try {
        await testDb.rawQuery('SELECT 1;');
      } finally {
        await testDb.close();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Força o reparo e exclusão de uma base de dados local ou virtual no Web caso esteja corrompida
  Future<void> forceRepairDatabase(String version) async {
    final key = version.toUpperCase();
    _resolvedDbPaths.remove(key);
    _knownMissingVersions.remove(key);
    if (_databases.containsKey(key)) {
      try {
        await _databases[key]!.close();
      } catch (_) {}
      _databases.remove(key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('web_db_ready_$key');
    await prefs.remove('db_indexed_$key');

    final dbPath = !kIsWeb
        ? await getDatabasesPath()
        : await databaseFactoryFfiWeb.getDatabasesPath();
    final candidates = [
      join(dbPath, "$key.sqlite"),
      join(dbPath, "$key.db"),
      "$key.sqlite",
      "$key.db",
      "/$key.sqlite",
      "/$key.db",
    ];

    for (final p in candidates) {
      try {
        if (kIsWeb) {
          if (await databaseFactoryFfiWeb.databaseExists(p)) {
            await databaseFactoryFfiWeb.deleteDatabase(p);
          }
        } else {
          final f = io.File(p);
          if (await f.exists()) {
            await f.delete();
          }
        }
      } catch (_) {}
    }
    debugPrint('🧹 Banco $key resetado com sucesso para recuperação limpa.');
  }

  /// Fecha e esquece a conexão em cache de um módulo.
  /// Chame antes de excluir o arquivo e depois de baixar uma versão nova,
  /// senão o app continua usando a conexão antiga.
  /// Aceita o nome do arquivo ("BEACON.cmt.mybible") ou a chave da Bíblia ("NVI").
  /// Invalida caches em memória para um banco/versão (ex: ao baixar nova versão na Loja)
  void invalidateVersion(String versionOrFilename) {
    final key = versionOrFilename.toUpperCase();
    final base = _stripExt(versionOrFilename).toUpperCase();
    _knownMissingVersions.remove(key);
    _knownMissingVersions.remove(base);
    _resolvedDbPaths.remove(key);
    _resolvedDbPaths.remove(base);
    _databases.remove(key);
    _databases.remove(base);
  }

  /// Verifica de forma instantânea se uma versão já foi resolvida ou se está faltando
  bool? isVersionKnownInstalled(String version) {
    final key = version.toUpperCase();
    if (_databases.containsKey(key) || _resolvedDbPaths.containsKey(key)) return true;
    if (_knownMissingVersions.contains(key)) return false;
    return null;
  }

  Future<void> closeDatabase(String nameOrFilename) async {
    final target = nameOrFilename.toLowerCase();
    final targetBase = _stripExt(nameOrFilename).toLowerCase();
    final targetUpper = nameOrFilename.toUpperCase();
    final targetBaseUpper = targetBase.toUpperCase();

    _knownMissingVersions.remove(targetUpper);
    _knownMissingVersions.remove(targetBaseUpper);
    _resolvedDbPaths.remove(targetUpper);
    _resolvedDbPaths.remove(targetBaseUpper);

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

  Future<Database> getDatabase(String version) {
    _ensureWebFactory();
    final key = version.toUpperCase();

    if (_databases.containsKey(key)) return SynchronousFuture(_databases[key]!);
    if (_knownMissingVersions.contains(key)) {
      return Future.error(Exception("Banco de dados da versão $version não encontrado localmente."));
    }

    if (_inFlightDatabases.containsKey(key)) {
      return _inFlightDatabases[key]!;
    }

    final future = _loadDatabaseInternal(key, version);
    _inFlightDatabases[key] = future;
    return future;
  }

  Future<Database> _loadDatabaseInternal(String key, String version) async {
    try {
      if (_resolvedDbPaths.containsKey(key)) {
        final cachedPath = _resolvedDbPaths[key]!;
        try {
          final db = kIsWeb
              ? await databaseFactoryFfiWeb.openDatabase(
                  cachedPath,
                  options: OpenDatabaseOptions(readOnly: true),
                )
              : await openDatabase(cachedPath, readOnly: true);
          _databases[key] = db;
          return db;
        } catch (_) {
          _resolvedDbPaths.remove(key);
        }
      }

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
                  final baseWithoutExt = _stripExt(eName);
                  if (eName == '$key.BBL.MYBIBLE' ||
                      eName == '$key.SQLITE' ||
                      eName == '$key.MYBIBLE' ||
                      eName == '$key.DB' ||
                      baseWithoutExt == key ||
                      baseWithoutExt.contains('($key)') ||
                      baseWithoutExt.contains(key) ||
                      key.contains(baseWithoutExt)) {
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
        final prefs = await SharedPreferences.getInstance();
        final isMarkedReady = prefs.getBool('web_db_ready_$key') == true;

        final possibleWebNames = <String>{
          '$key.sqlite',
          '$key.bbl.mybible',
          '$key.db',
          '${version.toLowerCase()}.bbl.mybible',
          '${version.toLowerCase()}.sqlite',
          '${version.toLowerCase()}.db',
          '$version.bbl.mybible',
          '$version.sqlite',
          '$version.db',
          version,
          '$version.mybible',
          '$key.mybible',
        };

        // Lê a lista de pacotes baixados em SharedPreferences para obter os nomes reais de arquivos (com case original)
        try {
          final downloadedItems = prefs.getStringList('downloaded_store_items') ?? [];
          for (final raw in downloadedItems) {
            final clean = raw.contains('/') ? raw.split('/').last : raw;
            final baseWithoutExt = _stripExt(clean).toUpperCase();
            if (baseWithoutExt == key ||
                baseWithoutExt.contains('($key)') ||
                key.contains(baseWithoutExt) ||
                baseWithoutExt.contains(key)) {
              possibleWebNames.add(clean);
              possibleWebNames.add(raw);
              possibleWebNames.add(clean.toLowerCase());
              possibleWebNames.add(clean.toUpperCase());
            }
          }
        } catch (_) {}

        for (final name in possibleWebNames) {
          final candidates = [
            join(dbPath, name),
            name,
            name.startsWith('/') ? name : '/$name',
            name.startsWith('/') ? name.substring(1) : name,
            join(dbPath, name.startsWith('/') ? name.substring(1) : name),
          ];

          for (final testPath in candidates) {
            try {
              if (await isValidSqliteWeb(testPath)) {
                path = testPath;
                exists = true;
                break;
              }
            } catch (_) {}
          }
          if (exists) break;
        }

        if (isMarkedReady && !exists) {
          debugPrint('⚠️ Flag web_db_ready_$key estava ativo, mas nenhum arquivo SQLite válido foi encontrado no Web.');
          await prefs.remove('web_db_ready_$key');
          await prefs.remove('db_indexed_$key');
        }
      } catch (e) {
        exists = false;
      }
    }

    // Auto-cura: validação profunda de cabeçalho SQLite do arquivo existente
    if (exists) {
      final isHealthy = kIsWeb
          ? await isValidSqliteWeb(path)
          : await isValidSqliteFile(path);
      if (!isHealthy) {
        debugPrint('🚨 Banco em $path é inválido ou corrompido! Purgando para recriar dos assets...');
        if (kIsWeb) {
          try {
            await databaseFactoryFfiWeb.deleteDatabase(path);
          } catch (_) {}
        } else {
          try {
            await io.File(path).delete();
          } catch (_) {}
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('web_db_ready_$key');
        await prefs.remove('db_indexed_$key');
        exists = false;
      }
    }

    if (!exists) {
      final isBuiltIn = key == 'NVI' || key == 'ARA_S';
      if (!isBuiltIn) {
        _knownMissingVersions.add(key);
        throw Exception("Banco de dados da versão $version não encontrado localmente.");
      }

      // Se não existir e for versão nativa, copia dos assets com verificação rigorosa de cabeçalho SQLite
      try {
        if (!kIsWeb) {
          await io.Directory(dirname(path)).create(recursive: true);
        }

        // Caminhos candidatos de assets por versão conhecida (garante ARA_S.db antes de qualquer outro)
        final List<String> candidateAssetPaths;
        if (key == 'ARA_S') {
          candidateAssetPaths = [
            'assets/database/ARA_S.db',
            'assets/database/ara_s.db',
            'assets/bible/sql/ARA_S.sqlite',
          ];
        } else if (key == 'NVI') {
          candidateAssetPaths = [
            'assets/bible/sql/NVI.sqlite',
            'assets/database/nvi.db',
            'assets/database/NVI.db',
          ];
        } else {
          candidateAssetPaths = [
            'assets/bible/sql/$key.sqlite',
            'assets/database/$key.db',
            'assets/database/${key.toLowerCase()}.db',
          ];
        }

        Uint8List? validBytes;
        for (final assetPath in candidateAssetPaths) {
          try {
            final data = await rootBundle.load(assetPath);
            final rawBytes = data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            );
            if (isValidSqliteBytes(rawBytes)) {
              validBytes = rawBytes;
              debugPrint('✅ Asset SQLite válido carregado para $key: $assetPath (${rawBytes.length} bytes)');
              break;
            } else {
              debugPrint('⚠️ Asset $assetPath descartado (conteúdo não-SQLite, provável HTML 404).');
            }
          } catch (_) {
            // Continua para o próximo candidato
          }
        }

        if (validBytes == null) {
          throw Exception("Nenhum binário SQLite válido encontrado para a versão nativa $key.");
        }

        if (!kIsWeb) {
          // Escreve no arquivo local (Mobile/Desktop)
          await io.File(path).writeAsBytes(validBytes, flush: true);
        } else {
          // No Web, usamos o factory para escrever no IndexedDB virtual filesystem
          final factory = databaseFactoryFfiWeb;
          await factory.writeDatabaseBytes(path, Uint8List.fromList(validBytes));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('web_db_ready_$key', true);
        }
        debugPrint("Banco de dados $key copiado para o armazenamento local com sucesso.");
      } catch (e) {
        debugPrint("Erro ao copiar banco de dados dos assets ($key): $e");
        rethrow;
      }
    }

    // Garante índices de performance na base bíblica (executado uma única vez, apenas em Mobile/Desktop)
    if (!kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('db_indexed_$key') != true) {
          final writableDb = await openDatabase(path);
          try {
            final tables = (await writableDb.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table'",
            )).map((t) => (t['name'] as String).toLowerCase()).toSet();

            if (tables.contains('verses')) {
              await writableDb.execute(
                'CREATE INDEX IF NOT EXISTS idx_verses_book_chap ON verses (book_number, chapter);',
              );
            } else if (tables.contains('verse')) {
              await writableDb.execute(
                'CREATE INDEX IF NOT EXISTS idx_verse_book_chap ON verse (book_id, chapter);',
              );
            } else if (tables.contains('versiculos')) {
              await writableDb.execute(
                'CREATE INDEX IF NOT EXISTS idx_versiculos_liv_cap ON versiculos (ver_liv_id, ver_capitulo);',
              );
            } else if (tables.contains('bible')) {
              await writableDb.execute(
                'CREATE INDEX IF NOT EXISTS idx_bible_book_chap ON Bible (Book, Chapter);',
              );
            }
          } finally {
            await writableDb.close();
          }
          await prefs.setBool('db_indexed_$key', true);
        }
      } catch (e) {
        debugPrint('Aviso ao indexar Bíblia $key: $e');
      }
    }

    // Abre o banco de dados com auto-recuperação resiliente
    Database db;
    try {
      db = kIsWeb
          ? await databaseFactoryFfiWeb.openDatabase(
              path,
              options: OpenDatabaseOptions(readOnly: true),
            )
          : await openDatabase(path, readOnly: true);
    } catch (e) {
      if (e.toString().contains('code 26') ||
          e.toString().contains('not a database') ||
          e.toString().contains('file is not a database')) {
        debugPrint('🚨 Erro "not a database" ao abrir $key ($path). Executando auto-reparo e reabrindo...');
        await forceRepairDatabase(key);
        return await _loadDatabaseInternal(key, version);
      }
      rethrow;
    }
    _databases[key] = db;
    _resolvedDbPaths[key] = path;
    _knownMissingVersions.remove(key);
    return db;
    } finally {
      _inFlightDatabases.remove(key);
    }
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
        } else if (tables.contains('verses') && !tables.contains('verse')) {
          schema = _VerseSchema.myBibleVerses;
        } else {
          schema = _VerseSchema.standard;
        }
        _verseSchemas[key] = schema;
      }

      List<Map<String, dynamic>> maps;

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
        if (maps.isEmpty && bookId <= 66) {
          maps = await db.query(
            'Bible',
            columns: ['Scripture as text'],
            where: 'Book = ? AND Chapter = ? AND Verse = ?',
            whereArgs: [bookId * 10, chapter, verse],
            limit: 1,
          );
        }
        if (maps.isNotEmpty) {
          return maps.first['text'] as String?;
        }
      } else if (schema == _VerseSchema.myBibleVerses) {
        final columns = await db.rawQuery("PRAGMA table_info(verses)");
        final colNames = columns.map((c) => (c['name'] as String).toLowerCase()).toSet();
        final bookCol = colNames.contains('book_number') ? 'book_number' : (colNames.contains('book_id') ? 'book_id' : 'book');
        maps = await db.query(
          'verses',
          columns: ['text'],
          where: '$bookCol = ? AND chapter = ? AND verse = ?',
          whereArgs: [bookId, chapter, verse],
          limit: 1,
        );
        if (maps.isEmpty && bookId <= 66) {
          maps = await db.query(
            'verses',
            columns: ['text'],
            where: '$bookCol = ? AND chapter = ? AND verse = ?',
            whereArgs: [bookId * 10, chapter, verse],
            limit: 1,
          );
        }
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
  Future<Database?> getCommentaryDatabase(String filename) {
    _ensureWebFactory();
    if (_databases.containsKey(filename)) {
      return SynchronousFuture(_databases[filename]!);
    }
    if (_inFlightCommentaries.containsKey(filename)) {
      return _inFlightCommentaries[filename]!;
    }
    final future = _loadCommentaryDatabaseInternal(filename);
    _inFlightCommentaries[filename] = future;
    return future;
  }

  Future<Database?> _loadCommentaryDatabaseInternal(String filename) async {
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
            final testData = await rootBundle.load(assetPath);
            final testBytes = testData.buffer.asUint8List(
              testData.offsetInBytes,
              testData.lengthInBytes,
            );
            if (isValidSqliteBytes(testBytes)) {
              data = testData;
              assetFoundPath = assetPath;
              break; // Encontrou!
            } else {
              debugPrint('⚠️ Comentário em $assetPath descartado (não é SQLite válido).');
            }
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
        debugPrint("Banco de comentários $filename copiado.");
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
    } finally {
      _inFlightCommentaries.remove(filename);
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
    final cacheKey = '$filename:$bookId';
    if (_commentedChaptersCache.containsKey(cacheKey)) {
      return _commentedChaptersCache[cacheKey]!;
    }

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

      final result = rows
          .map(
            (row) => {
              'chapter': (row['chapter'] as num).toInt(),
              'marker': hasMarker ? row['marker'] as String? : null,
            },
          )
          .toList();

      _commentedChaptersCache[cacheKey] = result;
      return result;
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
    final cacheKey = '$filename:$bookId';
    if (_bookCoverCache.containsKey(cacheKey)) {
      return _bookCoverCache[cacheKey];
    }

    try {
      final db = await getCommentaryDatabase(filename);
      if (db == null) {
        _bookCoverCache[cacheKey] = null;
        return null;
      }

      // 1. Checa uma única vez por banco se a tabela 'data' (imagens embutidas) sequer existe.
      // Quase todas as obras usam capas padrão do app e não possuem tabela 'data',
      // evitando 66 varreduras pesadas com LIKE no texto de cada livro!
      if (!_commentaryHasDataTable.containsKey(filename)) {
        final tables = await db.rawQuery(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name='data' LIMIT 1;",
        );
        _commentaryHasDataTable[filename] = tables.isNotEmpty;
      }

      if (_commentaryHasDataTable[filename] == false) {
        _bookCoverCache[cacheKey] = null;
        return null;
      }

      final schema = await _getCommentarySchema(db, filename);
      if (schema == null) {
        _bookCoverCache[cacheKey] = null;
        return null;
      }

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
            final imgRows = await db.query(
              'data',
              columns: ['content'],
              where: 'id = ? OR filename = ?',
              whereArgs: [imgId, imgId],
              limit: 1,
            );
            if (imgRows.isNotEmpty && imgRows.first['content'] != null) {
              final bytes = imgRows.first['content'] as Uint8List;
              _bookCoverCache[cacheKey] = bytes;
              return bytes;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Erro ao buscar capa do livro $bookId em $filename: $e");
    }
    _bookCoverCache[cacheKey] = null;
    return null;
  }

  // Abre o banco de dados de dicionários *.dct.mybible
  Future<Database> getDictionaryDatabase(String filename) {
    _ensureWebFactory();
    if (_databases.containsKey(filename)) {
      return SynchronousFuture(_databases[filename]!);
    }
    if (_inFlightDictionaries.containsKey(filename)) {
      return _inFlightDictionaries[filename]!;
    }
    final future = _loadDictionaryDatabaseInternal(filename);
    _inFlightDictionaries[filename] = future;
    return future;
  }

  Future<Database> _loadDictionaryDatabaseInternal(String filename) async {
    try {
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
        if (!isValidSqliteBytes(bytes)) {
          throw Exception("Arquivo de dicionário $filename em $assetPath não é um banco SQLite válido.");
        }

        if (!kIsWeb) {
          await io.File(path).writeAsBytes(bytes, flush: true);
        } else {
          final factory = databaseFactoryFfiWeb;
          await factory.writeDatabaseBytes(path, Uint8List.fromList(bytes));
        }
        debugPrint("Banco de dicionário $filename copiado.");
      } catch (e) {
        debugPrint("Erro ao copiar dicionário dos assets ($filename): $e");
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
    } finally {
      _inFlightDictionaries.remove(filename);
    }
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
      debugPrint("Erro ao buscar verbete: $e");
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
      debugPrint("Erro ao listar palavras por letra: $e");
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
      debugPrint("Erro ao buscar no dicionário: $e");
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
  Future<Database?> getBookDatabase(String filename) {
    _ensureWebFactory();
    if (_databases.containsKey(filename)) {
      return SynchronousFuture(_databases[filename]!);
    }
    if (_inFlightBooks.containsKey(filename)) {
      return _inFlightBooks[filename]!;
    }
    final future = _loadBookDatabaseInternal(filename);
    _inFlightBooks[filename] = future;
    return future;
  }

  Future<Database?> _loadBookDatabaseInternal(String filename) async {
    String path = filename;
    bool exists = false;

    final base = filename.contains('/') ? filename.split('/').last : filename;

    if (kIsWeb) {
      // Na Web, o módulo só existe se foi baixado pela loja (IndexedDB)
      final dbPath = await databaseFactoryFfiWeb.getDatabasesPath();
      final candidates = [
        join(dbPath, base),
        join(dbPath, filename),
        join(dbPath, 'books', base),
        base,
        filename,
      ];
      for (final cand in candidates) {
        try {
          if (await databaseFactoryFfiWeb.databaseExists(cand)) {
            path = cand;
            exists = true;
            break;
          }
        } catch (_) {}
      }
      if (!exists) return null; // Livros também dependem apenas do IndexedDB na web
    } else {
      // 1. Tenta buscar no diretório do 'store'
      final appDocDir = await getApplicationDocumentsDirectory();
      final storeCandidates = [
        join(appDocDir.path, 'store', 'books', base),
        join(appDocDir.path, 'store', filename),
        join(appDocDir.path, 'store', base),
      ];
      for (final sp in storeCandidates) {
        if (await io.File(sp).exists()) {
          path = sp;
          exists = true;
          debugPrint('📂 Banco encontrado no store: $sp');
          break;
        }
      }

      // 2. Fallback para diretório padrão de banco de dados
      if (!exists) {
        final dbPath = await getDatabasesPath();
        final dbCandidates = [
          join(dbPath, base),
          join(dbPath, filename),
        ];
        for (final dp in dbCandidates) {
          if (await io.File(dp).exists()) {
            path = dp;
            exists = true;
            debugPrint('📂 Banco encontrado no databases: $dp');
            break;
          }
        }
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
    } finally {
      _inFlightBooks.remove(filename);
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
  Future<Database> getStrongDatabase() {
    _ensureWebFactory();
    if (_databases.containsKey(_strongKey)) {
      return SynchronousFuture(_databases[_strongKey]!);
    }
    if (_inFlightStrongDb != null) {
      return _inFlightStrongDb!;
    }
    final future = _loadStrongDatabaseInternal();
    _inFlightStrongDb = future;
    return future;
  }

  Future<Database> _loadStrongDatabaseInternal() async {
    try {
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
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('web_db_ready_$_strongFilename') == true) {
          exists = true;
        } else {
          final factory = databaseFactoryFfiWeb;
          final candidates = [
            _strongFilename,
            destPath,
            _strongFilename.startsWith('/') ? _strongFilename.substring(1) : '/$_strongFilename',
          ];
          for (final c in candidates) {
            if (await factory.databaseExists(c)) {
              exists = true;
              break;
            }
          }
        }
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
        if (!isValidSqliteBytes(bytes)) {
          throw Exception("Arquivo Strong $_strongAsset não é um banco SQLite válido.");
        }

        if (!kIsWeb) {
          await io.File(destPath).writeAsBytes(bytes, flush: true);
        } else {
          final factory = databaseFactoryFfiWeb;
          await factory.writeDatabaseBytes(destPath, Uint8List.fromList(bytes));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('web_db_ready_$_strongFilename', true);
        }
        debugPrint('✅ $_strongFilename copiado para $destPath');
      } catch (e) {
        debugPrint('Erro ao copiar strong db: $e');
      }
    }

    // Garante índices de busca rápida em TRADUCAO e PALAVRA_ORIGINAL (executa uma única vez)
    try {
      final prefs = await SharedPreferences.getInstance();
      const int strongDbVer = 2;
      if (prefs.getInt('strong_db_indexed_version') != strongDbVer) {
        final writableDb = !kIsWeb
            ? await openDatabase(destPath)
            : await databaseFactoryFfiWeb.openDatabase(destPath);
        await writableDb.execute('CREATE INDEX IF NOT EXISTS idx_strong_trad ON STRONG(TRADUCAO);');
        await writableDb.execute('CREATE INDEX IF NOT EXISTS idx_strong_orig ON STRONG(PALAVRA_ORIGINAL);');
        await writableDb.close();
        await prefs.setInt('strong_db_indexed_version', strongDbVer);
      }
    } catch (e) {
      debugPrint('Aviso ao indexar strongV2.db: $e');
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
    } finally {
      _inFlightStrongDb = null;
    }
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

  // ──────────────────────────────────────────────────────────────────────────
  // Referências Bíblicas Cruzadas e Thompson (referencias.db)
  // ──────────────────────────────────────────────────────────────────────────

  static const _referencesKey = 'REFERENCIAS_DB';
  static const _referencesAsset = 'assets/database/referencias.db';
  static const _referencesFilename = 'referencias.db';

  /// Abre ou copia o banco `referencias.db` dos assets (344k referências cruzadas + Thompson).
  Future<Database> getReferencesDatabase() {
    _ensureWebFactory();
    if (_databases.containsKey(_referencesKey)) {
      return SynchronousFuture(_databases[_referencesKey]!);
    }
    if (_inFlightReferencesDb != null) {
      return _inFlightReferencesDb!;
    }
    final future = _loadReferencesDatabaseInternal();
    _inFlightReferencesDb = future;
    return future;
  }

  Future<Database> _loadReferencesDatabaseInternal() async {
    try {
      String destPath;
    if (!kIsWeb) {
      final appDocDir = await getApplicationDocumentsDirectory();
      destPath = join(appDocDir.path, _referencesFilename);
    } else {
      final dbPath = await databaseFactoryFfiWeb.getDatabasesPath();
      destPath = join(dbPath, _referencesFilename);
    }

    bool exists = false;
    if (!kIsWeb) {
      exists = await io.File(destPath).exists();
      if (exists) {
        final length = await io.File(destPath).length();
        if (length == 0) {
          try {
            await io.File(destPath).delete();
          } catch (_) {}
          exists = false;
        }
      }
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('web_db_ready_$_referencesFilename') == true) {
          exists = true;
        } else {
          final factory = databaseFactoryFfiWeb;
          final candidates = [
            _referencesFilename,
            destPath,
            _referencesFilename.startsWith('/') ? _referencesFilename.substring(1) : '/$_referencesFilename',
          ];
          for (final c in candidates) {
            if (await factory.databaseExists(c)) {
              exists = true;
              break;
            }
          }
        }
      } catch (e) {
        exists = false;
      }
    }

    if (!exists) {
      debugPrint('📦 Copiando $_referencesFilename dos assets...');
      try {
        final data = await rootBundle.load(_referencesAsset);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        if (!isValidSqliteBytes(bytes)) {
          throw Exception("Arquivo de referências $_referencesAsset não é um banco SQLite válido.");
        }

        if (!kIsWeb) {
          await io.File(destPath).writeAsBytes(bytes, flush: true);
        } else {
          final factory = databaseFactoryFfiWeb;
          await factory.writeDatabaseBytes(destPath, Uint8List.fromList(bytes));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('web_db_ready_$_referencesFilename', true);
        }
        debugPrint('✅ $_referencesFilename copiado para $destPath');
      } catch (e) {
        debugPrint('Erro ao copiar referencias db: $e');
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

    _databases[_referencesKey] = db;
    return db;
    } finally {
      _inFlightReferencesDb = null;
    }
  }

  /// Busca referências cruzadas para um versículo (ordenadas por relevância / votos).
  Future<List<Map<String, dynamic>>> getRawCrossReferences(
    int book,
    int chapter,
    int verse, {
    int limit = 50,
  }) async {
    try {
      final db = await getReferencesDatabase();
      return await db.query(
        'cross_references',
        where: 'from_b = ? AND from_c = ? AND from_v = ?',
        whereArgs: [book, chapter, verse],
        orderBy: 'votes DESC',
        limit: limit,
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar referências cruzadas: $e');
      return [];
    }
  }

  /// Busca cadeias temáticas da Bíblia Thompson para o versículo.
  Future<List<Map<String, dynamic>>> getRawThompsonChains(
    int book,
    int chapter,
    int verse,
  ) async {
    try {
      final db = await getReferencesDatabase();
      return await db.rawQuery(
        '''
        SELECT vt.topic_id, vt.topic_title, t.content AS chain_summary
        FROM thompson_verse_topics vt
        JOIN thompson_topics t ON vt.topic_id = t.topic_id
        WHERE vt.book = ? AND vt.chapter = ? AND vt.verse = ?
        ''',
        [book, chapter, verse],
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar temas Thompson: $e');
      return [];
    }
  }

  // ==========================================
  // Estudos Bíblicos Teológicos (estudos.db)
  // ==========================================
  static const _estudosKey = 'ESTUDOS_DB';
  static const _estudosAsset = 'assets/database/estudos.db';
  static const _estudosFilename = 'estudos.db';
  static const _estudosVersion = 2;

  /// Abre ou copia o banco `estudos.db` dos assets (605 estudos + 66 categorias).
  Future<Database> getEstudosDatabase() {
    _ensureWebFactory();
    if (_databases.containsKey(_estudosKey)) {
      return SynchronousFuture(_databases[_estudosKey]!);
    }
    if (_inFlightEstudosDb != null) {
      return _inFlightEstudosDb!;
    }
    final future = _loadEstudosDatabaseInternal();
    _inFlightEstudosDb = future;
    return future;
  }

  Future<Database> _loadEstudosDatabaseInternal() async {
    try {
      String destPath;
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        destPath = join(appDocDir.path, _estudosFilename);
      } else {
        final dbPath = await databaseFactoryFfiWeb.getDatabasesPath();
        destPath = join(dbPath, _estudosFilename);
      }

      final prefs = await SharedPreferences.getInstance();
      final savedVersion = prefs.getInt('estudos_db_version') ?? 1;

      bool exists = false;
      if (!kIsWeb) {
        exists = await io.File(destPath).exists();
        if (exists && savedVersion < _estudosVersion) {
          try {
            await io.File(destPath).delete();
          } catch (_) {}
          exists = false;
        } else if (exists) {
          final length = await io.File(destPath).length();
          if (length < 1024 * 1024) { // Menos de 1MB significa arquivo incompleto
            try {
              await io.File(destPath).delete();
            } catch (_) {}
            exists = false;
          }
        }
      } else {
        try {
          if (savedVersion < _estudosVersion) {
            exists = false;
          } else if (prefs.getBool('web_db_ready_estudos_v2') == true) {
            exists = true;
          } else {
            final factory = databaseFactoryFfiWeb;
            final candidates = [
              _estudosFilename,
              destPath,
              _estudosFilename.startsWith('/') ? _estudosFilename.substring(1) : '/$_estudosFilename',
            ];
            for (final c in candidates) {
              if (await factory.databaseExists(c)) {
                exists = true;
                break;
              }
            }
          }
        } catch (_) {
          exists = false;
        }
      }

      if (!exists) {
        debugPrint('📦 Copiando $_estudosFilename dos assets (v$_estudosVersion)...');
        try {
          final data = await rootBundle.load(_estudosAsset);
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          if (!isValidSqliteBytes(bytes)) {
            throw Exception("Arquivo Estudos $_estudosAsset não é um banco SQLite válido.");
          }

          if (!kIsWeb) {
            await io.File(destPath).writeAsBytes(bytes, flush: true);
          } else {
            final factory = databaseFactoryFfiWeb;
            await factory.writeDatabaseBytes(destPath, Uint8List.fromList(bytes));
            await prefs.setBool('web_db_ready_estudos_v2', true);
          }
          await prefs.setInt('estudos_db_version', _estudosVersion);
          debugPrint('✅ $_estudosFilename copiado para $destPath (v$_estudosVersion)');
        } catch (e) {
          debugPrint('Erro ao copiar estudos db: $e');
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

      _databases[_estudosKey] = db;
      return db;
    } finally {
      _inFlightEstudosDb = null;
    }
  }

  /// Retorna o conteúdo de um estudo por id diretamente do banco de dados SQLite.
  Future<String?> getEstudoContentById(int id) async {
    try {
      final db = await getEstudosDatabase();
      final rows = await db.query(
        'estudos',
        columns: ['content'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['content'] as String?;
      }
    } catch (e) {
      debugPrint('❌ Erro ao buscar estudo $id no SQLite: $e');
    }
    return null;
  }

  /// Fecha todos os bancos de dados abertos
  Future<void> closeAll() async {
    for (var db in _databases.values) {
      try {
        await db.close();
      } catch (_) {}
    }
    _databases.clear();
    _commentarySchemas.clear();
    _verseSchemas.clear();
    _commentaryHasMarker.clear();
    _commentaryHasDataTable.clear();
    _bookCoverCache.clear();
    _commentedChaptersCache.clear();
    _resolvedDbPaths.clear();
    _knownMissingVersions.clear();
  }
}
