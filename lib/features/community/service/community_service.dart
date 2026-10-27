import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/features/community/model/community_post.dart';
import 'package:keryx_app/features/community/model/community_comment.dart';
import 'package:keryx_app/features/community/model/community_story.dart';

class CommunityService {
  static const String _baseUrl = 'https://biblia-ia-esboco.nivaldo-nilngn.workers.dev/community';

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  String get _currentUserName =>
      FirebaseAuth.instance.currentUser?.displayName ??
      FirebaseAuth.instance.currentUser?.email?.split('@').first ??
      'Membro Keryx';
  String? get _currentUserAvatar {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.photoURL ??
        (user.providerData.isNotEmpty ? user.providerData.first.photoURL : null);
  }

  /// Busca os stories do dia
  Future<List<CommunityStory>> fetchStories() async {
    try {
      final uri = Uri.parse('$_baseUrl/stories');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['stories'] is List) {
          final list = (data['stories'] as List)
              .map((s) => CommunityStory.fromJson(s as Map<String, dynamic>))
              .toList();
          if (list.isNotEmpty) return list;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [CommunityService] Erro ao carregar stories: $e');
    }
    return _getFallbackStories();
  }

  List<CommunityStory> _getFallbackStories() {
    return [
      CommunityStory(
        id: 'story_v_today',
        authorName: 'Keryx Oficial',
        title: 'Versículo do Dia',
        bibleReference: 'Salmos 23:1',
        verseText: 'O SENHOR é o meu pastor, nada me faltará.',
        reflection: 'O cuidado de Deus não falha nem nos dias mais difíceis.',
        backgroundStyle: 'gold_gradient',
        createdAt: DateTime.now(),
      ),
      CommunityStory(
        id: 'story_prayer',
        authorName: 'Comunhão Keryx',
        title: 'Momento de Oração',
        bibleReference: 'Filipenses 4:6',
        verseText: 'Não estejais inquietos por coisa alguma; antes as vossas petições sejam em tudo conhecidas diante de Deus.',
        reflection: 'Entregue sua ansiedade nas mãos do Pai.',
        backgroundStyle: 'indigo_gradient',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      CommunityStory(
        id: 'story_grace',
        authorName: 'Devocional Diário',
        title: 'Graça & Paz',
        bibleReference: 'Efésios 2:8',
        verseText: 'Porque pela graça sois salvos, por meio da fé; e isto não vem de vós, é dom de Deus.',
        reflection: 'A graça é o abraço de misericórdia de Deus.',
        backgroundStyle: 'emerald_gradient',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ];
  }

  /// Publica um novo story bíblico no Cloudflare D1
  Future<CommunityStory?> createStory({
    required String title,
    String? bibleReference,
    String? verseText,
    String? reflection,
    String backgroundStyle = 'gold_gradient',
    String? authorAvatar,
    String? authorName,
  }) async {
    final storyId = 'story_${DateTime.now().millisecondsSinceEpoch}';
    final resolvedName = authorName ?? _currentUserName;
    final resolvedAvatar = authorAvatar ?? _currentUserAvatar;

    final newStory = CommunityStory(
      id: storyId,
      authorName: resolvedName,
      authorAvatar: resolvedAvatar,
      title: title,
      bibleReference: bibleReference,
      verseText: verseText,
      reflection: reflection,
      backgroundStyle: backgroundStyle,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );

    try {
      final uri = Uri.parse('$_baseUrl/stories');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': storyId,
              'author_name': resolvedName,
              'author_avatar': resolvedAvatar,
              'title': title,
              'bible_reference': bibleReference,
              'verse_text': verseText,
              'reflection': reflection,
              'background_style': backgroundStyle,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['story'] != null) {
          return CommunityStory.fromJson(data['story'] as Map<String, dynamic>);
        }
        return newStory;
      }
    } catch (e) {
      debugPrint('⚠️ [CommunityService] Erro ao salvar story no D1: $e');
    }

    return newStory;
  }

  /// Busca o feed de posts paginado
  Future<List<CommunityPost>> fetchFeed({int offset = 0, int limit = 20}) async {
    try {
      final userId = _currentUserId ?? '';
      final uri = Uri.parse('$_baseUrl/feed?offset=$offset&limit=$limit&userId=$userId');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['posts'] is List) {
          final list = (data['posts'] as List)
              .map((p) => CommunityPost.fromJson(p as Map<String, dynamic>))
              .toList();
          return list;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [CommunityService] Erro ao carregar feed: $e');
    }

    return [];
  }

  /// Publica um novo post no Cloudflare D1
  Future<CommunityPost?> createPost({
    required String caption,
    String? bibleReference,
    String? bibleText,
    String bibleVersion = 'ACF',
    String? mediaUrl,
    String mediaType = 'verse_card',
    String cardTheme = 'gold',
    String? userAvatar,
    String? userName,
  }) async {
    final postId = 'post_${DateTime.now().millisecondsSinceEpoch}';
    final resolvedName = userName ?? _currentUserName;
    final resolvedAvatar = userAvatar ?? _currentUserAvatar;

    final newPost = CommunityPost(
      id: postId,
      userId: _currentUserId ?? 'anon',
      userName: resolvedName,
      userAvatar: resolvedAvatar,
      userBadge: 'Membro',
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      caption: caption,
      bibleReference: bibleReference,
      bibleVersion: bibleVersion,
      bibleText: bibleText,
      cardTheme: cardTheme,
      createdAt: DateTime.now(),
    );

    try {
      final uri = Uri.parse('$_baseUrl/posts');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(newPost.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return newPost;
      } else {
        debugPrint('⚠️ [CommunityService] Erro ao salvar post no D1 (${res.statusCode}): ${res.body}');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ [CommunityService] Erro ao criar post no D1: $e');
      return null;
    }
  }

  /// Alterna reação (🙏 Orar / ❤️ Amém)
  Future<Map<String, dynamic>?> toggleReaction({
    required String postId,
    required String reactionType, // 'pray' ou 'amen'
  }) async {
    final userId = _currentUserId ?? 'anon';
    try {
      final uri = Uri.parse('$_baseUrl/react');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'post_id': postId,
          'user_id': userId,
          'reaction_type': reactionType,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ [CommunityService] Erro ao reagir: $e');
    }
    return null;
  }

  /// Busca os comentários de um post
  Future<List<CommunityComment>> fetchComments(String postId) async {
    try {
      final uri = Uri.parse('$_baseUrl/comments?postId=$postId');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['comments'] is List) {
          return (data['comments'] as List)
              .map((c) => CommunityComment.fromJson(c as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [CommunityService] Erro ao buscar comentários: $e');
    }
    return [];
  }

  /// Adiciona um comentário
  Future<CommunityComment?> addComment({
    required String postId,
    required String text,
  }) async {
    final commentId = 'comm_${DateTime.now().millisecondsSinceEpoch}';
    final newComment = CommunityComment(
      id: commentId,
      postId: postId,
      userId: _currentUserId ?? 'anon',
      userName: _currentUserName,
      userAvatar: _currentUserAvatar,
      text: text,
      createdAt: DateTime.now(),
    );

    try {
      final uri = Uri.parse('$_baseUrl/comments');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(newComment.toJson()),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        return newComment;
      }
    } catch (e) {
      debugPrint('⚠️ [CommunityService] Erro ao adicionar comentário: $e');
    }

    return newComment;
  }

  /// Deleta um post
  Future<bool> deletePost(String postId) async {
    final userId = _currentUserId ?? '';
    try {
      final uri = Uri.parse('$_baseUrl/posts/$postId?userId=$userId');
      final res = await http.delete(uri).timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ [CommunityService] Erro ao excluir post: $e');
      return false;
    }
  }

}
