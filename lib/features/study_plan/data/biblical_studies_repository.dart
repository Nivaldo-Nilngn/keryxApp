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

  /// Carrega o índice leve de estudos e categorias
  Future<List<BiblicalStudy>> loadIndex() async {
    if (_cachedIndex != null) return _cachedIndex!;

    // Tenta carregar do SQLite se disponível
    try {
      final db = await DatabaseService.instance.getEstudosDatabase();
      final rows = await db.query(
        'estudos',
        columns: ['id', 'title', 'slug', 'date', 'categories', 'excerpt'],
        orderBy: 'id DESC',
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
        return _cachedIndex!;
      }
    } catch (_) {}

    // Fallback: carregar índice json dos assets
    final jsonStr =
        await _bundle.loadString('assets/data/estudos/estudos_index.json');
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final rawPosts = data['posts'] as List<dynamic>? ?? [];
    _cachedIndex = rawPosts
        .map((p) => BiblicalStudy.fromJson(p as Map<String, dynamic>))
        .where((study) => !_isDownloadItem(study.title, study.categories))
        .toList();

    return _cachedIndex!;
  }

  /// Retorna as categorias com artigos disponíveis
  Future<List<StudyCategory>> loadCategories() async {
    if (_cachedCategories != null) return _cachedCategories!;

    // Tenta carregar do SQLite primeiro
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

    // Fallback
    final jsonStr =
        await _bundle.loadString('assets/data/estudos/estudos_index.json');
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final rawCats = data['categories'] as List<dynamic>? ?? [];
    _cachedCategories = rawCats
        .map((c) => StudyCategory.fromJson(c as Map<String, dynamic>))
        .where((c) => c.count > 0 && c.name.toLowerCase() != 'download' && c.slug.toLowerCase() != 'download')
        .toList();

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

/// Filtro de Categoria ativa (null = Todas)
final selectedStudyCategoryProvider = StateProvider<String?>((ref) => null);

/// Busca textual
final studySearchQueryProvider = StateProvider<String>((ref) => '');

/// Lista filtrada de estudos
final filteredBiblicalStudiesProvider = Provider<List<BiblicalStudy>>((ref) {
  final studiesAsync = ref.watch(biblicalStudiesIndexProvider);
  final selectedCat = ref.watch(selectedStudyCategoryProvider);
  final query = ref.watch(studySearchQueryProvider).trim().toLowerCase();

  return studiesAsync.maybeWhen(
    data: (allStudies) {
      return allStudies.where((study) {
        // Filtro de categoria
        if (selectedCat != null && selectedCat.isNotEmpty) {
          final hasCat = study.categories.any(
            (c) => c.toLowerCase() == selectedCat.toLowerCase(),
          );
          if (!hasCat) return false;
        }

        // Filtro de busca
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
