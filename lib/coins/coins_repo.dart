import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';
import '../services/local_store.dart';
import '../services/auth_service.dart';

/// Repository for granting coins from purchases with idempotency protection.
class CoinsRepo {
  static final CoinsRepo _instance = CoinsRepo._();
  factory CoinsRepo() => _instance;
  CoinsRepo._();

  /// Compute a stable processed key from productId and token.
  static String _computeProcessedKey(String productId, String token) {
    final input = '$productId:$token';
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Mark a purchase as processed locally (for sync with server's ALREADY_PROCESSED).
  /// Does NOT grant coins — just records the hash so future local checks skip it.
  static Future<void> markPurchaseProcessed(String productId, String purchaseToken) async {
    try {
      final p = await SharedPreferences.getInstance();
      final processedKey = _computeProcessedKey(productId, purchaseToken);
      final processed = p.getString(Keys.processedPurchases) ?? '';
      final processedList = processed.split(',');
      if (processedList.contains(processedKey)) return; // Already marked
      final updatedList = processed.isEmpty
          ? processedKey
          : '$processed,$processedKey';
      await p.setString(Keys.processedPurchases, updatedList);
      if (kDebugMode) {
        debugPrint('[CoinsRepo] Marked purchase as processed: $productId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CoinsRepo] markPurchaseProcessed error: $e');
      }
    }
  }

  @Deprecated('Use PurchaseOrdersLogger.grantCoinsClientFallback')
  static Future<bool> grantCoins({
    required int amount,
    required String productId,
    required String purchaseToken,
    String? orderId,
    double? usdAmount,
    int? previousBalance,
  }) async {
    // Block coin grants for guests
    if (AuthService().currentUser == null) {
      if (kDebugMode) {
        debugPrint('[CoinsRepo] Guest mode: Cannot grant coins. User must sign in.');
      }
      return false; // Guests cannot receive coins
    }

    try {
      final p = await SharedPreferences.getInstance();

      // Compute idempotency key from productId + token
      final processedKey = _computeProcessedKey(productId, purchaseToken);

      // Idempotency check: has this purchase been processed?
      final processed = p.getString(Keys.processedPurchases) ?? '';
      final processedList = processed.split(',');
      if (processedList.contains(processedKey)) {
        if (kDebugMode) {
          debugPrint('[CoinsRepo] Purchase $productId (key: $processedKey) already processed, skipping');
        }
        return false; // Already processed
      }

      // Unique transaction id for idempotent history (prevents duplicate entries).
      final transactionId = orderId ?? processedKey;

      // Grant coins locally
      await LocalStore.addCoins(amount);

      // Record transaction history (idempotent via transactionId)
      final usd = usdAmount ?? 0.0;
      await LocalStore.addTopupHistory(
        usd: usd,
        coins: amount,
        type: 'recharge',
        description: 'Coin Purchase',
        transactionId: transactionId,
        balanceBefore: previousBalance,
        balanceAfter: previousBalance != null ? previousBalance + amount : null,
      );

      // Mark purchase as processed using hash key
      final updatedList = processed.isEmpty
          ? processedKey
          : '$processed,$processedKey';
      await p.setString(Keys.processedPurchases, updatedList);

      if (kDebugMode) {
        debugPrint('[CoinsRepo] Granted $amount coins for purchase $productId (transactionId: $transactionId)');
      }

      return true;
    } catch (e, st) {
      // Never crash the game - log and return false
      if (kDebugMode) {
        debugPrint('[CoinsRepo] Error granting coins: $e');
        debugPrint('[CoinsRepo] StackTrace: $st');
      }
      return false;
    }
  }

  @Deprecated('Use PurchaseOrdersLogger.grantCoinsClientFallback')
  static Future<bool> grantCoinsWithVerification({
    required int amount,
    required String productId,
    required String purchaseToken,
    required String? orderId,
    required bool serverVerified,
    double? usdAmount,
  }) async {
    // In release mode, REQUIRE server verification to prevent cheating
    if (!kDebugMode && !serverVerified) {
      return false;
    }

    if (kDebugMode && !serverVerified) {
      debugPrint('[CoinsRepo] WARNING: Debug mode - granting coins without server verification. '
          'This should not happen in production!');
    }

    return await grantCoins(
      amount: amount,
      productId: productId,
      purchaseToken: purchaseToken,
      orderId: orderId,
      usdAmount: usdAmount,
    );
  }

  /// Check if a purchase has already been processed using hash key.
  static Future<bool> isPurchaseProcessed(String productId, String purchaseToken) async {
    try {
      final p = await SharedPreferences.getInstance();
      final processedKey = _computeProcessedKey(productId, purchaseToken);
      final processed = p.getString(Keys.processedPurchases) ?? '';
      return processed.split(',').contains(processedKey);
    } catch (_) {
      return false;
    }
  }

  /// Clear processed purchases (for testing/debugging only).
  static Future<void> clearProcessedPurchases() async {
    if (kDebugMode) {
      final p = await SharedPreferences.getInstance();
      await p.remove(Keys.processedPurchases);
    }
  }

  // ── Purchase Limit Tracking ──────────────────────────────────────────

  /// Get the current purchase count for a product from Firestore.
  static Future<int> getPurchaseCount(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('purchase_counts')
          .doc(productId)
          .get();
      return (doc.data()?['count'] as int?) ?? 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CoinsRepo] getPurchaseCount error: $e');
      }
      return 0;
    }
  }

  /// Increment the purchase count for a product in Firestore.
  static Future<void> incrementPurchaseCount(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('purchase_counts')
          .doc(productId)
          .set(
        {'count': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CoinsRepo] incrementPurchaseCount error: $e');
      }
    }
  }
}
