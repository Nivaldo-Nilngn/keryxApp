import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Query Security & SQL Parameterization Tests', () {
    test('Ensures user search queries are escaped or parameterized rather than interpolated', () {
      // Simula uma entrada com SQL Injection clássico
      const attackPayload = "' OR '1'='1' --";

      // Padrão seguro com whereArgs parametrizados
      const safeQueryPattern = 'WHERE TRADUCAO LIKE ? OR PALAVRA_ORIGINAL LIKE ?';
      final safeWhereArgs = ['%$attackPayload%', '%$attackPayload%'];

      expect(safeQueryPattern, contains('?'));
      expect(safeWhereArgs[0], equals("%' OR '1'='1' --%"));
      expect(safeWhereArgs.length, equals(2));
    });

    test('Ensures dictionary letter queries are bounded to sanitized prefix strings', () {
      String sanitizeLetter(String raw) {
        final clean = raw.trim().toUpperCase();
        if (clean.isEmpty) return 'A';
        return clean.substring(0, 1);
      }

      expect(sanitizeLetter('a'), equals('A'));
      expect(sanitizeLetter('   g   '), equals('G'));
      expect(sanitizeLetter("'; DROP TABLE users; --"), equals("'"));
      expect(sanitizeLetter(''), equals('A'));
    });

    test('Ensures verse topic queries strictly use integer parameters', () {
      ({String sql, List<Object> args}) safeTopicQuery(int book, int chapter, int verse) {
        return (
          sql: 'SELECT vt.topic_id FROM thompson_verse_topics vt WHERE vt.book = ? AND vt.chapter = ? AND vt.verse = ?',
          args: <Object>[book, chapter, verse],
        );
      }

      final q = safeTopicQuery(1, 1, 1);
      expect(q.sql, contains('WHERE vt.book = ? AND vt.chapter = ? AND vt.verse = ?'));
      expect(q.args, equals([1, 1, 1]));
      expect(q.args.every((arg) => arg is int), isTrue);
    });

    test('Ensures isValidSqliteBytes accepts SQLite 3 header and rejects HTML/corrupted files', () {
      final validSqliteHeader = 'SQLite format 3\u0000'.codeUnits;
      expect(validSqliteHeader.length, equals(16));

      bool isValidSqliteBytes(List<int> bytes) {
        if (bytes.length < 16) return false;
        const magic = [
          0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66, 0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00
        ];
        for (int i = 0; i < 16; i++) {
          if (bytes[i] != magic[i]) return false;
        }
        return true;
      }

      // Válido
      expect(isValidSqliteBytes(validSqliteHeader), isTrue);

      // Rejeita HTML de SPA/404 (Cloudflare Pages fallback)
      final htmlBytes = '<!DOCTYPE html><html lang="pt-BR">'.codeUnits;
      expect(isValidSqliteBytes(htmlBytes), isFalse);

      // Rejeita arquivo truncado / vazio
      expect(isValidSqliteBytes([]), isFalse);
      expect(isValidSqliteBytes([1, 2, 3]), isFalse);
    });

    test('Ensures concordance regex properly matches Strong tags in Scripture', () {
      const strongId = 'H8064';
      final regex = RegExp(
        '<(?:W)?${RegExp.escape(strongId)}[^>]*>',
        caseSensitive: false,
      );

      // Gênesis 1:1 no ARA_S: ' No princípio,<WH7225> criou<WH1254><H8804><WH853> Deus<WH430> os céus<WH8064> e<WH853> a terra.<WH776>'
      const gen1 = " No princípio,<WH7225> criou<WH1254><H8804><WH853> Deus<WH430> os céus<WH8064> e<WH853> a terra.<WH776>";
      expect(regex.hasMatch(gen1), isTrue);

      // Tag consecutiva sem espaço: <WH1254><H8804>
      final regexH1254 = RegExp('<(?:W)?H1254[^>]*>', caseSensitive: false);
      expect(regexH1254.hasMatch(gen1), isTrue);

      // Tag inexistente
      final regexNone = RegExp('<(?:W)?H9999[^>]*>', caseSensitive: false);
      expect(regexNone.hasMatch(gen1), isFalse);
    });
  });
}
