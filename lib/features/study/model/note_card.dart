import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:keryx_app/features/study/model/study_block.dart';

/// Representa um versículo vinculado a uma anotação.
class LinkedVerse {
  final String bookAbbrev;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;
  final String version;

  const LinkedVerse({
    required this.bookAbbrev,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.version,
  });

  Map<String, dynamic> toMap() => {
    'bookAbbrev': bookAbbrev,
    'bookName': bookName,
    'chapter': chapter,
    'verse': verse,
    'text': text,
    'version': version,
  };

  factory LinkedVerse.fromMap(Map<String, dynamic> m) => LinkedVerse(
    bookAbbrev: m['bookAbbrev'] ?? '',
    bookName: m['bookName'] ?? '',
    chapter: m['chapter'] ?? 1,
    verse: m['verse'] ?? 1,
    text: m['text'] ?? '',
    version: m['version'] ?? 'NVI',
  );

  String get reference => '$bookName $chapter:$verse ($version)';
}

/// Uma anotação enriquecida — pode vir da IA ou do usuário.
class NoteCard {
  final String id;
  final String title;
  final String body;
  final bool isAiGenerated;
  final bool isPublic;
  final bool isCommunityOnly;
  final bool isLocked;
  final bool isCollapsed;
  final List<LinkedVerse> verses;
  final List<String> commentaryKeys; // chaves para comentários exibidos
  final List<String> lexicalTerms; // termos Strongs / léxicos
  final List<String> tags;
  final List<StudyBlock> blocks;
  final int pageColor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastActivityAt;
  final String? authorId;
  final String? authorName;
  final String? authorPhoto;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;

  const NoteCard({
    required this.id,
    required this.title,
    required this.body,
    this.isAiGenerated = false,
    this.isPublic = false,
    this.isCommunityOnly = false,
    this.isLocked = false,
    this.isCollapsed = true,
    this.verses = const [],
    this.commentaryKeys = const [],
    this.lexicalTerms = const [],
    this.tags = const [],
    this.blocks = const [],
    this.pageColor = 0xFFFFFFFF,
    required this.createdAt,
    required this.updatedAt,
    this.lastActivityAt,
    this.authorId,
    this.authorName,
    this.authorPhoto,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByMe = false,
  });

  String get plainTextBody {
    if (!body.trim().startsWith('[')) return body;
    try {
      final List<dynamic> delta = jsonDecode(body);
      final buffer = StringBuffer();
      for (final op in delta) {
        if (op is Map && op.containsKey('insert') && op['insert'] is String) {
          buffer.write(op['insert']);
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return body;
    }
  }

  NoteCard copyWith({
    String? title,
    String? body,
    bool? isAiGenerated,
    bool? isPublic,
    bool? isCommunityOnly,
    bool? isLocked,
    bool? isCollapsed,
    List<LinkedVerse>? verses,
    List<String>? commentaryKeys,
    List<String>? lexicalTerms,
    List<String>? tags,
    List<StudyBlock>? blocks,
    int? pageColor,
    DateTime? updatedAt,
    DateTime? lastActivityAt,
    String? authorId,
    String? authorName,
    String? authorPhoto,
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
  }) => NoteCard(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    isAiGenerated: isAiGenerated ?? this.isAiGenerated,
    isPublic: isPublic ?? this.isPublic,
    isCommunityOnly: isCommunityOnly ?? this.isCommunityOnly,
    isLocked: isLocked ?? this.isLocked,
    isCollapsed: isCollapsed ?? this.isCollapsed,
    verses: verses ?? this.verses,
    commentaryKeys: commentaryKeys ?? this.commentaryKeys,
    lexicalTerms: lexicalTerms ?? this.lexicalTerms,
    tags: tags ?? this.tags,
    blocks: blocks ?? this.blocks,
    pageColor: pageColor ?? this.pageColor,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    authorId: authorId ?? this.authorId,
    authorName: authorName ?? this.authorName,
    authorPhoto: authorPhoto ?? this.authorPhoto,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    isLikedByMe: isLikedByMe ?? this.isLikedByMe,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'isAiGenerated': isAiGenerated,
    'isPublic': isPublic,
    'isCommunityOnly': isCommunityOnly,
    'isLocked': isLocked,
    'verses': verses.map((v) => v.toMap()).toList(),
    'commentaryKeys': commentaryKeys,
    'lexicalTerms': lexicalTerms,
    'tags': tags,
    'blocks': blocks.map((b) => b.toMap()).toList(),
    'pageColor': pageColor,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'lastActivityAt': lastActivityAt != null
        ? Timestamp.fromDate(lastActivityAt!)
        : null,
    'authorId': authorId,
    'authorName': authorName,
    'authorPhoto': authorPhoto,
    'likeCount': likeCount,
    'commentCount': commentCount,
  };

  factory NoteCard.fromMap(Map<String, dynamic> m) => NoteCard(
    id: m['id'] ?? '',
    title: m['title'] ?? 'Sem título',
    body: m['body'] ?? '',
    isAiGenerated: m['isAiGenerated'] ?? false,
    isPublic: m['isPublic'] ?? false,
    isCommunityOnly: m['isCommunityOnly'] ?? false,
    isLocked: m['isLocked'] ?? false,
    verses: (m['verses'] as List<dynamic>? ?? [])
        .map((v) => LinkedVerse.fromMap(Map<String, dynamic>.from(v)))
        .toList(),
    commentaryKeys: List<String>.from(m['commentaryKeys'] ?? []),
    lexicalTerms: List<String>.from(m['lexicalTerms'] ?? []),
    tags: List<String>.from(m['tags'] ?? []),
    blocks: (m['blocks'] as List<dynamic>? ?? [])
        .map((b) => StudyBlock.fromMap(Map<String, dynamic>.from(b)))
        .toList(),
    pageColor: m['pageColor'] ?? 0xFFFFFFFF,
    createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    lastActivityAt: (m['lastActivityAt'] as Timestamp?)?.toDate(),
    authorId: m['authorId'],
    authorName: m['authorName'],
    authorPhoto: m['authorPhoto'],
    likeCount: m['likeCount'] ?? 0,
    commentCount: m['commentCount'] ?? 0,
  );

  /// Constrói um NoteCard a partir de uma anotação IATheos legada
  /// (chave = "iatheos_<timestamp>", valor = texto bruto).
  factory NoteCard.fromIaTheos(String key, String rawText) {
    final ts = int.tryParse(key.replaceFirst('iatheos_', ''));
    final dt = ts != null
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : DateTime.now();
    return NoteCard(
      id: key,
      title: _extractTitle(rawText),
      body: rawText,
      isAiGenerated: true,
      blocks: [],
      createdAt: dt,
      updatedAt: dt,
    );
  }

  /// Constrói um NoteCard a partir de uma anotação bíblica legada
  /// (chave = "abbrev_chapter_verse", valor = texto).
  factory NoteCard.fromLegacy(String key, String text) {
    final parts = key.split('_');
    return NoteCard(
      id: key,
      title: parts.length == 3
          ? '${parts[0].toUpperCase()} ${parts[1]}:${parts[2]}'
          : 'Anotação',
      body: text,
      isAiGenerated: false,
      blocks: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static String _extractTitle(String body) {
    final lines = body.split('\n').where((l) => l.trim().isNotEmpty);
    if (lines.isEmpty) return 'Nota IATheos';
    var first = lines.first.replaceAll(RegExp(r'^#+\s*'), '').trim();
    if (first.length > 55) first = '${first.substring(0, 52)}...';
    return first.isEmpty ? 'Nota IATheos' : first;
  }
}
