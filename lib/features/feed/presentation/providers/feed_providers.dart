import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_providers.dart';
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
