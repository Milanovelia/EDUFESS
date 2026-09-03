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
  group('M8 Counselor landing', () {
    testWidgets('queue shows alias only and Tangani', (tester) async {
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
      expect(find.text('Siswa BK #A1B2'), findsOneWidget);
      expect(find.text('Tangani'), findsOneWidget);
      expect(find.textContaining('Menunggu penanganan'), findsOneWidget);
    });

    testWidgets('queue empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 'c1', role: 'counselor')),
            counselorQueueProvider.overrideWith((ref) async => []),
            counselorAssignedProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: BkPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada percakapan yang menunggu.'), findsOneWidget);
    });

    testWidgets('assigned shows active and history', (tester) async {
      final active = [_conv('1', 'Siswa BK #A1B2', 'assigned')];
      final history = [_conv('2', 'Siswa BK #C3D4', 'closed')];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 'c1', role: 'counselor')),
            counselorQueueProvider.overrideWith((ref) async => []),
            counselorAssignedProvider.overrideWith((ref) async => [...active, ...history]),
          ],
          child: const MaterialApp(home: BkPage()),
        ),
      );
      await tester.pumpAndSettle();
      // Tap Ditangani tab
      await tester.tap(find.text('Ditangani'));
      await tester.pumpAndSettle();
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.textContaining('Siswa BK #A1B2'), findsOneWidget);
      expect(find.textContaining('Siswa BK #C3D4'), findsOneWidget);
    });
  });

  group('Counselor conversation detail', () {
    testWidgets('shows alias and status', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 'c1', role: 'counselor')),
            counselingMessagesProvider.overrideWith((ref, id) async => []),
            bkConversationProvider.overrideWith((ref, id) async => _conv('conv1', 'Siswa BK #A1B2', 'assigned')),
          ],
          child: const MaterialApp(home: BkConversationPage(conversationId: 'conv1')),
        ),
      );
      await tester.pump();
      expect(find.text('Identitas BK kamu: Siswa BK #A1B2'), findsOneWidget);
      expect(find.textContaining('Sedang Ditangani'), findsOneWidget);
    });

    testWidgets('closed shows read-only and no composer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 'c1', role: 'counselor')),
            counselingMessagesProvider.overrideWith((ref, id) async => []),
            bkConversationProvider.overrideWith((ref, id) async => _conv('conv1', 'Siswa BK #A1B2', 'closed')),
          ],
          child: const MaterialApp(home: BkConversationPage(conversationId: 'conv1')),
        ),
      );
      await tester.pump();
      expect(find.text('Percakapan ini telah selesai.'), findsWidgets);
      expect(find.text('Tulis pesan...'), findsNothing);
    });

    testWidgets('shows close and reveal in popup', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => const UserProfile(id: '1', pseudonym: 'c1', role: 'counselor')),
            counselingMessagesProvider.overrideWith((ref, id) async => []),
            bkConversationProvider.overrideWith((ref, id) async => _conv('conv1', 'Siswa BK #A1B2', 'assigned')),
          ],
          child: const MaterialApp(home: BkConversationPage(conversationId: 'conv1')),
        ),
      );
      await tester.pump();
      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Buka Identitas'), findsOneWidget);
      expect(find.text('Selesaikan Percakapan'), findsOneWidget);
    });
  });

  group('BkConversation model M7/M8', () {
    test('isActive and isClosed', () {
      final open = _conv('1', 'Siswa BK #A1B2', 'open');
      final assigned = _conv('2', 'Siswa BK #C3D4', 'assigned');
      final closed = _conv('3', 'Siswa BK #E5F6', 'closed');
      expect(open.isActive, true);
      expect(assigned.isActive, true);
      expect(closed.isClosed, true);
      expect(closed.isActive, false);
    });

    test('fromQueueMap minimal', () {
      final m = {
        'conversation_id': '1',
        'student_alias': 'Siswa BK #A1B2',
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'closed_at': null,
      };
      final c = BkConversation.fromQueueMap(m);
      expect(c.studentAlias, 'Siswa BK #A1B2');
      expect(c.studentId, isNull);
    });
  });
}
