import 'package:flutter/foundation.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';

@immutable
class Passage {
  final int book; // 1 = Gênesis ... 66 = Apocalipse (mesma numeração do ARA_S.db)
  final int from; // Capítulo inicial
  final int to; // Capítulo final
  final int? verseFrom; // Versículo inicial (opcional)
  final int? verseTo; // Versículo final (opcional)

  const Passage({
    required this.book,
    required this.from,
    required this.to,
    this.verseFrom,
    this.verseTo,
  });

  /// Nome legível do livro em Português (ex.: "Gênesis", "Jó", "Salmos")
  String get bookName => BibleMetadata.getBookName(book);

  /// Referência formatada legível para exibição ao usuário
  /// Exemplos:
  /// - Gênesis 1-3
  /// - Gênesis 1
  /// - João 1:1-14
  /// - Lucas 1:1
  String get formattedReference {
    final bName = bookName;
    if (from == to) {
      if (verseFrom != null) {
        if (verseTo != null && verseTo != verseFrom) {
          return '$bName $from:$verseFrom-$verseTo';
        }
        return '$bName $from:$verseFrom';
      }
      return '$bName $from';
    } else {
      if (verseFrom != null || verseTo != null) {
        final vStart = verseFrom != null ? ':$verseFrom' : '';
        final vEnd = verseTo != null ? ':$verseTo' : '';
        return '$bName $from$vStart - $to$vEnd';
      }
      return '$bName $from-$to';
    }
  }

  factory Passage.fromJson(Map<String, dynamic> json) {
    return Passage(
      book: json['book'] as int,
      from: json['from'] as int,
      to: json['to'] as int,
      verseFrom: json['verseFrom'] as int?,
      verseTo: json['verseTo'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'book': book,
    'from': from,
    'to': to,
    if (verseFrom != null) 'verseFrom': verseFrom,
    if (verseTo != null) 'verseTo': verseTo,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Passage &&
          runtimeType == other.runtimeType &&
          book == other.book &&
          from == other.from &&
          to == other.to &&
          verseFrom == other.verseFrom &&
          verseTo == other.verseTo;

  @override
  int get hashCode => Object.hash(book, from, to, verseFrom, verseTo);

  @override
  String toString() => 'Passage($formattedReference)';
}
