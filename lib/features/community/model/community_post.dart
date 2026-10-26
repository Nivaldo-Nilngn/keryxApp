import 'package:flutter/foundation.dart';

@immutable
class CommunityPost {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String userBadge;
  final String? mediaUrl;
  final String mediaType; // 'verse_card', 'image', 'video'
  final String caption;
  final String? bibleReference;
  final String bibleVersion;
  final String? bibleText;
  final String cardTheme; // 'gold', 'indigo', 'emerald', 'crimson', 'sepia'
  final int prayingCount;
  final int amenCount;
  final int commentsCount;
  final DateTime createdAt;
  final bool userPrayed;
  final bool userAmen;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.userBadge = 'Membro',
    this.mediaUrl,
    this.mediaType = 'verse_card',
    required this.caption,
    this.bibleReference,
    this.bibleVersion = 'ACF',
    this.bibleText,
    this.cardTheme = 'gold',
    this.prayingCount = 0,
    this.amenCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.userPrayed = false,
    this.userAmen = false,
  });

  CommunityPost copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? userBadge,
    String? mediaUrl,
    String? mediaType,
    String? caption,
    String? bibleReference,
    String? bibleVersion,
    String? bibleText,
    String? cardTheme,
    int? prayingCount,
    int? amenCount,
    int? commentsCount,
    DateTime? createdAt,
    bool? userPrayed,
    bool? userAmen,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userBadge: userBadge ?? this.userBadge,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      bibleReference: bibleReference ?? this.bibleReference,
      bibleVersion: bibleVersion ?? this.bibleVersion,
      bibleText: bibleText ?? this.bibleText,
      cardTheme: cardTheme ?? this.cardTheme,
      prayingCount: prayingCount ?? this.prayingCount,
      amenCount: amenCount ?? this.amenCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      userPrayed: userPrayed ?? this.userPrayed,
      userAmen: userAmen ?? this.userAmen,
    );
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      try {
        return DateTime.parse(d.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return CommunityPost(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? json['userName']?.toString() ?? 'Irmão em Cristo',
      userAvatar: json['user_avatar']?.toString() ?? json['userAvatar']?.toString(),
      userBadge: json['user_badge']?.toString() ?? json['userBadge']?.toString() ?? 'Membro',
      mediaUrl: json['media_url']?.toString() ?? json['mediaUrl']?.toString(),
      mediaType: json['media_type']?.toString() ?? json['mediaType']?.toString() ?? 'verse_card',
      caption: json['caption']?.toString() ?? '',
      bibleReference: json['bible_reference']?.toString() ?? json['bibleReference']?.toString(),
      bibleVersion: json['bible_version']?.toString() ?? json['bibleVersion']?.toString() ?? 'ACF',
      bibleText: json['bible_text']?.toString() ?? json['bibleText']?.toString(),
      cardTheme: json['card_theme']?.toString() ?? json['cardTheme']?.toString() ?? 'gold',
      prayingCount: (json['praying_count'] ?? json['prayingCount'] ?? 0) is int
          ? (json['praying_count'] ?? json['prayingCount'] ?? 0) as int
          : int.tryParse((json['praying_count'] ?? json['prayingCount'] ?? 0).toString()) ?? 0,
      amenCount: (json['amen_count'] ?? json['amenCount'] ?? 0) is int
          ? (json['amen_count'] ?? json['amenCount'] ?? 0) as int
          : int.tryParse((json['amen_count'] ?? json['amenCount'] ?? 0).toString()) ?? 0,
      commentsCount: (json['comments_count'] ?? json['commentsCount'] ?? 0) is int
          ? (json['comments_count'] ?? json['commentsCount'] ?? 0) as int
          : int.tryParse((json['comments_count'] ?? json['commentsCount'] ?? 0).toString()) ?? 0,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      userPrayed: json['user_prayed'] == true || json['userPrayed'] == true,
      userAmen: json['user_amen'] == true || json['userAmen'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'user_badge': userBadge,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
      'bible_reference': bibleReference,
      'bible_version': bibleVersion,
      'bible_text': bibleText,
      'card_theme': cardTheme,
      'praying_count': prayingCount,
      'amen_count': amenCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
      'user_prayed': userPrayed,
      'user_amen': userAmen,
    };
  }
}
