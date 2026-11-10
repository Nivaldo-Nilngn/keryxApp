import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/features/home/service/devocional_service.dart';

void main() {
  group('DevocionalData Sanitizer & Parser Tests', () {
    test('sanitizeTitle limpa título corrompido com url de Astro Island', () {
      const corrupted = 'O medo de desagradar"],"url":[0,"https://www.bibliaonline.com.br/devocional/2026-11-09';
      final clean = DevocionalData.sanitizeTitle(corrupted);
      expect(clean, 'O medo de desagradar');
    });

    test('sanitizeTitle preserva títulos limpos normais', () {
      expect(DevocionalData.sanitizeTitle('O Bom Pastor'), 'O Bom Pastor');
      expect(DevocionalData.sanitizeTitle('Paz em Meio à Tempestade'), 'Paz em Meio à Tempestade');
    });

    test('DevocionalData.fromMap sanitiza título automaticamente', () {
      final map = {
        'title': 'O medo de desagradar"],"url":[0,"https://www.bibliaonline.com.br/devocional/2026-11-09',
        'verse': '“Porque, persuado eu agora a homens ou a Deus?”',
        'verseReference': 'Gálatas 1:10',
        'content': 'Reflexão diária...',
      };

      final data = DevocionalData.fromMap(map);
      expect(data.title, 'O medo de desagradar');
      expect(data.verse, '“Porque, persuado eu agora a homens ou a Deus?”');
      expect(data.verseReference, 'Gálatas 1:10');
    });

    test('DevocionalData constructor sanitiza título automaticamente', () {
      final data = DevocionalData(
        title: 'O medo de desagradar"],"url":[0,"https://www.bibliaonline.com.br/devocional/2026-11-09',
        verse: '“Versículo”',
        verseReference: 'Ref',
        content: 'Conteúdo',
      );
      expect(data.title, 'O medo de desagradar');
    });
  });
}

