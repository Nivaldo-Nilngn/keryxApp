import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/database_service.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';

class StrongRepository {
  final DatabaseService _dbService;

  StrongRepository(this._dbService);

  Future<Map<String, dynamic>?> getStrongEntry(String strongId) async {
    return await _dbService.getStrongEntry(strongId);
  }

  Future<List<Map<String, dynamic>>> getConcordance(String rawStrongId, String currentVersion) async {
    final strongId = rawStrongId.trim();
    final versionToUse =
        ['ARA_S', 'ARA+STRONG ATUALIZADA + STRONG', 'JFARASTRONG'].contains(currentVersion.toUpperCase())
            ? currentVersion.toUpperCase()
            : 'ARA_S';

    try {
      return await _queryConcordance(strongId, versionToUse);
    } catch (e) {
      if (e.toString().contains('code 26') ||
          e.toString().contains('not a database') ||
          e.toString().contains('file is not a database')) {
        debugPrint('⚠️ Erro de base de dados corrompida em concordância. Executando auto-reparo para $versionToUse...');
        await _dbService.forceRepairDatabase(versionToUse);
        return await _queryConcordance(strongId, versionToUse);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _queryConcordance(String strongId, String versionToUse) async {
    final db = await _dbService.getDatabase(versionToUse);

    final tablesResult = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final tables = tablesResult.map((t) => (t['name'] as String).toLowerCase()).toList();

    final String tableName;
    final String bookCol, chapterCol, verseCol, textCol;

    if (tables.contains('versiculos')) {
      tableName = 'VERSICULOS';
      bookCol = 'VER_LIV_ID';
      chapterCol = 'VER_CAPITULO';
      verseCol = 'VER_VERSICULO';
      textCol = 'VER_TEXTO';
    } else if (tables.contains('bible')) {
      tableName = 'Bible';
      bookCol = 'Book';
      chapterCol = 'Chapter';
      verseCol = 'Verse';
      textCol = 'Scripture';
    } else {
      tableName = 'verse';
      bookCol = 'book_id';
      chapterCol = 'chapter';
      verseCol = 'verse';
      textCol = 'text';
    }

    final exactStrongId = '<$strongId';
    final wStrongId = '<W$strongId';

    final rows = await db.query(
      tableName,
      columns: [bookCol, chapterCol, verseCol, textCol],
      where:
          '$textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR '
          '$textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ? OR $textCol LIKE ?',
      whereArgs: [
        '%$exactStrongId>%', '%$exactStrongId %', '%$exactStrongId,%', '%$exactStrongId.%', '%$exactStrongId;%', '%$exactStrongId:%', '%$exactStrongId!%', '%$exactStrongId?%', '%$exactStrongId"%',
        '%$wStrongId>%', '%$wStrongId %', '%$wStrongId,%', '%$wStrongId.%', '%$wStrongId;%', '%$wStrongId:%', '%$wStrongId!%', '%$wStrongId?%', '%$wStrongId"%',
      ],
      limit: 1000,
    );

    final regex = RegExp(
      '<(?:W)?${RegExp.escape(strongId)}[^>]*>',
      caseSensitive: false,
    );
    final List<Map<String, dynamic>> results = [];

    for (var row in rows) {
      final text = (row[textCol] ?? '').toString();
      if (regex.hasMatch(text)) {
        results.add({
          'book_id': row[bookCol],
          'chapter': row[chapterCol],
          'verse': row[verseCol],
          'text': text,
        });
      }
    }
    return results;
  }
}

final strongRepositoryProvider = Provider((ref) {
  return StrongRepository(ref.watch(databaseServiceProvider));
});

final strongEntryProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, code) async {
  final repo = ref.watch(strongRepositoryProvider);
  return await repo.getStrongEntry(code);
});

final strongConcordanceProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, code) async {
  final repo = ref.watch(strongRepositoryProvider);
  final currentVersion = ref.watch(selectedVersionProvider);
  return await repo.getConcordance(code, currentVersion);
});
