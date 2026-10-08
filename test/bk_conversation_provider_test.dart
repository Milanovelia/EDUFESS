import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:edufess/features/auth/data/profile_repository.dart';
import 'package:edufess/features/auth/presentation/providers/auth_controller.dart';
import 'package:edufess/features/counseling/data/counseling_repository.dart';
import 'package:edufess/features/counseling/data/models/bk_conversation.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_conversation_page.dart';
import 'package:edufess/features/counseling/presentation/providers/counseling_providers.dart';

/// P0-3 Option A: conversation loading uses RPC minimal projections only.
/// RPC/auth/network errors propagate as typed errors — never swallowed to
/// null, never replaced by a direct full-row select.
void main() {
  const student = UserProfile(id: 's1', pseudonym: 's1', role: 'student');

  BkConversation conv(String id) => BkConversation(
    id: id,
    studentAlias: 'Siswa BK #A1B2',
    status: 'open',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  ProviderContainer containerWith({
    required CounselingRepository repo,
    UserProfile profile = student,
  }) {
    final container = ProviderContainer(
      overrides: [
        counselingRepositoryProvider.overrideWithValue(repo),
        currentProfileProvider.overrideWith((ref) async => profile),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('bkConversationProvider error propagation', () {
    // NOTE: awaiting provider futures directly in a bare container can hit
    // autoDispose timing quirks, so error assertions go through a
    // listener-held subscription (same lifecycle as a watching widget),
    // while the .future documents propagation semantics.
    Future<AsyncValue<BkConversation?>> settledState(
      ProviderContainer container,
      String id,
    ) async {
      final sub = container.listen(
        bkConversationProvider(id),
        (prev, next) {},
        onError: (e, st) {},
      );
      try {
        await container
            .read(bkConversationProvider(id).future)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Expected for error cases; state below is the assertion target.
      }
      final state = container.read(bkConversationProvider(id));
      sub.close();
      return state;
    }

    test('denied RPCs produce error state, not null', () async {
      final container = containerWith(
        repo: CounselingRepository(
          _RpcClient(PostgrestException(message: 'Not authorized.')),
        ),
      );
      // The future must complete with the typed error, never null data.
      // Riverpod surfaces in-flight failures as AsyncLoading-with-error
      // before settling to AsyncError; either way hasError must be true
      // and the typed message must be present.
      final state = await settledState(container, 'conv-1');
      expect(state.hasError, isTrue);
      expect(state.error.toString(), contains('Tidak memiliki akses.'));
      expect(state.hasValue, isFalse);
    });

    test('network failure surfaces as error, not empty conversation',
        () async {
      final container = containerWith(
        repo: CounselingRepository(_RpcClient(Exception('SocketException'))),
      );
      final state = await settledState(container, 'conv-1');
      expect(state.hasError, isTrue);
      expect(state.error, isA<CounselingException>());
      expect(state.hasValue, isFalse);
    });

    test('RPC success resolves the conversation', () async {
      final container = containerWith(repo: _ListRepo([conv('conv-1')]));
      final c = await container.read(bkConversationProvider('conv-1').future);
      expect(c?.id, 'conv-1');
      expect(c?.studentAlias, 'Siswa BK #A1B2');
    });

    test('unknown id resolves to legitimate null, not error', () async {
      final container = containerWith(repo: _ListRepo([conv('other')]));
      expect(
        await container.read(bkConversationProvider('conv-x').future),
        isNull,
      );
      expect(
        container.read(bkConversationProvider('conv-x')),
        isA<AsyncData>(),
      );
    });

    test('minimal RPC payloads leave identity fields null', () async {
      final container = containerWith(repo: _ListRepo([conv('conv-1')]));
      final c = await container.read(bkConversationProvider('conv-1').future);
      expect(c?.studentId, isNull);
      expect(c?.counselorId, isNull);
      expect(c?.identityRevealedAt, isNull);
    });
  });

  group('BkConversationPage header error state', () {
    Future<void> pumpErrorPage(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => student),
            counselingRepositoryProvider.overrideWithValue(
              CounselingRepository(
                _RpcClient(PostgrestException(message: 'Not authorized.')),
              ),
            ),
            counselingMessagesProvider.overrideWith((ref, id) async => []),
          ],
          child: const MaterialApp(
            home: BkConversationPage(conversationId: 'conv-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('provider error renders message with retry', (tester) async {
      await pumpErrorPage(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Tidak memiliki akses.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsWidgets);
    });

    testWidgets('retry invalidates the conversation provider', (tester) async {
      await pumpErrorPage(tester);
      await tester.tap(find.text('Coba lagi').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Still an error (repo still throws), but retry executed cleanly.
      expect(find.text('Tidak memiliki akses.'), findsOneWidget);
    });
  });

  group('getActiveConversation RPC-only behavior', () {
    CounselingRepository repoWith(Object rpcError) => CounselingRepository(
      _RpcClient(rpcError),
    );

    test('empty RPC list resolves to legitimate null', () async {
      final repo = _ListRepo(const []);
      expect(await repo.getActiveConversation(), isNull);
    });

    test('RPC failure propagates as typed error, not null', () async {
      final repo = repoWith(Exception('SocketException'));
      await expectLater(
        repo.getActiveConversation(),
        throwsA(isA<CounselingException>()),
      );
    });

    test('denied RPC propagates access message, not null', () async {
      final repo = repoWith(
        const PostgrestException(message: 'Not authorized.'),
      );
      await expectLater(
        repo.getActiveConversation(),
        throwsA(
          isA<CounselingException>().having(
            (e) => e.message,
            'message',
            'Tidak memiliki akses.',
          ),
        ),
      );
    });
  });

  group('P0-3 conversation-loading safety net', () {
    test('no direct full-row conversation table fallback remains', () {
      final repoSource = File(
        'lib/features/counseling/data/counseling_repository.dart',
      ).readAsStringSync();
      final providerSource = File(
        'lib/features/counseling/presentation/providers/counseling_providers.dart',
      ).readAsStringSync();
      // Dangerous pattern: direct read from counseling_conversations with a
      // bare .select() (full-row). Creation uses id-only .select('id'),
      // which is allowed and must not trip this guard.
      final fullRowFallback = RegExp(
        '''from\\(['"]counseling_conversations['"]\\)\\s*\\.select\\(\\s*\\)''',
      );
      expect(fullRowFallback.hasMatch(repoSource), isFalse);
      expect(fullRowFallback.hasMatch(providerSource), isFalse);
      expect(providerSource, isNot(contains('counseling_conversations')));
      // Repository conversation loading uses the minimal RPC projection
      // parser; the sensitive full-row parser is no longer referenced there.
      expect(repoSource, contains('BkConversation.fromQueueMap'));
      expect(repoSource, isNot(contains('BkConversation.fromMap')));
    });
  });
}

/// Supabase client whose RPCs fail with a raw server-style error.
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

/// Repository returning fixed RPC lists (never touches the network).
class _ListRepo extends CounselingRepository {
  _ListRepo(this.items)
    : super(
        SupabaseClient(
          'http://localhost:1',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<BkConversation> items;

  @override
  Future<List<BkConversation>> fetchStudentConversations() async => items;

  @override
  Future<List<BkConversation>> fetchCounselorQueue() async => const [];

  @override
  Future<List<BkConversation>> fetchCounselorAssigned() async => const [];
}
