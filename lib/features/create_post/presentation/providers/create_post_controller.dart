import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_providers.dart';
import '../../../feed/data/repositories/feed_repository.dart';

class CreatePostController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  SupabaseClient get _client => ref.read(supabaseClientProvider);

  Future<String?> createPost({
    required String type,
    required String title,
    required String content,
    String? subjectId,
    String? topicId,
    required bool isPseudonymous,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = FeedRepository(_client);
      await repo.createPost(
        type: type,
        title: title,
        content: content,
        subjectId: subjectId,
        topicId: topicId,
        isPseudonymous: isPseudonymous,
      );
      state = const AsyncData(null);
      return null;
    } catch (e) {
      // Log raw so logcat exposes DB/RLS root cause without leaking to UI.
      // ignore: avoid_print
      print('[CreatePost] raw error: $e');
      final msg = translatePostError(e);
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }
}

final createPostControllerProvider =
    NotifierProvider<CreatePostController, AsyncValue<void>>(CreatePostController.new);
