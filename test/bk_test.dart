import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_page.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_conversation_page.dart';
import 'package:edufess/features/counseling/presentation/providers/counseling_providers.dart';
import 'package:edufess/features/counseling/data/models/bk_conversation.dart';
import 'package:edufess/features/auth/data/profile_repository.dart';
import 'package:edufess/features/auth/presentation/providers/auth_controller.dart';

BkConversation _conv(String id, String alias, String status) => BkConversation(
      id: id,
      studentAlias: alias,
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      closedAt: status == 'closed' ? DateTime.now() : null,
    );

void main() {
  group('BK landing role behavior', () {
    testWidgets('student without consent shows consent view', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 's1', role: 'student')),
            hasBkConsentProvider.overrideWith((ref) async => false),
            studentConversationsProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: BkPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ketentuan BK'), findsOneWidget);
      expect(find.text('Saya menyetujui ketentuan BK (bk-consent-v1)'), findsOneWidget);
    });

    testWidgets('student with consent shows start counseling', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 's1', role: 'student')),
            hasBkConsentProvider.overrideWith((ref) async => true),
            studentConversationsProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: BkPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mulai Konseling'), findsOneWidget);
      expect(find.textContaining('Belum ada percakapan BK.'), findsOneWidget);
    });

    testWidgets('counselor shows queue and assigned tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 'c1', role: 'counselor')),
            counselorQueueProvider.overrideWith((ref) async => [_conv('1', 'Siswa BK #A1B2', 'open')]),
            counselorAssignedProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: BkPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Antrean'), findsOneWidget);
      expect(find.text('Ditangani'), findsOneWidget);
      expect(find.text('Siswa BK #A1B2'), findsOneWidget);
    });

    testWidgets('admin shows no BK privileged dashboard', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 'admin', role: 'admin')),
          ],
          child: const MaterialApp(home: BkPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Akses BK terbatas untuk siswa dan guru BK.'), findsOneWidget);
    });
  });

  group('Consent', () {
    testWidgets('consent requires checkbox', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 's1', role: 'student')),
            hasBkConsentProvider.overrideWith((ref) async => false),
          ],
          child: const MaterialApp(home: BkPage()),
        ),
      );
      await tester.pumpAndSettle();
      final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Saya Setuju dan Lanjutkan'));
      expect(btn.onPressed, isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      final btn2 = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Saya Setuju dan Lanjutkan'));
      expect(btn2.onPressed, isNotNull);
    });
  });

  group('Student conversation list', () {
    testWidgets('shows conversations', (tester) async {
      final convs = [_conv('1', 'Siswa BK #A1B2', 'open'), _conv('2', 'Siswa BK #C3D4', 'assigned')];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 's1', role: 'student')),
            hasBkConsentProvider.overrideWith((ref) async => true),
            studentConversationsProvider.overrideWith((ref) async => convs),
          ],
          child: const MaterialApp(home: BkPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Siswa BK #A1B2'), findsOneWidget);
      expect(find.textContaining('Siswa BK #C3D4'), findsOneWidget);
    });
  });

  group('BkConversationPage', () {
    testWidgets('shows message composer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 's1', role: 'student')),
            counselingMessagesProvider.overrideWith((ref, id) async => []),
          ],
          child: const MaterialApp(home: BkConversationPage(conversationId: 'conv1')),
        ),
      );
      await tester.pump();
      expect(find.text('Tulis pesan...'), findsOneWidget);
      expect(find.text('Kirim'), findsOneWidget);
    });

    testWidgets('shows empty messages', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 's1', role: 'student')),
            counselingMessagesProvider.overrideWith((ref, id) async => []),
            bkConversationProvider.overrideWith((ref, id) async => _conv('conv1', 'Siswa BK #A1B2', 'open')),
          ],
          child: const MaterialApp(home: BkConversationPage(conversationId: 'conv1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Belum ada pesan.'), findsOneWidget);
    });

    testWidgets('counselor sees reveal button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 'c1', role: 'counselor')),
            counselingMessagesProvider.overrideWith((ref, id) async => []),
          ],
          child: const MaterialApp(home: BkConversationPage(conversationId: 'conv1')),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('student does not see reveal', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 's1', role: 'student')),
            counselingMessagesProvider.overrideWith((ref, id) async => []),
          ],
          child: const MaterialApp(home: BkConversationPage(conversationId: 'conv1')),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('reveal requires reason', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 'c1', role: 'counselor')),
            counselingMessagesProvider.overrideWith((ref, id) async => []),
          ],
          child: const MaterialApp(home: BkConversationPage(conversationId: 'conv1')),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();
      expect(find.text('Akses Identitas'), findsOneWidget);
      expect(find.text('Alasan *'), findsOneWidget);
      await tester.tap(find.text('Konfirmasi'));
      await tester.pump();
      expect(find.text('Alasan wajib diisi.'), findsOneWidget);
    });
  });

  group('BkConversation model', () {
    test('fromMap', () {
      final m = {
        'id': '1',
        'student_id': 'stu-1',
        'counselor_id': null,
        'student_alias': 'Siswa BK #A1B2',
        'status': 'open',
        'identity_revealed_at': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      final c = BkConversation.fromMap(m);
      expect(c.studentAlias, 'Siswa BK #A1B2');
    });
  });
}
