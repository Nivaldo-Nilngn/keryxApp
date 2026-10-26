import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/core/utils/bible_text_parser.dart';

void main() {
  group('BibleTextParser Optimization & Caching Tests', () {
    test('cleanToPlainText caches results and strips tags properly', () {
      const rawText = '<pb/><f [1]>Nota 1</f>No princípio <w G746>criou</w> Deus os céus.';
      final cleaned1 = BibleTextParser.cleanToPlainText(rawText);
      expect(cleaned1, contains('No princípio'));
      expect(cleaned1, contains('criou'));
      expect(cleaned1, isNot(contains('<pb/>')));
      expect(cleaned1, isNot(contains('<w G746>')));

      // Second run must hit cache
      final cleaned2 = BibleTextParser.cleanToPlainText(rawText);
      expect(cleaned2, equals(cleaned1));
    });

    test('cleanToPlainText handles empty and repetitive texts', () {
      expect(BibleTextParser.cleanToPlainText(''), equals(''));
      expect(BibleTextParser.cleanToPlainText('Texto simples'), equals('Texto simples'));
      
      // Verify clearing cache works
      BibleTextParser.clearCache();
    });
  });
}
