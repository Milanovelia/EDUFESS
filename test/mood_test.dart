import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_mood_page.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_mood_history_page.dart';
import 'package:edufess/features/counseling/presentation/providers/counseling_providers.dart';
import 'package:edufess/features/counseling/data/models/bk_mood_checkin.dart';

BkMoodCheckin _mood(int level, String? note) => BkMoodCheckin(
      id: 'id-$level',
      moodLevel: level,
      note: note,
      checkedInAt: DateTime.now(),
    );

void main() {
  group('BkMoodCheckin model', () {
    test('labels', () {
      expect(BkMoodCheckin(id: '1', moodLevel: 1, checkedInAt: DateTime.now()).label, 'Sangat Buruk');
      expect(BkMoodCheckin(id: '1', moodLevel: 5, checkedInAt: DateTime.now()).label, 'Sangat Baik');
      expect(BkMoodCheckin(id: '1', moodLevel: 3, checkedInAt: DateTime.now()).emoji, '😐');
    });
  });

  group('BkMoodPage', () {
    testWidgets('shows mood options', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentMoodHistoryProvider.overrideWith((ref) async => [])],
          child: const MaterialApp(home: BkMoodPage()),
        ),
      );
      await tester.pump();
      expect(find.text('Bagaimana perasaanmu?'), findsOneWidget);
      expect(find.textContaining('Sangat Buruk'), findsWidgets);
      expect(find.textContaining('Sangat Baik'), findsWidgets);
      expect(find.text('Simpan Check-In'), findsOneWidget);
    });

    testWidgets('requires mood selection', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentMoodHistoryProvider.overrideWith((ref) async => [])],
          child: const MaterialApp(home: BkMoodPage()),
        ),
      );
      await tester.pump();
      final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Simpan Check-In'));
      expect(btn.onPressed, isNull);
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentMoodHistoryProvider.overrideWith((ref) async => [])],
          child: const MaterialApp(home: BkMoodPage()),
        ),
      );
      await tester.pump();
      expect(find.textContaining('bukan alat diagnosis'), findsOneWidget);
    });

    testWidgets('shows history', (tester) async {
      final history = [_mood(3, 'Biasa'), _mood(5, 'Senang')];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentMoodHistoryProvider.overrideWith((ref) async => history)],
          child: const MaterialApp(home: BkMoodPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Riwayat Mood'), findsOneWidget);
      expect(find.textContaining('Biasa'), findsWidgets);
      expect(find.textContaining('Sangat Baik'), findsWidgets);
    });

    testWidgets('shows empty history', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentMoodHistoryProvider.overrideWith((ref) async => [])],
          child: const MaterialApp(home: BkMoodPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada riwayat mood.'), findsOneWidget);
    });
  });

  group('CounselorMoodHistoryPage', () {
    testWidgets('shows alias and disclaimer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bkConversationProvider.overrideWith((ref, id) async => null),
            counselorMoodHistoryProvider.overrideWith((ref, id) async => [_mood(3, 'note')]),
          ],
          child: const MaterialApp(home: CounselorMoodHistoryPage(conversationId: 'conv1')),
        ),
      );
      await tester.pump();
      expect(find.textContaining('bukan hasil diagnosis'), findsOneWidget);
    });

    testWidgets('shows mood history', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bkConversationProvider.overrideWith((ref, id) async => null),
            counselorMoodHistoryProvider.overrideWith((ref, id) async => [_mood(2, 'Buruk'), _mood(4, 'Baik')]),
          ],
          child: const MaterialApp(home: CounselorMoodHistoryPage(conversationId: 'conv1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Buruk'), findsWidgets);
      expect(find.textContaining('Baik'), findsWidgets);
    });
  });
}
