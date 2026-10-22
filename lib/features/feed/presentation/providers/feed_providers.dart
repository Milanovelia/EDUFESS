import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_providers.dart';
import '../../data/models/comment.dart';
import '../../data/models/post.dart';
import '../../data/models/subject.dart';
import '../../data/models/topic.dart';
import '../../data/repositories/feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(supabaseClientProvider));
});

final subjectsProvider = FutureProvider<List<Subject>>((ref) async {
  return ref.watch(feedRepositoryProvider).fetchSubjects();
});

/// Topics filtered by selected subject (null = all).
final topicsProvider = FutureProvider.family<List<Topic>, String?>((ref, subjectId) async {
  return ref.watch(feedRepositoryProvider).fetchTopics(subjectId: subjectId);
});

/// Feed filter state.
class FeedFilter {
  const FeedFilter({this.subjectId, this.topicId});
  final String? subjectId;
  final String? topicId;

  FeedFilter copyWith({String? subjectId, String? topicId, bool clearTopic = false}) {
    return FeedFilter(
      subjectId: subjectId ?? this.subjectId,
      topicId: clearTopic ? null : (topicId ?? this.topicId),
    );
  }
}

class FeedFilterNotifier extends Notifier<FeedFilter> {
  @override
  FeedFilter build() => const FeedFilter();
  void setFilter(FeedFilter filter) => state = filter;
  void clear() => state = const FeedFilter();
}

final feedFilterProvider = NotifierProvider<FeedFilterNotifier, FeedFilter>(FeedFilterNotifier.new);

final feedPostsProvider = FutureProvider<List<Post>>((ref) async {
  final filter = ref.watch(feedFilterProvider);
  return ref.watch(feedRepositoryProvider).fetchPosts(
        subjectId: filter.subjectId,
        topicId: filter.topicId,
      );
});

final postDetailProvider = FutureProvider.family<Post?, String>((ref, id) async {
  return ref.watch(feedRepositoryProvider).fetchPostById(id);
});

final commentsProvider = FutureProvider.family<List<Comment>, String>((ref, postId) async {
  return ref.watch(feedRepositoryProvider).fetchComments(postId);
});

final savedPostsProvider = FutureProvider<List<Post>>((ref) async {
  try {
    return await ref.watch(feedRepositoryProvider).fetchBookmarkedPostsFallback();
  } catch (_) {
    return ref.watch(feedRepositoryProvider).fetchBookmarkedPosts();
  }
});

class PostInteractionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> toggleHelpful(Post post) async {
    state = const AsyncLoading();
    try {
      await ref.read(feedRepositoryProvider).toggleHelpful(post.id, post.currentUserHelpful);
      ref.invalidate(feedPostsProvider);
      ref.invalidate(postDetailProvider(post.id));
      ref.invalidate(savedPostsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = translateHelpfulError(e);
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> toggleBookmark(Post post) async {
    state = const AsyncLoading();
    try {
      await ref.read(feedRepositoryProvider).toggleBookmark(post.id, post.currentUserBookmarked);
      ref.invalidate(feedPostsProvider);
      ref.invalidate(postDetailProvider(post.id));
      ref.invalidate(savedPostsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = translateBookmarkError(e);
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> createComment({
    required String postId,
    String? parentId,
    required String content,
    required bool isPseudonymous,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(feedRepositoryProvider).createComment(
            postId: postId,
            parentId: parentId,
            content: content,
            isPseudonymous: isPseudonymous,
          );
      ref.invalidate(commentsProvider(postId));
      ref.invalidate(feedPostsProvider);
      ref.invalidate(postDetailProvider(postId));
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = translateCommentError(e);
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> deletePost(String postId) async {
    state = const AsyncLoading();
    try {
      await ref.read(feedRepositoryProvider).softDeletePost(postId);
      ref.invalidate(feedPostsProvider);
      ref.invalidate(savedPostsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      state = AsyncError(e.toString(), StackTrace.current);
      return 'Gagal menghapus post.';
    }
  }

  Future<String?> editPost({
    required String postId,
    required String title,
    required String content,
    required String type,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(feedRepositoryProvider).updatePost(
            postId: postId,
            title: title,
            content: content,
            type: type,
          );
      ref.invalidate(feedPostsProvider);
      ref.invalidate(postDetailProvider(postId));
      ref.invalidate(savedPostsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = translatePostError(e);
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> deleteComment({required String commentId, required String postId}) async {
    state = const AsyncLoading();
    try {
      await ref.read(feedRepositoryProvider).softDeleteComment(commentId);
      ref.invalidate(commentsProvider(postId));
      ref.invalidate(feedPostsProvider);
      ref.invalidate(postDetailProvider(postId));
      state = const AsyncData(null);
      return null;
    } catch (e) {
      state = AsyncError(e.toString(), StackTrace.current);
      return 'Gagal menghapus komentar.';
    }
  }

  Future<String?> markBestAnswer({required String commentId, required String postId, required bool isBest}) async {
    state = const AsyncLoading();
    try {
      await ref.read(feedRepositoryProvider).markBestAnswer(commentId: commentId, isBest: isBest);
      ref.invalidate(commentsProvider(postId));
      ref.invalidate(postDetailProvider(postId));
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = translateBestAnswerError(e);
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }
}

final postInteractionProvider = NotifierProvider<PostInteractionController, AsyncValue<void>>(PostInteractionController.new);
