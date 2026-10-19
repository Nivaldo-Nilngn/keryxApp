import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class DevocionalData {
  final String title;
  final String verse;
  final String verseReference;
  final String content;

  DevocionalData({
    required this.title,
    required this.verse,
    required this.verseReference,
    required this.content,
  });

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
      title: map['title'] ?? '',
      verse: map['verse'] ?? '',
      verseReference: map['verseReference'] ?? '',
      content: map['content'] ?? '',
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
      final targetUrl = 'https://www.bibliaonline.com.br/devocional-diario?b=acf';
      final url = kIsWeb
          ? Uri.parse('https://biblia-ia-esboco.nivaldo-nilngn.workers.dev/devocional')
          : Uri.parse(targetUrl);
          
      final response = await http.get(url, headers: kIsWeb ? null : {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      });

      if (response.statusCode == 200) {
        String body = response.body.replaceAll('&quot;', '"');

        String title = 'Devocional Diário';
        String content = 'Reflita na Palavra de Deus no dia de hoje.';
        String verse = '“O Senhor é o meu pastor; de nada terei falta.”';
        String verseRef = 'Bíblia Sagrada';

        // O texto completo do devocional atual fica no Astro Island do "ShareInviteCard"
        final match = RegExp(r'"title":\[0,"(.*?)"\],"text":\[0,"(.*?)"\]').firstMatch(body);
        
        if (match != null) {
          title = match.group(1) ?? title;
          String textRaw = match.group(2) ?? '';
          
          // O texto vem com escapes de aspas e quebras de linha
          String decodedText = textRaw.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
          
          // Separa o versículo/referência do restante do conteúdo
          final parts = decodedText.split('\n\n');
          if (parts.length > 1) {
            String firstPart = parts.first;
            
            // Procura a referência no final do versículo no formato "(Livro Cap:Verso)"
            final refMatch = RegExp(r'\((.*?)\)$').firstMatch(firstPart.trim());
            if (refMatch != null) {
              verseRef = refMatch.group(1) ?? verseRef;
              verse = firstPart.replaceAll(refMatch.group(0)!, '').trim();
            } else {
              verse = firstPart.trim();
            }
            
            content = parts.sublist(1).join('\n\n').trim();
          } else {
            content = decodedText;
          }
        }

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

        // Cache the valid response
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, jsonEncode(devocional.toMap()));
        } catch (e) {
          print('Erro ao salvar cache do devocional: $e');
        }

        return devocional;
      }
    } catch (e) {
      print('Erro ao buscar devocional: $e');
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
      print('Erro ao ler cache do devocional: $e');
    }
    
    // Fallback final estático
    return DevocionalData(
      title: 'O Bom Pastor',
      verse: '“O Senhor é o meu pastor; de nada terei falta.”',
      verseReference: 'Salmos 23:1',
      content: 'Confiar que o Senhor é o nosso pastor é um ato contínuo de entrega. Reconhecer nossa fragilidade e descansar na certeza do Seu cuidado diário, provisão perene e proteção soberana.',
    );
  }
}
