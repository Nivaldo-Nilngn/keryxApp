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

enum _ParsedTokenType {
  plain,
  italic,
  bold,
  jesus,
  selo,
  footnote,
  strong,
}

class _ParsedVerseToken {
  final _ParsedTokenType type;
  final String text;
  final String? codeOrType;
  final String? footnoteBody;
  final int verseNumber;

  const _ParsedVerseToken({
    required this.type,
    required this.text,
    this.codeOrType,
    this.footnoteBody,
    this.verseNumber = 0,
  });
}

/// Parser utilitário para textos bíblicos, tags MySword, HTML, Strong e cabeçalhos
class BibleTextParser {
  // Regexes pré-compiladas estáticas (evita recompilação custosa a cada frame/versículo)
  static final RegExp _titleRegex = RegExp(
    r'<(?:TS\d*|ts\d*|title|TITLE|h\d*|H\d*|t|T)>(.*?)<\/(?:TS\d*|ts\d*|title|TITLE|h\d*|H\d*|t|T)>|<(?:TS\d*|ts\d*)>(.*?)<(?:Ts\d*|ts\d*)>',
    dotAll: true,
  );

  static final RegExp _styleRegex = RegExp(
    r'<style[^>]*>.*?</style>',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _swordControlRegex = RegExp(
    r'<(?:pb|br|hr)\s*\/?>|<\/?(?:S|W|WTG|n|Q\d*|q\d*|wj|CI|FI|FO|FR|FU|GM|GW|LD|ND|PI|pn|PM|PO|PP|PR|PS|PT|R|RA|RC|RD|RM|RQ|RS|RT|RU|SE|SM|ST|SU|TA|TB|TC|TH|TI|TP|TR|TS|TT|VR|VP|VS)[^>]*>',
    caseSensitive: false,
  );

  static final RegExp _strongTagRegex = RegExp(
    r'<W?[HG]\d+>?',
    caseSensitive: false,
  );

  static final RegExp _hebrewRegex = RegExp(r'[\u0590-\u05FF]');
  static final RegExp _hebrewConsonantsRegex = RegExp(r'[^\u05D0-\u05EA]');
  static final RegExp _tokenPattern = RegExp(r'「(.*?)」', dotAll: true);
  static final RegExp _blockPattern = RegExp(r'『(.*?)』(?:\s*《(.*?)》)?', dotAll: true);
  static final RegExp _htmlTagRegex = RegExp(r'<[^>]+>');
  static final RegExp _bracketsRegex = RegExp(r'[「」『』《》]');
  static final RegExp _multipleWhitespaceRegex = RegExp(r'\s{2,}');
  static final RegExp _brTagRegex = RegExp(r'<br\s*\/?>', caseSensitive: false);
  static final RegExp _rfBlockRegex = RegExp(r'<RF>.*?<Rf>', dotAll: true, caseSensitive: false);
  static final RegExp _clBlockRegex = RegExp(r'<CL>.*?<Cl>', dotAll: true, caseSensitive: false);
  static final RegExp _footnoteBlockRegex = RegExp(r'<(?:f|note)>.*?<\/(?:f|note)>', dotAll: true, caseSensitive: false);
  static final RegExp _alphaNumTagRegex = RegExp(r'<[a-zA-Z]{1,4}\d+>?');
  static final RegExp _seloRegex = RegExp(r'<SELO[A-Z0-9]+>[^<]+<\/selo[a-z0-9]+>', caseSensitive: false);
  static final RegExp _seloCaptureRegex = RegExp(r'<SELO[A-Z0-9]+>([^<]+)<\/selo[a-z0-9]+>', caseSensitive: false);
  static final RegExp _seloSearchRegex = RegExp(r'<SELO([A-Z0-9]+)>', caseSensitive: false);
  static final RegExp _sentenceSplitRegex = RegExp(r'(?<=[.!?])\s+');
  static final RegExp _alphaCharRegex = RegExp(r'[A-Za-zÀ-Úà-ú]');
  static final RegExp _upperInitialWordsRegex = RegExp(r'^([A-ZÀ-Ú0-9\s,;:\-–—]{4,})\b(?=\s+[a-zà-ú])');

  static final RegExp _s1Regex = RegExp(r'<S1([HG])(\d+)>', caseSensitive: false);
  static final RegExp _sheRegex = RegExp(r'(?:<w>|\b)S([HEG])E?(\d+)[a-zA-Z]?(?:<w>|\b)', caseSensitive: false);
  static final RegExp _wPartRegex = RegExp(r'』(.*?)《', dotAll: true);
  static final RegExp _bodyRegex = RegExp(r'『(.*?)』', dotAll: true);
  static final RegExp _itemRegex = RegExp(
    r'^(?:(\d+)\s*)?(.*?)(?:(S[HEG]E?\d+[a-zA-Z]?|W?[HG]\d+[a-zA-Z]?)\s*)?([\u0590-\u05FF\uFB1D-\uFB4F\u0370-\u03FF\u1F00-\u1FFF־׃׀]+)\s*$',
    dotAll: true,
  );
  static final RegExp _digitsOnlyRegex = RegExp(r'[^0-9]');
  static final RegExp _trailerRegex = RegExp(r'[׃־׀]');
  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  static final RegExp _tokenRegex = RegExp(
    r'(?:<(RF|CL|f|note)>(.*?)<\/(?:RF|CL|f|note)>|<(RF|CL)>(.*?)<(?:Rf|Cl)>)' // 1,2 ou 3,4: Nota
    r'|(?:([^\s<>]+)\s*<(W?[HG]\d+)>?)', // 5, 6: Palavra antes da tag
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _formatRegex = RegExp(
    r'(?:<(RF|CL|f|note)>(.*?)<\/(?:RF|CL|f|note)>|<(RF|CL)>(.*?)<(?:Rf|Cl)>)'
    r'|<(i|em)>(.*?)<\/(?:i|em)>'
    r'|<(b|strong)>(.*?)<\/(?:b|strong)>'
    r'|<(?:wj|jesus|red)>(.*?)<\/(?:wj|jesus|red)>'
    r'|<SELO[A-Z0-9]+>([^<]+)<\/selo[a-z0-9]+>',
    caseSensitive: false,
    dotAll: true,
  );

  // Caches em memória com capacidade limitada para evitar memory leaks na Web
  static final Map<String, String> _cleanPlainTextCache = {};
  static final Map<String, ({String text, String? title})> _titleAndTextCache = {};
  static final Map<String, List<_ParsedVerseToken>> _tokenCache = {};

  /// Limpa todos os caches em memória do parser
  static void clearCache() {
    _cleanPlainTextCache.clear();
    _titleAndTextCache.clear();
    _tokenCache.clear();
  }

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
    return _hebrewRegex.hasMatch(text);
  }

  /// Converte tokens de módulos interlineares em uma lista de palavras estruturadas
  static List<InterlinearWord> parseInterlinearTokens(String raw) {
    final result = <InterlinearWord>[];
    final matches = _tokenPattern.allMatches(raw).toList();

    if (matches.isEmpty) {
      for (final m in _blockPattern.allMatches(raw)) {
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
        final isHebrew = _hebrewRegex.hasMatch(w);
        if (isHebrew) {
          final consonants = w.replaceAll(_hebrewConsonantsRegex, '');
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
    final s1Match = _s1Regex.firstMatch(content);
    if (s1Match != null) {
      strongCode = '${s1Match.group(1)!.toUpperCase()}${s1Match.group(2)}';
    } else {
      final sheMatch = _sheRegex.firstMatch(content);
      if (sheMatch != null) {
        final prefix = sheMatch.group(1)!.toUpperCase() == 'H' ? 'H' : 'G';
        strongCode = '$prefix${sheMatch.group(2)}';
      }
    }

    // 2. Extrai partes <w> entre 『...』 e 《...》
    final wPartMatch = _wPartRegex.firstMatch(content);
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
          if (p == '׃' || p == '־' || p == '׀' || p == 'פ' || p == 'ס' || _trailerRegex.hasMatch(p)) {
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
    final bodyMatch = _bodyRegex.firstMatch(content);
    if (bodyMatch != null) {
      body = bodyMatch.group(1)!;
    }
    _parseTokenFallback(body, '', result);
  }

  static void _parseTokenFallback(String body, String morph, List<InterlinearWord> result) {
    final cleanBody = body.replaceAll(_htmlTagRegex, ' ').replaceAll(_whitespaceRegex, ' ').trim();
    final m = _itemRegex.firstMatch(cleanBody);
    if (m != null) {
      var rawStrong = m.group(3);
      String? strongCode;
      if (rawStrong != null) {
        rawStrong = rawStrong.toUpperCase();
        if (rawStrong.startsWith('SHE') || rawStrong.startsWith('SH') || rawStrong.startsWith('WH')) {
          strongCode = 'H${rawStrong.replaceAll(_digitsOnlyRegex, '')}';
        } else if (rawStrong.startsWith('SGE') || rawStrong.startsWith('SG') || rawStrong.startsWith('WG')) {
          strongCode = 'G${rawStrong.replaceAll(_digitsOnlyRegex, '')}';
        } else if (rawStrong.startsWith('H') || rawStrong.startsWith('G')) {
          strongCode = '${rawStrong[0]}${rawStrong.substring(1).replaceAll(_digitsOnlyRegex, '')}';
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

  /// Extrai o título e normaliza o texto bruto vindo do banco de dados (com cache em memória)
  static ({String text, String? title}) extractTitleAndText(String rawText) {
    if (rawText.isEmpty) return (text: '', title: null);

    final cached = _titleAndTextCache[rawText];
    if (cached != null) return cached;

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

    final result = (text: workingText.trim(), title: extractedTitle);
    if (_titleAndTextCache.length > 1000) {
      _titleAndTextCache.clear();
    }
    _titleAndTextCache[rawText] = result;
    return result;
  }

  /// Retorna as sub-versões disponíveis em um texto (ex: JER, CNBB em 5catolicas)
  static List<String> getAvailableSubVersions(String rawVerseText) {
    final matches = _seloSearchRegex.allMatches(rawVerseText);
    return matches.map((m) => m.group(1)!.toUpperCase()).toSet().toList();
  }

  /// Limpa completamente qualquer marcação e retorna apenas o texto legível limpo (com cache em memória)
  static String cleanToPlainText(String text, {String? subVersionFilter}) {
    if (text.isEmpty) return '';

    final cacheKey = '${text.hashCode}_${subVersionFilter ?? ""}';
    final cached = _cleanPlainTextCache[cacheKey];
    if (cached != null) return cached;

    var clean = text;

    // Remove blocos de estilo
    clean = clean.replaceAll(_styleRegex, '');

    // Filtra pela sub-versão se fornecida
    if (subVersionFilter != null && subVersionFilter.isNotEmpty) {
      final subRegex = RegExp('<($subVersionFilter)>(.*?)</\\1>', caseSensitive: false, dotAll: true);
      final blockMatch = subRegex.firstMatch(clean);
      if (blockMatch != null) {
        clean = blockMatch.group(2)!;
        clean = clean.replaceAll(_seloRegex, '');
      }
    } else {
      // Formata selos de multi-traduções (ex: 5catolicas) para leitura geral
      clean = clean.replaceAllMapped(_seloCaptureRegex, (match) {
        return ' — ${match.group(1)}: ';
      });
    }

    // Detecta módulos interlineares (BHS, LXX, MyBible/MySword) e reconstrói o texto no idioma original
    if (isInterlinearText(clean)) {
      final interlinearWords = parseInterlinearTokens(clean);
      if (interlinearWords.isNotEmpty) {
        final res = assembleInterlinearText(interlinearWords);
        if (_cleanPlainTextCache.length > 2000) _cleanPlainTextCache.clear();
        _cleanPlainTextCache[cacheKey] = res;
        return res;
      }
    }

    // Remove blocos de notas inteiros
    clean = clean.replaceAll(_rfBlockRegex, '');
    clean = clean.replaceAll(_clBlockRegex, '');
    clean = clean.replaceAll(_footnoteBlockRegex, '');

    // Remove tags Strong
    clean = clean.replaceAll(_strongTagRegex, '');
    clean = clean.replaceAll(_alphaNumTagRegex, '');

    // Converte quebras de linha básicas
    clean = clean.replaceAll(_brTagRegex, ' ');

    // Remove tags HTML/XML residuais e delimitadores interlineares residuais
    clean = clean.replaceAll(_htmlTagRegex, '');
    clean = clean.replaceAll(_bracketsRegex, '');

    // Desescapa entidades HTML
    clean = unescapeHtml(clean);

    // Remove múltiplos espaços em branco
    final result = clean.replaceAll(_multipleWhitespaceRegex, ' ').trim();
    if (_cleanPlainTextCache.length > 2000) _cleanPlainTextCache.clear();
    _cleanPlainTextCache[cacheKey] = result;
    return result;
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

    final trimmed = text.trim();
    if (trimmed.length > 3 &&
        trimmed == trimmed.toUpperCase() &&
        trimmed.contains(_alphaCharRegex)) {
      return _toSentenceCase(trimmed);
    }

    final match = _upperInitialWordsRegex.firstMatch(trimmed);
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
    final sentences = input.split(_sentenceSplitRegex);
    final result = <String>[];
    for (var sentence in sentences) {
      final sTrim = sentence.trim();
      if (sTrim.isEmpty) continue;
      final firstCharIndex = sTrim.indexOf(_alphaCharRegex);
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

  /// Extrai e armazena em cache os tokens estruturados de um versículo (0ms em chamadas subsequentes)
  static List<_ParsedVerseToken> _getVerseTokens(
    String rawVerseText,
    int verseNumber,
    bool isStrongVersion,
    String? subVersionFilter,
  ) {
    final cacheKey = '${rawVerseText.hashCode}_${verseNumber}_${isStrongVersion ? 1 : 0}_${subVersionFilter ?? ""}';
    final cached = _tokenCache[cacheKey];
    if (cached != null) return cached;

    String text = rawVerseText;
    if (subVersionFilter != null && subVersionFilter.isNotEmpty) {
      final subRegex = RegExp('<($subVersionFilter)>(.*?)</\\1>', caseSensitive: false, dotAll: true);
      final blockMatch = subRegex.firstMatch(text);
      if (blockMatch != null) {
        text = blockMatch.group(2)!;
        text = text.replaceAll(_seloRegex, '');
      }
    }

    text = text.replaceAll(_styleRegex, '');

    final hasStrongsInText = isStrongVersion || _strongTagRegex.hasMatch(text);
    final tokens = <_ParsedVerseToken>[];

    if (isInterlinearText(text)) {
      final words = parseInterlinearTokens(text);
      for (final item in words) {
        final textWithSpace = item.word + (item.needsSpace ? ' ' : '');
        if (item.strongCode != null && item.strongCode!.isNotEmpty) {
          tokens.add(_ParsedVerseToken(
            type: _ParsedTokenType.strong,
            text: textWithSpace,
            codeOrType: item.strongCode!,
          ));
        } else {
          tokens.add(_ParsedVerseToken(
            type: _ParsedTokenType.plain,
            text: textWithSpace,
          ));
        }
      }
    } else if (!hasStrongsInText) {
      _extractRichFormattingTokens(text, verseNumber, tokens);
    } else {
      int lastEnd = 0;
      for (final match in _tokenRegex.allMatches(text)) {
        if (match.start > lastEnd) {
          final rawSlice = text.substring(lastEnd, match.start);
          _extractRichFormattingTokens(rawSlice, verseNumber, tokens);
        }

        final noteType = match.group(1) ?? match.group(3);
        final noteContent = match.group(2) ?? match.group(4);
        if (noteType != null && noteContent != null) {
          tokens.add(_ParsedVerseToken(
            type: _ParsedTokenType.footnote,
            text: '',
            codeOrType: noteType.toUpperCase(),
            footnoteBody: cleanToPlainText(noteContent),
            verseNumber: verseNumber,
          ));
        } else if (match.group(5) != null && match.group(6) != null) {
          final word = _cleanWordPunctuation(match.group(5)!);
          final tag = match.group(6)!.toUpperCase();
          tokens.add(_ParsedVerseToken(
            type: _ParsedTokenType.strong,
            text: word,
            codeOrType: tag,
          ));
        }
        lastEnd = match.end;
      }

      if (lastEnd < text.length) {
        final tail = text.substring(lastEnd);
        _extractRichFormattingTokens(tail, verseNumber, tokens);
      }
    }

    if (_tokenCache.length > 2500) {
      _tokenCache.clear();
    }
    _tokenCache[cacheKey] = tokens;
    return tokens;
  }

  static void _extractRichFormattingTokens(
    String text,
    int verseNumber,
    List<_ParsedVerseToken> tokens,
  ) {
    if (text.isEmpty) return;
    int lastEnd = 0;
    for (final m in _formatRegex.allMatches(text)) {
      if (m.start > lastEnd) {
        final plainSlice = _sanitizeSlice(text.substring(lastEnd, m.start));
        if (plainSlice.isNotEmpty) {
          tokens.add(_ParsedVerseToken(
            type: _ParsedTokenType.plain,
            text: plainSlice,
          ));
        }
      }

      final noteType = m.group(1) ?? m.group(3);
      final noteBody = m.group(2) ?? m.group(4);
      if (noteType != null && noteBody != null) {
        tokens.add(_ParsedVerseToken(
          type: _ParsedTokenType.footnote,
          text: '',
          codeOrType: noteType.toUpperCase(),
          footnoteBody: cleanToPlainText(noteBody),
          verseNumber: verseNumber,
        ));
      } else if (m.group(5) != null && m.group(6) != null) {
        final content = _sanitizeSlice(m.group(6)!);
        if (content.isNotEmpty) {
          tokens.add(_ParsedVerseToken(
            type: _ParsedTokenType.italic,
            text: content,
          ));
        }
      } else if (m.group(7) != null && m.group(8) != null) {
        final content = _sanitizeSlice(m.group(8)!);
        if (content.isNotEmpty) {
          tokens.add(_ParsedVerseToken(
            type: _ParsedTokenType.bold,
            text: content,
          ));
        }
      } else if (m.group(9) != null) {
        final content = _sanitizeSlice(m.group(9)!);
        if (content.isNotEmpty) {
          tokens.add(_ParsedVerseToken(
            type: _ParsedTokenType.jesus,
            text: content,
          ));
        }
      } else if (m.group(10) != null) {
        final content = _sanitizeSlice(m.group(10)!);
        if (content.isNotEmpty) {
          final prefix = tokens.isEmpty ? '' : '\n\n';
          tokens.add(_ParsedVerseToken(
            type: _ParsedTokenType.selo,
            text: '$prefix$content: ',
          ));
        }
      }
      lastEnd = m.end;
    }

    if (lastEnd < text.length) {
      final tail = _sanitizeSlice(text.substring(lastEnd));
      if (tail.isNotEmpty) {
        tokens.add(_ParsedVerseToken(
          type: _ParsedTokenType.plain,
          text: tail,
        ));
      }
    }
  }

  /// Constrói a lista de InlineSpans com suporte a:
  /// - Formatação itálica (<i>...</i>) e negrito (<b>...</b>)
  /// - Palavras de Jesus em destaque (<wj>...</wj> ou <jesus>)
  /// - Notas de rodapé interativas (<RF> / <CL>)
  /// - Strong's interativos (<WH1234> Palavra) se a versão possuir Strongs
  ///
  /// Otimizado com tokenização em cache (0ms em chamadas repetidas na Web).
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
    final effectiveTextColor = KeryxColorContrast.ensureReadableTextColor(textColor, context);
    final tokens = _getVerseTokens(rawVerseText, verseNumber, isStrongVersion, subVersionFilter);

    if (tokens.isEmpty) {
      return [
        TextSpan(
          text: cleanToPlainText(rawVerseText, subVersionFilter: subVersionFilter),
          style: TextStyle(color: effectiveTextColor),
        )
      ];
    }

    final spans = <InlineSpan>[];
    for (final token in tokens) {
      switch (token.type) {
        case _ParsedTokenType.plain:
          spans.add(TextSpan(
            text: token.text,
            style: TextStyle(color: effectiveTextColor),
          ));
        case _ParsedTokenType.italic:
          spans.add(TextSpan(
            text: token.text,
            style: TextStyle(fontStyle: FontStyle.italic, color: effectiveTextColor),
          ));
        case _ParsedTokenType.bold:
          spans.add(TextSpan(
            text: token.text,
            style: TextStyle(fontWeight: FontWeight.bold, color: effectiveTextColor),
          ));
        case _ParsedTokenType.jesus:
          spans.add(TextSpan(
            text: token.text,
            style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w500),
          ));
        case _ParsedTokenType.selo:
          spans.add(TextSpan(
            text: token.text,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.kPrimaryGold),
          ));
        case _ParsedTokenType.footnote:
          spans.add(_buildFootnoteBadge(
            token.codeOrType!,
            token.footnoteBody ?? '',
            token.verseNumber,
            onFootnoteTap,
          ));
        case _ParsedTokenType.strong:
          spans.add(_buildStrongSpan(
            context,
            token.text,
            token.codeOrType!,
            onStrongTap,
            textColor: effectiveTextColor,
            strongHighlightColor: strongHighlightColor,
            underline: strongUnderline,
            bold: strongBold,
          ));
      }
    }

    return spans;
  }

  /// Limpa pontuações que grudaram na palavra junto com Strong
  static String _cleanWordPunctuation(String word) {
    return word.replaceAll(_strongTagRegex, '').replaceAll(_htmlTagRegex, '');
  }

  static String _sanitizeSlice(String slice) {
    if (slice.isEmpty) return '';
    var clean = slice;
    clean = clean.replaceAll(_strongTagRegex, '');
    clean = clean.replaceAll(_swordControlRegex, '');
    clean = clean.replaceAll(_htmlTagRegex, '');
    clean = clean.replaceAll(_bracketsRegex, '');
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
