import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/feed/data/models/post.dart';
import 'package:edufess/features/feed/presentation/pages/post_detail_page.dart';
import 'package:edufess/features/feed/presentation/providers/feed_providers.dart';

Post _post({required bool isPseudonymous}) => Post(
      id: 'test-id',
      type: 'question',
      title: 'Judul Detail',
      content: 'Konten lengkap untuk detail post.',
      isPseudonymous: isPseudonymous,
      displayAuthor: isPseudonymous ? 'Siswa Anonim #B2C3' : 'M2_Student1',
      subjectId: 'sub-1',
      subjectName: 'Informatika',
      subjectSlug: 'informatika',
      topicId: 'topic-1',
      topicName: 'Algoritma',
      topicSlug: 'algoritma',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

void main() {
  testWidgets('PostDetail shows not found for null', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postDetailProvider.overrideWith((ref, id) async => null),
        ],
        child: const MaterialApp(home: PostDetailPage(postId: 'missing')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Post tidak ditemukan atau telah dihapus.'), findsOneWidget);
  });

  testWidgets('PostDetail renders post', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postDetailProvider.overrideWith((ref, id) async => _post(isPseudonymous: false)),
        ],
        child: const MaterialApp(home: PostDetailPage(postId: 'test-id')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Judul Detail'), findsOneWidget);
    expect(find.text('M2_Student1'), findsOneWidget);
    expect(find.text('Konten lengkap untuk detail post.'), findsOneWidget);
  });

  testWidgets('PostDetail shows pseudonymous alias', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postDetailProvider.overrideWith((ref, id) async => _post(isPseudonymous: true)),
        ],
        child: const MaterialApp(home: PostDetailPage(postId: 'test-id')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Siswa Anonim #B2C3'), findsOneWidget);
  });

  testWidgets('PostDetail without subject hides subject chip', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postDetailProvider.overrideWith(
            (ref, id) async => Post(
              id: 'test-id',
              type: 'note',
              title: 'Judul Bebas',
              content: 'Konten tanpa mata pelajaran.',
              isPseudonymous: false,
              displayAuthor: 'M2_Student1',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
        ],
        child: const MaterialApp(home: PostDetailPage(postId: 'test-id')),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Judul Bebas'), findsOneWidget);
    expect(find.text('Informatika'), findsNothing);
  });
}
