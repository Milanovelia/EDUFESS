import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/explore/presentation/pages/explore_page.dart';
import 'package:edufess/features/explore/presentation/providers/explore_search_providers.dart';
import 'package:edufess/features/feed/data/models/post.dart';
import 'package:edufess/features/feed/data/models/subject.dart';
import 'package:edufess/features/feed/data/models/topic.dart';
import 'package:edufess/features/feed/presentation/providers/feed_providers.dart';

Post _post(String id, String title, {String? subjectId, String? topicId, String type = 'note', bool isPseudo = false, String author = 'Author'}) => Post(
      id: id,
      type: type,
      title: title,
      content: 'content $title',
      isPseudonymous: isPseudo,
      displayAuthor: author,
      subjectId: subjectId ?? 'sub-1',
      subjectName: 'Informatika',
      subjectSlug: 'informatika',
      topicId: topicId,
      topicName: topicId != null ? 'Pemrograman' : null,
      topicSlug: topicId != null ? 'pemrograman' : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      helpfulCount: 1,
      commentCount: 2,
    );

final fakeSubjects = [
  Subject(id: 'sub-1', name: 'Informatika', slug: 'informatika', createdAt: DateTime.now()),
  Subject(id: 'sub-2', name: 'Matematika', slug: 'matematika', createdAt: DateTime.now()),
];

final fakeTopicsInf = [
  Topic(id: 'top-1', subjectId: 'sub-1', name: 'Pemrograman', slug: 'pemrograman', createdAt: DateTime.now()),
  Topic(id: 'top-2', subjectId: 'sub-1', name: 'Algoritma', slug: 'algoritma', createdAt: DateTime.now()),
];

/// Helper to pump ExplorePage with overrides
Future<void> pumpExplore(
  WidgetTester tester, {
  ExploreSearchState? searchState,
  List<Subject>? subjects,
  List<Topic>? topics,
  List<String>? recent,
}) async {
  final state = searchState ?? const ExploreSearchState();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subjectsProvider.overrideWith((ref) async => subjects ?? fakeSubjects),
        topicsProvider.overrideWith((ref, subjectId) async => topics ?? (subjectId == 'sub-1' ? fakeTopicsInf : [])),
        exploreSearchProvider.overrideWith(() => _FakeSearchNotifier(state)),
        if (recent != null) recentSearchesProvider.overrideWith(() => _FakeRecentNotifier(recent)),
      ],
      child: const MaterialApp(home: ExplorePage()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeSearchNotifier extends ExploreSearchNotifier {
  _FakeSearchNotifier(this._state);
  final ExploreSearchState _state;
  @override
  ExploreSearchState build() => _state;
}

class _FakeRecentNotifier extends RecentSearchesNotifier {
  _FakeRecentNotifier(this._list);
  final List<String> _list;
  @override
  List<String> build() => _list;
}

void main() {
  group('Explore initial state', () {
    testWidgets('shows discovery text when no query/filter', (tester) async {
      await pumpExplore(tester);
      expect(find.text('Jelajahi materi dan diskusi dari berbagai pelajaran.'), findsOneWidget);
    });

    testWidgets('shows search field', (tester) async {
      await pumpExplore(tester);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cari judul, konten, atau topik...'), findsOneWidget);
    });

    testWidgets('shows no subject/topic filters', (tester) async {
      await pumpExplore(tester);
      expect(find.text('Informatika'), findsNothing);
      expect(find.text('Matematika'), findsNothing);
      expect(find.text('Pemrograman'), findsNothing);
    });
  });

  group('search input', () {
    testWidgets('clear button appears when query not empty', (tester) async {
      await pumpExplore(tester, searchState: const ExploreSearchState(query: 'flutter'));
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear button absent when query empty', (tester) async {
      await pumpExplore(tester);
      expect(find.byIcon(Icons.clear), findsNothing);
    });
  });

  group('search states', () {
    testWidgets('shows loading when searching', (tester) async {
      final state = const ExploreSearchState(query: 'flutter', loading: true, results: []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectsProvider.overrideWith((ref) async => fakeSubjects),
            topicsProvider.overrideWith((ref, subjectId) async => []),
            exploreSearchProvider.overrideWith(() => _FakeSearchNotifier(state)),
          ],
          child: const MaterialApp(home: ExplorePage()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows results', (tester) async {
      final posts = [_post('1', 'Flutter Dasar'), _post('2', 'Dart Lanjutan')];
      await pumpExplore(tester, searchState: ExploreSearchState(query: 'flutter', results: posts, hasMore: false, offset: 2));
      expect(find.text('Flutter Dasar'), findsOneWidget);
      expect(find.text('Dart Lanjutan'), findsOneWidget);
    });

    testWidgets('shows no results filtered message', (tester) async {
      await pumpExplore(tester, searchState: const ExploreSearchState(query: 'tidakada', results: [], hasMore: false));
      expect(find.text('Coba ubah kata kunci atau filter pencarian.'), findsOneWidget);
    });

    testWidgets('shows error with retry', (tester) async {
      await pumpExplore(tester, searchState: const ExploreSearchState(query: 'flutter', error: 'Pencarian gagal. Coba lagi.', results: []));
      expect(find.text('Pencarian gagal. Coba lagi.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });
  });

  group('filters', () {
    testWidgets('subject/topic filters removed', (tester) async {
      await pumpExplore(tester);
      expect(find.text('Informatika'), findsNothing);
      expect(find.text('Pemrograman'), findsNothing);
    });

    testWidgets('post type filter', (tester) async {
      await pumpExplore(tester);
      expect(find.text('Catatan'), findsOneWidget);
      expect(find.text('Pertanyaan'), findsOneWidget);
      expect(find.text('Rangkuman'), findsOneWidget);
    });

    testWidgets('sort selector', (tester) async {
      await pumpExplore(tester, searchState: const ExploreSearchState(sort: 'terbaru'));
      expect(find.text('Terbaru'), findsOneWidget);
      // Check dropdown exists
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });
  });

  group('pseudonymous display', () {
    String authorLine(WidgetTester tester) => tester
        .widgetList<Text>(find.byWidgetPredicate(
          (w) => w is Text && w.textSpan != null,
        ))
        .map((w) => w.textSpan!.toPlainText())
        .firstWhere((s) => s.isNotEmpty);

    testWidgets('result shows alias for pseudonymous', (tester) async {
      final post = _post('1', 'Judul Pseudo', isPseudo: true, author: 'Siswa Anonim #AB12');
      await pumpExplore(tester, searchState: ExploreSearchState(query: 'pseudo', results: [post]));
      expect(authorLine(tester), contains('Siswa Anonim #AB12'));
    });

    testWidgets('result shows pseudonym for public', (tester) async {
      final post = _post('1', 'Judul Public', isPseudo: false, author: 'M4_Student1');
      await pumpExplore(tester, searchState: ExploreSearchState(query: 'public', results: [post]));
      expect(authorLine(tester), contains('M4_Student1'));
    });
  });

  group('pagination', () {
    testWidgets('load more button when hasMore', (tester) async {
      final posts = [_post('1', 'A'), _post('2', 'B')];
      final state = ExploreSearchState(query: 'a', results: posts, hasMore: true, offset: 2);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectsProvider.overrideWith((ref) async => fakeSubjects),
            topicsProvider.overrideWith((ref, subjectId) async => fakeTopicsInf),
            exploreSearchProvider.overrideWith(() => _FakeSearchNotifier(state)),
          ],
          child: const MaterialApp(home: ExplorePage()),
        ),
      );
      await tester.pumpAndSettle();
      // scroll to ensure button visible - find the vertical list
      final vertical = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.vertical);
      await tester.drag(vertical, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('Muat lebih banyak'), findsOneWidget);
    });

    testWidgets('no load more when no more', (tester) async {
      final posts = [_post('1', 'A')];
      await pumpExplore(tester, searchState: ExploreSearchState(query: 'a', results: posts, hasMore: false, offset: 1));
      expect(find.text('Muat lebih banyak'), findsNothing);
    });
  });

  group('recent searches', () {
    testWidgets('shows recent when query empty', (tester) async {
      await pumpExplore(tester, recent: ['flutter', 'aljabar']);
      expect(find.text('Pencarian terbaru'), findsOneWidget);
      expect(find.text('flutter'), findsOneWidget);
      expect(find.text('aljabar'), findsOneWidget);
    });

    testWidgets('clear history button', (tester) async {
      await pumpExplore(tester, recent: ['flutter']);
      expect(find.text('Hapus'), findsOneWidget);
    });

    testWidgets('hides recent when query not empty', (tester) async {
      await pumpExplore(tester, searchState: const ExploreSearchState(query: 'flutter'), recent: ['flutter']);
      expect(find.text('Pencarian terbaru'), findsNothing);
    });
  });

  group('ExploreSearchState', () {
    test('hasQueryOrFilter false when empty', () {
      const s = ExploreSearchState();
      expect(s.hasQueryOrFilter, false);
    });
    test('hasQueryOrFilter true when query', () {
      const s = ExploreSearchState(query: 'test');
      expect(s.hasQueryOrFilter, true);
    });
    test('hasQueryOrFilter true when subject', () {
      const s = ExploreSearchState(subjectId: 'sub-1');
      expect(s.hasQueryOrFilter, true);
    });
  });

  group('RecentSearchesNotifier', () {
    test('adds up to 5', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(recentSearchesProvider.notifier);
      for (var i = 0; i < 7; i++) {
        notifier.add('q$i');
      }
      expect(container.read(recentSearchesProvider).length, 5);
      expect(container.read(recentSearchesProvider).first, 'q6');
    });

    test('dedupes and moves to front', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(recentSearchesProvider.notifier);
      notifier.add('flutter');
      notifier.add('aljabar');
      notifier.add('flutter');
      expect(container.read(recentSearchesProvider), ['flutter', 'aljabar']);
    });

    test('clear', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(recentSearchesProvider.notifier);
      notifier.add('test');
      notifier.clear();
      expect(container.read(recentSearchesProvider), isEmpty);
    });
  });

  group('ExploreSort', () {
    test('labels exist', () {
      expect(ExploreSort.labels['terbaru'], 'Terbaru');
      expect(ExploreSort.labels['helpful'], 'Paling Membantu');
      expect(ExploreSort.labels['comments'], 'Paling Banyak Dikomentari');
    });
  });
}
