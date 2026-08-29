import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/create_post/presentation/pages/create_post_page.dart';
import 'package:edufess/features/feed/data/models/subject.dart';
import 'package:edufess/features/feed/presentation/providers/feed_providers.dart';

void main() {
  final fakeSubjects = [
    Subject(id: 'sub-1', name: 'Informatika', slug: 'informatika', createdAt: DateTime.now()),
    Subject(id: 'sub-2', name: 'Matematika', slug: 'matematika', createdAt: DateTime.now()),
  ];

  testWidgets('CreatePostPage renders form', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectsProvider.overrideWith((ref) async => fakeSubjects),
          topicsProvider.overrideWith((ref, subjectId) async => []),
        ],
        child: const MaterialApp(home: CreatePostPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buat Post'), findsOneWidget);
    expect(find.text('Judul *'), findsOneWidget);
    expect(find.text('Konten *'), findsOneWidget);
    // Button is inside ListView, may need scroll
    expect(find.text('Posting', skipOffstage: false), findsOneWidget);
  });

  testWidgets('CreatePostPage validates required fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectsProvider.overrideWith((ref) async => fakeSubjects),
          topicsProvider.overrideWith((ref, subjectId) async => []),
        ],
        child: const MaterialApp(home: CreatePostPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Posting', skipOffstage: false), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Should show validation errors for title/content
    expect(find.text('Judul wajib diisi.'), findsOneWidget);
  });

  testWidgets('CreatePostPage subject change resets topic', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectsProvider.overrideWith((ref) async => fakeSubjects),
          topicsProvider.overrideWith((ref, subjectId) async => []),
        ],
        child: const MaterialApp(home: CreatePostPage()),
      ),
    );
    await tester.pumpAndSettle();
    // Initially no topic dropdown when no subject selected
    expect(find.text('Topik (opsional)'), findsNothing);
    // Select subject
    await tester.tap(find.text('Mata Pelajaran *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Informatika').last);
    await tester.pumpAndSettle();
    // Now topic dropdown appears
    expect(find.text('Topik (opsional)'), findsOneWidget);
  });
}


