import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/community/model/community_post.dart';
import 'package:keryx_app/features/community/model/community_story.dart';
import 'package:keryx_app/features/community/service/community_service.dart';

final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService();
});

class CommunityFeedState {
  final List<CommunityPost> posts;
  final List<CommunityStory> stories;
  final bool isLoading;
  final bool isRefreshing;
  final bool hasMore;
  final String? errorMessage;

  const CommunityFeedState({
    this.posts = const [],
    this.stories = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.hasMore = true,
    this.errorMessage,
  });

  CommunityFeedState copyWith({
    List<CommunityPost>? posts,
    List<CommunityStory>? stories,
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    String? errorMessage,
  }) {
    return CommunityFeedState(
      posts: posts ?? this.posts,
      stories: stories ?? this.stories,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
    );
  }
}

class CommunityFeedNotifier extends StateNotifier<CommunityFeedState> {
  final CommunityService _service;

  CommunityFeedNotifier(this._service) : super(const CommunityFeedState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final stories = await _service.fetchStories();
      final posts = await _service.fetchFeed(offset: 0, limit: 20);
      state = state.copyWith(
        stories: stories,
        posts: posts,
        isLoading: false,
        hasMore: posts.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Não foi possível carregar a comunidade.',
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true);
    try {
      final stories = await _service.fetchStories();
      final posts = await _service.fetchFeed(offset: 0, limit: 20);
      state = state.copyWith(
        stories: stories,
        posts: posts,
        isRefreshing: false,
        hasMore: posts.length >= 10,
      );
    } catch (_) {
      state = state.copyWith(isRefreshing: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    try {
      final nextPosts = await _service.fetchFeed(
        offset: state.posts.length,
        limit: 20,
      );
      if (nextPosts.isEmpty) {
        state = state.copyWith(hasMore: false);
      } else {
        state = state.copyWith(
          posts: [...state.posts, ...nextPosts],
          hasMore: nextPosts.length >= 20,
        );
      }
    } catch (_) {}
  }

  /// Alterna reação otimista no post
  Future<void> toggleReaction(String postId, String reactionType) async {
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final currentPost = state.posts[index];
    final isPray = reactionType == 'pray';

    final bool newActive;
    final int newPrayCount;
    final int newAmenCount;

    if (isPray) {
      newActive = !currentPost.userPrayed;
      newPrayCount = newActive
          ? currentPost.prayingCount + 1
          : (currentPost.prayingCount > 0 ? currentPost.prayingCount - 1 : 0);
      newAmenCount = currentPost.amenCount;
    } else {
      newActive = !currentPost.userAmen;
      newAmenCount = newActive
          ? currentPost.amenCount + 1
          : (currentPost.amenCount > 0 ? currentPost.amenCount - 1 : 0);
      newPrayCount = currentPost.prayingCount;
    }

    final updatedPost = currentPost.copyWith(
      userPrayed: isPray ? newActive : currentPost.userPrayed,
      userAmen: !isPray ? newActive : currentPost.userAmen,
      prayingCount: newPrayCount,
      amenCount: newAmenCount,
    );

    final updatedList = List<CommunityPost>.from(state.posts);
    updatedList[index] = updatedPost;
    state = state.copyWith(posts: updatedList);

    // Envia requisição para o D1 em segundo plano
    _service.toggleReaction(postId: postId, reactionType: reactionType);
  }

  /// Adiciona novo post publicado pelo usuário no topo da lista
  void addLocalPost(CommunityPost post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  /// Adiciona novo story publicado pelo usuário no topo da bandeja de stories
  void addLocalStory(CommunityStory story) {
    state = state.copyWith(stories: [story, ...state.stories]);
  }

  /// Remove post deletado
  Future<void> deletePost(String postId) async {
    final updatedList = state.posts.where((p) => p.id != postId).toList();
    state = state.copyWith(posts: updatedList);
    await _service.deletePost(postId);
  }
}

final communityFeedProvider =
    StateNotifierProvider<CommunityFeedNotifier, CommunityFeedState>((ref) {
  final service = ref.watch(communityServiceProvider);
  return CommunityFeedNotifier(service);
});
