import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/core/utils/bible_reference_helper.dart';

void main() {
  group('BibleReferenceHelper Tests', () {
    test('Parse Hebreus 11:1 (ACF)', () {
      final res = BibleReferenceHelper.parse('Hebreus 11:1 (ACF)');
      expect(res, isNotNull);
      expect(res!.rawBookName, 'Hebreus');
      expect(res.chapter, 11);
      expect(res.verse, 1);
    });

    test('Parse Hebreus 11:1', () {
      final res = BibleReferenceHelper.parse('Hebreus 11:1');
      expect(res, isNotNull);
      expect(res!.rawBookName, 'Hebreus');
      expect(res.chapter, 11);
      expect(res.verse, 1);
    });

    test('Parse 1 João 3:16', () {
      final res = BibleReferenceHelper.parse('1 João 3:16');
      expect(res, isNotNull);
      expect(res!.rawBookName, '1 João');
      expect(res.chapter, 3);
      expect(res.verse, 16);
    });

    test('Parse Salmos 23:1-2', () {
      final res = BibleReferenceHelper.parse('Salmos 23:1-2');
      expect(res, isNotNull);
      expect(res!.rawBookName, 'Salmos');
      expect(res.chapter, 23);
      expect(res.verse, 1);
    });

    test('Parse Gênesis 1', () {
      final res = BibleReferenceHelper.parse('Gênesis 1');
      expect(res, isNotNull);
      expect(res!.rawBookName, 'Gênesis');
      expect(res.chapter, 1);
      expect(res.verse, isNull);
    });
  });
}
