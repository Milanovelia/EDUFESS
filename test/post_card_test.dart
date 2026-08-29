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

  testWidgets('PostCard shows subject and topic', (tester) async {
    final post = _fakePost(isPseudonymous: false, displayAuthor: 'M2_Student1');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PostCard(post: post)),
      ),
    );
    expect(find.text('Informatika'), findsOneWidget);
    expect(find.text('Pemrograman'), findsOneWidget);
  });
}
