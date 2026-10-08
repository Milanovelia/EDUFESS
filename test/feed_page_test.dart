import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/feed/data/models/post.dart';
import 'package:edufess/features/feed/presentation/pages/home_page.dart';
import 'package:edufess/features/feed/presentation/providers/feed_providers.dart';

Post _post(String title, String author) => Post(
      id: 'id-$title',
      type: 'note',
      title: title,
      content: 'konten $title',
      isPseudonymous: false,
      displayAuthor: author,
      subjectId: 'sub-1',
      subjectName: 'Informatika',
      subjectSlug: 'informatika',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

void main() {
  testWidgets('HomePage shows loading', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedPostsProvider.overrideWith((ref) => Future<List<Post>>.delayed(const Duration(milliseconds: 100), () => [])),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('HomePage shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedPostsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada post. Jadilah yang pertama berbagi!'), findsOneWidget);
  });

  testWidgets('HomePage shows error state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedPostsProvider.overrideWith((ref) async => throw Exception('fail')),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gagal memuat feed.'), findsOneWidget);
  });

  testWidgets('HomePage shows posts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedPostsProvider.overrideWith((ref) async => [_post('Judul 1', 'Author1')]),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Judul 1'), findsOneWidget);
    final authorLine = tester
        .widgetList<Text>(find.byWidgetPredicate(
          (w) => w is Text && w.textSpan != null,
        ))
        .single
        .textSpan!
        .toPlainText();
    expect(authorLine, contains('Author1'));
  });

  testWidgets('HomePage shows composer entry above feed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedPostsProvider.overrideWith((ref) async => [_post('Judul 1', 'Author1')]),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tulis sesuatu...'), findsOneWidget);
  });

  testWidgets('HomePage shows composer entry on empty feed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedPostsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tulis sesuatu...'), findsOneWidget);
    expect(find.text('Belum ada post. Jadilah yang pertama berbagi!'), findsOneWidget);
  });
}
