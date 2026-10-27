import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/utils/search_helper.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';

class BibleReferenceParsed {
  final String rawBookName;
  final int chapter;
  final int? verse;

  const BibleReferenceParsed({
    required this.rawBookName,
    required this.chapter,
    this.verse,
  });
}

class BibleReferenceHelper {
  BibleReferenceHelper._();

  /// Parseia strings de referência como "Hebreus 11:1", "Salmos 23:1-2", "1 João 3:16", "Gênesis 1:1 (ACF)"
  static BibleReferenceParsed? parse(String reference) {
    if (reference.trim().isEmpty) return null;

    // Remove parênteses como "(ACF)", "(NVI)", etc.
    final clean = reference.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), '').trim();

    // Regex para pegar: [Prefixo numérico opcional + Nome do Livro] [Capítulo] [:]? [Versículo]?
    final regex = RegExp(
      r'^([0-9]?\s*[a-zA-ZáéíóúÁÉÍÓÚãõÃÕâêîôûÂÊÎÔÛçÇ]+)\s+(\d+)(?:[:\.,\s]+(\d+))?',
      caseSensitive: false,
    );

    final match = regex.firstMatch(clean);
    if (match == null) return null;

    final rawBook = match.group(1)?.trim() ?? '';
    final chapter = int.tryParse(match.group(2) ?? '') ?? 1;
    final verse = match.group(3) != null ? int.tryParse(match.group(3)!) : null;

    if (rawBook.isEmpty) return null;

    return BibleReferenceParsed(
      rawBookName: rawBook,
      chapter: chapter,
      verse: verse,
    );
  }

  /// Resolve o [BibleBook] correto e abre a leitura diretamente no capítulo e versículo alvo
  static Future<void> openReference(
    BuildContext context,
    WidgetRef ref,
    String? reference,
  ) async {
    final parsed = reference != null ? parse(reference) : null;

    if (parsed == null) {
      final lastRead = ref.read(lastReadProvider);
      if (lastRead != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReadingScreen(
              book: lastRead.book,
              initialChapter: lastRead.chapter,
            ),
          ),
        );
      } else {
        ref.read(navigationProvider.notifier).setIndex(1);
      }
      return;
    }

    final targetBook = _resolveBook(ref, parsed.rawBookName);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingScreen(
            book: targetBook,
            initialChapter: parsed.chapter,
            initialVerse: parsed.verse,
          ),
        ),
      );
    }
  }

  /// Encontra o [BibleBook] correspondente pelo nome ou abreviação
  static BibleBook _resolveBook(WidgetRef ref, String rawName) {
    final normSearch = SearchHelper.normalize(rawName).replaceAll(' ', '');

    // 1. Tenta encontrar na lista em memória se disponível
    try {
      final booksAsync = ref.read(booksProvider);
      final books = booksAsync.value;
      if (books != null && books.isNotEmpty) {
        for (final b in books) {
          final normName = SearchHelper.normalize(b.name).replaceAll(' ', '');
          final normAbbrev = SearchHelper.normalize(b.abbrev).replaceAll(' ', '');
          if (normName == normSearch || normAbbrev == normSearch) {
            return b;
          }
        }
        for (final b in books) {
          final normName = SearchHelper.normalize(b.name).replaceAll(' ', '');
          if (normName.startsWith(normSearch) || normSearch.startsWith(normName)) {
            return b;
          }
        }
      }
    } catch (_) {}

    // 2. Busca estática garantida no BibleMetadata (cobre todos os 66 livros da Bíblia)
    for (final entry in BibleMetadata.bookNames.entries) {
      final id = entry.key;
      final name = entry.value;
      final details = BibleMetadata.bookDetails[id];
      final abbrev = (details?['abbrev'] as String?) ?? '';

      final normName = SearchHelper.normalize(name).replaceAll(' ', '');
      final normAbbrev = SearchHelper.normalize(abbrev).replaceAll(' ', '');

      if (normName == normSearch || normAbbrev == normSearch || normName.startsWith(normSearch)) {
        return BibleBook(
          id: id,
          abbrev: abbrev,
          name: name,
          author: (details?['author'] as String?) ?? '',
          group: (details?['group'] as String?) ?? '',
          chapters: (details?['chapters'] as int?) ?? 1,
        );
      }
    }

    // 3. Fallback seguro caso não ache
    return BibleBook.fromName(rawName);
  }
}
