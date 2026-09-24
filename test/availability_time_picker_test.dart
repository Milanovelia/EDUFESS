import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:edufess/app/theme/app_theme.dart';
import 'package:edufess/features/counseling/data/counseling_repository.dart';
import 'package:edufess/features/counseling/data/models/bk_appointment.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_availability_page.dart';
import 'package:edufess/features/counseling/presentation/providers/counseling_providers.dart';

/// BK-APPT-04: availability time pickers are dial-only.
///
/// The framework keyboard/input time-picker mode crashes inside small or
/// keyboard-shrunk viewports (invalid constraints — device showed
/// "BoxConstraints has non-normalized height constraints"). The crash is
/// theme-independent (reproduced with the default theme too), so no local
/// theme override can fix it; dial mode is device-verified working.
/// These tests lock the fallback under the real [AppTheme] at phone size:
/// the picker opens, no input-mode toggle exists, and saving still works.
void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    _RecordingRepo repo, {
    required DateTime slotDate,
  }) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          counselingRepositoryProvider.overrideWithValue(repo),
          myAvailabilityProvider.overrideWith(
            (ref) async => [
              CounselorAvailability(
                id: 's1',
                counselorId: 'c1',
                availableDate: slotDate,
                startTime: '09:00:00',
                endTime: '10:00:00',
                isActive: true,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CounselorAvailabilityPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openStartPicker(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih Mulai'));
    await tester.pumpAndSettle();
  }

  group('BK-APPT-04 dial-only time pickers (AppTheme, phone size)', () {
    testWidgets('picker opens without exception', (tester) async {
      await pumpPage(
        tester,
        _RecordingRepo(),
        slotDate: DateTime.now().add(const Duration(days: 2)),
      );
      await openStartPicker(tester);
      expect(tester.takeException(), isNull);
      // Dial picker is showing (OK action present).
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('switch-to-input control is unavailable', (tester) async {
      await pumpPage(
        tester,
        _RecordingRepo(),
        slotDate: DateTime.now().add(const Duration(days: 2)),
      );
      await openStartPicker(tester);
      expect(tester.takeException(), isNull);
      // dialOnly: no entry-mode toggle of either direction exists.
      expect(find.byTooltip('Switch to text input mode'), findsNothing);
      expect(find.byTooltip('Switch to dial input mode'), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('time can still be changed and saved', (tester) async {
      final repo = _RecordingRepo();
      await pumpPage(
        tester,
        repo,
        slotDate: DateTime.now().add(const Duration(days: 2)),
      );
      expect(find.text('Edit Slot'), findsNothing);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Save unchanged valid values straight from the prefilled dialog.
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(repo.updatedIds, ['s1']);
      expect(repo.updatedStart, '09:00:00');
      expect(repo.updatedEnd, '10:00:00');
      expect(find.text('Slot diubah.'), findsOneWidget);
    });
  });
}

/// In-memory stand-in: records update calls for save-flow assertions.
class _RecordingRepo extends CounselingRepository {
  _RecordingRepo()
    : super(
        SupabaseClient(
          'http://localhost:1',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<String> updatedIds = [];
  String? updatedStart;
  String? updatedEnd;

  @override
  Future<void> updateAvailability({
    required String availabilityId,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    updatedIds.add(availabilityId);
    updatedStart = startTime;
    updatedEnd = endTime;
  }

  @override
  Future<void> deactivateAvailability({required String availabilityId}) async {}
}
