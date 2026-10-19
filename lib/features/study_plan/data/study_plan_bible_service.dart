import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/core/services/database_service.dart';
import '../domain/domain.dart';

@immutable
class StudyVerse {
  final int book;
  final int chapter;
  final int verse;
  final String rawScripture;

  const StudyVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.rawScripture,
  });

  String get bookName => BibleMetadata.getBookName(book);
  String get reference => '$bookName $chapter:$verse';
}

class StudyPlanBibleService {
  final DatabaseService _dbService;

  StudyPlanBibleService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Carrega todos os versículos das passagens de um determinado dia do plano
  Future<List<StudyVerse>> loadPassagesVerses(List<Passage> passages) async {
    final db = await _dbService.getDatabase('ARA_S');
    final List<StudyVerse> allVerses = [];

    for (final p in passages) {
      final where = StringBuffer('Book = ?');
      final args = <Object>[p.book];

      if (p.from == p.to) {
        where.write(' AND Chapter = ?');
        args.add(p.from);

        if (p.verseFrom != null) {
          where.write(' AND Verse BETWEEN ? AND ?');
          args.add(p.verseFrom!);
          args.add(p.verseTo ?? 999);
        }
      } else {
        where.write(' AND Chapter BETWEEN ? AND ?');
        args.add(p.from);
        args.add(p.to);
      }

      final rows = await db.query(
        'Bible',
        columns: ['Book', 'Chapter', 'Verse', 'Scripture'],
        where: where.toString(),
        whereArgs: args,
        orderBy: 'Chapter, Verse',
      );

      for (final r in rows) {
        allVerses.add(
          StudyVerse(
            book: r['Book'] as int,
            chapter: r['Chapter'] as int,
            verse: r['Verse'] as int,
            rawScripture: (r['Scripture'] ?? '').toString(),
          ),
        );
      }
    }

    return allVerses;
  }
}

final studyPlanBibleServiceProvider = Provider<StudyPlanBibleService>((ref) {
  return StudyPlanBibleService();
});

typedef StudyFontStyleBuilder = TextStyle Function(
  String fontName, {
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  TextDecoration? decoration,
  Color? decorationColor,
});

/// Parser de versículos do ARA_S.db com suporte a Strong e limpeza de tags
class StudyVerseParser {
  static final RegExp _malformedTag =
      RegExp(r'<([a-zA-ZáéíóúâêîôûãõçÁÉÍÓÚÂÊÎÔÛÃÕÇ]+)<W([HG]\d+)>');
  static final RegExp _verbTenseTag = RegExp(r'<[HG]\d+>');
  static final RegExp _anyTag = RegExp(r'<[^>]+>');
  static final RegExp _dupStrong = RegExp(r'(<W[HG]\d+>)(?:<W[HG]\d+>)+');
  static final RegExp _tokenPattern = RegExp(r'^([^\s<]+)(?:<W([HG]\d+)>)?(.*)$');

  /// Normaliza e pré-processa o texto do versículo
  static String preprocess(String raw) {
    var s = raw.trim();
    if (s.startsWith('>') || s.startsWith('<')) {
      s = s.replaceAll(RegExp(r'^[> <]+'), '');
    }
    // Corrige tags malformadas do tipo '><Mas<WG1161>' -> 'Mas<WG1161>'
    s = s.replaceAllMapped(
      _malformedTag,
      (m) => '${m.group(1)}<W${m.group(2)}>',
    );
    // Remove tags de tempo verbal que não são Strong (ex: <H8804>, <G5656>)
    s = s.replaceAll(_verbTenseTag, '');
    // Remove tags Strong duplicadas em sequência (mantendo a primeira)
    s = s.replaceAllMapped(_dupStrong, (m) => m.group(1)!);
    return s;
  }

  /// Constrói spans ricos onde palavras com Strong são tocáveis
  static List<InlineSpan> buildSpans({
    required BuildContext context,
    required String rawText,
    required double fontSize,
    required Color textColor,
    Color strongColor = const Color(0xFF4ADE80),
    bool strongUnderline = true,
    bool strongBold = true,
    String fontFamily = 'Inter',
    double height = 1.68,
    StudyFontStyleBuilder? fontStyleBuilder,
    required void Function(String strongCode, String word) onStrongTap,
  }) {
    final clean = preprocess(rawText);
    final spans = <InlineSpan>[];
    final tokens = clean.split(' ');

    TextStyle makeStyle({
      required Color color,
      FontWeight? fontWeight,
      TextDecoration? decoration,
      Color? decorationColor,
    }) {
      if (fontStyleBuilder != null) {
        return fontStyleBuilder(
          fontFamily,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          decoration: decoration,
          decorationColor: decorationColor,
        );
      }
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
        decorationColor: decorationColor,
      );
    }

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.isEmpty) continue;

      final match = _tokenPattern.firstMatch(token);
      if (match != null) {
        final word = match.group(1)!;
        final strongCode = match.group(2); // ex: 'H7225' ou 'G3056'
        final trailingPunctuation = match.group(3) ?? '';

        if (strongCode != null) {
          final cleanWord = word.replaceAll(_anyTag, '');
          final targetWordForPopup =
              cleanWord.replaceAll(RegExp(r'[,.;:!?"]+$'), '');

          spans.add(
            TextSpan(
              text: cleanWord,
              style: makeStyle(
                color: strongColor,
                fontWeight: strongBold ? FontWeight.bold : FontWeight.w600,
                decoration: strongUnderline
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: strongColor.withValues(alpha: 0.35),
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => onStrongTap(strongCode, targetWordForPopup),
            ),
          );
        } else {
          final cleanWord = word.replaceAll(_anyTag, '');
          spans.add(
            TextSpan(
              text: cleanWord,
              style: makeStyle(color: textColor),
            ),
          );
        }

        if (trailingPunctuation.isNotEmpty) {
          final cleanTrail = trailingPunctuation.replaceAll(_anyTag, '');
          if (cleanTrail.isNotEmpty) {
            spans.add(
              TextSpan(
                text: cleanTrail,
                style: makeStyle(color: textColor),
              ),
            );
          }
        }
      } else {
        spans.add(
          TextSpan(
            text: token.replaceAll(_anyTag, ''),
            style: makeStyle(color: textColor),
          ),
        );
      }

      if (i < tokens.length - 1) {
        spans.add(TextSpan(text: ' ', style: makeStyle(color: textColor)));
      }
    }

    return spans;
  }
}
