import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';
import '../models/user_data.dart';
import 'app_mode_service.dart';

typedef PreferencesLoader = Future<SharedPreferences> Function();

/// Collapses a value tree into strictly JSON-safe primitives.
///
/// SharedPreferences history/pending/cache rows are persisted with
/// [jsonEncode], which throws on any non-encodable object. Recovery and remote
/// sources routinely carry Firestore [Timestamp]s (`createdAt`, `finishedAt`,
/// …), [FieldValue] sentinels, and nested maps/lists of the same. Running every
/// row through this before encoding guarantees a single bad field can never
/// crash the whole history load (the reported
/// "Converting object to an encodable object failed: Instance of 'Timestamp'").
dynamic sanitizeForJson(dynamic value) {
  if (value == null || value is num || value is String || value is bool) {
    return value;
  }
  if (value is Timestamp) return value.toDate().millisecondsSinceEpoch;
  if (value is DateTime) return value.millisecondsSinceEpoch;
  if (value is FieldValue) return null;
  if (value is Map) {
    return value
        .map((key, val) => MapEntry(key.toString(), sanitizeForJson(val)));
  }
  if (value is Iterable) return value.map(sanitizeForJson).toList();
  return value.toString();
}

class WalletHistoryReadResult {
  const WalletHistoryReadResult({
    required this.entries,
    required this.remoteUnavailable,
  });

  final List<Map<String, dynamic>> entries;
  final bool remoteUnavailable;
}

/// Remote boundary kept small so durability and merge behavior can be tested
/// without Firebase. Ledger documents are create-only and use their
/// transaction id as the Firestore document id.
abstract class WalletHistoryRemote {
  Future<void> createLedgerIfAbsent(
    String uid,
    String transactionId,
    Map<String, dynamic> entry,
  );

  Future<List<Map<String, dynamic>>> readAllLedger(String uid,
      {int pageSize = 100});

  Future<List<Map<String, dynamic>>> readAllLegacy(String uid,
      {int pageSize = 100});

  Future<List<Map<String, dynamic>>> readPurchaseOrders(String uid,
      {int pageSize = 100});

  Future<List<Map<String, dynamic>>> readRecoveryRows(String uid,
          {int pageSize = 100}) async =>
      const <Map<String, dynamic>>[];
}

class FirestoreWalletHistoryRemote implements WalletHistoryRemote {
  FirestoreWalletHistoryRemote([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> createLedgerIfAbsent(
    String uid,
    String transactionId,
    Map<String, dynamic> entry,
  ) async {
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('wallet_ledger')
        .doc(transactionId);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) return;
      transaction.set(ref, <String, dynamic>{
        ...entry,
        'uid': uid,
        'transactionId': transactionId,
        'status': 'synced',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<Map<String, dynamic>>> _readPaged(
    Query<Map<String, dynamic>> base, {
    required int pageSize,
  }) async {
    final rows = <Map<String, dynamic>>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      var query = base.limit(pageSize);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final page = await query.get();
      for (final doc in page.docs) {
        rows.add(<String, dynamic>{...doc.data(), '_documentId': doc.id});
      }
      if (page.docs.length < pageSize) break;
      cursor = page.docs.last;
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> _readPagedSafely(
    Query<Map<String, dynamic>> query, {
    required int pageSize,
  }) async {
    try {
      return await _readPaged(query, pageSize: pageSize);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[WALLET_HISTORY] recovery source deferred: $error');
      }
      return const <Map<String, dynamic>>[];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> readAllLedger(String uid,
      {int pageSize = 100}) {
    return _readPaged(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('wallet_ledger')
          .orderBy('createdAt', descending: true),
      pageSize: pageSize,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> readAllLegacy(String uid,
      {int pageSize = 100}) {
    return _readPaged(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .orderBy('createdAt', descending: true),
      pageSize: pageSize,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> readPurchaseOrders(String uid,
      {int pageSize = 100}) {
    return _readPaged(
      _firestore
          .collection('purchase_orders')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true),
      pageSize: pageSize,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> readRecoveryRows(String uid,
      {int pageSize = 100}) async {
    final rows = <Map<String, dynamic>>[];
    final pending = await _readPagedSafely(
      _firestore
          .collection('pending_referral_rewards')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true),
      pageSize: pageSize,
    );
    for (final reward in pending) {
      final coins = (reward['coins'] as num?)?.toInt() ?? 0;
      final inviteeUid = reward['inviteeUid']?.toString() ?? '';
      if (coins <= 0 || inviteeUid.isEmpty) continue;
      rows.add(<String, dynamic>{
        ...reward,
        'uid': uid,
        'transactionId': 'ref_${inviteeUid}_referrer',
        'type': 'credit',
        'source': 'referral_referrer_reward',
        'delta': coins,
        'coins': coins,
        'title': 'Referral accepted',
        'message': reward['message'] ?? 'Referral reward',
      });
    }

    final roomRows = await _readPagedSafely(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('onlineRoomHistory')
          .orderBy('finishedAt', descending: true),
      pageSize: pageSize,
    );
    for (final room in roomRows) {
      final matchId = room['_documentId']?.toString() ?? '';
      final bet = (room['betAmount'] as num?)?.toInt() ?? 0;
      final won = (room['coinsWon'] as num?)?.toInt() ?? 0;
      if (matchId.isEmpty) continue;
      if (bet > 0) {
        rows.add(<String, dynamic>{
          ...room,
          'uid': uid,
          'transactionId': '${matchId}_bet_$uid',
          'type': 'debit',
          'source': 'friend_room_bet_entry',
          'delta': -bet,
          'coins': bet,
          'title': 'Friend Room Bet Entry',
          'createdAt': room['finishedAt'],
        });
      }
      if (won > 0) {
        rows.add(<String, dynamic>{
          ...room,
          'uid': uid,
          'transactionId': '${matchId}_prize_$uid',
          'type': 'credit',
          'source': 'friend_room_prize',
          'delta': won,
          'coins': won,
          'title': 'Friend Room Prize',
          'createdAt': room['finishedAt'],
        });
      }
    }

    final iapRows = await _readPagedSafely(
      _firestore
          .collection('iap_transactions')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true),
      pageSize: pageSize,
    );
    for (final iap in iapRows) {
      final coins =
          ((iap['coinsGranted'] ?? iap['coins'] ?? iap['amount']) as num?)
                  ?.toInt() ??
              0;
      final id = (iap['transactionId'] ?? iap['_documentId'])?.toString() ?? '';
      if (coins <= 0 || id.isEmpty) continue;
      rows.add(<String, dynamic>{
        ...iap,
        'uid': uid,
        'transactionId': id,
        'type': 'credit',
        'source': 'iap_purchase',
        'delta': coins,
        'coins': coins,
        'title': 'Coin Purchase',
      });
    }

    // Older arena versions may have written only user_logs or the shared
    // online_room_history mirror. Convert surviving coin fields without
    // inventing a refund when the source does not prove one occurred.
    void addArenaRows(Map<String, dynamic> source) {
      final metadata = source['metadata'] is Map
          ? Map<String, dynamic>.from(source['metadata'] as Map)
          : source;
      final matchId =
          (metadata['matchId'] ?? source['_documentId'])?.toString() ?? '';
      if (matchId.isEmpty) return;
      final bet = (metadata['betAmount'] as num?)?.toInt() ?? 0;
      final won = (metadata['coinsWon'] as num?)?.toInt() ?? 0;
      final createdAt = source['createdAt'] ?? source['finishedAt'];
      if (bet > 0) {
        rows.add(<String, dynamic>{
          'uid': uid,
          'transactionId': '${matchId}_bet_$uid',
          'type': 'debit',
          'source': 'friend_room_bet_entry',
          'delta': -bet,
          'coins': bet,
          'title': 'Friend Room Bet Entry',
          'createdAt': createdAt,
        });
      }
      if (won > 0) {
        rows.add(<String, dynamic>{
          'uid': uid,
          'transactionId': '${matchId}_prize_$uid',
          'type': 'credit',
          'source': 'friend_room_prize',
          'delta': won,
          'coins': won,
          'title': 'Friend Room Prize',
          'createdAt': createdAt,
        });
      }
    }

    final userLogs = await _readPagedSafely(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('user_logs')
          .orderBy('createdAt', descending: true),
      pageSize: pageSize,
    );
    for (final log in userLogs) {
      if (log['eventName'] == 'friend_room_finished') addArenaRows(log);
    }
    for (final participantField in const <String>['hostUid', 'guestUid']) {
      final sharedRooms = await _readPagedSafely(
        _firestore
            .collection('online_room_history')
            .where(participantField, isEqualTo: uid)
            .orderBy('finishedAt', descending: true),
        pageSize: pageSize,
      );
      for (final room in sharedRooms) {
        addArenaRows(room);
      }
    }
    return rows;
  }
}

/// Durable wallet history cache, pending upload queue, migration, and reader.
///
/// Local online data is always scoped by uid. Normal logout never removes any
/// of these keys. A row is written to the pending queue before the network is
/// attempted, and is removed only after Firestore confirms the immutable
/// ledger document exists.
class WalletHistoryService {
  WalletHistoryService({
    WalletHistoryRemote? remote,
    PreferencesLoader? preferencesLoader,
  })  : _remote = remote ?? FirestoreWalletHistoryRemote(),
        _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static final WalletHistoryService instance = WalletHistoryService();

  final WalletHistoryRemote _remote;
  final PreferencesLoader _preferencesLoader;

  static String historyKey(String uid) => 'topupHistory_$uid';
  static String pendingKey(String uid) => 'pendingWalletLedger_$uid';
  static String migrationKey(String uid) => 'history_migrated_$uid';

  Future<void> recordCredit({
    required String uid,
    required int coins,
    required String transactionId,
    required String source,
    required String title,
    String? description,
    int? balanceBefore,
    int? balanceAfter,
    String? itemType,
    String? itemId,
    String? assetPath,
    double usd = 0,
  }) {
    return recordPending(
      uid: uid,
      delta: coins.abs(),
      transactionId: transactionId,
      source: source,
      title: title,
      description: description,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      itemType: itemType,
      itemId: itemId,
      assetPath: assetPath,
      usd: usd,
    );
  }

  Future<void> recordDebit({
    required String uid,
    required int coins,
    required String transactionId,
    required String source,
    required String title,
    String? description,
    int? balanceBefore,
    int? balanceAfter,
    String? itemType,
    String? itemId,
    String? assetPath,
    double usd = 0,
  }) {
    return recordPending(
      uid: uid,
      delta: -coins.abs(),
      transactionId: transactionId,
      source: source,
      title: title,
      description: description,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      itemType: itemType,
      itemId: itemId,
      assetPath: assetPath,
      usd: usd,
    );
  }

  Future<void> recordOffline({
    required int delta,
    required String transactionId,
    required String source,
    required String title,
    String? description,
    int? balanceBefore,
    int? balanceAfter,
    String? itemType,
    String? itemId,
    String? assetPath,
    double usd = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = _makeRow(
      uid: 'offline',
      delta: delta,
      transactionId: transactionId,
      source: source,
      title: title,
      description: description,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      itemType: itemType,
      itemId: itemId,
      assetPath: assetPath,
      usd: usd,
      localCreatedAtMs: now,
      mode: 'offline',
      status: 'synced',
    );
    final prefs = await _preferencesLoader();
    await _upsert(prefs, Keys.offlineTopupHistory, row);
  }

  Future<void> recordPending({
    required String uid,
    required int delta,
    required String transactionId,
    required String source,
    required String title,
    String? description,
    int? balanceBefore,
    int? balanceAfter,
    String? itemType,
    String? itemId,
    String? assetPath,
    double usd = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = _makeRow(
      uid: uid,
      delta: delta,
      transactionId: transactionId,
      source: source,
      title: title,
      description: description,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      itemType: itemType,
      itemId: itemId,
      assetPath: assetPath,
      usd: usd,
      localCreatedAtMs: now,
      mode: 'pending',
      status: 'pending',
    );
    final prefs = await _preferencesLoader();
    await _upsert(prefs, historyKey(uid), row);
    await _upsert(prefs, pendingKey(uid), row);

    if (!AppModeService.canUseOnlineServices) return;
    await _uploadOne(prefs, uid, row);
  }

  /// Writes a history row to the local cache ONLY — never to the pending queue
  /// and never to Firestore. Used when a canonical ledger already exists
  /// remotely and only a local display row is wanted (Part 10 IAP display).
  Future<void> recordLocalDisplayOnly({
    required String uid,
    required int delta,
    required String transactionId,
    required String source,
    required String title,
    String? description,
    int? balanceBefore,
    int? balanceAfter,
    String? itemType,
    String? itemId,
    String? assetPath,
    double usd = 0,
  }) async {
    final row = _makeRow(
      uid: uid,
      delta: delta,
      transactionId: transactionId,
      source: source,
      title: title,
      description: description,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      itemType: itemType,
      itemId: itemId,
      assetPath: assetPath,
      usd: usd,
      localCreatedAtMs: DateTime.now().millisecondsSinceEpoch,
      mode: 'online',
      status: 'synced',
    );
    final prefs = await _preferencesLoader();
    await _upsert(prefs, historyKey(uid), row);
  }

  Future<void> flushPending(String uid) async {
    if (!AppModeService.canUseOnlineServices) return;
    final prefs = await _preferencesLoader();
    final pending = _readJsonRows(prefs.getString(pendingKey(uid)));
    for (final row in pending) {
      await _uploadOne(prefs, uid, row);
    }
  }

  Future<void> _uploadOne(
    SharedPreferences prefs,
    String uid,
    Map<String, dynamic> row,
  ) async {
    final transactionId = row['transactionId']?.toString() ?? '';
    if (transactionId.isEmpty) return;
    try {
      await _remote.createLedgerIfAbsent(uid, transactionId, row);
      final synced = <String, dynamic>{
        ...row,
        'mode': 'online',
        'status': 'synced',
      };
      await _upsert(prefs, historyKey(uid), synced);
      await _removeById(prefs, pendingKey(uid), transactionId);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[WALLET_HISTORY] queued $transactionId: $error');
      }
    }
  }

  Future<WalletHistoryReadResult> readMergedHistory(String? uid) async {
    final prefs = await _preferencesLoader();
    if (uid == null ||
        uid.isEmpty ||
        AppModeService.current == AppMode.offline) {
      return WalletHistoryReadResult(
        entries: _dedupeAndSort(
            _readJsonRows(prefs.getString(Keys.offlineTopupHistory))),
        remoteUnavailable: false,
      );
    }

    // Migration and pending flush are best-effort. A failure in either (e.g. a
    // recovery source with unexpected data, or a transient network error) must
    // never blank the whole history page — locally cached rows still render.
    try {
      await migrateLegacyHistory(uid);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[WALLET_HISTORY] migration deferred: $error');
      }
    }
    try {
      await flushPending(uid);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[WALLET_HISTORY] pending flush deferred: $error');
      }
    }

    var remoteUnavailable = false;
    final remoteRows = <Map<String, dynamic>>[];
    try {
      remoteRows
          .addAll((await _remote.readAllLedger(uid)).map(_normalizeRemote));
      for (final legacy in await _remote.readAllLegacy(uid)) {
        final row = _normalizeRemote(legacy);
        final explicitId = legacy['transactionId']?.toString() ?? '';
        row['transactionId'] =
            explicitId.isNotEmpty ? explicitId : _legacyId(uid, row);
        remoteRows.add(row);
      }
    } catch (error) {
      remoteUnavailable = true;
      if (kDebugMode) {
        debugPrint('[WALLET_HISTORY] remote read deferred: $error');
      }
    }

    final rows = <Map<String, dynamic>>[
      ...remoteRows,
      ..._readJsonRows(prefs.getString(historyKey(uid))),
      ..._readJsonRows(prefs.getString(pendingKey(uid))),
      ..._ownedGlobalLegacyRows(prefs, uid),
    ];
    final merged = _dedupeAndSort(rows);
    await prefs.setString(historyKey(uid), _encodeRows(merged));
    return WalletHistoryReadResult(
      entries: merged,
      remoteUnavailable: remoteUnavailable,
    );
  }

  /// Idempotent best-effort backfill from local pipe history, legacy remote
  /// transactions and surviving IAP order documents. Local copies are retained.
  Future<void> migrateLegacyHistory(String uid) async {
    final prefs = await _preferencesLoader();
    if (prefs.getBool(migrationKey(uid)) == true) return;
    if (prefs.getString(Keys.legacyHistoryOwnerUid) == null &&
        (prefs.getString(Keys.topupHistory)?.isNotEmpty ?? false)) {
      await prefs.setString(Keys.legacyHistoryOwnerUid, uid);
    }

    final localRows = <Map<String, dynamic>>[
      ..._readJsonRows(prefs.getString(historyKey(uid))),
      ..._ownedGlobalLegacyRows(prefs, uid),
    ];
    var allSucceeded = true;
    final candidates = <Map<String, dynamic>>[...localRows];
    try {
      candidates.addAll((await _remote.readAllLegacy(uid)).map((legacy) {
        final row = _normalizeRemote(legacy);
        row.remove('transactionId');
        row.remove('_documentId');
        return row;
      }));
    } catch (_) {
      allSucceeded = false;
    }
    try {
      final orders = await _remote.readPurchaseOrders(uid);
      candidates.addAll(orders
          .map((order) => _purchaseOrderRow(uid, order))
          .where((row) => signedDelta(row) != 0));
    } catch (_) {
      // Purchase-order recovery is optional and may require a missing index.
    }
    try {
      candidates
          .addAll((await _remote.readRecoveryRows(uid)).map(_normalizeRemote));
    } catch (_) {
      // Recovery sources are best-effort; canonical/local history still wins.
    }

    for (final original in candidates) {
      final row = <String, dynamic>{...original};
      var transactionId = row['transactionId']?.toString() ?? '';
      if (transactionId.isEmpty) {
        transactionId = _legacyId(uid, row);
        row['transactionId'] = transactionId;
      }
      row['uid'] = uid;
      row['mode'] = 'online';
      row['status'] = 'synced';
      try {
        await _remote.createLedgerIfAbsent(uid, transactionId, row);
        await _upsert(prefs, historyKey(uid), row);
      } catch (_) {
        allSucceeded = false;
        row['mode'] = 'pending';
        row['status'] = 'pending';
        // Never let a single un-queueable row abort the whole migration.
        try {
          await _upsert(prefs, pendingKey(uid), row);
        } catch (queueError) {
          if (kDebugMode) {
            debugPrint('[WALLET_HISTORY] could not queue $transactionId: '
                '$queueError');
          }
        }
      }
    }
    if (allSucceeded) await prefs.setBool(migrationKey(uid), true);
  }

  static Map<String, dynamic> _makeRow({
    required String uid,
    required int delta,
    required String transactionId,
    required String source,
    required String title,
    required int localCreatedAtMs,
    required String mode,
    required String status,
    String? description,
    int? balanceBefore,
    int? balanceAfter,
    String? itemType,
    String? itemId,
    String? assetPath,
    double usd = 0,
  }) {
    return <String, dynamic>{
      'uid': uid,
      'transactionId': transactionId,
      'type': delta >= 0 ? 'credit' : 'debit',
      'source': source,
      'delta': delta,
      'coins': delta.abs(),
      'usd': usd,
      if (balanceBefore != null) ...<String, dynamic>{
        'before': balanceBefore,
        'balanceBefore': balanceBefore,
      },
      if (balanceAfter != null) ...<String, dynamic>{
        'after': balanceAfter,
        'balanceAfter': balanceAfter,
      },
      'title': title,
      if (description != null) ...<String, dynamic>{
        'message': description,
        'description': description,
      },
      if (itemType != null) 'itemType': itemType,
      if (itemId != null) 'itemId': itemId,
      if (assetPath != null && assetPath.isNotEmpty) 'assetPath': assetPath,
      'localCreatedAtMs': localCreatedAtMs,
      'dateTime': DateTime.fromMillisecondsSinceEpoch(localCreatedAtMs),
      'mode': mode,
      'status': status,
    };
  }

  static Map<String, dynamic> _normalizeRemote(Map<String, dynamic> data) {
    final delta = signedDelta(data);
    final timestamp = data['createdAt'];
    final localMs = (data['localCreatedAtMs'] as num?)?.toInt();
    final dateTime = timestamp is Timestamp
        ? timestamp.toDate()
        : timestamp is DateTime
            ? timestamp
            : localMs != null
                ? DateTime.fromMillisecondsSinceEpoch(localMs)
                : DateTime.fromMillisecondsSinceEpoch(0);
    return <String, dynamic>{
      ...data,
      'transactionId':
          (data['transactionId'] ?? data['_documentId'] ?? '').toString(),
      'dateTime': dateTime,
      'localCreatedAtMs': localMs ?? dateTime.millisecondsSinceEpoch,
      'delta': delta,
      'coins': delta.abs(),
      'type': data['type']?.toString() ?? (delta >= 0 ? 'credit' : 'debit'),
      if (data['before'] != null)
        'balanceBefore': (data['before'] as num).toInt(),
      if (data['after'] != null) 'balanceAfter': (data['after'] as num).toInt(),
      if (data['message'] != null) 'description': data['message'].toString(),
      'mode': data['mode']?.toString() ?? 'online',
      'status': data['status']?.toString() ?? 'synced',
    };
  }

  static int signedDelta(Map<String, dynamic> data) {
    final explicit = (data['delta'] as num?)?.toInt();
    if (explicit != null) return explicit;
    final amount = ((data['coins'] ?? data['amount']) as num?)?.toInt() ?? 0;
    final type = TransactionRecord.mapLegacyType(
        data['type']?.toString() ?? data['source']?.toString() ?? '');
    return type == 'win' || type == 'recharge' || type == 'credit'
        ? amount.abs()
        : -amount.abs();
  }

  static Map<String, dynamic> _purchaseOrderRow(
      String uid, Map<String, dynamic> order) {
    final coins =
        ((order['coinsGranted'] ?? order['coins']) as num?)?.toInt() ?? 0;
    final id = (order['transactionId'] ?? order['_documentId']).toString();
    return _normalizeRemote(<String, dynamic>{
      ...order,
      'uid': uid,
      'transactionId': id,
      'type': 'credit',
      'source': 'iap_purchase',
      'delta': coins.abs(),
      'coins': coins.abs(),
      'title': 'Coin Purchase',
      'status': 'synced',
      'mode': 'online',
    });
  }

  static String _legacyId(String uid, Map<String, dynamic> row) {
    final payload = <Object?>[
      (row['dateTime'] is DateTime)
          ? (row['dateTime'] as DateTime).toIso8601String()
          : row['localCreatedAtMs'],
      signedDelta(row),
      row['type'],
      row['description'] ?? row['message'],
      row['balanceBefore'] ?? row['before'],
      row['balanceAfter'] ?? row['after'],
    ].join('|');
    return 'legacy_${uid}_${sha256.convert(utf8.encode(payload)).toString()}';
  }

  List<Map<String, dynamic>> _ownedGlobalLegacyRows(
      SharedPreferences prefs, String uid) {
    final raw = prefs.getString(Keys.topupHistory);
    if (raw == null || raw.isEmpty) return const [];
    final owner = prefs.getString(Keys.legacyHistoryOwnerUid);
    if (owner != null && owner != uid) return const [];
    return _parseStoredRows(raw, uid: uid);
  }

  static List<Map<String, dynamic>> _parseStoredRows(String raw,
      {String uid = ''}) {
    final jsonRows = _readJsonRows(raw);
    if (jsonRows.isNotEmpty || raw.trimLeft().startsWith('[')) return jsonRows;
    final rows = <Map<String, dynamic>>[];
    for (final encoded in raw.split(',')) {
      final parts = encoded.split('|');
      if (parts.length < 4) continue;
      final date = DateTime.tryParse(parts[0]);
      if (date == null) continue;
      final coins = int.tryParse(parts[2]) ?? 0;
      final legacyType = TransactionRecord.mapLegacyType(parts[3]);
      final credit = legacyType == 'win' || legacyType == 'recharge';
      final row = _makeRow(
        uid: uid,
        delta: credit ? coins.abs() : -coins.abs(),
        transactionId: '',
        source: parts[3],
        title: parts.length > 9 && parts[9].isNotEmpty
            ? parts[9]
            : (parts.length > 6 && parts[6].isNotEmpty ? parts[6] : parts[3]),
        description: parts.length > 6 && parts[6].isNotEmpty ? parts[6] : null,
        balanceBefore: parts.length > 4 ? int.tryParse(parts[4]) : null,
        balanceAfter: parts.length > 5 ? int.tryParse(parts[5]) : null,
        itemType: parts.length > 7 && parts[7].isNotEmpty ? parts[7] : null,
        assetPath: parts.length > 8 && parts[8].isNotEmpty ? parts[8] : null,
        usd: double.tryParse(parts[1]) ?? 0,
        localCreatedAtMs: date.millisecondsSinceEpoch,
        mode: 'pending',
        status: 'pending',
      );
      row['transactionId'] = _legacyId(uid, row);
      rows.add(row);
    }
    return rows;
  }

  static List<Map<String, dynamic>> _readJsonRows(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.whereType<Map>().map((value) {
        final row = Map<String, dynamic>.from(value);
        final date = row['dateTime'];
        if (date is String) row['dateTime'] = DateTime.tryParse(date);
        if (row['dateTime'] == null && row['localCreatedAtMs'] is num) {
          row['dateTime'] = DateTime.fromMillisecondsSinceEpoch(
              (row['localCreatedAtMs'] as num).toInt());
        }
        return row;
      }).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static List<Map<String, dynamic>> _dedupeAndSort(
      Iterable<Map<String, dynamic>> rows) {
    final byId = <String, Map<String, dynamic>>{};
    final byFallback = <String, Map<String, dynamic>>{};
    final seenFallback = <String>{};
    for (final original in rows) {
      final row = <String, dynamic>{...original};
      final id = row['transactionId']?.toString() ?? '';
      final date = row['dateTime'] is DateTime
          ? row['dateTime'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(
              (row['localCreatedAtMs'] as num?)?.toInt() ?? 0);
      row['dateTime'] = date;
      row['delta'] = signedDelta(row);
      row['coins'] = signedDelta(row).abs();
      final fallback = '${date.millisecondsSinceEpoch}|${row['delta']}|'
          '${row['source'] ?? ''}|${row['title'] ?? row['description'] ?? ''}';
      if (!seenFallback.add(fallback)) continue;
      if (id.isNotEmpty) {
        final old = byId[id];
        if (old == null || old['status'] != 'synced') byId[id] = row;
      } else {
        byFallback.putIfAbsent(fallback, () => row);
      }
    }
    final result = <Map<String, dynamic>>[
      ...byId.values,
      ...byFallback.values,
    ];
    result.sort((a, b) =>
        (b['dateTime'] as DateTime).compareTo(a['dateTime'] as DateTime));
    return result;
  }

  Future<void> _upsert(
      SharedPreferences prefs, String key, Map<String, dynamic> row) async {
    final rows = _readJsonRows(prefs.getString(key));
    final id = row['transactionId']?.toString() ?? '';
    rows.removeWhere(
        (value) => id.isNotEmpty && value['transactionId']?.toString() == id);
    rows.add(row);
    await prefs.setString(key, _encodeRows(rows));
  }

  Future<void> _removeById(
      SharedPreferences prefs, String key, String transactionId) async {
    final rows = _readJsonRows(prefs.getString(key));
    rows.removeWhere(
        (row) => row['transactionId']?.toString() == transactionId);
    await prefs.setString(key, _encodeRows(rows));
  }

  static String _encodeRows(Iterable<Map<String, dynamic>> rows) {
    return jsonEncode(rows.map((row) {
      final copy = <String, dynamic>{...row};
      // Preserve the readable ISO date so [_readJsonRows] can DateTime.parse it;
      // the localCreatedAtMs int is the fallback. Everything else (createdAt /
      // finishedAt Timestamps, FieldValue sentinels, nested maps) is collapsed
      // to JSON-safe primitives so jsonEncode can never throw on a stray field.
      final date = copy['dateTime'];
      if (date is DateTime) copy['dateTime'] = date.toIso8601String();
      copy.remove('createdAt');
      copy.remove('_documentId');
      return sanitizeForJson(copy);
    }).toList());
  }
}
