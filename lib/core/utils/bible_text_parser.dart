import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/utils/keryx_color_contrast.dart';

/// Modelo de nota de rodapé ou comentário vinculado ao versículo
class VerseFootnote {
  final String type; // 'RF', 'CL', 'NOTA'
  final String content;

  const VerseFootnote({
    required this.type,
    required this.content,
  });
}

/// Palavra individual de módulo bíblico interlinear (ex: BHS, LXX, MyBible/MySword)
class InterlinearWord {
  final String word;
  final String? strongCode;
  final String? translit;
  final String? gloss;
  final bool needsSpace;

  const InterlinearWord({
    required this.word,
    this.strongCode,
    this.translit,
    this.gloss,
    required this.needsSpace,
  });
}

/// Resultado do parseamento completo de um versículo
class ParsedVerse {
  final String cleanText;
  final String? title;
  final List<VerseFootnote> footnotes;
  final List<InlineSpan> richSpans;

  const ParsedVerse({
    required this.cleanText,
    this.title,
    this.footnotes = const [],
    this.richSpans = const [],
  });
}

/// Parser utilitário para textos bíblicos, tags MySword, HTML, Strong e cabeçalhos
class BibleTextParser {
  // Regexes para títulos e subtítulos de seção (BJP, NA2009, MySword)
  static final RegExp _titleRegex = RegExp(
    r'<(?:TS\d*|ts\d*|title|TITLE|h\d*|H\d*|t|T)>(.*?)<\/(?:TS\d*|ts\d*|title|TITLE|h\d*|H\d*|t|T)>|<(?:TS\d*|ts\d*)>(.*?)<(?:Ts\d*|ts\d*)>',
    dotAll: true,
  );

  // Regex para tags de estilo não visuais (como blocos de CSS na versão A Mensagem)
  static final RegExp _styleRegex = RegExp(
    r'<style[^>]*>.*?</style>',
    caseSensitive: false,
    dotAll: true,
  );

  // Regex para tags de controle do MySword / SWORD / USFM
  static final RegExp _swordControlRegex = RegExp(
    r'<(?:pb|br|hr)\s*\/?>|<\/?(?:S|W|WTG|n|Q\d*|q\d*|wj|CI|FI|FO|FR|FU|GM|GW|LD|ND|PI|pn|PM|PO|PP|PR|PS|PT|R|RA|RC|RD|RM|RQ|RS|RT|RU|SE|SM|ST|SU|TA|TB|TC|TH|TI|TP|TR|TS|TT|VR|VP|VS)[^>]*>',
    caseSensitive: false,
  );

  // Regex para tags Strong's no formato <H1234>, <WH1234>, <G1234>, <WG1234> ou sem fechamento <WH1234
  static final RegExp _strongTagRegex = RegExp(
    r'<W?[HG]\d+>?',
    caseSensitive: false,
  );

  /// Verifica se o texto é de um módulo interlinear (ex: BHS, LXX, MyBible/MySword)
  static bool isInterlinearText(String text) {
    if (text.isEmpty) return false;
    return text.contains('「') ||
        text.contains('『') ||
        text.contains('<w>') ||
        text.contains('SHE') ||
        text.contains('SGE');
  }

  /// Verifica se o texto é escrito da direita para a esquerda (Hebraico)
  static bool isRtlText(String text) {
    if (text.isEmpty) return false;
    return RegExp(r'[\u0590-\u05FF]').hasMatch(text);
  }

  /// Converte tokens de módulos interlineares em uma lista de palavras estruturadas
  static List<InterlinearWord> parseInterlinearTokens(String raw) {
    final result = <InterlinearWord>[];
    final tokenPattern = RegExp(r'「(.*?)」', dotAll: true);
    final matches = tokenPattern.allMatches(raw).toList();

    if (matches.isEmpty) {
      final blockPattern = RegExp(r'『(.*?)』(?:\s*《(.*?)》)?', dotAll: true);
      for (final m in blockPattern.allMatches(raw)) {
        final body = m.group(1) ?? '';
        final morph = m.group(2) ?? '';
        _parseTokenFallback(body, morph, result);
      }
    } else {
      for (final m in matches) {
        final content = m.group(1) ?? '';
        _parseRawToken(content, result);
      }
    }

    // Ajusta espaçamento respeitando gramática hebraica (prefixos inseparáveis e maqaf)
    for (int i = 0; i < result.length; i++) {
      final item = result[i];
      final w = item.word;
      bool needsSpace = true;

      if (w.endsWith('־')) {
        needsSpace = false;
      } else {
        final isHebrew = RegExp(r'[\u0590-\u05FF]').hasMatch(w);
        if (isHebrew) {
          final consonants = w.replaceAll(RegExp(r'[^\u05D0-\u05EA]'), '');
          if (consonants.length <= 1 && i < result.length - 1) {
            needsSpace = false;
          }
        }
      }

      if (i == result.length - 1) {
        needsSpace = false;
      }

      result[i] = InterlinearWord(
        word: item.word,
        strongCode: item.strongCode,
        translit: item.translit,
        gloss: item.gloss,
        needsSpace: needsSpace,
      );
    }

    return result;
  }

  static void _parseRawToken(String content, List<InterlinearWord> result) {
    // 1. Extração do código Strong: prioriza <S1H(\d+)> ou <S1G(\d+)>, fallback para SHE(\d+) ou SGE(\d+)
    String? strongCode;
    final s1Match = RegExp(r'<S1([HG])(\d+)>', caseSensitive: false).firstMatch(content);
    if (s1Match != null) {
      strongCode = '${s1Match.group(1)!.toUpperCase()}${s1Match.group(2)}';
    } else {
      final sheMatch = RegExp(r'(?:<w>|\b)S([HEG])E?(\d+)[a-zA-Z]?(?:<w>|\b)', caseSensitive: false).firstMatch(content);
      if (sheMatch != null) {
        final prefix = sheMatch.group(1)!.toUpperCase() == 'H' ? 'H' : 'G';
        strongCode = '$prefix${sheMatch.group(2)}';
      }
    }

    // 2. Extrai partes <w> entre 『...』 e 《...》
    final wPartMatch = RegExp(r'』(.*?)《', dotAll: true).firstMatch(content);
    if (wPartMatch != null) {
      final wTokens = wPartMatch.group(1)!.split('<w>');
      final parts = wTokens.where((x) => x.isNotEmpty).toList();
      if (parts.length >= 5) {
        final translit = parts.length > 1 ? parts[1].trim() : '';
        final gloss = parts.length > 2 ? parts[2].trim() : '';
        final lemma = parts[4].trim();
        final textWord = (parts.length > 5 && parts[5].trim().isNotEmpty) ? parts[5].trim() : lemma;

        // Pontuação e cantilação ao final (parts[6], parts[7]...)
        var trailer = '';
        for (int i = 6; i < parts.length; i++) {
          final p = parts[i].trim();
          if (p == '׃' || p == '־' || p == '׀' || p == 'פ' || p == 'ס' || RegExp(r'[׃־׀]').hasMatch(p)) {
            trailer += p;
          }
        }

        final cleanWord = (textWord + trailer).trim();
        if (cleanWord.isNotEmpty) {
          result.add(InterlinearWord(
            word: cleanWord,
            strongCode: strongCode,
            translit: translit,
            gloss: gloss,
            needsSpace: true,
          ));
          return;
        }
      }
    }

    // Fallback se não bater nos slots estruturados de <w>
    var body = content;
    final bodyMatch = RegExp(r'『(.*?)』', dotAll: true).firstMatch(content);
    if (bodyMatch != null) {
      body = bodyMatch.group(1)!;
    }
    _parseTokenFallback(body, '', result);
  }

  static void _parseTokenFallback(String body, String morph, List<InterlinearWord> result) {
    final itemRegex = RegExp(
      r'^(?:(\d+)\s*)?(.*?)(?:(S[HEG]E?\d+[a-zA-Z]?|W?[HG]\d+[a-zA-Z]?)\s*)?([\u0590-\u05FF\uFB1D-\uFB4F\u0370-\u03FF\u1F00-\u1FFF־׃׀]+)\s*$',
      dotAll: true,
    );
    final cleanBody = body.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final m = itemRegex.firstMatch(cleanBody);
    if (m != null) {
      var rawStrong = m.group(3);
      String? strongCode;
      if (rawStrong != null) {
        rawStrong = rawStrong.toUpperCase();
        if (rawStrong.startsWith('SHE') || rawStrong.startsWith('SH') || rawStrong.startsWith('WH')) {
          strongCode = 'H${rawStrong.replaceAll(RegExp(r'[^0-9]'), '')}';
        } else if (rawStrong.startsWith('SGE') || rawStrong.startsWith('SG') || rawStrong.startsWith('WG')) {
          strongCode = 'G${rawStrong.replaceAll(RegExp(r'[^0-9]'), '')}';
        } else if (rawStrong.startsWith('H') || rawStrong.startsWith('G')) {
          strongCode = '${rawStrong[0]}${rawStrong.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
        }
      }
      final word = m.group(4)!.trim();
      final translit = m.group(2)?.trim();
      result.add(InterlinearWord(
        word: word,
        strongCode: strongCode,
        translit: translit,
        needsSpace: true,
      ));
    }
  }

  /// Monta o texto legível limpo a partir da lista de palavras interlineares
  static String assembleInterlinearText(List<InterlinearWord> words) {
    final sb = StringBuffer();
    for (final w in words) {
      sb.write(w.word);
      if (w.needsSpace) sb.write(' ');
    }
    return sb.toString();
  }

  /// Extrai o título e normaliza o texto bruto vindo do banco de dados
  static ({String text, String? title}) extractTitleAndText(String rawText) {
    if (rawText.isEmpty) return (text: '', title: null);

    String? extractedTitle;
    String workingText = rawText;

    // 1. Extração de títulos
    final matches = _titleRegex.allMatches(workingText);
    if (matches.isNotEmpty) {
      final titles = <String>[];
      for (final m in matches) {
        final group = m.group(1) ?? m.group(2);
        if (group != null && group.trim().isNotEmpty) {
          titles.add(cleanToPlainText(group.trim()));
        }
      }
      if (titles.isNotEmpty) {
        extractedTitle = titles.join(' — ');
      }
      workingText = workingText.replaceAll(_titleRegex, ' ');
    }

    // 2. Normalização de CAIXA ALTA (VIVA, ARC1969, JFA-rc)
    workingText = normalizeAllCaps(workingText);

    return (text: workingText.trim(), title: extractedTitle);
  }

  /// Retorna as sub-versões disponíveis em um texto (ex: JER, CNBB em 5catolicas)
  static List<String> getAvailableSubVersions(String rawVerseText) {
    final matches = RegExp(r'<SELO([A-Z0-9]+)>', caseSensitive: false).allMatches(rawVerseText);
    return matches.map((m) => m.group(1)!.toUpperCase()).toSet().toList();
  }

  /// Limpa completamente qualquer marcação e retorna apenas o texto legível limpo
  static String cleanToPlainText(String text, {String? subVersionFilter}) {
    if (text.isEmpty) return '';

    var clean = text;

    // Remove blocos de estilo
    clean = clean.replaceAll(_styleRegex, '');

    // Filtra pela sub-versão se fornecida
    if (subVersionFilter != null && subVersionFilter.isNotEmpty) {
      final blockMatch = RegExp('<($subVersionFilter)>(.*?)</\\1>', caseSensitive: false, dotAll: true).firstMatch(clean);
      if (blockMatch != null) {
        clean = blockMatch.group(2)!;
        // Remove as tags de selo, pois já estamos na versão isolada
        clean = clean.replaceAll(RegExp(r'<SELO[A-Z0-9]+>[^<]+<\/selo[a-z0-9]+>', caseSensitive: false), '');
      }
    } else {
      // Formata selos de multi-traduções (ex: 5catolicas) para leitura geral
      clean = clean.replaceAllMapped(RegExp(r'<SELO[A-Z0-9]+>([^<]+)<\/selo[a-z0-9]+>', caseSensitive: false), (match) {
        return ' — ${match.group(1)}: ';
      });
    }

    // Detecta módulos interlineares (BHS, LXX, MyBible/MySword) e reconstrói o texto no idioma original
    if (isInterlinearText(clean)) {
      final interlinearWords = parseInterlinearTokens(clean);
      if (interlinearWords.isNotEmpty) {
        return assembleInterlinearText(interlinearWords);
      }
    }

    // Remove blocos de notas inteiros
    clean = clean.replaceAll(RegExp(r'<RF>.*?<Rf>', dotAll: true, caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'<CL>.*?<Cl>', dotAll: true, caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'<(?:f|note)>.*?<\/(?:f|note)>', dotAll: true, caseSensitive: false), '');

    // Remove tags Strong
    clean = clean.replaceAll(_strongTagRegex, '');
    clean = clean.replaceAll(RegExp(r'<[a-zA-Z]{1,4}\d+>?'), '');

    // Converte quebras de linha básicas
    clean = clean.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), ' ');

    // Remove tags HTML/XML residuais e delimitadores interlineares residuais
    clean = clean.replaceAll(RegExp(r'<[^>]+>'), '');
    clean = clean.replaceAll(RegExp(r'[「」『』《》]'), '');

    // Desescapa entidades HTML
    clean = unescapeHtml(clean);

    // Remove múltiplos espaços em branco
    return clean.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Desescapa entidades HTML comuns
  static String unescapeHtml(String text) {
    if (!text.contains('&')) return text;
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…');
  }

  /// Corrige versículos ou frases iniciais em CAIXA ALTA (comum em VIVA, ARC1969)
  static String normalizeAllCaps(String text) {
    if (text.isEmpty) return text;

    // Se o versículo inteiro ou uma grande sentença estiver em caixa alta:
    // Ex: "NO PRINCÍPIO, criou Deus..." ou "DISSE O SENHOR AO MEU SENHOR: ASSENTA-TE..."
    final trimmed = text.trim();
    if (trimmed.length > 3 &&
        trimmed == trimmed.toUpperCase() &&
        trimmed.contains(RegExp(r'[A-ZÀ-Ú]'))) {
      return _toSentenceCase(trimmed);
    }

    // Se as primeiras palavras estiverem em CAIXA ALTA (ex: "NO PRINCÍPIO, Deus...")
    // Detecta padrão inicial de 2 ou mais palavras em maiúsculas
    final match = RegExp(r'^([A-ZÀ-Ú0-9\s,;:\-–—]{4,})\b(?=\s+[a-zà-ú])').firstMatch(trimmed);
    if (match != null) {
      final upperPart = match.group(1)!;
      final rest = trimmed.substring(upperPart.length);
      final normalizedPart = _toSentenceCase(upperPart);
      return '$normalizedPart$rest';
    }

    return text;
  }

  static String _toSentenceCase(String input) {
    if (input.isEmpty) return input;
    // Divide por pontuação final (. ! ?) mantendo os delimitadores
    final sentences = input.split(RegExp(r'(?<=[.!?])\s+'));
    final result = <String>[];
    for (var sentence in sentences) {
      final sTrim = sentence.trim();
      if (sTrim.isEmpty) continue;
      final firstCharIndex = sTrim.indexOf(RegExp(r'[A-Za-zÀ-Úà-ú]'));
      if (firstCharIndex == -1) {
        result.add(sTrim.toLowerCase());
      } else {
        final prefix = sTrim.substring(0, firstCharIndex);
        final char = sTrim[firstCharIndex].toUpperCase();
        final remainder = sTrim.substring(firstCharIndex + 1).toLowerCase();
        result.add('$prefix$char$remainder');
      }
    }
    return result.join(' ');
  }

  /// Constrói a lista de InlineSpans com suporte a:
  /// - Formatação itálica (<i>...</i>) e negrito (<b>...</b>)
  /// - Palavras de Jesus em destaque (<wj>...</wj> ou <jesus>)
  /// - Notas de rodapé interativas (<RF> / <CL>)
  /// - Strong's interativos (<WH1234> Palavra) se a versão possuir Strongs
  static List<InlineSpan> buildRichVerseSpans({
    required BuildContext context,
    required String rawVerseText,
    required int verseNumber,
    required bool isStrongVersion,
    required void Function(String strongCode, String word) onStrongTap,
    required void Function(String footnoteType, String content, int verseNumber) onFootnoteTap,
    String? subVersionFilter,
    Color? textColor,
    int? strongHighlightColor,
    bool strongUnderline = true,
    bool strongBold = true,
  }) {
    // Filtra pela sub-versão antes de tudo, isolando apenas a tradução selecionada
    String text = rawVerseText;
    if (subVersionFilter != null && subVersionFilter.isNotEmpty) {
      final blockMatch = RegExp('<($subVersionFilter)>(.*?)</\\1>', caseSensitive: false, dotAll: true).firstMatch(text);
      if (blockMatch != null) {
        text = blockMatch.group(2)!;
        text = text.replaceAll(RegExp(r'<SELO[A-Z0-9]+>[^<]+<\/selo[a-z0-9]+>', caseSensitive: false), '');
      }
    }

    // 1. Extração preliminar de estilo (limpa tags style do MSG)
    text = text.replaceAll(_styleRegex, '');

    // Verifica se há marcações de Strong
    final hasStrongsInText = isStrongVersion || _strongTagRegex.hasMatch(text);

    final List<InlineSpan> spans = [];

    // Garante que a cor do texto respeite contraste mínimo WCAG 2.1 (4.5:1)
    final effectiveTextColor = KeryxColorContrast.ensureReadableTextColor(textColor, context);

    // Suporte prioritário a módulos interlineares (BHS Hebraico, LXX Grego, etc.) com Strong's integrados
    if (isInterlinearText(text)) {
      final interlinearSpans = _buildInterlinearSpans(
        context: context,
        text: text,
        onStrongTap: onStrongTap,
        textColor: effectiveTextColor,
        strongHighlightColor: strongHighlightColor,
        strongUnderline: strongUnderline,
        strongBold: strongBold,
      );
      if (interlinearSpans.isNotEmpty) {
        return interlinearSpans;
      }
    }

    // Se NÃO tem Strongs, fazemos o parsing de formatação rica (HTML, notas e itálico)
    if (!hasStrongsInText) {
      spans.addAll(_parseRichFormatting(
        context: context,
        text: text,
        verseNumber: verseNumber,
        onFootnoteTap: onFootnoteTap,
        textColor: effectiveTextColor,
      ));
      return spans.isEmpty
          ? [TextSpan(text: cleanToPlainText(text), style: TextStyle(color: effectiveTextColor))]
          : spans;
    }

    // COM Strongs: parsing de tokens com vinculação palavra-código
    // Regex que encontra notas ou palavras associadas a códigos Strong
    final tokenRegex = RegExp(
      r'(?:<(RF|CL|f|note)>(.*?)<\/(?:RF|CL|f|note)>|<(RF|CL)>(.*?)<(?:Rf|Cl)>)' // 1,2 ou 3,4: Nota
      r'|(?:([^\s<>]+)\s*<(W?[HG]\d+)>?)', // 5, 6: Palavra antes da tag
      caseSensitive: false,
      dotAll: true,
    );

    int lastEnd = 0;

    for (final match in tokenRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        final rawSlice = text.substring(lastEnd, match.start);
        spans.addAll(_parseRichFormatting(
          context: context,
          text: rawSlice,
          verseNumber: verseNumber,
          onFootnoteTap: onFootnoteTap,
          textColor: effectiveTextColor,
        ));
      }

      // 1. Nota de Rodapé
      final noteType = match.group(1) ?? match.group(3);
      final noteContent = match.group(2) ?? match.group(4);
      if (noteType != null && noteContent != null) {
        spans.add(_buildFootnoteBadge(
          noteType.toUpperCase(),
          cleanToPlainText(noteContent),
          verseNumber,
          onFootnoteTap,
        ));
      }
      // 2. Palavra antes da tag Strong
      else if (match.group(5) != null && match.group(6) != null) {
        final word = _cleanWordPunctuation(match.group(5)!);
        final tag = match.group(6)!.toUpperCase();
        spans.add(_buildStrongSpan(
          context,
          word,
          tag,
          onStrongTap,
          textColor: effectiveTextColor,
          strongHighlightColor: strongHighlightColor,
          underline: strongUnderline,
          bold: strongBold,
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final tail = text.substring(lastEnd);
      spans.addAll(_parseRichFormatting(
        context: context,
        text: tail,
        verseNumber: verseNumber,
        onFootnoteTap: onFootnoteTap,
        textColor: effectiveTextColor,
      ));
    }

    if (spans.isEmpty) {
      return [TextSpan(text: cleanToPlainText(text), style: TextStyle(color: effectiveTextColor))];
    }

    return spans;
  }

  /// Limpa pontuações que grudaram na palavra junto com Strong
  static String _cleanWordPunctuation(String word) {
    return word.replaceAll(_strongTagRegex, '').replaceAll(RegExp(r'<[^>]+>'), '');
  }

  /// Faz o parse de trechos de texto interpretando `<i>`, `<b>`, `<wj>` e notas
  static List<InlineSpan> _parseRichFormatting({
    required BuildContext context,
    required String text,
    required int verseNumber,
    required void Function(String footnoteType, String content, int verseNumber) onFootnoteTap,
    Color? textColor,
  }) {
    if (text.isEmpty) return [];

    final spans = <InlineSpan>[];

    // Regex para tags HTML visuais e notas
    final formatRegex = RegExp(
      r'(?:<(RF|CL|f|note)>(.*?)<\/(?:RF|CL|f|note)>|<(RF|CL)>(.*?)<(?:Rf|Cl)>)'
      r'|<(i|em)>(.*?)<\/(?:i|em)>'
      r'|<(b|strong)>(.*?)<\/(?:b|strong)>'
      r'|<(?:wj|jesus|red)>(.*?)<\/(?:wj|jesus|red)>'
      r'|<SELO[A-Z0-9]+>([^<]+)<\/selo[a-z0-9]+>',
      caseSensitive: false,
      dotAll: true,
    );

    int lastEnd = 0;

    for (final m in formatRegex.allMatches(text)) {
      if (m.start > lastEnd) {
        final plainSlice = _sanitizeSlice(text.substring(lastEnd, m.start));
        if (plainSlice.isNotEmpty) {
          spans.add(TextSpan(
            text: plainSlice,
            style: textColor != null ? TextStyle(color: textColor) : null,
          ));
        }
      }

      // Nota de rodapé
      final noteType = m.group(1) ?? m.group(3);
      final noteBody = m.group(2) ?? m.group(4);
      if (noteType != null && noteBody != null) {
        spans.add(_buildFootnoteBadge(
          noteType.toUpperCase(),
          cleanToPlainText(noteBody),
          verseNumber,
          onFootnoteTap,
        ));
      }
      // Itálico
      else if (m.group(5) != null && m.group(6) != null) {
        final content = _sanitizeSlice(m.group(6)!);
        if (content.isNotEmpty) {
          spans.add(TextSpan(
            text: content,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: textColor,
            ),
          ));
        }
      }
      // Negrito
      else if (m.group(7) != null && m.group(8) != null) {
        final content = _sanitizeSlice(m.group(8)!);
        if (content.isNotEmpty) {
          spans.add(TextSpan(
            text: content,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ));
        }
      }
      // Palavras de Jesus (Red Letter)
      else if (m.group(9) != null) {
        final content = _sanitizeSlice(m.group(9)!);
        if (content.isNotEmpty) {
          spans.add(TextSpan(
            text: content,
            style: const TextStyle(
              color: Color(0xFFEF4444), // Vermelho elegante para palavras de Cristo
              fontWeight: FontWeight.w500,
            ),
          ));
        }
      }
      // Módulo Multi-traduções (ex: 5catolicas)
      else if (m.group(10) != null) {
        final content = _sanitizeSlice(m.group(10)!);
        if (content.isNotEmpty) {
          final prefix = spans.isEmpty ? '' : '\n\n';
          spans.add(TextSpan(
            text: '$prefix$content: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.kPrimaryGold,
            ),
          ));
        }
      }

      lastEnd = m.end;
    }

    if (lastEnd < text.length) {
      final tail = _sanitizeSlice(text.substring(lastEnd));
      if (tail.isNotEmpty) {
        spans.add(TextSpan(
          text: tail,
          style: textColor != null ? TextStyle(color: textColor) : null,
        ));
      }
    }

    return spans;
  }

  static List<InlineSpan> _buildInterlinearSpans({
    required BuildContext context,
    required String text,
    required void Function(String strongCode, String word) onStrongTap,
    Color? textColor,
    int? strongHighlightColor,
    bool strongUnderline = true,
    bool strongBold = true,
  }) {
    final words = parseInterlinearTokens(text);
    if (words.isEmpty) return [];

    final spans = <InlineSpan>[];
    for (final item in words) {
      final textWithSpace = item.word + (item.needsSpace ? ' ' : '');
      if (item.strongCode != null && item.strongCode!.isNotEmpty) {
        spans.add(_buildStrongSpan(
          context,
          textWithSpace,
          item.strongCode!,
          onStrongTap,
          textColor: textColor,
          strongHighlightColor: strongHighlightColor,
          underline: strongUnderline,
          bold: strongBold,
        ));
      } else {
        spans.add(TextSpan(
          text: textWithSpace,
          style: TextStyle(color: textColor),
        ));
      }
    }
    return spans;
  }

  static String _sanitizeSlice(String slice) {
    if (slice.isEmpty) return '';
    var clean = slice;
    clean = clean.replaceAll(_strongTagRegex, '');
    clean = clean.replaceAll(_swordControlRegex, '');
    clean = clean.replaceAll(RegExp(r'<[^>]+>'), '');
    clean = clean.replaceAll(RegExp(r'[「」『』《》]'), '');
    clean = unescapeHtml(clean);
    return clean;
  }

  static WidgetSpan _buildFootnoteBadge(
    String type,
    String body,
    int verseNumber,
    void Function(String footnoteType, String content, int verseNumber) onFootnoteTap,
  ) {
    final label = (type == 'CL' || type == 'NOTE') ? 'COM' : 'NOTA';
    return WidgetSpan(
      alignment: PlaceholderAlignment.top,
      child: GestureDetector(
        onTap: () => onFootnoteTap(label, body, verseNumber),
        child: Container(
          margin: const EdgeInsets.only(left: 4, right: 3, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.kPrimaryGold.withValues(alpha: 0.25),
                AppTheme.kPrimaryGold.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 7,
              fontWeight: FontWeight.w900,
              color: AppTheme.kPrimaryGold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  static InlineSpan _buildStrongSpan(
    BuildContext context,
    String word,
    String tag,
    void Function(String strongCode, String word) onStrongTap, {
    Color? textColor,
    int? strongHighlightColor,
    bool underline = true,
    bool bold = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color? color;
    Color? decorationColor;

    if (strongHighlightColor == 0) {
      // Mesma cor do texto (sem cor especial)
      color = textColor; // Se textColor for especificado, usa textColor; senão null (herda do parent)
      decorationColor = (textColor ?? Theme.of(context).colorScheme.onSurface).withValues(alpha: 0.35);
    } else if (strongHighlightColor != null) {
      color = Color(strongHighlightColor);
      decorationColor = color.withValues(alpha: 0.35);
    } else {
      // Padrão: verde no escuro, azul no claro
      color = isDark ? const Color(0xFF4ADE80) : const Color(0xFF2563EB);
      decorationColor = isDark ? const Color(0x4D4ADE80) : const Color(0x4D2563EB);
    }

    return TextSpan(
      text: word,
      recognizer: TapGestureRecognizer()..onTap = () => onStrongTap(tag, word),
      style: TextStyle(
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        decoration: underline ? TextDecoration.underline : TextDecoration.none,
        decorationColor: decorationColor,
      ),
    );
  }
}
