import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/audit_service.dart';
import '../services/local_store.dart';
import 'coins_catalog.dart';

/// Centralised writer for client-reported purchase telemetry.
///
/// Every record written by this logger is marked `verified: false` and
/// `trustedRevenue: false`. The records are diagnostic logs — not revenue
/// truth — and only become trusted when backend verification is added later.
///
/// Collections written:
///   • `purchase_orders/{transactionId}`                   — every state transition
///   • `users/{uid}/wallet_ledger/{transactionId}`         — IAP coin grants (fallback)
///   • `users/{uid}/ownedAvatars/{avatarId}`               — avatar unlocks (fallback)
///   • `audit_logs/{autoId}`                               — IAP event stream (via [AuditService])
///
/// The doc id IS the transactionId (see [_transactionIdFor]), so duplicate
/// stream events from Google Play naturally collapse to a single document.
class PurchaseOrdersLogger {
  PurchaseOrdersLogger._();
  static final PurchaseOrdersLogger instance = PurchaseOrdersLogger._();

  static const String _kPackageName = 'com.xoarena.neonclash';
  static const String _kSource = 'google_play_client';
  static const String _kPlatform = 'android';
  static const String _kNote =
      'Client-reported purchase log. Not backend verified.';

  /// In-memory cache of the appVersion so we don't hit PackageInfo on every write.
  String? _cachedAppVersion;
  Future<String?>? _appVersionFuture;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ─── id helpers ────────────────────────────────────────────────────────────

  /// SHA-256 of [token]. Raw token is never stored.
  static String _hashToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  /// Firestore doc-id-safe form of [orderId]. Strips slashes, dots, and the
  /// leading `__` Firestore reserves.
  static String _sanitizeOrderId(String orderId) {
    var s = orderId.replaceAll(RegExp(r'[/\.]'), '_');
    if (s.startsWith('__')) s = 'id_${s.substring(2)}';
    return s.isEmpty ? 'unknown' : s;
  }

  /// Build the canonical, deterministic transactionId for a [PurchaseDetails].
  ///
  /// Format: `iap_client_${uid}_${productId}_${suffix}` where the suffix is the
  /// SHA-256 of the Google Play purchaseToken (the per-purchase unique value),
  /// falling back to the sanitized orderId only when the token is missing.
  ///
  /// DUPLICATE-PREVENTION KEY IS THE purchaseTokenHash, NOT the productId. Every
  /// new Google Play purchase carries a fresh purchaseToken, so the same coin
  /// pack can be bought many times (different token → different doc id → new
  /// grant), while a retry / app-restart / stream-replay of ONE purchase reuses
  /// the same token → same doc id → collapses to a single row (set, never add).
  /// The productId is included only for readability. Returns null when neither a
  /// purchaseToken nor an orderId is present — callers must then skip writes.
  ///
  /// NOTE: the raw purchaseToken is never used as an id or stored; only its
  /// SHA-256 hash is used.
  String? _transactionIdFor(PurchaseDetails purchase, {String? uid}) {
    final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedUid == null) return null;
    final productId = purchase.productID;

    String? suffix;
    final token = purchase.verificationData.serverVerificationData;
    if (token.isNotEmpty) {
      suffix = _hashToken(token);
    } else {
      final orderId = purchase.purchaseID;
      if (orderId != null && orderId.isNotEmpty) {
        suffix = _sanitizeOrderId(orderId);
      }
    }
    if (suffix == null) return null;

    return 'iap_client_${resolvedUid}_${productId}_$suffix';
  }

  // ─── field builders ────────────────────────────────────────────────────────

  Future<String?> _appVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion;
    _appVersionFuture ??= () async {
      try {
        final p = await PackageInfo.fromPlatform();
        return '${p.version}+${p.buildNumber}';
      } catch (_) {
        return null;
      }
    }();
    _cachedAppVersion = await _appVersionFuture;
    return _cachedAppVersion;
  }

  Map<String, dynamic> _identityFields() {
    final u = FirebaseAuth.instance.currentUser;
    return <String, dynamic>{
      if (u != null) 'uid': u.uid,
      if (u?.email != null) 'email': u!.email,
      if (u?.displayName != null) 'displayName': u!.displayName,
      if (u?.photoURL != null) 'photoURL': u!.photoURL,
    };
  }

  Future<Map<String, dynamic>> _baseFields() async {
    return <String, dynamic>{
      ..._identityFields(),
      'packageName': _kPackageName,
      'packageNameAndroid': _kPackageName,
      'source': _kSource,
      'platform': _kPlatform,
      'verified': false,
      'trustedRevenue': false,
      'note': _kNote,
      'appVersion': await _appVersion(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _productClassification(String productId) {
    if (CoinsCatalog.isAvatarProduct(productId)) {
      final avatarId = CoinsCatalog.avatarIdForProductId(productId);
      return <String, dynamic>{
        'productId': productId,
        'productType': 'premium_avatar',
        if (avatarId != null) 'avatarId': avatarId.toString(),
      };
    }
    if (CoinsCatalog.isCoinProduct(productId)) {
      return <String, dynamic>{
        'productId': productId,
        'productType': 'coin_pack',
        'coins': CoinsCatalog.coinsForProductId(productId),
      };
    }
    return <String, dynamic>{
      'productId': productId,
      'productType': 'unknown',
    };
  }

  Map<String, dynamic> _purchaseFields(PurchaseDetails p) {
    final token = p.verificationData.serverVerificationData;
    final out = <String, dynamic>{
      ..._productClassification(p.productID),
      'rawPurchaseStatus': p.status.name,
      if (p.purchaseID != null && p.purchaseID!.isNotEmpty)
        'orderId': p.purchaseID,
      if (token.isNotEmpty) 'purchaseTokenHash': _hashToken(token),
    };
    final txDate = p.transactionDate;
    if (txDate != null && txDate.isNotEmpty) {
      final ms = int.tryParse(txDate);
      if (ms != null) {
        out['transactionDate'] = Timestamp.fromMillisecondsSinceEpoch(ms);
      }
    }
    if (p.error != null) {
      out['errorCode'] = p.error!.code;
      out['errorMessage'] = p.error!.message;
    }
    return out;
  }

  // ─── public logging API ────────────────────────────────────────────────────

  /// Debug-only trace for when the user taps Buy. No Firestore write.
  Future<String?> logStarted({
    required String productId,
    ProductDetails? product,
  }) async {
    if (kDebugMode) {
      debugPrint('[IAP_LOG] purchase_started '
          'productId=$productId price=${product?.price ?? '-'}');
    }
    return null;
  }

  Future<void> logPending(PurchaseDetails p) => _logStatus(p, 'pending');

  Future<void> logPurchasedClientReported(PurchaseDetails p) =>
      _logStatus(p, 'purchased_client_reported');

  Future<void> logCancelled(PurchaseDetails p) async {
    if (kDebugMode) {
      debugPrint('[IAP_LOG] purchase_cancelled productId=${p.productID}');
    }
  }

  Future<void> logError(PurchaseDetails p) async {
    if (kDebugMode) {
      debugPrint('[IAP_LOG] purchase_error productId=${p.productID} '
          'code=${p.error?.code ?? '-'} msg=${p.error?.message ?? '-'}');
    }
  }

  Future<void> logRestored(PurchaseDetails p) =>
      _logStatus(p, 'restored_client_reported');

  Future<void> logAlreadyProcessed(PurchaseDetails p) =>
      _logStatus(p, 'already_processed_client');

  Future<void> _logStatus(PurchaseDetails p, String status) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final txId = _transactionIdFor(p, uid: uid);
    if (txId == null) {
      if (kDebugMode) {
        debugPrint('[IAP_LOG] skipping purchase_orders write '
            'status=$status productId=${p.productID} — no orderId or purchaseToken');
      }
      return;
    }
    try {
      final base = await _baseFields();
      final data = <String, dynamic>{
        ...base,
        ..._purchaseFields(p),
        'status': status,
        // createdAt only set on first write; later writes preserve it.
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db
          .collection('purchase_orders')
          .doc(txId)
          .set(data, SetOptions(merge: true));
      _auditPurchase(
        _auditEventForStatus(status),
        p.productID,
        orderId: p.purchaseID,
        purchaseTokenHash: _maybeHashToken(p),
        status: status,
        errorMessage: p.error?.message,
      );
      if (kDebugMode) {
        debugPrint('[IAP_LOG] purchase_orders updated '
            'status=$status productId=${p.productID} '
            'orderId=${p.purchaseID ?? '-'} '
            'purchaseTokenHash=${_maybeHashToken(p) ?? '-'} '
            'txId=$txId');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP_LOG] _logStatus($status) error: $e');
    }
  }

  /// Mirror a Cloud Function outcome into purchase_orders so admins see the
  /// full timeline even when the CF is the actual grantor.
  Future<void> logCfMirror({
    required PurchaseDetails p,
    required bool ok,
    int? coinsAdded,
    int? balanceBefore,
    int? balanceAfter,
    String? avatarId,
    String? error,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final txId = _transactionIdFor(p, uid: uid);
    if (txId == null) {
      if (kDebugMode) {
        debugPrint('[IAP_LOG] logCfMirror skipped — no orderId or purchaseToken for ${p.productID}');
      }
      return;
    }
    final isAvatar = CoinsCatalog.isAvatarProduct(p.productID);
    try {
      final base = await _baseFields();
      final data = <String, dynamic>{
        ...base,
        ..._purchaseFields(p),
        'status': ok
            ? (isAvatar
                ? 'avatar_unlocked_client_fallback'
                : 'coin_granted_client_fallback')
            : (isAvatar ? 'avatar_unlock_failed' : 'coin_grant_failed'),
        if (coinsAdded != null) 'grantedCoins': coinsAdded,
        if (balanceBefore != null) 'balanceBefore': balanceBefore,
        if (balanceAfter != null) 'balanceAfter': balanceAfter,
        if (avatarId != null) 'avatarId': avatarId,
        if (ok && isAvatar) 'unlocked': true,
        if (!ok && error != null) 'errorMessage': error,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db
          .collection('purchase_orders')
          .doc(txId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP_LOG] logCfMirror error: $e');
    }
  }

  /// Free client-side coin grant fallback. Used when Cloud Functions are not
  /// deployed (Spark/free plan) so a real Google Play `PurchaseStatus.purchased`
  /// event is not lost. Runs atomically inside a single Firestore transaction:
  /// reads `users/{uid}` + `users/{uid}/wallet_ledger/{transactionId}`, and only
  /// when the ledger doc does NOT already exist does it increase
  /// `Wallet.coins` by the exact hardcoded [coinsToGrant], create the ledger
  /// doc, and update `purchase_orders/{transactionId}`.
  ///
  /// SECURITY LIMITATION: this is a free client-side fallback. It is NOT
  /// equivalent to server-side Google Play verification (Google Play Developer
  /// API / Cloud Functions). It trusts the in-memory purchase object returned
  /// by the billing client. Every record it writes is therefore marked
  /// `verified: false` and `trustedRevenue: false`. Add backend verification
  /// later to upgrade these to trusted revenue.
  ///
  /// Returns true when the grant landed, false when the ledger doc already
  /// existed (duplicate — another stream emit beat us to it). Throws when the
  /// Firestore transaction itself fails; callers MUST NOT consume/complete the
  /// purchase in that case so Google Play re-delivers it later.
  Future<bool> grantCoinsClientFallback({
    required PurchaseDetails purchase,
    required int coinsToGrant,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('grantCoinsClientFallback: no signed-in user');
    }
    final txId = _transactionIdFor(purchase, uid: uid);
    if (txId == null) {
      throw StateError(
          'grantCoinsClientFallback: no orderId or purchaseToken for ${purchase.productID}');
    }
    final productId = purchase.productID;
    final orderId = purchase.purchaseID;
    final token = purchase.verificationData.serverVerificationData;
    final tokenHash = token.isNotEmpty ? _hashToken(token) : null;

    final userRef = _db.collection('users').doc(uid);
    final ledgerRef = userRef.collection('wallet_ledger').doc(txId);
    final orderRef = _db.collection('purchase_orders').doc(txId);

    // First mark the order as "grant in flight" so admins see we tried.
    // verificationError records WHY we fell back (Cloud Functions missing).
    try {
      final base = await _baseFields();
      await orderRef.set(<String, dynamic>{
        ...base,
        ..._purchaseFields(purchase),
        'transactionId': txId,
        'status': 'coin_grant_started',
        'grantMode': 'google_play_client_only',
        'verificationError': 'cloud_functions_disabled_client_only',
        'coins': coinsToGrant,
        'grantedCoins': coinsToGrant,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {/* logging never blocks */}

    int? balanceBefore;
    int? balanceAfter;
    bool granted = false;

    // Atomic grant. On failure we rethrow (after recording the failure) so the
    // caller leaves the purchase unconsumed for re-delivery.
    try {
      await _db.runTransaction((tx) async {
        final existing = await tx.get(ledgerRef);
        if (existing.exists) {
          if (kDebugMode) {
            debugPrint('[IAP] duplicate_purchase_ignored txId=$txId');
          }
          balanceBefore = (existing.data()?['balanceBefore'] as num?)?.toInt();
          balanceAfter = (existing.data()?['balanceAfter'] as num?)?.toInt();
          return;
        }

        final userSnap = await tx.get(userRef);
        final wallet = userSnap.data()?['Wallet'] as Map<String, dynamic>?;
        final current = (wallet?['coins'] as num?)?.toInt() ?? 0;
        balanceBefore = current;
        balanceAfter = current + coinsToGrant;

        tx.set(
          userRef,
          <String, dynamic>{
            'Wallet': <String, dynamic>{'coins': balanceAfter},
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Wallet ledger entry — the immutable, deterministic proof that this
        // exact purchase was already granted. Marked unverified/untrusted.
        tx.set(ledgerRef, <String, dynamic>{
          'uid': uid,
          'type': 'iap_google_play',
          'productId': productId,
          'packageName': _kPackageName,
          'coins': coinsToGrant,
          'amount': coinsToGrant,
          'coinsDelta': coinsToGrant,
          'balanceBefore': balanceBefore,
          'balanceAfter': balanceAfter,
          if (orderId != null) 'orderId': orderId,
          if (tokenHash != null) 'purchaseTokenHash': tokenHash,
          'transactionId': txId,
          'status': 'coin_granted_client_fallback',
          'source': _kSource,
          'platform': _kPlatform,
          'verified': false,
          'trustedRevenue': false,
          'grantMode': 'google_play_client_only',
          'note':
              'Granted from Google Play Billing client without backend verification',
          'createdAt': FieldValue.serverTimestamp(),
        });

        granted = true;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] failed coin_grant txId=$txId error=$e');
      _auditPurchase('coin_grant_failed', productId,
          orderId: orderId,
          purchaseTokenHash: tokenHash,
          status: 'coin_grant_failed',
          errorMessage: e.toString());
      try {
        await orderRef.set(<String, dynamic>{
          'status': 'coin_grant_failed',
          'errorMessage': e.toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
      // Rethrow: caller must NOT consume the purchase on a real grant failure.
      rethrow;
    }

    // Mirror the local notifier so the UI updates instantly.
    if (granted && balanceAfter != null) {
      LocalStore.setCoins(balanceAfter!);
    }

    // Update the order with the final balances regardless of whether *this*
    // emit was the one that granted (the resulting state is the same).
    try {
      await orderRef.set(<String, dynamic>{
        'status': 'coin_granted_client_fallback',
        'grantMode': 'google_play_client_only',
        if (balanceBefore != null) 'balanceBefore': balanceBefore,
        if (balanceAfter != null) 'balanceAfter': balanceAfter,
        'coins': coinsToGrant,
        'grantedCoins': coinsToGrant,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    _auditPurchase(
      granted
          ? 'iap_coin_purchase_client_fallback'
          : 'duplicate_purchase_prevented',
      productId,
      orderId: orderId,
      purchaseTokenHash: tokenHash,
      status: granted
          ? 'coin_granted_client_fallback'
          : 'already_processed_client',
      coins: coinsToGrant,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
    );

    return granted;
  }

  /// Client-side avatar unlock fallback (Section I). Creates the new
  /// `users/{uid}/ownedAvatars/{avatarId}` subcollection doc AND appends to
  /// the existing `Inventory.ownedAvatars` + `Inventory.avatars` arrays so
  /// the avatar gallery picks the entitlement up immediately.
  ///
  /// Returns true when the entitlement landed for the first time, false if
  /// the user already owned it.
  Future<bool> unlockAvatarClientFallback({
    required PurchaseDetails purchase,
    required int avatarCatalogId,
    required String entitlement,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('unlockAvatarClientFallback: no signed-in user');
    }
    final txId = _transactionIdFor(purchase, uid: uid);
    if (txId == null) {
      throw StateError(
          'unlockAvatarClientFallback: no orderId or purchaseToken for ${purchase.productID}');
    }
    final productId = purchase.productID;
    final orderId = purchase.purchaseID;
    final token = purchase.verificationData.serverVerificationData;
    final tokenHash = token.isNotEmpty ? _hashToken(token) : null;
    final avatarIdStr = avatarCatalogId.toString();

    final userRef = _db.collection('users').doc(uid);
    final ownedRef = userRef.collection('ownedAvatars').doc(avatarIdStr);
    final orderRef = _db.collection('purchase_orders').doc(txId);

    try {
      final base = await _baseFields();
      await orderRef.set(<String, dynamic>{
        ...base,
        ..._purchaseFields(purchase),
        'transactionId': txId,
        'status': 'avatar_unlock_started',
        'grantMode': 'google_play_client_only',
        'verificationError': 'cloud_functions_disabled_client_only',
        'avatarId': avatarIdStr,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    bool firstUnlock = false;

    try {
      await _db.runTransaction((tx) async {
        final existing = await tx.get(ownedRef);
        if (existing.exists) {
          // Already owned: skip writes, just leave the marker.
          return;
        }
        tx.set(ownedRef, <String, dynamic>{
          'uid': uid,
          'avatarId': avatarIdStr,
          'productId': productId,
          if (orderId != null) 'orderId': orderId,
          if (tokenHash != null) 'purchaseTokenHash': tokenHash,
          'transactionId': txId,
          'source': _kSource,
          'platform': _kPlatform,
          'verified': false,
          'trustedRevenue': false,
          'grantMode': 'google_play_client_only',
          'note':
              'Unlocked from Google Play Billing client without backend verification',
          'unlockedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Append to the legacy fields the rest of the app already reads.
        // Use set+merge with FieldValue.arrayUnion so concurrent writes
        // remain idempotent.
        tx.set(
          userRef,
          <String, dynamic>{
            'Inventory': <String, dynamic>{
              'ownedAvatars': FieldValue.arrayUnion([avatarCatalogId]),
              'avatars': FieldValue.arrayUnion([entitlement]),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        firstUnlock = true;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IAP_LOG] unlockAvatarClientFallback tx error: $e');
      }
      _auditPurchase('avatar_unlock_failed', productId,
          orderId: orderId,
          purchaseTokenHash: tokenHash,
          status: 'avatar_unlock_failed',
          avatarId: avatarIdStr,
          errorMessage: e.toString());
      try {
        await orderRef.set(<String, dynamic>{
          'status': 'avatar_unlock_failed',
          'errorMessage': e.toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
      // Rethrow: caller must NOT acknowledge the purchase on a real failure.
      rethrow;
    }

    try {
      await orderRef.set(<String, dynamic>{
        'status': firstUnlock
            ? 'avatar_unlocked_client_fallback'
            : 'already_processed_client',
        'avatarId': avatarIdStr,
        'unlocked': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    _auditPurchase(
      firstUnlock
          ? 'iap_avatar_unlock_client_fallback'
          : 'duplicate_purchase_prevented',
      productId,
      orderId: orderId,
      purchaseTokenHash: tokenHash,
      status: firstUnlock
          ? 'avatar_unlocked_client_fallback'
          : 'already_processed_client',
      avatarId: avatarIdStr,
    );

    return firstUnlock;
  }

  // ─── audit helpers ─────────────────────────────────────────────────────────

  String _auditEventForStatus(String status) {
    switch (status) {
      case 'started':
        return 'purchase_started';
      case 'pending':
        return 'purchase_pending';
      case 'purchased_client_reported':
        return 'purchase_client_reported';
      case 'cancelled':
        return 'purchase_cancelled';
      case 'error':
        return 'purchase_error';
      case 'already_processed_client':
        return 'duplicate_purchase_prevented';
      case 'restored_client_reported':
        return 'purchase_restored';
      default:
        return 'purchase_status_$status';
    }
  }

  void _auditPurchase(
    String eventName,
    String productId, {
    String? orderId,
    String? purchaseTokenHash,
    required String status,
    int? coins,
    int? balanceBefore,
    int? balanceAfter,
    String? avatarId,
    String? errorMessage,
  }) {
    final email = FirebaseAuth.instance.currentUser?.email;
    AuditService.log(eventName, <String, dynamic>{
      'productId': productId,
      if (orderId != null) 'orderId': orderId,
      if (purchaseTokenHash != null) 'purchaseTokenHash': purchaseTokenHash,
      'status': status,
      'source': _kSource,
      'verified': false,
      'trustedRevenue': false,
      if (email != null) 'email': email,
      if (coins != null) 'coins': coins,
      if (balanceBefore != null) 'balanceBefore': balanceBefore,
      if (balanceAfter != null) 'balanceAfter': balanceAfter,
      if (avatarId != null) 'avatarId': avatarId,
      if (errorMessage != null) 'errorMessage': errorMessage,
    });
  }

  static String? _maybeHashToken(PurchaseDetails p) {
    final token = p.verificationData.serverVerificationData;
    return token.isNotEmpty ? _hashToken(token) : null;
  }
}
