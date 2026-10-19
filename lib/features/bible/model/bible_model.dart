import 'package:keryx_app/core/utils/bible_text_parser.dart';

class BibleBook {
  final int? id;
  final String abbrev;
  final String name;
  final String author;
  final String group;
  final int chapters;

  BibleBook({
    this.id,
    required this.abbrev,
    required this.name,
    required this.author,
    required this.group,
    required this.chapters,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'abbrev': abbrev,
        'name': name,
        'author': author,
        'group': group,
        'chapters': chapters,
      };

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    String abbrev;
    if (json['abbrev'] is Map) {
      abbrev = json['abbrev']['pt'] ?? json['abbrev']['en'] ?? '';
    } else if (json['abbrev'] is String) {
      abbrev = json['abbrev'];
    } else {
      // If it's just a string from Scriptura API /api/books (unlikely to be Map here if it's string list)
      abbrev = (json['name'] ?? '').toString().toLowerCase();
    }

    return BibleBook(
      id: json['id'],
      abbrev: abbrev,
      name: json['name'] ?? '',
      author: json['author'] ?? '',
      group: json['group'] ?? '',
      chapters: json['chapters'] ?? 0,
    );
  }

  // Custom factory for Scriptura API string list
  factory BibleBook.fromName(String name) {
    return BibleBook(
      abbrev: name.toLowerCase().replaceAll(' ', ''),
      name: name,
      author: 'Desconhecido',
      group: 'Bíblia',
      chapters: 0,
    );
  }
}

class BibleChapter {
  final BibleBook book;
  final int chapterNumber;
  final List<BibleVerse> verses;

  BibleChapter({
    required this.book,
    required this.chapterNumber,
    required this.verses,
  });

  factory BibleChapter.fromJson(Map<String, dynamic> json, [String? fallbackBookId, int? fallbackChapter]) {
    // Handle "verses" as a List (A Bíblia Digital / Pesquisar na Biblia) or Map (Scriptura API)
    List<BibleVerse> verseList = [];
    final rawVerses = json['verses'];

    if (rawVerses is List) {
      verseList = rawVerses.map((v) => BibleVerse.fromJson(v)).toList();
    } else if (rawVerses is Map) {
      rawVerses.forEach((key, value) {
        verseList.add(BibleVerse(
          number: int.tryParse(key) ?? 0,
          text: value.toString(),
        ));
      });
      verseList.sort((a, b) => a.number.compareTo(b.number));
    }

    return BibleChapter(
      book: json['book'] is Map 
          ? BibleBook.fromJson(json['book']) 
          : BibleBook.fromName(json['book_name'] ?? fallbackBookId ?? ''),
      chapterNumber: json['chapter'] is Map 
          ? json['chapter']['number'] 
          : (json['chapter'] ?? fallbackChapter ?? 0),
      verses: verseList,
    );
  }
}

class BibleVerse {
  final int number;
  final String text;
  final String? title;
  final String? verseLabel;

  BibleVerse({
    required this.number,
    required this.text,
    this.title,
    this.verseLabel,
  });

  String get displayVerse => verseLabel ?? '$number';

  BibleVerse copyWith({
    int? number,
    String? text,
    String? title,
    String? verseLabel,
  }) {
    return BibleVerse(
      number: number ?? this.number,
      text: text ?? this.text,
      title: title ?? this.title,
      verseLabel: verseLabel ?? this.verseLabel,
    );
  }

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    final rawNumber = json['number'] ?? json['verse_number'] ?? json['verse'];
    final int parsedNumber;
    String? label;

    if (rawNumber is int) {
      parsedNumber = rawNumber;
    } else if (rawNumber != null) {
      final str = rawNumber.toString();
      parsedNumber = int.tryParse(str) ?? int.tryParse(str.split('-').first) ?? 0;
      if (str.contains('-') || str.contains(',')) {
        label = str;
      }
    } else {
      parsedNumber = 0;
    }

    final rawText = (json['text'] ?? '').toString();
    final parsed = BibleTextParser.extractTitleAndText(rawText);

    return BibleVerse(
      number: parsedNumber,
      text: parsed.text,
      title: json['title'] ?? parsed.title,
      verseLabel: label ?? json['verse_label']?.toString(),
    );
  }
}

class BookSummary {
  final String overview;
  final String period;
  final String context;
  final String audience;
  final String purpose;
  final String biblicalConnections;
  final String theologicalRelevance;
  final String practicalApplication;

  BookSummary({
    required this.overview,
    required this.period,
    required this.context,
    required this.audience,
    required this.purpose,
    required this.biblicalConnections,
    required this.theologicalRelevance,
    required this.practicalApplication,
  });
}

