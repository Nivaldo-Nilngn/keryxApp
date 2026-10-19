import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/bible_service.dart';

final usxServiceProvider = Provider((ref) => UsxService());

class UsxService {
  final BibleService _bibleService = BibleService();

  Future<List<Map<String, dynamic>>> getChapterRichText(String version, int bookId, int chapter) async {
    try {
      // Converte o bookId numérico (1, 40) para a abreviação esperada pelo BibleService se necessário
      // Mas o BibleService parece aceitar a string que vier.
      // Vamos tentar usar o bookId como string.
      final bibleChapter = await _bibleService.getChapter(version, bookId.toString(), chapter);
      
      // Retorna no formato esperado pelo richChapterProvider
      return bibleChapter.verses.map((v) => {
        'type': 'verse',
        'number': v.number.toString(),
        'text': v.text,
      }).toList();
    } catch (e) {
      print('Erro no UsxService: $e');
      return [];
    }
  }

  // Fallback se alguém ainda usar o nome antigo
  Future<List<Map<String, dynamic>>> getRichChapter(String version, String bookId, int chapter) async {
    return getChapterRichText(version, int.tryParse(bookId) ?? 1, chapter);
  }
}
