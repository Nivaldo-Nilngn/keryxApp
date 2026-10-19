import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://www.bibliaonline.com.br/devocional-diario?b=acf');
  final response = await http.get(url, headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
  });

  if (response.statusCode == 200) {
    String body = response.body.replaceAll('&quot;', '"');

    String title = 'Devocional Diário';
    String content = 'Reflita na Palavra de Deus no dia de hoje.';
    String verse = '“O Senhor é o meu pastor; de nada terei falta.”';
    String verseRef = 'Bíblia Sagrada';

    final match = RegExp(r'"title":\[0,"(.*?)"\],"text":\[0,"(.*?)"\]').firstMatch(body);
    
    if (match != null) {
      title = match.group(1) ?? title;
      String textRaw = match.group(2) ?? '';
      
      String decodedText = textRaw.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
      
      final parts = decodedText.split('\n\n');
      if (parts.length > 1) {
        String firstPart = parts.first;
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

    print('--- DEVOCIONAL EXTRAÍDO ---');
    print('TÍTULO: $title');
    print('VERSÍCULO: $verse');
    print('REFERÊNCIA: $verseRef');
    print('CONTEÚDO:\n$content');
  } else {
    print('Erro: ${response.statusCode}');
  }
}
