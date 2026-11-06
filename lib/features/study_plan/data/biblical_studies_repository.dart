import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/database_service.dart';
import '../domain/biblical_study.dart';

class BiblicalStudiesRepository {
  final AssetBundle _bundle;

  BiblicalStudiesRepository({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  List<BiblicalStudy>? _cachedIndex;
  List<StudyCategory>? _cachedCategories;
  final Map<int, String> _fullContentCache = {};

  bool _isDownloadItem(String title, List<String> categories) {
    final t = title.toLowerCase();
    if (t.contains('download') || t.startsWith('bíblia digital') || t.startsWith('biblia digital')) {
      return true;
    }
    return categories.any((c) => c.toLowerCase() == 'download');
  }

  /// Comparador natural inteligente de A a Z (ex: Salmo 1, Salmo 2, Salmo 4, Salmo 17, Salmo 23, Salmo 26...)
  static int naturalCompare(String a, String b) {
    final regExp = RegExp(r'(\d+|\D+)');
    final matchesA =
        regExp.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
    final matchesB =
        regExp.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();

    final minLen =
        matchesA.length < matchesB.length ? matchesA.length : matchesB.length;
    for (int i = 0; i < minLen; i++) {
      final partA = matchesA[i];
      final partB = matchesB[i];

      final numA = int.tryParse(partA);
      final numB = int.tryParse(partB);

      if (numA != null && numB != null) {
        final comp = numA.compareTo(numB);
        if (comp != 0) return comp;
      } else {
        final comp = partA.compareTo(partB);
        if (comp != 0) return comp;
      }
    }

    return matchesA.length.compareTo(matchesB.length);
  }

  void _prewarmDatabase() {
    Future.microtask(() async {
      try {
        await DatabaseService.instance.getEstudosDatabase();
      } catch (_) {}
    });
  }

  /// Carrega o índice leve de estudos e categorias de forma instantânea
  Future<List<BiblicalStudy>> loadIndex() async {
    if (_cachedIndex != null) return _cachedIndex!;

    // 1. Carregamento instantâneo a partir do índice JSON (~250KB)
    try {
      final jsonStr =
          await _bundle.loadString('assets/data/estudos/estudos_index.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final rawPosts = data['posts'] as List<dynamic>? ?? [];
      _cachedIndex = rawPosts
          .map((p) => BiblicalStudy.fromJson(p as Map<String, dynamic>))
          .where((study) => !_isDownloadItem(study.title, study.categories))
          .toList();

      // Ordena de A a Z com ordenação natural inteligente
      _cachedIndex!.sort((a, b) => naturalCompare(a.title, b.title));

      // Pré-aquece o banco SQLite em segundo plano sem travar a UI
      _prewarmDatabase();

      return _cachedIndex!;
    } catch (_) {}

    // 2. Fallback de segurança: carregar do SQLite se o JSON falhar
    try {
      final db = await DatabaseService.instance.getEstudosDatabase();
      final rows = await db.query(
        'estudos',
        columns: ['id', 'title', 'slug', 'date', 'categories', 'excerpt'],
        orderBy: 'title COLLATE NOCASE ASC',
      );
      if (rows.isNotEmpty) {
        _cachedIndex = rows.map((r) {
          List<String> cats = [];
          try {
            final raw = r['categories'] as String?;
            if (raw != null && raw.isNotEmpty) {
              cats = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
            }
          } catch (_) {}

          return BiblicalStudy(
            id: r['id'] as int,
            title: (r['title'] as String?) ?? '',
            slug: (r['slug'] as String?) ?? '',
            date: (r['date'] as String?) ?? '',
            categories: cats,
            excerpt: (r['excerpt'] as String?) ?? '',
          );
        }).where((study) => !_isDownloadItem(study.title, study.categories)).toList();

        // Ordena de A a Z com ordenação natural inteligente
        _cachedIndex!.sort((a, b) => naturalCompare(a.title, b.title));

        return _cachedIndex!;
      }
    } catch (_) {}

    return _cachedIndex ?? [];
  }

  /// Retorna as categorias com artigos disponíveis de forma instantânea
  Future<List<StudyCategory>> loadCategories() async {
    if (_cachedCategories != null) return _cachedCategories!;

    // 1. Carregamento ultra rápido do JSON
    try {
      final jsonStr =
          await _bundle.loadString('assets/data/estudos/estudos_index.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final rawCats = data['categories'] as List<dynamic>? ?? [];
      _cachedCategories = rawCats
          .map((c) => StudyCategory.fromJson(c as Map<String, dynamic>))
          .where((c) => c.count > 0 && c.name.toLowerCase() != 'download' && c.slug.toLowerCase() != 'download')
          .toList();

      return _cachedCategories!;
    } catch (_) {}

    // 2. Fallback do SQLite se necessário
    try {
      final db = await DatabaseService.instance.getEstudosDatabase();
      final rows = await db.query(
        'categorias',
        columns: ['id', 'name', 'slug', 'count'],
        where: "count > 0 AND lower(name) != 'download' AND lower(slug) != 'download'",
        orderBy: 'count DESC',
      );
      if (rows.isNotEmpty) {
        _cachedCategories = rows.map((r) {
          return StudyCategory(
            id: r['id'] as int,
            name: (r['name'] as String?) ?? '',
            slug: (r['slug'] as String?) ?? '',
            count: (r['count'] as int?) ?? 0,
          );
        }).toList();
        return _cachedCategories!;
      }
    } catch (_) {}

    return _cachedCategories ?? [];
  }

  /// Carrega o conteúdo completo de um artigo específico direto do SQLite (estudos.db)
  Future<String?> loadFullContent(int postId) async {
    if (_fullContentCache.containsKey(postId)) {
      return _fullContentCache[postId];
    }

    try {
      final dbContent =
          await DatabaseService.instance.getEstudoContentById(postId);
      if (dbContent != null && dbContent.isNotEmpty) {
        _fullContentCache[postId] = dbContent;
        return dbContent;
      }
    } catch (_) {}

    return null;
  }
}

/// Provider do repositório
final biblicalStudiesRepositoryProvider =
    Provider<BiblicalStudiesRepository>((ref) {
  return BiblicalStudiesRepository();
});

/// Provider do índice de estudos
final biblicalStudiesIndexProvider =
    FutureProvider<List<BiblicalStudy>>((ref) async {
  final repo = ref.watch(biblicalStudiesRepositoryProvider);
  return repo.loadIndex();
});

/// Provider das categorias
final studyCategoriesProvider =
    FutureProvider<List<StudyCategory>>((ref) async {
  final repo = ref.watch(biblicalStudiesRepositoryProvider);
  return repo.loadCategories();
});

/// Filtro de Grupo de Navegação ativo (ex: 'Antigo Testamento', 'Defesa da Fé', etc.; null = Todos)
final selectedStudyGroupProvider = StateProvider<String?>((ref) => null);

/// Filtro de Subcategoria específica ativa (null = Todas do grupo ou do acervo geral)
final selectedStudyCategoryProvider = StateProvider<String?>((ref) => null);

/// Busca textual
final studySearchQueryProvider = StateProvider<String>((ref) => '');

/// Lista filtrada de estudos
final filteredBiblicalStudiesProvider = Provider<List<BiblicalStudy>>((ref) {
  final studiesAsync = ref.watch(biblicalStudiesIndexProvider);
  final selectedGroup = ref.watch(selectedStudyGroupProvider);
  final selectedCat = ref.watch(selectedStudyCategoryProvider);
  final query = ref.watch(studySearchQueryProvider).trim().toLowerCase();

  return studiesAsync.maybeWhen(
    data: (allStudies) {
      return allStudies.where((study) {
        // 1. Filtro de Subcategoria específica
        if (selectedCat != null && selectedCat.isNotEmpty) {
          final hasCat = study.categories.any(
            (c) => c.toLowerCase() == selectedCat.toLowerCase(),
          );
          if (!hasCat) return false;
        } else if (selectedGroup != null && selectedGroup.isNotEmpty) {
          // 2. Filtro por Grupo Geral (ex: 'Antigo Testamento', 'Doutrinas', etc.)
          final groupObj = kStudyGroups.firstWhere(
            (g) => g.title.toLowerCase() == selectedGroup.toLowerCase(),
            orElse: () => StudySectionGroup(title: selectedGroup, subcategories: const []),
          );
          if (!groupObj.matches(study.categories)) {
            return false;
          }
        }

        // 3. Filtro de busca textual
        if (query.isNotEmpty) {
          final inTitle = study.title.toLowerCase().contains(query);
          final inExcerpt = study.excerpt.toLowerCase().contains(query);
          final inCat = study.categories.any((c) => c.toLowerCase().contains(query));
          if (!inTitle && !inExcerpt && !inCat) return false;
        }

        return true;
      }).toList();
    },
    orElse: () => [],
  );
});

/// Provider para carregar conteúdo completo de um artigo
final studyContentProvider =
    FutureProvider.family<String?, int>((ref, postId) async {
  final repo = ref.watch(biblicalStudiesRepositoryProvider);
  return repo.loadFullContent(postId);
});
