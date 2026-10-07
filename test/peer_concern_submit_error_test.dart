import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:edufess/features/counseling/data/peer_concern_repository.dart';
import 'package:edufess/features/counseling/presentation/providers/peer_concern_providers.dart';

/// Submit duplicate-active error mapping.
///
/// Device finding (BK-PC-03): server RPC `submit_bk_peer_concern` rejects
/// with the Indonesian message
/// 'Kamu sudah memiliki laporan aktif untuk teman ini.'.
/// The repository translator must surface that exact message instead of
/// degrading to the generic 'Gagal mengirim kepedulian.'.
///
/// These tests run the REAL repository translator (plus the REAL
/// controller path) against raw [PostgrestException]s via [_RpcClient],
/// so the asserted messages are the production mapping — not a copy of it.
void main() {
  PeerConcernRepository repoThrowing(String message) =>
      PeerConcernRepository(_RpcClient(PostgrestException(message: message)));

  group('submit duplicate-active error mapping (real translator)', () {
    test('Indonesian server message maps to the specific message, '
        'not the generic fallback', () async {
      final repo = repoThrowing(
        'Kamu sudah memiliki laporan aktif untuk teman ini.',
      );
      try {
        await repo.submit(
          targetStudentRef: 'target-id',
          reason: 'bullying',
          details: 'dia dibully',
        );
        fail('submit should throw');
      } on PeerConcernException catch (e) {
        expect(e.message, 'Kamu sudah memiliki laporan aktif untuk teman ini.');
        expect(e.message, isNot('Gagal mengirim kepedulian.'));
      }
    });

    test('legacy English variant keeps working', () async {
      final repo = repoThrowing('already have an active report');
      try {
        await repo.submit(targetStudentRef: 'target-id', reason: 'bullying');
        fail('submit should throw');
      } on PeerConcernException catch (e) {
        expect(e.message, 'Kamu sudah memiliki laporan aktif untuk teman ini.');
      }
    });

    test('controller surfaces the specific message to the UI', () async {
      final container = ProviderContainer(
        overrides: [
          peerConcernRepositoryProvider.overrideWithValue(
            repoThrowing('Kamu sudah memiliki laporan aktif untuk teman ini.'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final err = await container
          .read(peerConcernControllerProvider.notifier)
          .submit(
            targetRef: 'target-id',
            reason: 'bullying',
            details: 'dia dibully',
          );

      expect(err, 'Kamu sudah memiliki laporan aktif untuk teman ini.');
      expect(err, isNot('Gagal mengirim kepedulian.'));
    });

    test('unrecognized submit errors still use the generic fallback', () async {
      final repo = repoThrowing('something completely unexpected');
      try {
        await repo.submit(targetStudentRef: 'target-id', reason: 'bullying');
        fail('submit should throw');
      } on PeerConcernException catch (e) {
        expect(e.message, 'Gagal mengirim kepedulian.');
      }
    });
  });
}

/// Supabase client whose RPCs fail with a raw server-style error, so the
/// REAL repository translator executes (same pattern as
/// availability_management_test.dart).
class _RpcClient extends SupabaseClient {
  _RpcClient(this.rpcError)
    : super(
        'http://localhost:1',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

  final Object rpcError;

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    get = false,
  }) {
    throw rpcError;
  }
}
