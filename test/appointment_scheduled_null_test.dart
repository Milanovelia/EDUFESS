import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edufess/features/counseling/data/models/bk_appointment.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_appointments_page.dart';
import 'package:edufess/features/counseling/presentation/providers/counseling_providers.dart';

/// P0-1: the schema permits one-sided-null scheduled times, so the student
/// appointment card must render every combination without force-unwrapping.
void main() {
  final day = DateTime.now().add(const Duration(days: 1));
  final hourLater = day.add(const Duration(hours: 1));

  BkAppointment appt({required String id, DateTime? start, DateTime? end}) =>
      BkAppointment(
        appointmentId: id,
        status: 'pending',
        requestedStartAt: day,
        requestedEndAt: hourLater,
        scheduledStartAt: start,
        scheduledEndAt: end,
        counselorDisplay: 'Guru BK',
        createdAt: DateTime.now(),
      );

  Future<void> pumpCard(WidgetTester tester, BkAppointment a) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentAppointmentsProvider.overrideWith((ref) async => [a]),
        ],
        child: const MaterialApp(home: BkAppointmentsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('P0-1 scheduled-time null safety', () {
    testWidgets('start + end renders existing range', (tester) async {
      await pumpCard(tester, appt(id: 'a1', start: day, end: hourLater));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Terjadwal:'), findsOneWidget);
    });

    testWidgets('start + null end renders without throwing', (tester) async {
      await pumpCard(tester, appt(id: 'a2', start: day));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Terjadwal mulai:'), findsOneWidget);
      expect(find.textContaining(' - '), findsNothing);
    });

    testWidgets('null start + end renders without throwing', (tester) async {
      await pumpCard(tester, appt(id: 'a3', end: hourLater));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Terjadwal sampai:'), findsOneWidget);
    });

    testWidgets('null + null hides scheduling line', (tester) async {
      await pumpCard(tester, appt(id: 'a4'));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Terjadwal'), findsNothing);
    });
  });
}
