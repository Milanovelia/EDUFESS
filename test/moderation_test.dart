import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/moderation/data/models/moderation_report.dart';
import 'package:edufess/features/moderation/presentation/providers/moderation_providers.dart';
import 'package:edufess/features/moderation/presentation/pages/moderation_page.dart';
import 'package:edufess/features/moderation/presentation/widgets/report_dialog.dart';
import 'package:edufess/features/feed/data/models/post.dart';
import 'package:edufess/features/feed/data/models/comment.dart';
import 'package:edufess/features/feed/presentation/widgets/post_card.dart';
import 'package:edufess/features/feed/presentation/widgets/comment_card.dart';
import 'package:edufess/features/auth/data/profile_repository.dart';
import 'package:edufess/features/auth/presentation/providers/auth_controller.dart';

Post _post(String id) => Post(
      id: id,
      type: 'note',
      title: 'Judul $id',
      content: 'konten $id',
      isPseudonymous: false,
      displayAuthor: 'Author',
      subjectId: 'sub-1',
      subjectName: 'Informatika',
      subjectSlug: 'informatika',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

Comment _comment(String id, {bool isOwn = false}) => Comment(
      id: id,
      postId: 'post-1',
      parentId: null,
      content: 'komen $id',
      isPseudonymous: false,
      displayAuthor: 'Author',
      isBestAnswer: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isOwn: isOwn,
    );

ModerationReport _report(String id, {String targetType = 'post', String reason = 'spam'}) => ModerationReport(
      reportId: id,
      targetType: targetType,
      reason: reason,
      details: 'detail',
      status: 'pending',
      createdAt: DateTime.now(),
      postId: targetType == 'post' ? 'post-1' : null,
      commentId: targetType == 'comment' ? 'comment-1' : null,
      targetTitle: 'Title',
      targetContent: 'Content',
      displayAuthor: 'Siswa Anonim #AB12',
      subjectName: 'Informatika',
      topicName: 'Pemrograman',
    );

void main() {
  group('ReportReason', () {
    test('labels exist', () {
      expect(ReportReason.labels['spam'], 'Spam');
      expect(ReportReason.labels['harassment'], 'Pelecehan');
      expect(ReportReason.labels['hate'], 'Ujaran kebencian');
      expect(ReportReason.all.length, 8);
    });
  });

  group('PostCard report action', () {
    testWidgets('shows report menu', (tester) async {
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: Scaffold(body: PostCard(post: _post('1'))))),
      );
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Laporkan'), findsOneWidget);
    });
  });

  group('CommentCard report action', () {
    testWidgets('shows report menu', (tester) async {
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: Scaffold(body: CommentCard(comment: _comment('1'))))),
      );
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Laporkan'), findsOneWidget);
    });

    testWidgets('shows reply and report together', (tester) async {
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: Scaffold(body: CommentCard(comment: _comment('1'), onReply: () {})))),
      );
      expect(find.text('Balas'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  group('Report dialog', () {
    testWidgets('reason selector and details field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(builder: (c, ref, _) {
                return ElevatedButton(
                  onPressed: () => showReportDialog(c, ref, targetType: 'post', postId: 'p1'),
                  child: const Text('open'),
                );
              }),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Laporkan Post'), findsOneWidget);
      expect(find.text('Alasan *'), findsOneWidget);
      expect(find.text('Detail (opsional)'), findsOneWidget);
      expect(find.text('Kirim'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
    });

    testWidgets('requires reason', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(builder: (c, ref, _) {
                return ElevatedButton(
                  onPressed: () => showReportDialog(c, ref, targetType: 'comment', commentId: 'c1'),
                  child: const Text('open'),
                );
              }),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim'));
      await tester.pump();
      expect(find.text('Pilih alasan.'), findsOneWidget);
    });
  });

  group('ModerationPage', () {
    testWidgets('loading state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isAdminProvider.overrideWith((ref) async => true),
            moderationQueueProvider.overrideWith((ref) async {
              await Future.delayed(const Duration(milliseconds: 100));
              return [];
            }),
          ],
          child: const MaterialApp(home: ModerationPage()),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('empty queue', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isAdminProvider.overrideWith((ref) async => true),
            moderationQueueProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: ModerationPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada laporan pending.'), findsOneWidget);
    });

    testWidgets('shows report card', (tester) async {
      final reports = [_report('r1', targetType: 'post', reason: 'spam'), _report('r2', targetType: 'comment', reason: 'harassment')];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isAdminProvider.overrideWith((ref) async => true),
            moderationQueueProvider.overrideWith((ref) async => reports),
          ],
          child: const MaterialApp(home: ModerationPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Spam'), findsOneWidget);
      expect(find.text('Pelecehan'), findsOneWidget);
      expect(find.text('Siswa Anonim #AB12'), findsWidgets);
    });

    testWidgets('dismiss confirmation', (tester) async {
      final reports = [_report('r1')];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isAdminProvider.overrideWith((ref) async => true),
            moderationQueueProvider.overrideWith((ref) async => reports),
            moderationActionProvider.overrideWith(() => _FakeModAction()),
          ],
          child: const MaterialApp(home: ModerationPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tolak'));
      await tester.pumpAndSettle();
      expect(find.text('Tolak laporan?'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
    });

    testWidgets('remove confirmation', (tester) async {
      final reports = [_report('r1')];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isAdminProvider.overrideWith((ref) async => true),
            moderationQueueProvider.overrideWith((ref) async => reports),
            moderationActionProvider.overrideWith(() => _FakeModAction()),
          ],
          child: const MaterialApp(home: ModerationPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus Konten'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus konten?'), findsOneWidget);
    });

    testWidgets('non-admin denied', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isAdminProvider.overrideWith((ref) async => false),
          ],
          child: const MaterialApp(home: ModerationPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tidak memiliki akses moderasi.'), findsOneWidget);
    });

    testWidgets('queue error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isAdminProvider.overrideWith((ref) async => true),
            moderationQueueProvider.overrideWith((ref) async => throw Exception('fail')),
          ],
          child: const MaterialApp(home: ModerationPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coba lagi'), findsOneWidget);
    });
  });

  group('ModerationReport model', () {
    test('fromMap', () {
      final m = {
        'report_id': 'r1',
        'target_type': 'post',
        'reason': 'spam',
        'details': null,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'reviewed_at': null,
        'reviewed_by': null,
        'post_id': 'p1',
        'comment_id': null,
        'target_title': 't',
        'target_content': 'c',
        'display_author': 'alias',
        'subject_name': 'Informatika',
        'topic_name': null,
      };
      final r = ModerationReport.fromMap(m);
      expect(r.reportId, 'r1');
      expect(r.isPost, true);
    });

    test('does not expose reporter identity', () {
      final m = {
        'report_id': 'r1',
        'target_type': 'post',
        'reason': 'spam',
        'details': null,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'reviewed_at': null,
        'reviewed_by': null,
        'post_id': 'p1',
        'comment_id': null,
        'target_title': 't',
        'target_content': 'c',
        'display_author': 'alias',
        'subject_name': 'Informatika',
        'topic_name': null,
        'reporter_id': 'should-not-exist',
      };
      final r = ModerationReport.fromMap(m);
      // reporter_id should be ignored even if present in raw map (legacy)
      expect(r.toString().contains('reporter'), false);
    });
  });

  group('isAdminProvider', () {
    test('true when admin', () async {
      final container = ProviderContainer(overrides: [
        currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 'admin', role: 'admin')),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(isAdminProvider.future), true);
    });
    test('false when student', () async {
      final container = ProviderContainer(overrides: [
        currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 's', role: 'student')),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(isAdminProvider.future), false);
    });
  });
}

class _FakeModAction extends ModerationActionController {
  @override
  Future<String?> dismiss(String reportId) async => null;
  @override
  Future<String?> remove(String reportId) async => null;
}
