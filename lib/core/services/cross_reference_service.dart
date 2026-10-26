import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/core/services/database_service.dart';

class CrossReferenceVerse {
  final int targetBookId;
  final String targetBookName;
  final int targetChapter;
  final int targetVerseStart;
  final int targetVerseEnd;
  final int votes;
  final String? verseText;

  const CrossReferenceVerse({
    required this.targetBookId,
    required this.targetBookName,
    required this.targetChapter,
    required this.targetVerseStart,
    required this.targetVerseEnd,
    required this.votes,
    this.verseText,
  });

  String get displayReference {
    if (targetVerseStart == targetVerseEnd) {
      return '$targetBookName $targetChapter:$targetVerseStart';
    }
    return '$targetBookName $targetChapter:$targetVerseStart-$targetVerseEnd';
  }

  CrossReferenceVerse copyWithText(String text) {
    return CrossReferenceVerse(
      targetBookId: targetBookId,
      targetBookName: targetBookName,
      targetChapter: targetChapter,
      targetVerseStart: targetVerseStart,
      targetVerseEnd: targetVerseEnd,
      votes: votes,
      verseText: text,
    );
  }
}

class ThompsonChainTopic {
  final String topicId;
  final String topicTitle;
  final String chainSummary;

  const ThompsonChainTopic({
    required this.topicId,
    required this.topicTitle,
    required this.chainSummary,
  });
}

class CrossReferenceService {
  final DatabaseService _dbService = DatabaseService();
  final BibleService _bibleService = BibleService();

  /// Retorna as referências cruzadas ordenadas por relevância instantaneamente (0.1ms)
  Future<List<CrossReferenceVerse>> getCrossReferences({
    required int bookId,
    required int chapter,
    required int verse,
    int limit = 35,
  }) async {
    final rows = await _dbService.getRawCrossReferences(
      bookId,
      chapter,
      verse,
      limit: limit,
    );
    final items = <CrossReferenceVerse>[];

    for (final row in rows) {
      final toB = row['to_b'] as int;
      final toC = row['to_c'] as int;
      final toVs = row['to_vs'] as int;
      final toVe = row['to_ve'] as int;
      final votes = row['votes'] as int;
      final bookName = BibleMetadata.getBookName(toB);

      items.add(
        CrossReferenceVerse(
          targetBookId: toB,
          targetBookName: bookName,
          targetChapter: toC,
          targetVerseStart: toVs,
          targetVerseEnd: toVe,
          votes: votes,
          verseText: null, // Carregado de forma preguiçosa/lazy para não travar a UI
        ),
      );
    }

    return items;
  }

  /// Busca o texto de um único versículo relacionado sob demanda com cache
  Future<String?> fetchSingleVerseText({
    required String version,
    required int bookId,
    required int chapter,
    required int verse,
  }) async {
    return _bibleService.getVerseText(
      version: version,
      bookId: bookId,
      chapter: chapter,
      verse: verse,
    );
  }

  /// Retorna os temas da Bíblia Thompson e suas cadeias para o versículo
  Future<List<ThompsonChainTopic>> getThompsonChains({
    required int bookId,
    required int chapter,
    required int verse,
  }) async {
    final rows = await _dbService.getRawThompsonChains(bookId, chapter, verse);
    return rows
        .map(
          (r) => ThompsonChainTopic(
            topicId: r['topic_id']?.toString() ?? '',
            topicTitle: r['topic_title']?.toString() ?? '',
            chainSummary: r['chain_summary']?.toString() ?? '',
          ),
        )
        .toList();
  }
}

// ─── Riverpod Providers ───────────────────────────────────────────────────────

final crossReferenceServiceProvider = Provider((ref) => CrossReferenceService());

final crossReferencesForVerseProvider = FutureProvider.family<
  List<CrossReferenceVerse>,
  ({int bookId, int chapter, int verse})
>((ref, arg) async {
  final service = ref.watch(crossReferenceServiceProvider);
  return service.getCrossReferences(
    bookId: arg.bookId,
    chapter: arg.chapter,
    verse: arg.verse,
  );
});

final thompsonChainsForVerseProvider = FutureProvider.family<
  List<ThompsonChainTopic>,
  ({int bookId, int chapter, int verse})
>((ref, arg) async {
  final service = ref.watch(crossReferenceServiceProvider);
  return service.getThompsonChains(
    bookId: arg.bookId,
    chapter: arg.chapter,
    verse: arg.verse,
  );
});
