import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xo_arena_neon_clash/core/keys.dart';
import 'package:xo_arena_neon_clash/services/app_mode_service.dart';
import 'package:xo_arena_neon_clash/services/user_repo.dart';
import 'package:xo_arena_neon_clash/services/wallet_history_service.dart';

class _FakeRemote implements WalletHistoryRemote {
  final Map<String, Map<String, dynamic>> ledger = {};
  final List<Map<String, dynamic>> legacy = [];
  final List<Map<String, dynamic>> orders = [];
  bool failWrites = false;
  bool failReads = false;

  @override
  Future<void> createLedgerIfAbsent(
      String uid, String transactionId, Map<String, dynamic> entry) async {
    if (failWrites) throw Exception('unavailable');
    ledger.putIfAbsent(transactionId, () => <String, dynamic>{...entry});
  }

  @override
  Future<List<Map<String, dynamic>>> readAllLedger(String uid,
      {int pageSize = 100}) async {
    if (failReads) throw Exception('unavailable');
    return ledger.entries
        .map((entry) => <String, dynamic>{
              ...entry.value,
              '_documentId': entry.key,
            })
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> readAllLegacy(String uid,
      {int pageSize = 100}) async {
    if (failReads) throw Exception('unavailable');
    return legacy.map((row) => <String, dynamic>{...row}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> readPurchaseOrders(String uid,
      {int pageSize = 100}) async {
    if (failReads) throw Exception('unavailable');
    return orders.map((row) => <String, dynamic>{...row}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> readRecoveryRows(String uid,
          {int pageSize = 100}) async =>
      const <Map<String, dynamic>>[];
}

Map<String, dynamic> _row(String id, int delta, int timestamp) =>
    <String, dynamic>{
      'uid': 'u1',
      'transactionId': id,
      'type': delta >= 0 ? 'credit' : 'debit',
      'source': 'test_$id',
      'delta': delta,
      'coins': delta.abs(),
      'title': id,
      'localCreatedAtMs': timestamp,
      'dateTime':
          DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String(),
      'mode': 'online',
      'status': 'synced',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppModeService.modeNotifier.value = AppMode.online;
  });

  test('getTopupHistory_merges_remote_and_local', () async {
    final remote = _FakeRemote()
      ..ledger['r1'] = _row('r1', 10, 1)
      ..ledger['r2'] = _row('r2', -5, 2);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WalletHistoryService.migrationKey('u1'), true);
    await prefs.setString(
      WalletHistoryService.historyKey('u1'),
      jsonEncode(<Map<String, dynamic>>[
        _row('l1', 1, 3),
        _row('l2', 2, 4),
        _row('l3', 3, 5),
      ]),
    );
    final result =
        await WalletHistoryService(remote: remote).readMergedHistory('u1');
    expect(result.entries, hasLength(5));
  });

  test('getTopupHistory_does_not_early_return_remote', () async {
    final remote = _FakeRemote()..ledger['remote'] = _row('remote', 10, 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WalletHistoryService.migrationKey('u1'), true);
    await prefs.setString(WalletHistoryService.historyKey('u1'),
        jsonEncode(<Map<String, dynamic>>[_row('local', 20, 2)]));
    final entries =
        (await WalletHistoryService(remote: remote).readMergedHistory('u1'))
            .entries;
    expect(entries.map((row) => row['transactionId']),
        containsAll(<String>['remote', 'local']));
  });

  test('logout_does_not_delete_history', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        WalletHistoryService.historyKey('u1'), jsonEncode([_row('a', 1, 1)]));
    await prefs.setString(
        WalletHistoryService.pendingKey('u1'), jsonEncode([_row('b', 1, 2)]));
    await UserRepo.clearLogoutPreferences(prefs);
    expect(prefs.getString(WalletHistoryService.historyKey('u1')), isNotNull);
    expect(prefs.getString(WalletHistoryService.pendingKey('u1')), isNotNull);
  });

  test('force_logout_does_not_delete_history', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        WalletHistoryService.historyKey('u1'), jsonEncode([_row('a', 1, 1)]));
    await UserRepo.clearLogoutPreferences(prefs);
    await UserRepo.clearLogoutPreferences(prefs);
    expect(prefs.getString(WalletHistoryService.historyKey('u1')), isNotNull);
  });

  test('history_pagination_loads_old_entries', () async {
    final remote = _FakeRemote();
    for (var i = 0; i < 300; i++) {
      remote.ledger['tx$i'] = _row('tx$i', 1, i + 1);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WalletHistoryService.migrationKey('u1'), true);
    final entries =
        (await WalletHistoryService(remote: remote).readMergedHistory('u1'))
            .entries;
    expect(entries, hasLength(300));
    expect(entries.map((row) => row['transactionId']), contains('tx0'));
  });

  test('pending_history_flushes_after_reconnect', () async {
    final remote = _FakeRemote()..failWrites = true;
    final service = WalletHistoryService(remote: remote);
    await service.recordCredit(
      uid: 'u1',
      coins: 50,
      transactionId: 'pending1',
      source: 'mission_reward',
      title: 'Mission Reward',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(WalletHistoryService.pendingKey('u1')),
        contains('pending1'));
    remote.failWrites = false;
    await service.flushPending('u1');
    expect(remote.ledger, contains('pending1'));
    expect(prefs.getString(WalletHistoryService.pendingKey('u1')), '[]');
  });

  test('legacy_topupHistory_migrates_to_wallet_ledger', () async {
    final remote = _FakeRemote();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Keys.topupHistory,
        '2025-01-01T00:00:00.000Z|0|100|win|0|100|Old reward');
    final service = WalletHistoryService(remote: remote);
    await service.migrateLegacyHistory('u1');
    final firstIds = remote.ledger.keys.toList();
    expect(firstIds, hasLength(1));
    expect(firstIds.single, startsWith('legacy_u1_'));
    await service.migrateLegacyHistory('u1');
    expect(remote.ledger.keys.toList(), firstIds);
  });

  test('sanitizeForJson collapses Timestamp, FieldValue and nesting', () {
    final out = sanitizeForJson(<String, dynamic>{
      'ts': Timestamp.fromMillisecondsSinceEpoch(5),
      'fv': FieldValue.serverTimestamp(),
      'nested': <dynamic>[Timestamp.fromMillisecondsSinceEpoch(7)],
      'map': <String, dynamic>{'inner': Timestamp.fromMillisecondsSinceEpoch(9)},
      'n': 3,
      's': 'ok',
    }) as Map<String, dynamic>;
    expect(() => jsonEncode(out), returnsNormally);
    expect(out['ts'], 5);
    expect(out['fv'], isNull);
    expect((out['nested'] as List).first, 7);
    expect((out['map'] as Map)['inner'], 9);
    expect(out['n'], 3);
    expect(out['s'], 'ok');
  });

  test('timestamp_sanitizer_prevents_json_crash', () async {
    final remote = _FakeRemote();
    // A recovered ledger row carrying raw Firestore Timestamp fields — this is
    // exactly what previously crashed jsonEncode inside _encodeRows.
    remote.ledger['tsrow'] = <String, dynamic>{
      'uid': 'u1',
      'transactionId': 'tsrow',
      'type': 'credit',
      'source': 'friend_room_prize',
      'delta': 100,
      'coins': 100,
      'title': 'Friend Room Prize',
      'localCreatedAtMs': 10,
      'finishedAt': Timestamp.fromMillisecondsSinceEpoch(10),
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(10),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WalletHistoryService.migrationKey('u1'), true);

    final result =
        await WalletHistoryService(remote: remote).readMergedHistory('u1');
    expect(result.entries, hasLength(1));

    // The cached copy written back to SharedPreferences must be valid JSON —
    // no Timestamp may leak through.
    final cached = prefs.getString(WalletHistoryService.historyKey('u1'));
    expect(cached, isNotNull);
    expect(() => jsonDecode(cached!), returnsNormally);
  });

  test('account_details_reads_wallet_ledger delta', () {
    expect(
        WalletHistoryService.signedDelta(<String, dynamic>{'delta': -75}), -75);
    expect(
        WalletHistoryService.signedDelta(
            <String, dynamic>{'coins': 1000, 'type': 'credit'}),
        1000);
  });
}
