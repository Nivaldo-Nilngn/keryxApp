import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class DevocionalData {
  final String _title;
  final String verse;
  final String verseReference;
  final String content;

  DevocionalData({
    required String title,
    required this.verse,
    required this.verseReference,
    required this.content,
  }) : _title = sanitizeTitle(title);

  String get title => sanitizeTitle(_title);

  static String sanitizeTitle(String raw) {
    String clean = raw.trim();
    if (clean.contains('"],"url":')) {
      clean = clean.split('"],"url":').first.trim();
    }
    if (clean.contains('","url":')) {
      clean = clean.split('","url":').first.trim();
    }
    if (clean.contains('"url":')) {
      clean = clean.split('"url":').first.trim();
    }
    clean = clean.replaceAll(RegExp(r'["\]\[,]+$'), '').trim();
    return clean.isEmpty ? 'Devocional Diário' : clean;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'verse': verse,
      'verseReference': verseReference,
      'content': content,
    };
  }

  factory DevocionalData.fromMap(Map<String, dynamic> map) {
    return DevocionalData(
      title: map['title']?.toString() ?? '',
      verse: map['verse']?.toString() ?? '',
      verseReference: map['verseReference']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
    );
  }
}

final devocionalServiceProvider = Provider<DevocionalService>((ref) {
  return DevocionalService();
});

final devocionalDiarioProvider = FutureProvider<DevocionalData?>((ref) async {
  final service = ref.read(devocionalServiceProvider);
  return await service.fetchDevocionalDiario();
});

class DevocionalService {
  static const _cacheKey = 'cached_devocional';

  Future<DevocionalData?> fetchDevocionalDiario() async {
    try {
      const targetUrl = 'https://www.bibliaonline.com.br/devocional-diario?b=acf';
      final url = kIsWeb
          ? Uri.parse('https://biblia-ia-esboco.nivaldo-nilngn.workers.dev/devocional')
          : Uri.parse(targetUrl);
          
      final response = await http.get(url, headers: kIsWeb ? null : {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      });

      if (response.statusCode == 200) {
        final body = response.body;

        String title = 'Devocional Diário';
        String content = 'Reflita na Palavra de Deus no dia de hoje.';
        String verse = '“O Senhor é o meu pastor; de nada terei falta.”';
        String verseRef = 'Bíblia Sagrada';

        bool parsed = false;

        // Estratégia 1: Parse robusto de props JSON do Astro Island (ShareInviteCard)
        final cardIdx = body.indexOf('ShareInviteCard');
        if (cardIdx != -1) {
          final propsIdx = body.indexOf('props="', cardIdx);
          if (propsIdx != -1) {
            final start = propsIdx + 'props="'.length;
            final end = body.indexOf('"', start);
            if (end != -1 && end > start) {
              try {
                final rawProps = body.substring(start, end)
                    .replaceAll('&quot;', '"')
                    .replaceAll('&#34;', '"');
                final Map<String, dynamic> data = jsonDecode(rawProps);
                
                final rawTitle = data['title'];
                if (rawTitle is List && rawTitle.length > 1) {
                  title = rawTitle[1].toString().trim();
                } else if (rawTitle != null) {
                  title = rawTitle.toString().trim();
                }

                String textRaw = '';
                final rawText = data['text'];
                if (rawText is List && rawText.length > 1) {
                  textRaw = rawText[1].toString();
                } else if (rawText != null) {
                  textRaw = rawText.toString();
                }

                if (textRaw.isNotEmpty) {
                  _parseTextAndVerse(textRaw, (v, r, c) {
                    verse = v;
                    verseRef = r;
                    content = c;
                  });
                  parsed = true;
                }
              } catch (e) {
                debugPrint('⚠️ Erro no parse JSON do ShareInviteCard: $e');
              }
            }
          }
        }

        // Estratégia 2: Regex isolada e independente (sem amarrar title ao text)
        if (!parsed) {
          final bodyUnescaped = body.replaceAll('&quot;', '"');

          final titleMatch = RegExp(r'"title":\s*\[0,\s*"([^"\\]*(?:\\.[^"\\]*)*)"\]').firstMatch(bodyUnescaped);
          if (titleMatch != null) {
            final raw = titleMatch.group(1);
            if (raw != null) {
              title = raw.replaceAll(r'\"', '"').trim();
            }
          } else {
            final h1Match = RegExp(r'<h1[^>]*data-text=["\x27]title["\x27][^>]*>(.*?)</h1>', dotAll: true).firstMatch(body);
            if (h1Match != null) {
              title = h1Match.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
            }
          }

          final textMatch = RegExp(r'"text":\s*\[0,\s*"(.*?)"\](?=,\s*"|\s*})', dotAll: true).firstMatch(bodyUnescaped);
          if (textMatch != null) {
            final textRaw = textMatch.group(1) ?? '';
            _parseTextAndVerse(textRaw, (v, r, c) {
              verse = v;
              verseRef = r;
              content = c;
            });
            parsed = true;
          }
        }

        title = DevocionalData.sanitizeTitle(title);

        String previewVerse = verse;
        if (!previewVerse.startsWith('“') && !previewVerse.startsWith('"')) {
          previewVerse = '“$previewVerse”';
        }

        final devocional = DevocionalData(
          title: title,
          verse: previewVerse, 
          verseReference: verseRef,
          content: content.trim(),
        );

        // Salva cache atualizado
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, jsonEncode(devocional.toMap()));
        } catch (e) {
          debugPrint('Erro ao salvar cache do devocional: $e');
        }

        return devocional;
      }
    } catch (e) {
      debugPrint('Erro ao buscar devocional: $e');
    }
    
    // Fallback para o cache em caso de erro de rede ou CORS
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cacheKey);
      if (cachedStr != null) {
        final map = jsonDecode(cachedStr);
        return DevocionalData.fromMap(map);
      }
    } catch (e) {
      debugPrint('Erro ao ler cache do devocional: $e');
    }
    
    // Fallback final estático
    return DevocionalData(
      title: 'O Bom Pastor',
      verse: '“O Senhor é o meu pastor; de nada terei falta.”',
      verseReference: 'Salmos 23:1',
      content: 'Confiar que o Senhor é o nosso pastor é um ato contínuo de entrega. Reconhecer nossa fragilidade e descansar na certeza do Seu cuidado diário, provisão perene e proteção soberana.',
    );
  }

  void _parseTextAndVerse(
    String textRaw,
    void Function(String verse, String verseRef, String content) onParsed,
  ) {
    String decodedText = textRaw.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');

    String verse = '“O Senhor é o meu pastor; de nada terei falta.”';
    String verseRef = 'Bíblia Sagrada';
    String content = decodedText;

    final parts = decodedText.split('\n\n');
    if (parts.length > 1) {
      String firstPart = parts.first.trim();

      final refMatch = RegExp(r'\(([^()]+)\)$').firstMatch(firstPart);
      if (refMatch != null) {
        verseRef = refMatch.group(1)?.trim() ?? verseRef;
        verse = firstPart.substring(0, refMatch.start).trim();
      } else {
        verse = firstPart;
      }

      content = parts.sublist(1).join('\n\n').trim();
    }

    onParsed(verse, verseRef, content);
  }
}
