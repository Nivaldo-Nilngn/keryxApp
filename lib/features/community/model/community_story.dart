import 'package:flutter/foundation.dart';

@immutable
class CommunityStory {
  final String id;
  final String authorName;
  final String? authorAvatar;
  final String title;
  final String? bibleReference;
  final String? verseText;
  final String? reflection; // Reflexão devocional para enriquecer o story
  final String? mediaUrl;
  final String backgroundStyle; // 'gold_gradient', 'indigo_gradient', 'emerald_gradient', 'crimson_gradient'
  final DateTime createdAt;
  final DateTime? expiresAt;

  const CommunityStory({
    required this.id,
    required this.authorName,
    this.authorAvatar,
    required this.title,
    this.bibleReference,
    this.verseText,
    this.reflection,
    this.mediaUrl,
    this.backgroundStyle = 'gold_gradient',
    required this.createdAt,
    this.expiresAt,
  });

  factory CommunityStory.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      try {
        return DateTime.parse(d.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return CommunityStory(
      id: json['id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? json['authorName']?.toString() ?? 'Keryx Comunidade',
      authorAvatar: json['author_avatar']?.toString() ?? json['authorAvatar']?.toString(),
      title: json['title']?.toString() ?? 'Versículo do Dia',
      bibleReference: json['bible_reference']?.toString() ?? json['bibleReference']?.toString(),
      verseText: json['verse_text']?.toString() ?? json['verseText']?.toString(),
      reflection: json['reflection']?.toString(),
      mediaUrl: json['media_url']?.toString() ?? json['mediaUrl']?.toString(),
      backgroundStyle: json['background_style']?.toString() ?? json['backgroundStyle']?.toString() ?? 'gold_gradient',
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      expiresAt: json['expires_at'] != null ? parseDate(json['expires_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'title': title,
      'bible_reference': bibleReference,
      'verse_text': verseText,
      'reflection': reflection,
      'media_url': mediaUrl,
      'background_style': backgroundStyle,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}
