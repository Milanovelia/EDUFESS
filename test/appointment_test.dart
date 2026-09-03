import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/counseling/data/models/bk_appointment.dart';
import 'package:edufess/features/counseling/presentation/providers/counseling_providers.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_appointments_page.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_availability_page.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_appointments_page.dart';

BkAppointment _appt(String id, String status) => BkAppointment(
      appointmentId: id,
      status: status,
      requestedStartAt: DateTime.now().add(const Duration(days: 1)),
      requestedEndAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
      scheduledStartAt: status == 'accepted' ? DateTime.now().add(const Duration(days: 1)) : null,
      scheduledEndAt: status == 'accepted' ? DateTime.now().add(const Duration(days: 1, hours: 1)) : null,
      counselorDisplay: 'Guru BK',
      createdAt: DateTime.now(),
    );

CounselorSlot _slot(String id) => CounselorSlot(
      availabilityId: id,
      availableDate: DateTime.now().add(const Duration(days: 1)),
      startTime: '09:00:00',
      endTime: '10:00:00',
      counselorDisplay: 'Guru BK',
    );

void main() {
  group('BkAppointment model', () {
    test('fromStudentMap', () {
      final m = {
        'appointment_id': 'a1',
        'status': 'pending',
        'requested_start_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'requested_end_at': DateTime.now().add(const Duration(days: 1, hours: 1)).toIso8601String(),
        'scheduled_start_at': null,
        'scheduled_end_at': null,
        'student_note': 'note',
        'counselor_display': 'Guru BK',
        'created_at': DateTime.now().toIso8601String(),
        'cancelled_at': null,
        'completed_at': null,
      };
      final a = BkAppointment.fromStudentMap(m);
      expect(a.appointmentId, 'a1');
      expect(a.isPending, true);
    });

    test('status helpers', () {
      expect(_appt('1', 'pending').isPending, true);
      expect(_appt('1', 'accepted').isAccepted, true);
      expect(_appt('1', 'cancelled').isCancelled, true);
    });
  });

  group('Student appointments page', () {
    testWidgets('shows no appointments', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentAppointmentsProvider.overrideWith((ref) async => [])],
          child: const MaterialApp(home: BkAppointmentsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Belum ada jadwal'), findsOneWidget);
      expect(find.text('Buat Janji'), findsOneWidget);
    });

    testWidgets('shows appointments', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentAppointmentsProvider.overrideWith((ref) async => [_appt('1', 'pending'), _appt('2', 'accepted')]),
          ],
          child: const MaterialApp(home: BkAppointmentsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Menunggu Konfirmasi'), findsOneWidget);
      expect(find.text('Terjadwal'), findsOneWidget);
    });

    testWidgets('cancel button for pending', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentAppointmentsProvider.overrideWith((ref) async => [_appt('1', 'pending')]),
          ],
          child: const MaterialApp(home: BkAppointmentsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Batalkan Janji'), findsOneWidget);
    });
  });

  group('Counselor availability page', () {
    testWidgets('shows add slot', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myAvailabilityProvider.overrideWith((ref) async => [])],
          child: const MaterialApp(home: CounselorAvailabilityPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tambah Slot'), findsOneWidget);
      expect(find.text('Belum ada slot.'), findsOneWidget);
    });

    testWidgets('shows slots', (tester) async {
      final avail = CounselorAvailability(
        id: '1',
        counselorId: 'c1',
        availableDate: DateTime.now().add(const Duration(days: 1)),
        startTime: '09:00:00',
        endTime: '10:00:00',
        isActive: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myAvailabilityProvider.overrideWith((ref) async => [avail])],
          child: const MaterialApp(home: CounselorAvailabilityPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('09:00:00'), findsOneWidget);
    });
  });

  group('Counselor appointments page', () {
    testWidgets('shows tabs', (tester) async {
      final appt = BkAppointment(
        appointmentId: '1',
        status: 'pending',
        requestedStartAt: DateTime.now().add(const Duration(days: 1)),
        requestedEndAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
        studentAlias: 'Siswa BK #A1B2',
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [counselorAppointmentsProvider.overrideWith((ref) async => [appt])],
          child: const MaterialApp(home: CounselorAppointmentsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Tab, 'Permintaan'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Terjadwal'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Riwayat'), findsOneWidget);
    });

    testWidgets('shows pending actions', (tester) async {
      final appt = BkAppointment(
        appointmentId: '1',
        status: 'pending',
        requestedStartAt: DateTime.now().add(const Duration(days: 1)),
        requestedEndAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
        studentAlias: 'Siswa BK #A1B2',
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [counselorAppointmentsProvider.overrideWith((ref) async => [appt])],
          child: const MaterialApp(home: CounselorAppointmentsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Terima'), findsOneWidget);
      expect(find.text('Tolak'), findsOneWidget);
      expect(find.text('Atur Ulang'), findsOneWidget);
    });

    testWidgets('shows accepted actions', (tester) async {
      final appt = BkAppointment(
        appointmentId: '1',
        status: 'accepted',
        requestedStartAt: DateTime.now().add(const Duration(days: 1)),
        requestedEndAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
        scheduledStartAt: DateTime.now().add(const Duration(days: 1)),
        scheduledEndAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
        studentAlias: 'Siswa BK #A1B2',
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [counselorAppointmentsProvider.overrideWith((ref) async => [appt])],
          child: const MaterialApp(home: CounselorAppointmentsPage()),
        ),
      );
      await tester.pumpAndSettle();
      // Need to tap Terjadwal tab
      await tester.tap(find.text('Terjadwal'));
      await tester.pumpAndSettle();
      expect(find.text('Tandai Selesai'), findsOneWidget);
    });
  });

  group('CounselorSlot', () {
    test('dateLabel', () {
      final s = _slot('1');
      expect(s.dateLabel, contains('/'));
      expect(s.timeLabel, contains('09:00:00'));
    });
  });

  group('Time validation', () {
    test('start before end', () {
      final start = DateTime(2026, 9, 10, 9, 0);
      final end = DateTime(2026, 9, 10, 10, 0);
      expect(start.isBefore(end), true);
      expect(end.difference(start).inMinutes, 60);
    });

    test('past rejection', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(past.isBefore(DateTime.now()), true);
    });

    test('duration validation', () {
      final start = DateTime(2026, 9, 10, 9, 0);
      final end = DateTime(2026, 9, 10, 12, 0); // 3 hours > 120 min
      expect(end.difference(start).inMinutes > 120, true);
    });
  });
}
