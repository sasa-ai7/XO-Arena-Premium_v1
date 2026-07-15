import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xo_arena_neon_clash/services/app_mode_service.dart';
import 'package:xo_arena_neon_clash/services/wallet_history_service.dart';
import 'package:xo_arena_neon_clash/services/wallet_transaction_service.dart';

/// In-memory ledger so the whole apply → record → merge flow runs without
/// Firebase. Mirrors the fake used in wallet_history_service_test.
class _FakeRemote implements WalletHistoryRemote {
  final Map<String, Map<String, dynamic>> ledger = {};

  @override
  Future<void> createLedgerIfAbsent(
      String uid, String transactionId, Map<String, dynamic> entry) async {
    ledger.putIfAbsent(transactionId, () => <String, dynamic>{...entry});
  }

  @override
  Future<List<Map<String, dynamic>>> readAllLedger(String uid,
          {int pageSize = 100}) async =>
      ledger.entries
          .map((e) => <String, dynamic>{...e.value, '_documentId': e.key})
          .toList();

  @override
  Future<List<Map<String, dynamic>>> readAllLegacy(String uid,
          {int pageSize = 100}) async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> readPurchaseOrders(String uid,
          {int pageSize = 100}) async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> readRecoveryRows(String uid,
          {int pageSize = 100}) async =>
      const <Map<String, dynamic>>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int balance;
  late _FakeRemote remote;

  WalletTransactionService build({
    bool offline = false,
    bool online = true,
    String? uid = 'u1',
  }) {
    return WalletTransactionService(
      historyService: WalletHistoryService(
        remote: remote,
        preferencesLoader: SharedPreferences.getInstance,
      ),
      uidProvider: () => uid,
      balanceReader: () => balance,
      walletMutator: (delta) async {
        final next = balance + delta;
        balance = next < 0 ? 0 : next;
      },
      preferencesLoader: SharedPreferences.getInstance,
      isOfflineMode: () => offline,
      canUseOnline: () => online,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppModeService.modeNotifier.value = AppMode.online;
    balance = 100;
    remote = _FakeRemote();
  });

  test('wallet_apply_delta_creates_balance_and_ledger', () async {
    final svc = build();
    final result = await svc.applyCredit(
      coins: 50,
      transactionId: 'c1',
      source: 'mission_reward',
      title: 'Mission Reward',
    );
    expect(result.success, isTrue);
    expect(balance, 150);
    expect(remote.ledger, contains('c1'));

    final history = await svc.readMergedHistory('u1');
    final row = history.entries.firstWhere((e) => e['transactionId'] == 'c1');
    expect(row['delta'], 50);
  });

  test('wallet_debit_creates_negative_transaction', () async {
    final svc = build();
    final result = await svc.applyDebit(
      coins: 30,
      transactionId: 'd1',
      source: 'x_color_purchase',
      title: 'Color Purchase',
    );
    expect(result.success, isTrue);
    expect(balance, 70);

    final history = await svc.readMergedHistory('u1');
    final row = history.entries.firstWhere((e) => e['transactionId'] == 'd1');
    expect(row['delta'], -30);
    expect((row['coins'] as int), 30);
  });

  test('no_wallet_change_without_ledger_when_uid_missing', () async {
    final svc = build(uid: null);
    final result = await svc.applyCredit(
      coins: 50,
      transactionId: 'x1',
      source: 's',
      title: 't',
    );
    expect(result.success, isFalse);
    expect(result.reason, 'no_uid');
    expect(balance, 100); // wallet untouched
  });

  test('insufficient_debit_rejected_without_side_effects', () async {
    final svc = build();
    balance = 20;
    final result = await svc.applyDebit(
      coins: 50,
      transactionId: 'd2',
      source: 's',
      title: 't',
    );
    expect(result.success, isFalse);
    expect(result.reason, 'insufficient');
    expect(balance, 20);
    expect(remote.ledger, isNot(contains('d2')));
  });

  test('duplicate_transactionId_does_not_double_apply', () async {
    final svc = build();
    final first = await svc.applyCredit(
      coins: 50,
      transactionId: 'dup',
      source: 's',
      title: 't',
    );
    expect(first.success, isTrue);
    expect(balance, 150);

    final second = await svc.applyCredit(
      coins: 50,
      transactionId: 'dup',
      source: 's',
      title: 't',
    );
    expect(second.reason, 'duplicate');
    expect(second.success, isTrue); // already-processed counts as success
    expect(balance, 150); // NOT 200 — never double-credited
  });

  test('blocked_mode_makes_no_change_and_no_record', () async {
    final svc = build(online: false);
    final result = await svc.applyCredit(
      coins: 50,
      transactionId: 'b1',
      source: 's',
      title: 't',
    );
    expect(result.success, isFalse);
    expect(result.reason, 'blocked');
    expect(balance, 100);
    expect(remote.ledger, isNot(contains('b1')));
  });

  test('zero_delta_creates_no_transaction', () async {
    final svc = build();
    final result = await svc.applyCredit(
      coins: 0,
      transactionId: 'z1',
      source: 's',
      title: 't',
    );
    expect(result.success, isFalse);
    expect(result.reason, 'zero');
    expect(balance, 100);
    expect(remote.ledger, isNot(contains('z1')));
  });

  test('offline_delta_records_offline_history', () async {
    final svc = build(offline: true, uid: null);
    final result = await svc.applyDebit(
      coins: 10,
      transactionId: 'off1',
      source: 'level_continue',
      title: 'Continue',
    );
    expect(result.success, isTrue);
    expect(balance, 90);

    AppModeService.modeNotifier.value = AppMode.offline;
    final history = await svc.readMergedHistory(null);
    expect(history.entries.any((e) => e['transactionId'] == 'off1'), isTrue);
    AppModeService.modeNotifier.value = AppMode.online;
  });
}
