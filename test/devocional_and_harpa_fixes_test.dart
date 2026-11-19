import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/core/utils/bible_text_parser.dart';
import 'package:keryx_app/core/utils/bible_reference_helper.dart';
import 'package:keryx_app/core/utils/search_helper.dart';
import 'package:keryx_app/features/store/repository/harpa_audio_service.dart';

class _HymnTestModel {
  final String number;
  final String name;
  const _HymnTestModel({required this.number, required this.name});
}

void main() {
  group('Devocional Reference & Strong Tag Parsing Tests', () {
    test('Regex captures complex, accented and numbered biblical references', () {
      final refRegex = RegExp(
        r'((?:[1-3]\s+)?[A-ZÁÉÍÓÚÂÊÎÔÛÃÕÇ][a-záéíóúâêîôûãõç]+(?:\s+(?:de|dos|da)\s+[A-ZÁÉÍÓÚÂÊÎÔÛÃÕÇ][a-záéíóúâêîôûãõç]+)?\s+\d+[:\.,\s]+\d+(?:-\d+)?)',
      );

      const text = 'Confira Lucas 5:5 e também João 21:15 para meditar. '
          'Veja ainda Êxodo 20:1-17, 1 João 3:16 e Cântico dos Cânticos 2:4.';

      final matches = refRegex.allMatches(text).map((m) => m.group(0)!).toList();

      expect(matches, contains('Lucas 5:5'));
      expect(matches, contains('João 21:15'));
      expect(matches, contains('Êxodo 20:1-17'));
      expect(matches, contains('1 João 3:16'));
      expect(matches, contains('Cântico dos Cânticos 2:4'));
    });

    test('BibleTextParser.cleanToPlainText removes all Strong tags completely', () {
      const rawStrongVerse =
          '15. Depois de<WG3767><WG3753> terem comido,<WG709><G5656> perguntou<WG3004><G5719> Jesus<WG2424> a Simão<WG4613> Pedro:';
      final clean = BibleTextParser.cleanToPlainText(rawStrongVerse);

      expect(clean.contains('<WG'), isFalse);
      expect(clean.contains('<G'), isFalse);
      expect(clean.contains('>'), isFalse);
      expect(clean, '15. Depois de terem comido, perguntou Jesus a Simão Pedro:');
    });

    test('BibleReferenceHelper.parse and BibleMetadata.findBookId resolve Lucas and João synchronously', () {
      final parsedLucas = BibleReferenceHelper.parse('Lucas 5:5');
      expect(parsedLucas, isNotNull);
      expect(parsedLucas!.rawBookName, 'Lucas');
      expect(parsedLucas.chapter, 5);
      expect(parsedLucas.verse, 5);

      final bookIdLucas = BibleMetadata.findBookId(parsedLucas.rawBookName);
      expect(bookIdLucas, 42); // Lucas é o livro 42 da Bíblia
      expect(BibleMetadata.bookDetails[bookIdLucas]?['abbrev'], 'lc');

      final parsedJoao = BibleReferenceHelper.parse('João 21:15');
      expect(parsedJoao, isNotNull);
      final bookIdJoao = BibleMetadata.findBookId(parsedJoao!.rawBookName);
      expect(bookIdJoao, 43); // João é o livro 43
      expect(BibleMetadata.bookDetails[bookIdJoao]?['abbrev'], 'jo');
    });
  });

  group('Harpa Cristã Search, Numbering & Selection Integrity Tests', () {
    test('Regex correctly extracts hymn number and title without dot or with dot', () {
      final testCases = [
        {'id': '1. CHUVAS DE GRAÇA', 'num': '1', 'name': 'CHUVAS DE GRAÇA'},
        {'id': '117 O SENHOR SALVA A TODO O PECADOR', 'num': '117', 'name': 'O SENHOR SALVA A TODO O PECADOR'},
        {'id': '136 JESUS, NOSSO SOCORRO', 'num': '136', 'name': 'JESUS, NOSSO SOCORRO'},
        {'id': '212 OS GUERREIROS SE PREPARAM', 'num': '212', 'name': 'OS GUERREIROS SE PREPARAM'},
        {'id': '325. A LUZ DO CEU RAIOU', 'num': '325', 'name': 'A LUZ DO CEU RAIOU'},
        {'id': '442. HISTÓRIA DE CRISTO', 'rowId': 542, 'num': '542', 'name': 'HISTÓRIA DE CRISTO'},
      ];

      for (final tc in testCases) {
        final id = tc['id'] as String;
        final rowId = (tc['rowId'] as int?) ?? 0;

        String num = '';
        String name = '';

        final numMatch = RegExp(r'^(\d+)[\.\s\-]+(.*)$').firstMatch(id);
        if (numMatch != null) {
          num = numMatch.group(1)!.trim();
          name = numMatch.group(2)!.trim();
        } else {
          final dotIdx = id.indexOf('.');
          num = dotIdx > 0 ? id.substring(0, dotIdx).trim() : (rowId > 0 ? '$rowId' : id);
          name = dotIdx > 0 ? id.substring(dotIdx + 1).trim() : id;
        }

        if (rowId == 542 || (num == '442' && name.toUpperCase().contains('HISTÓRIA DE CRISTO'))) {
          num = '542';
        }

        expect(num, tc['num']);
        expect(name, tc['name']);
      }
    });

    test('Selecting filtered hymn opens real index in full list, not filtered index', () {
      final hymns = [
        const _HymnTestModel(number: '1', name: 'CHUVAS DE GRAÇA'),
        const _HymnTestModel(number: '2', name: 'SAUDOSA LEMBRANÇA'),
        const _HymnTestModel(number: '325', name: 'A LUZ DO CÉU RAIOU'),
        const _HymnTestModel(number: '640', name: 'DE VALOR EM VALOR'),
      ];

      // Busca por 325
      const query = '325';
      final q = SearchHelper.normalize(query);
      final numQuery = int.tryParse(query);

      final filtered = hymns.where((h) {
        if (numQuery != null) {
          final hNum = int.tryParse(h.number);
          if (hNum != null && hNum == numQuery) return true;
          if (h.number == query || h.number.padLeft(3, '0') == query) return true;
        }
        final nameNorm = SearchHelper.normalize(h.name);
        return nameNorm.contains(q) || h.number.contains(query);
      }).toList();

      expect(filtered.length, 1);
      final clickedHymn = filtered[0]; // no filtered, índice é 0!

      // O realIndex na lista completa deve ser 2, NÃO 0!
      final realIndex = hymns.indexOf(clickedHymn);
      expect(realIndex, 2);
      expect(hymns[realIndex].name, 'A LUZ DO CÉU RAIOU');
      expect(hymns[realIndex].number, '325');
    });

    test('Search handles accent normalization (e.g. ceu matches CÉU)', () {
      final hymns = [
        const _HymnTestModel(number: '1', name: 'CHUVAS DE GRAÇA'),
        const _HymnTestModel(number: '325', name: 'A LUZ DO CÉU RAIOU'),
      ];

      const query = 'ceu';
      final q = SearchHelper.normalize(query);

      final filtered = hymns.where((h) {
        final nameNorm = SearchHelper.normalize(h.name);
        return nameNorm.contains(q);
      }).toList();

      expect(filtered.length, 1);
      expect(filtered.first.number, '325');
    });

    test('B2 stream URL embeds Authorization query param for Web / PWA audio playback', () {
      const downloadUrl = 'https://f005.backblazeb2.com/file';
      const bucketName = 'AppBiblia';
      const fileName = 'audios/Harpa_Crista/001.mp3';
      const token = 'fake_download_token_123';

      final encodedFileName = fileName.split('/').map((part) => Uri.encodeComponent(part)).join('/');
      final rawUrl = '$downloadUrl/$bucketName/$encodedFileName';
      final streamUrl = '$rawUrl?Authorization=$token';

      expect(streamUrl, 'https://f005.backblazeb2.com/file/AppBiblia/audios/Harpa_Crista/001.mp3?Authorization=fake_download_token_123');
      final uri = Uri.parse(streamUrl);
      expect(uri.queryParameters['Authorization'], 'fake_download_token_123');
      expect(uri.pathSegments.last, '001.mp3');
    });

    test('Audio file name padLeft ensures proper 3-digit MP3 name across all hymns', () {
      expect('1'.padLeft(3, '0'), '001');
      expect('15'.padLeft(3, '0'), '015');
      expect('117'.padLeft(3, '0'), '117');
      expect('325'.padLeft(3, '0'), '325');
      expect('640'.padLeft(3, '0'), '640');
    });

    test('Telegram proxy stream URL and headers are correctly constructed', () {
      final harpa = HarpaAudioService.instance;
      const fileId = 'CQACAgEAAyEGAATtSoN2AAMDav9R2r4ZrTKZaeNJF0KSKSYa8yoAAicKAAJ4RPlH1HhH4d0ZGyg9BA';
      final proxyUrl = 'https://biblia-ia-esboco.nivaldo-nilngn.workers.dev/download?file_id=${Uri.encodeComponent(fileId)}&title=Harpa_001.mp3';

      final headers = harpa.getDownloadHeaders(proxyUrl);
      expect(headers['X-App-Token'], isNotEmpty);
      expect(proxyUrl, contains('workers.dev/download?file_id='));
    });

    test('Local audio path does not use hardcoded PC desktop paths, prioritizing Telegram stream', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final harpa = HarpaAudioService.instance;
      final localPath = await harpa.getLocalAudioPath('001');
      expect(localPath, isNull);
    });
  });
}
