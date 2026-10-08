import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/feed/data/models/post.dart';
import 'package:edufess/features/feed/presentation/widgets/post_card.dart';

Post _fakePost({required bool isPseudonymous, required String displayAuthor}) {
  return Post(
    id: 'test-id',
    type: 'question',
    title: 'Kenapa for loop lebih cocok?',
    content: 'Penjelasan panjang tentang for loop dan while loop di pemrograman.',
    isPseudonymous: isPseudonymous,
    displayAuthor: displayAuthor,
    subjectId: 'sub-1',
    subjectName: 'Informatika',
    subjectSlug: 'informatika',
    topicId: 'topic-1',
    topicName: 'Pemrograman',
    topicSlug: 'pemrograman',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    updatedAt: DateTime.now(),
  );
}

void main() {
  testWidgets('PostCard shows public author pseudonym', (tester) async {
    final post = _fakePost(isPseudonymous: false, displayAuthor: 'M2_Student1');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PostCard(post: post)),
      ),
    );
    expect(find.text('M2_Student1'), findsOneWidget);
    expect(find.text('Kenapa for loop lebih cocok?'), findsOneWidget);
  });

  testWidgets('PostCard shows pseudonymous alias', (tester) async {
    final post = _fakePost(isPseudonymous: true, displayAuthor: 'Siswa Anonim #A1B2');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PostCard(post: post)),
      ),
    );
    expect(find.text('Siswa Anonim #A1B2'), findsOneWidget);
    expect(find.text('M2_Student1'), findsNothing);
  });

  testWidgets('PostCard hides subject and topic chips', (tester) async {
    final post = _fakePost(isPseudonymous: false, displayAuthor: 'M2_Student1');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PostCard(post: post)),
      ),
    );
    expect(find.text('Informatika'), findsNothing);
    expect(find.text('Pemrograman'), findsNothing);
    expect(find.text('Kenapa for loop lebih cocok?'), findsOneWidget);
  });

  testWidgets('PostCard comment icon has explicit tap handler', (tester) async {
    final post = _fakePost(isPseudonymous: false, displayAuthor: 'M2_Student1');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PostCard(post: post)),
      ),
    );
    // The comment-count icon sits between helpful (favorite) and bookmark.
    final commentIcon = find.byIcon(Icons.chat_bubble_outline);
    expect(commentIcon, findsOneWidget);
    final ancestors = find.ancestor(
      of: commentIcon,
      matching: find.byWidgetPredicate(
        (w) => w is InkWell && w.onTap != null,
      ),
    );
    // Inner comment InkWell (padded hit area) + outer card InkWell.
    expect(ancestors, findsNWidgets(2));
    final inner = tester.widgetList<InkWell>(ancestors).firstWhere(
      (w) => w.child is Padding,
    );
    expect(inner.onTap, isNotNull);
  });

  testWidgets('PostCard without subject renders without crash', (tester) async {
    final post = Post(
      id: 'no-subject-id',
      type: 'note',
      title: 'Postingan bebas',
      content: 'Konten tanpa mata pelajaran.',
      isPseudonymous: false,
      displayAuthor: 'M2_Student1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PostCard(post: post)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Postingan bebas'), findsOneWidget);
    expect(find.text('Informatika'), findsNothing);
  });

  test('Post.fromMap parses null subject fields', () {
    final now = DateTime.now().toIso8601String();
    final post = Post.fromMap({
      'id': 'null-subject',
      'type': 'note',
      'title': 't',
      'content': 'c',
      'is_pseudonymous': false,
      'display_author': 'M2_Student1',
      'subject_id': null,
      'subject_name': null,
      'subject_slug': null,
      'topic_id': null,
      'topic_name': null,
      'topic_slug': null,
      'created_at': now,
      'updated_at': now,
    });
    expect(post.subjectId, isNull);
    expect(post.subjectName, isNull);
    expect(post.subjectSlug, isNull);
  });
}
