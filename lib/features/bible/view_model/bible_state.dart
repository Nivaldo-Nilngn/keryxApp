import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/core/services/usx_service.dart';
import 'package:keryx_app/core/services/ai_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/features/home/view_model/journey_provider.dart';
import 'dart:convert';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/core/services/database_service.dart';

// Provider singleton do serviço de banco de dados
final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);

// Provider singleton do serviço offline
final bibleServiceProvider = Provider<BibleService>((ref) => BibleService());

// Provider do serviço USX (Premium)
final usxServiceProvider = Provider<UsxService>((ref) => UsxService());

// Provider do serviço de IA
final aiServiceProvider = Provider<AiService>((ref) => AiService());

// Versão selecionada pelo usuário (ex: 'NVI', 'ACF', 'ARC')
class SelectedVersionNotifier extends StateNotifier<String> {
  SelectedVersionNotifier() : super('NVI') {
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selectedVersion');
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setVersion(String version) async {
    state = version;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedVersion', version);
  }
}

final selectedVersionProvider = StateNotifierProvider<SelectedVersionNotifier, String>((ref) {
  return SelectedVersionNotifier();
});

// ID do Comentário selecionado (ex: 'MOODY', 'MACARTHUR')
final selectedCommentaryIdProvider = StateProvider<String>((ref) => 'MOODY');

/// Verifica se a versão atual possui números de Strong's
final isStrongAvailableProvider = Provider<bool>((ref) {
  final version = ref.watch(selectedVersionProvider).toUpperCase();
  return BibleService.versionsWithStrongs.contains(version) ||
      version.endsWith('_S') ||
      version.contains('STRONG');
});

// Retorna o objeto completo do comentário selecionado
final selectedCommentaryMetadataProvider = Provider<CommentaryMetadata>((ref) {
  final id = ref.watch(selectedCommentaryIdProvider);
  return BibleService.categorizedCommentaries.firstWhere(
    (c) => c.id == id,
    orElse: () => BibleService.categorizedCommentaries.first,
  );
});

// Comentário selecionado (Legado para manter compatibilidade onde usa filename)
final selectedCommentaryProvider = Provider<String>((ref) {
  return ref.watch(selectedCommentaryMetadataProvider).filename;
});

// Dicionário selecionado pelo usuário
final selectedDictionaryProvider = StateProvider<String>(
  (ref) => 'STRONG (BR).dct.mybible',
);

final dictionaryTotalTermCountProvider = FutureProvider.family<int, String>((
  ref,
  dictId,
) async {
  final dbService = ref.read(databaseServiceProvider);
  return await dbService.getDictionaryTotalWordCount(dictId);
});

final availableDictionariesListProvider = Provider<Map<String, String>>((ref) {
  final storeState = ref.watch(storeProvider);

  final downloadedDicts = storeState.availablePackages.where((item) {
    return item.category == StoreCategory.dictionaries &&
        storeState.isDownloaded(item.filename);
  }).toList();

  final map = <String, String>{};

  for (var entry in BibleService.availableDictionaries.entries) {
    if (storeState.isDownloaded(entry.value) || entry.key == 'STRONG (BR)') {
      map[entry.key] = entry.value;
    }
  }

  String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final existingFilenames = map.values.map((v) => v.toLowerCase()).toSet();
  final existingNames = map.keys.map((k) => normalize(k)).toSet();

  for (var d in downloadedDicts) {
    final normFile = d.filename.toLowerCase();
    final normName = normalize(d.name);

    if (!existingFilenames.contains(normFile) &&
        !existingNames.contains(normName)) {
      map[d.name] = d.filename;
      existingFilenames.add(normFile);
      existingNames.add(normName);
    }
  }

  return map;
});

// Query de busca no dicionário
final dictionarySearchQueryProvider = StateProvider<String>((ref) => '');

// Query de busca de livro
final bookSearchQueryProvider = StateProvider<String>((ref) => '');

// Provider que carrega os 66 livros da versão selecionada
final booksProvider = FutureProvider<List<BibleBook>>((ref) async {
  final bibleService = ref.watch(bibleServiceProvider);
  final version = ref.watch(selectedVersionProvider);
  return bibleService.getBooks(version: version);
});

/// Parâmetros do capítulo usando Record (Dart 3) para garantir igualdade por valor.
/// (abbrev, chapter, version) — Records implementam == e hashCode corretamente.
typedef ChapterParams = ({String abbrev, int chapter, String version});

// Provider para capítulo específico com chave imutável (Record do Dart 3)
final currentChapterProvider =
    FutureProvider.family<BibleChapter, ChapterParams>((ref, params) async {
      final bibleService = ref.watch(bibleServiceProvider);
      return bibleService.getChapter(
        params.version,
        params.abbrev,
        params.chapter,
      );
    });

/// Parâmetros para comparação de versículos
typedef CompareParams = ({
  String bookId,
  int chapter,
  int verse,
  String versionsStr,
});

// Provider para comparar um versículo em múltiplas versões
final compareVersesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, CompareParams>((
      ref,
      params,
    ) async {
      final bibleService = ref.watch(bibleServiceProvider);
      return bibleService.getVerseAcrossVersions(
        bookId: params.bookId,
        chapter: params.chapter,
        verse: params.verse,
        versions: params.versionsStr.split(','),
      );
    });

// Provider que retorna o conjunto de versículos que possuem comentário no capítulo atual
final chapterCommentaryStatusProvider =
    FutureProvider.family<Set<int>, ChapterParams>((ref, params) async {
      final bibleService = ref.watch(bibleServiceProvider);
      final commentary = ref.watch(selectedCommentaryMetadataProvider);

      // params.abbrev é numérico ("1", "40") — usa diretamente como bookId
      final bookId = int.tryParse(params.abbrev) ?? 1;

      print(
        '[DEBUG commentary] abbrev=${params.abbrev} bookId=$bookId chapter=${params.chapter} commentary=${commentary.id}',
      );
      final result = await bibleService.getCommentedVerses(
        filename: commentary.filename,
        versionId: commentary.id,
        bookId: bookId,
        chapter: params.chapter,
      );
      print('[DEBUG commentary] resultado: $result');
      return result;
    });

final availableCommentariesForChapterProvider =
    FutureProvider.family<List<CommentaryMetadata>, ChapterParams>((
      ref,
      params,
    ) async {
      // Reutiliza a lógica do provider principal
      return ref.read(availableCommentariesProvider((
        abbrev: params.abbrev,
        bookId: BibleMetadata.findBookId(params.abbrev),
        bookName: '', // nome do livro não é estritamente necessário aqui se o bookId estiver correto
      )));
    });

final availableCommentariesForVerseProvider =
    FutureProvider.family<
      List<CommentaryMetadata>,
      ({String abbrev, int chapter, int verse})
    >((ref, params) async {
      // Reutiliza a lógica do provider principal
      return ref.read(availableCommentariesProvider((
        abbrev: params.abbrev,
        bookId: BibleMetadata.findBookId(params.abbrev),
        bookName: '', 
      )));
    });

// Provider dedicado para Análise de IA (rápido e independente)
final aiAnalysisProvider =
    FutureProvider.family<
      String,
      ({String bookName, String abbrev, int chapter, List<int> verses})
    >((ref, params) async {
      final bibleService = ref.watch(bibleServiceProvider);
      final aiService = ref.watch(aiServiceProvider);

      // Pega o texto de todos os versículos selecionados
      final StringBuffer allText = StringBuffer();
      for (final v in params.verses) {
        final text = await bibleService.getVerseText(
          version: 'NVI', // TODO: Poderia usar a versão atual
          bookId: BibleMetadata.findBookId(params.abbrev),
          chapter: params.chapter,
          verse: v,
        );
        allText.write('[$v] $text ');
      }

      final verseRange = params.verses.length == 1 
          ? '${params.verses.first}' 
          : '${params.verses.first}-${params.verses.last}';

      return await aiService.analyzeVerseTheology(
        "${params.bookName} ${params.chapter}:$verseRange",
        allText.toString().trim(),
      );
    });

typedef UnifiedCommentaryResult = ({CommentaryMetadata metadata, String text});

// Provider que retorna a lista de metadados disponíveis para o carrossel (mesclando pré-definidos com baixados da loja)
final availableCommentariesProvider =
    Provider.family<
      List<CommentaryMetadata>,
      ({String abbrev, int bookId, String bookName})
    >((ref, params) {

      // Busca itens baixados da loja que são comentários (várias subcategorias)
      final storeState = ref.watch(storeProvider);
      final downloadedItems = storeState.availablePackages.where((item) {
        final isStudyItem =
            item.category == StoreCategory.commentaries ||
            item.category == StoreCategory.expository ||
            item.category == StoreCategory.homiletics ||
            item.category == StoreCategory.culture;
        return isStudyItem && storeState.isDownloaded(item.filename);
      }).toList();

      // Converte itens da loja para CommentaryMetadata
      final storeMetas = downloadedItems.map((item) {
        // Tenta detectar se o comentário é específico para o livro atual baseado no nome
        final isSpecificToBook = item.name.toLowerCase().contains(
          params.bookName.toLowerCase(),
        );

        return CommentaryMetadata(
          name: item.name,
          id: item.filename,
          filename: item.filename,
          category: isSpecificToBook
              ? CommentaryCategory.especifico
              : CommentaryCategory.geral,
          bookId: isSpecificToBook ? params.bookId : null,
          storeCategoryName: item.categoryDisplayName,
        );
      }).toList();

      // Remove duplicatas por filename (baseando-se apenas no nome do arquivo, sem pasta)
      final seenFilenames = <String>{};
      final result = <CommentaryMetadata>[];

      final sourceList = storeMetas;

      for (final meta in sourceList) {
        final baseFilename = meta.filename.split('/').last;

        // Só exibe se estiver baixado na Loja
        if (!storeState.isDownloaded(meta.filename)) {
          continue;
        }

        if (meta.category == CommentaryCategory.especifico &&
            meta.bookId != params.bookId) {
          continue;
        }

        if (!seenFilenames.contains(baseFilename)) {
          seenFilenames.add(baseFilename);
          result.add(meta);
        }
      }

      return result;
    });

typedef VerseCoverageParams = ({
  String abbrev,
  int bookId,
  String bookName,
  int chapter,
  int startVerse,
  int endVerse,
});

/// Provider inteligente que retorna APENAS os comentários baixados que realmente
/// contêm notas para o versículo selecionado
final relevantCommentariesForVersesProvider =
    FutureProvider.family<List<CommentaryMetadata>, VerseCoverageParams>((
      ref,
      params,
    ) async {
      final bibleService = ref.read(bibleServiceProvider);
      final storeState = ref.watch(storeProvider);

      final allMetas = ref.watch(
        availableCommentariesProvider((
          abbrev: params.abbrev,
          bookId: params.bookId,
          bookName: params.bookName,
        )),
      );

      final downloaded = allMetas.where((meta) {
        return storeState.isDownloaded(meta.filename);
      }).toList();

      if (downloaded.isEmpty) return [];

      final verseList = [
        for (int v = params.startVerse; v <= params.endVerse; v++) v,
      ];

      final checkFutures = downloaded.map((meta) async {
        try {
          final hasNotes = await bibleService.hasCommentaryForVerses(
            filename: meta.filename,
            versionId: meta.id,
            bookId: params.bookId,
            chapter: params.chapter,
            verses: verseList,
          );
          return hasNotes ? meta : null;
        } catch (_) {
          return null;
        }
      });

      final results = await Future.wait(checkFutures);
      return results.whereType<CommentaryMetadata>().toList();
    });

/// Provider que retorna os comentários que cobrem qualquer parte do livro
final bookCoveringCommentariesProvider =
    FutureProvider.family<
      List<CommentaryMetadata>,
      ({String abbrev, int bookId, String bookName})
    >((ref, params) async {
      final bibleService = ref.watch(bibleServiceProvider);
      final storeState = ref.watch(storeProvider);

      final allMetas = ref.watch(availableCommentariesProvider(params));

      final downloaded = allMetas.where((meta) {
        return storeState.isDownloaded(meta.filename);
      }).toList();

      if (downloaded.isEmpty) return [];

      final checkFutures = downloaded.map((meta) async {
        final covers = await bibleService.hasCommentaryForBook(
          filename: meta.filename,
          bookId: params.bookId,
        );
        return covers ? meta : null;
      });

      final results = await Future.wait(checkFutures);
      return results.whereType<CommentaryMetadata>().toList();
    });

typedef CommentaryParams = ({
  String filename,
  String id,
  int bookId,
  int chapter,
  int verse,
});

// Provider para carregar o texto de um comentário específico
final verseCommentaryProvider =
    FutureProvider.family<String?, CommentaryParams>((ref, params) async {
      final bibleService = ref.watch(bibleServiceProvider);
      return bibleService.getCommentaryForVerse(
        filename: params.filename,
        versionId: params.id,
        bookId: params.bookId,
        chapter: params.chapter,
        verse: params.verse,
      );
    });

// Provider para buscar blocos únicos de comentários por capítulo (para a view em lista inteira)
final chapterCommentariesProvider =
    FutureProvider.family<
      List<({int fromVerse, int toVerse, String text})>,
      CommentaryParams
    >((ref, params) async {
      final dbService = ref.read(databaseServiceProvider);
      return dbService.getChapterCommentaries(
        params.filename,
        params.bookId,
        params.chapter,
      );
    });

// Provider para buscar os IDs de livros que possuem algum comentário em uma obra específica
final commentedBooksProvider = FutureProvider.family<Set<int>, String>((
  ref,
  filename,
) async {
  final bibleService = ref.watch(bibleServiceProvider);
  return bibleService.getCommentedBooks(filename);
});

final commentedChaptersDetailProvider =
    FutureProvider.family<
      List<Map<String, dynamic>>,
      ({String filename, int bookId})
    >((ref, params) async {
      final service = ref.watch(bibleServiceProvider);
      return await service.getCommentedChaptersDetail(
        params.filename,
        params.bookId,
      );
    });

// Provider para buscar a capa de um livro específico do comentário (se houver no banco)
final commentaryBookCoverProvider =
    FutureProvider.family<Uint8List?, ({String filename, int bookId})>((
      ref,
      params,
    ) async {
      final service = ref.watch(bibleServiceProvider);
      return service.getBookCoverImage(params.filename, params.bookId);
    });

// Provider para saber se a lista de livros no seletor de comentários é curta (para travar navbar)
final isCommentaryBookListShortProvider = StateProvider<bool>((ref) => false);

// Provider para buscar os versículos comentados em um capítulo (para leitura contínua)
final commentedVersesProvider =
    FutureProvider.family<
      Set<int>,
      ({String filename, String versionId, int bookId, int chapter})
    >((ref, params) async {
      final bibleService = ref.watch(bibleServiceProvider);
      return bibleService.getCommentedVerses(
        filename: params.filename,
        versionId: params.versionId,
        bookId: params.bookId,
        chapter: params.chapter,
      );
    });

typedef XRefParams = ({String bookId, int chapter, int verse});

// Provider para carregar referências cruzadas de um versículo
final verseXRefsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, XRefParams>((
      ref,
      params,
    ) async {
      final bibleService = ref.watch(bibleServiceProvider);
      final intBookId = int.tryParse(params.bookId) ?? 0;
      return bibleService.getXRefsForVerse(
        intBookId,
        params.chapter,
        params.verse,
      );
    });

typedef DictionaryParams = ({String dictId, String word});

/// Busca um verbete Strong diretamente no banco local [strongV2.db].
/// Retorna uma String formatada pronta para exibir, ou null se não encontrado.
final strongLocalProvider = FutureProvider.family<String?, String>((
  ref,
  code,
) async {
  final dbService = DatabaseService();
  final entry = await dbService.getStrongEntry(code);
  if (entry == null) return null;

  final palavra = entry['PALAVRA_ORIGINAL'] ?? '';
  final traducao = entry['TRADUCAO'] ?? '';
  final pronuncia = entry['PRONUNCIA'] != null
      ? ' [${entry['PRONUNCIA']}]'
      : '';
  final classe = entry['CLASSE_GRAMATICAL'] != null
      ? '\n${entry['CLASSE_GRAMATICAL']}'
      : '';
  final significado = entry['SIGNIFICADO'] ?? '';
  final definicao = entry['DEFINICAO_STRONG'] ?? '';
  final anotacao = entry['ANOTACAO'] ?? '';

  final buffer = StringBuffer();
  if (palavra.isNotEmpty) {
    buffer.writeln('$palavra — $traducao$pronuncia$classe');
  }
  if (significado.isNotEmpty) buffer.writeln('\n$significado');
  if (definicao.isNotEmpty) buffer.writeln('\n📖 $definicao');
  if (anotacao.isNotEmpty) buffer.writeln('\n💡 $anotacao');
  return buffer.toString().trim();
});

// Provider para carregar uma entrada do dicionário com fallback IA
final dictionaryProvider = FutureProvider.family<String?, DictionaryParams>((
  ref,
  params,
) async {
  final bibleService = ref.watch(bibleServiceProvider);
  final query = params.word.trim();
  if (query.isEmpty) return null;

  // 1. Prioridade máxima: banco local strongV2.db (offline, sem rede)
  final isStrongCode = RegExp(
    r'^[GH]\d+$',
    caseSensitive: false,
  ).hasMatch(query);
  if (isStrongCode) {
    final local = await ref.read(strongLocalProvider(query).future);
    if (local != null && local.trim().isNotEmpty) return local;
  }

  // 2. Tenta dicionário .dct.mybible offline
  final offline = await bibleService.getDictionaryEntry(params.dictId, query);
  if (offline != null && offline.trim().isNotEmpty) return offline;

  // 3. Fallback IA
  final aiService = AiService();
  if (isStrongCode) {
    return aiService.getStrongDefinition(query, "Termo isolado");
  }
  return aiService.getDictionarySummary(query);
});

// Provider para listar palavras de um dicionário por letra
final dictionaryLetterWordsProvider =
    FutureProvider.family<
      List<Map<String, dynamic>>,
      ({String dictId, String letter})
    >((ref, params) async {
      final bibleService = ref.watch(bibleServiceProvider);
      return bibleService.getDictionaryWordsByLetter(
        params.dictId,
        params.letter,
      );
    });

// Provider para buscar termos no dicionário (Busca Global)
final dictionarySearchWordsProvider =
    FutureProvider.family<
      List<Map<String, dynamic>>,
      ({String dictId, String query})
    >((ref, params) async {
      if (params.query.isEmpty) return [];

      final bibleService = ref.watch(bibleServiceProvider);
      final dictsMap = ref.watch(availableDictionariesListProvider);

      List<Map<String, dynamic>> allResults = [];

      // Realiza a busca em todos os dicionários disponíveis
      for (final entry in dictsMap.entries) {
        final dictName = entry.key;
        final dictFile = entry.value;

        try {
          final results = await bibleService.searchDictionary(
            dictFile,
            params.query,
          );
          // Adiciona a origem para exibição na UI
          final mutableResults = results.map((r) {
            return Map<String, dynamic>.from(r)..['source_dictionary'] = dictName;
          }).toList();
          allResults.addAll(mutableResults);
        } catch (_) {}
      }

      // Remover duplicatas exatas se houver (mesmo termo e conteúdo)
      final seen = <String>{};
      final uniqueResults = <Map<String, dynamic>>[];
      for (var r in allResults) {
        final key = '${r['word']}_${r['data']}';
        if (!seen.contains(key)) {
          seen.add(key);
          uniqueResults.add(r);
        }
      }

      return uniqueResults;
    });

// Provider para contar termos por letra
final dictionaryLetterCountProvider =
    FutureProvider.family<int, ({String dictId, String letter})>((
      ref,
      params,
    ) async {
      final bibleService = ref.watch(bibleServiceProvider);
      return bibleService.getDictionaryWordCountByLetter(
        params.dictId,
        params.letter,
      );
    });

// Provider para buscar concordância de um código Strong dinamicamente

// Provider para carregar o capítulo com formatação rica (USX)
final richChapterProvider =
    FutureProvider.family<List<Map<String, dynamic>>, ChapterParams>((
      ref,
      params,
    ) async {
      final usxService = ref.watch(usxServiceProvider);
      return usxService.getChapterRichText(
        params.version,
        int.tryParse(params.abbrev) ?? 1,
        params.chapter,
      );
    });

// Estado para marcações de cores nos versículos (chave = "Livro_Capitulo_Versiculo", valor = cor em Inteiro)
final highlightsProvider =
    StateNotifierProvider<HighlightsNotifier, Map<String, int>>((ref) {
      final userAsync = ref.watch(authStateProvider);
      return HighlightsNotifier(userAsync.value?.uid);
    });

class HighlightsNotifier extends StateNotifier<Map<String, int>> {
  final String? userId;

  HighlightsNotifier(this.userId) : super({}) {
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    if (userId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('highlights')
          .get();

      final Map<String, int> loaded = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['color'] != null) {
          loaded[doc.id] = data['color'] as int;
        }
      }
      state = loaded;
    } catch (e) {
      print('Erro ao carregar highlights: $e');
    }
  }

  void toggleHighlight(String key, int colorValue) {
    if (state.containsKey(key) && state[key] == colorValue) {
      final newState = Map<String, int>.from(state)..remove(key);
      state = newState;

      if (userId != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('highlights')
            .doc(key)
            .delete();
      }
    } else {
      final newState = Map<String, int>.from(state)..[key] = colorValue;
      state = newState;

      if (userId != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('highlights')
            .doc(key)
            .set({
              'color': colorValue,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
    }
  }
}

// Estado para versículos favoritos (chave = "Livro_Capitulo_Versiculo")
final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (ref) {
    final userAsync = ref.watch(authStateProvider);
    return FavoritesNotifier(userAsync.value?.uid);
  },
);

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final String? userId;

  FavoritesNotifier(this.userId) : super({}) {
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    if (userId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      final Set<String> loaded = {};
      for (var doc in snapshot.docs) {
        loaded.add(doc.id);
      }
      state = loaded;
    } catch (e) {
      print('Erro ao carregar favoritos: $e');
    }
  }

  void toggleFavorite(String key) {
    if (state.contains(key)) {
      final newState = Set<String>.from(state)..remove(key);
      state = newState;

      if (userId != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .doc(key)
            .delete();
      }
    } else {
      final newState = Set<String>.from(state)..add(key);
      state = newState;

      if (userId != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .doc(key)
            .set({'updatedAt': FieldValue.serverTimestamp()});
      }
    }
  }
}

// Estado para anotações em texto (chave = "Livro_Capitulo_Versiculo", valor = texto)
final annotationsProvider =
    StateNotifierProvider<AnnotationsNotifier, Map<String, String>>((ref) {
      final userAsync = ref.watch(authStateProvider);
      return AnnotationsNotifier(userAsync.value?.uid);
    });

class AnnotationsNotifier extends StateNotifier<Map<String, String>> {
  final String? userId;

  AnnotationsNotifier(this.userId) : super({}) {
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    if (userId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('annotations')
          .get();

      final Map<String, String> loaded = {};
      for (var doc in snapshot.docs) {
        loaded[doc.id] = doc.data()['text'] as String;
      }
      state = loaded;
    } catch (e) {
      debugPrint('Erro ao carregar annotations: $e');
    }
  }

  void saveAnnotation(String key, String text) {
    if (text.trim().isEmpty) {
      removeAnnotation(key);
      return;
    }
    final newState = Map<String, String>.from(state)..[key] = text;
    state = newState;

    if (userId != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('annotations')
          .doc(key)
          .set({'text': text, 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  void removeAnnotation(String key) {
    if (state.containsKey(key)) {
      final newState = Map<String, String>.from(state)..remove(key);
      state = newState;

      if (userId != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('annotations')
            .doc(key)
            .delete();
      }
    }
  }
}

// Classe para armazenar os dados de última leitura
class LastReadData {
  final BibleBook book;
  final int chapter;
  final int? verse;

  LastReadData({required this.book, required this.chapter, this.verse});

  Map<String, dynamic> toJson() => {'book': book.toJson(), 'chapter': chapter, 'verse': verse};

  factory LastReadData.fromJson(Map<String, dynamic> json) => LastReadData(
    book: BibleBook.fromJson(json['book']),
    chapter: json['chapter'],
    verse: json['verse'] as int?,
  );
}

// Provider para o estado da última leitura - agora com sincronização Firebase!
final lastReadProvider = StateNotifierProvider<LastReadNotifier, LastReadData?>(
  (ref) {
    final authAsync = ref.watch(authStateProvider);
    return LastReadNotifier(authAsync.value?.uid);
  },
);

class LastReadNotifier extends StateNotifier<LastReadData?> {
  final String? userId;

  LastReadNotifier(this.userId) : super(null) {
    _init();
  }

  Future<void> _init() async {
    // 1. Prioridade inicial: Local (mais rápido)
    await _loadLocal();

    // 2. Sincronização secundária: Firebase (se logado)
    if (userId != null) {
      await _loadFromFirestore();
    }
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('lastRead');
    if (jsonString != null) {
      try {
        state = LastReadData.fromJson(jsonDecode(jsonString));
      } catch (e) {
        debugPrint('Erro ao carregar last read local: $e');
      }
    }
  }

  Future<void> _loadFromFirestore() async {
    if (userId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && doc.data()?['lastRead'] != null) {
        final lastReadData = LastReadData.fromJson(doc.data()!['lastRead']);

        // Só atualiza o estado se for diferente do local (e salva o local de volta se necessário)
        if (state == null ||
            state!.book.abbrev != lastReadData.book.abbrev ||
            state!.chapter != lastReadData.chapter) {
          state = lastReadData;
          _saveLocal(lastReadData);
        }
      }
    } catch (e) {
      debugPrint('Erro ao sincronizar last read do Firebase: $e');
    }
  }

  Future<void> save(BibleBook book, int chapter, {int? verse}) async {
    final data = LastReadData(book: book, chapter: chapter, verse: verse);
    state = data;

    // Salva Local
    await _saveLocal(data);

    // Salva Firebase
    if (userId != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'lastRead': data.toJson(),
          'lastReadAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Erro ao salvar last read no Firebase: $e');
      }
    }

    // Registra atividade na jornada do usuário
    await JourneyNotifier.recordActivityStatic();
  }

  Future<void> _saveLocal(LastReadData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastRead', jsonEncode(data.toJson()));
  }
}

// Classe para armazenar os dados da última leitura de comentário
class LastCommentaryReadData {
  final BibleBook book;
  final int chapter;
  final CommentaryMetadata metadata;

  LastCommentaryReadData({
    required this.book,
    required this.chapter,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'book': book.toJson(),
    'chapter': chapter,
    'metadata': {
      'name': metadata.name,
      'id': metadata.id,
      'filename': metadata.filename,
      'category': metadata.category.index,
      'bookId': metadata.bookId,
    },
  };

  factory LastCommentaryReadData.fromJson(Map<String, dynamic> json) =>
      LastCommentaryReadData(
        book: BibleBook.fromJson(json['book']),
        chapter: json['chapter'],
        metadata: CommentaryMetadata(
          name: json['metadata']['name'],
          id: json['metadata']['id'],
          filename: json['metadata']['filename'],
          category: CommentaryCategory.values[json['metadata']['category']],
          bookId: json['metadata']['bookId'],
        ),
      );
}

// Provider para o estado do último comentário lido
final lastCommentaryReadProvider =
    StateNotifierProvider<LastCommentaryReadNotifier, LastCommentaryReadData?>((
      ref,
    ) {
      final authAsync = ref.watch(authStateProvider);
      return LastCommentaryReadNotifier(authAsync.value?.uid);
    });

class LastCommentaryReadNotifier
    extends StateNotifier<LastCommentaryReadData?> {
  final String? userId;

  LastCommentaryReadNotifier(this.userId) : super(null) {
    _init();
  }

  Future<void> _init() async {
    await _loadLocal();
    if (userId != null) {
      await _loadFromFirestore();
    }
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('lastCommentaryRead');
    if (jsonString != null) {
      try {
        state = LastCommentaryReadData.fromJson(jsonDecode(jsonString));
      } catch (e) {
        debugPrint('Erro ao carregar last commentary read local: $e');
      }
    }
  }

  Future<void> _loadFromFirestore() async {
    if (userId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && doc.data()?['lastCommentaryRead'] != null) {
        final data = LastCommentaryReadData.fromJson(
          doc.data()!['lastCommentaryRead'],
        );
        if (state == null ||
            state!.book.abbrev != data.book.abbrev ||
            state!.chapter != data.chapter ||
            state!.metadata.id != data.metadata.id) {
          state = data;
          _saveLocal(data);
        }
      }
    } catch (e) {
      debugPrint('Erro ao sincronizar last commentary read do Firebase: $e');
    }
  }

  Future<void> save(
    BibleBook book,
    int chapter,
    CommentaryMetadata metadata,
  ) async {
    final data = LastCommentaryReadData(
      book: book,
      chapter: chapter,
      metadata: metadata,
    );
    state = data;

    await _saveLocal(data);

    if (userId != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'lastCommentaryRead': data.toJson(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Erro ao salvar last commentary read no Firebase: $e');
      }
    }
  }

  Future<void> _saveLocal(LastCommentaryReadData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastCommentaryRead', jsonEncode(data.toJson()));
  }
}

enum AppThemeMode { light, dark, sepia, paper }

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode');
    if (saved != null) {
      try {
        state = AppThemeMode.values.firstWhere((e) => e.name == saved);
      } catch (_) {
        state = AppThemeMode.dark;
      }
    }
  }

  void setTheme(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  // Mantido para compatibilidade se algo ainda chamar toggle()
  void toggle() {
    if (state == AppThemeMode.dark) {
      setTheme(AppThemeMode.light);
    } else {
      setTheme(AppThemeMode.dark);
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>(
      (ref) => ThemeModeNotifier(),
    );

// ─── Visibilidade de Strongs (Exibir / Ocultar) ──────────────────────────────
class StrongsVisibilityNotifier extends StateNotifier<bool> {
  StrongsVisibilityNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('showStrongs') ?? true;
  }

  void toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showStrongs', state);
  }
}

final showStrongsProvider =
    StateNotifierProvider<StrongsVisibilityNotifier, bool>(
      (ref) => StrongsVisibilityNotifier(),
    );

// Provider para análise teológica do versículo com IA
final verseTheologyProvider =
    FutureProvider.family<String, ({String reference, String text})>((
      ref,
      params,
    ) async {
      final aiService = AiService();
      return aiService.analyzeVerseTheology(params.reference, params.text);
    });

// ─── Versículo do Dia ──────────────────────────────────────────────
class VerseOfDay {
  final String text;
  final String reference;
  final String bookAbbrev;
  final int chapter;

  VerseOfDay({
    required this.text,
    required this.reference,
    required this.bookAbbrev,
    required this.chapter,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'reference': reference,
    'bookAbbrev': bookAbbrev,
    'chapter': chapter,
  };

  factory VerseOfDay.fromJson(Map<String, dynamic> json) => VerseOfDay(
    text: json['text'],
    reference: json['reference'],
    bookAbbrev: json['bookAbbrev'],
    chapter: json['chapter'],
  );
}

// ─── Versículo do Dia (Sincronizado Globalmente via Firebase) ────────────────
final verseOfDayProvider = FutureProvider<VerseOfDay>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now().toIso8601String().substring(0, 10);

  // 1. Tenta carregar do Cache Local (rápido)
  final savedDate = prefs.getString('verse_of_day_date');
  final savedData = prefs.getString('verse_of_day_data');
  if (savedDate == today && savedData != null) {
    try {
      return VerseOfDay.fromJson(jsonDecode(savedData));
    } catch (_) {}
  }

  // 2. Tenta carregar do Firebase (Sincronização entre todos os usuários)
  final firestore = FirebaseFirestore.instance;
  final globalRef = firestore.collection('public').doc('verse_of_day');

  try {
    final doc = await globalRef.get();

    if (doc.exists) {
      final data = doc.data()!;
      final firebaseDate = data['date'] as String;

      if (firebaseDate == today) {
        // Usa o versículo que já foi gerado por outro usuário hoje
        final verse = VerseOfDay.fromJson(data['verse']);
        await _saveVerseLocal(prefs, today, verse);
        return verse;
      }
    }

    // 3. Se chegamos aqui, ninguém gerou o versículo de HOJE ainda
    // Vamos gerar um novo e salvar no Firebase para todo mundo ver o mesmo
    final bibleService = BibleService();
    final randomVerse = await bibleService.getRandomVerse('NVI');

    final verse = VerseOfDay(
      text: randomVerse['text'],
      reference:
          "${randomVerse['book_name']} ${randomVerse['chapter']}:${randomVerse['verse_number']}",
      bookAbbrev: randomVerse['book_id'],
      chapter: randomVerse['chapter'],
    );

    // Salva no Firebase globalmente
    await globalRef.set({
      'date': today,
      'verse': verse.toJson(),
      'generatedAt': FieldValue.serverTimestamp(),
    });

    // Salva Localmente também
    await _saveVerseLocal(prefs, today, verse);
    return verse;
  } catch (e) {
    debugPrint('Erro ao sincronizar versículo global: $e');
    // Fallback: se houver erro de rede, tenta usar o que tiver salvo ou o João 3:16
    if (savedData != null) return VerseOfDay.fromJson(jsonDecode(savedData));
    return VerseOfDay(
      text:
          "Porque Deus amou o mundo de tal maneira que deu o seu Filho unigênito, para que todo aquele que nele crê não pereça, mas tenha a vida eterna.",
      reference: "João 3:16",
      bookAbbrev: "43",
      chapter: 3,
    );
  }
});

Future<void> _saveVerseLocal(
  SharedPreferences prefs,
  String date,
  VerseOfDay verse,
) async {
  await prefs.setString('verse_of_day_date', date);
  await prefs.setString('verse_of_day_data', jsonEncode(verse.toJson()));
}

class RecentBooksNotifier extends StateNotifier<List<String>> {
  RecentBooksNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_books') ?? [];
    state = list;
  }

  void add(String abbrev) async {
    final list = List<String>.from(state);
    list.remove(abbrev);
    list.insert(0, abbrev);
    if (list.length > 6) {
      list.removeLast();
    }
    state = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_books', list);
  }
}

final recentBooksProvider =
    StateNotifierProvider<RecentBooksNotifier, List<String>>((ref) {
      return RecentBooksNotifier();
    });


