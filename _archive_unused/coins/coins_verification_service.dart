import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/app_config.dart';

/// Service for server-side verification of in-app purchases using Firebase Cloud Functions.
class CoinsVerificationService {
  static final CoinsVerificationService _instance = CoinsVerificationService._();
  factory CoinsVerificationService() => _instance;
  CoinsVerificationService._();

  /// Verify purchase with Firebase Cloud Function and grant coins on server.
  /// 
  /// Returns a map with:
  /// - 'ok': bool - Whether verification succeeded
  /// - 'coinsAdded': int? - Number of coins added (if successful)
  /// - 'newBalance': int? - New coin balance (if provided by Cloud Function)
  /// - 'consumed': bool? - Whether purchase was consumed
  /// - 'message': String? - Optional message (e.g., "Purchase already processed")
  /// - 'error': String? - Error message if verification failed
  /// 
  /// The Cloud Function will:
  /// 1. Verify Firebase Auth token (automatic via callable function)
  /// 2. Extract UID from token (server-authoritative, does not accept uid from client)
  /// 3. Verify purchase using Google Play Developer API
  /// 4. Grant coins to user in Firestore (idempotent via purchaseToken)
  /// 5. Consume the purchase via Google Play API
  /// 6. Return success response
  /// 
  /// Security: Cloud Functions automatically verify Firebase Auth tokens.
  /// UID is extracted from auth token on server - never sent from client.
  Future<Map<String, dynamic>> verifyAndGrantCoins({
    required String uid, // Kept for backward compatibility but not sent to server
    required String productId,
    required String purchaseToken,
    required String? orderId,
    required String packageName,
  }) async {
    // Spark plan: purchases disabled — return early without calling Cloud Function.
    if (!AppConfig.kEnableRealPurchases) {
      if (kDebugMode) {
        debugPrint('[VerificationService] kEnableRealPurchases=false — purchase verification disabled');
      }
      return {
        'ok': false,
        'coinsAdded': null,
        'newBalance': null,
        'consumed': false,
        'functionsUnavailable': false,
        'error': 'Purchases are temporarily unavailable.',
      };
    }

    // Logging
    if (kDebugMode) {
      debugPrint('[VerificationService] Calling Cloud Function for verification...');
      debugPrint('[VerificationService] productId: $productId');
      debugPrint('[VerificationService] purchaseToken: ${purchaseToken.length > 20 ? purchaseToken.substring(0, 20) + "..." : purchaseToken}');
      debugPrint('[VerificationService] orderId: $orderId');
      debugPrint('[VerificationService] packageName: $packageName');
    }

    // Verify user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('[VerificationService] User not authenticated - cannot verify purchase');
      }
      return {
        'ok': false,
        'coinsAdded': null,
        'newBalance': null,
        'consumed': false,
        'functionsUnavailable': false,
        'error': 'User not authenticated',
      };
    }

    try {
      // Force-refresh auth token to prevent 401 Unauthorized errors
      await user.getIdToken(true);

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('verifyGooglePlayPurchase');

      // Prepare request data
      // IMPORTANT: uid is NOT sent - Cloud Function extracts it from auth token
      final requestData = <String, dynamic>{
        'productId': productId,
        'purchaseToken': purchaseToken,
        'packageName': packageName,
        if (orderId != null) 'orderId': orderId,
        // uid is NOT included - server extracts it from Firebase Auth token
      };

      if (kDebugMode) {
        debugPrint('[VerificationService] Calling Cloud Function with data: $requestData');
      }

      // Call Cloud Function (automatic authentication via Firebase SDK)
      final result = await callable.call(requestData).timeout(
        const Duration(seconds: 10),
      );

      final data = result.data as Map<String, dynamic>;
      final ok = data['ok'] as bool? ?? false;
      final coinsAdded = data['coinsAdded'] as int?;
      final newBalance = data['newBalance'] as int?;
      final message = data['message'] as String?;
      final error = data['error'] as String?;

      // Logging
      if (kDebugMode) {
        debugPrint('[VerificationService] Cloud Function response:');
        debugPrint('[VerificationService]   result.ok: $ok');
        if (ok) {
          debugPrint('[VerificationService]   coinsAdded: $coinsAdded');
          debugPrint('[VerificationService]   newBalance: $newBalance');
          if (message != null) {
            debugPrint('[VerificationService]   message: $message');
          }
        } else {
          debugPrint('[VerificationService]   error: $error');
        }
      }

      return {
        'ok': ok,
        'coinsAdded': coinsAdded,
        'newBalance': newBalance,
        'consumed': data['consumed'] as bool? ?? false,
        'functionsUnavailable': false,
        'message': message,
        'error': error,
      };
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[VerificationService] Cloud Function error:');
        debugPrint('[VerificationService]   code: ${e.code}');
        debugPrint('[VerificationService]   message: ${e.message}');
        if (e.details != null) {
          debugPrint('[VerificationService]   details: ${e.details}');
        }
      }

      // Detect "Cloud Functions not deployed / unavailable" conditions. On the
      // Spark (free) plan the `verifyGooglePlayPurchase` callable does not exist,
      // so Firebase returns NOT_FOUND / UNAVAILABLE / INTERNAL. We surface a
      // dedicated [functionsUnavailable] flag so the caller can fall back to the
      // free client-side grant path instead of treating it as a real rejection.
      final code = e.code.toLowerCase();
      final msg = (e.message ?? '').toLowerCase();
      final functionsUnavailable = code == 'not-found' ||
          code == 'unavailable' ||
          code == 'unimplemented' ||
          code == 'internal' ||
          msg.contains('not_found') ||
          msg.contains('not found') ||
          msg.contains('not-found') ||
          msg.contains('not deployed') ||
          msg.contains('not available');

      // Map Firebase Functions error codes to response
      return {
        'ok': false,
        'coinsAdded': null,
        'newBalance': null,
        'consumed': false,
        'functionsUnavailable': functionsUnavailable,
        'error': e.message ?? 'Cloud Function error: ${e.code}',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VerificationService] Unexpected error calling Cloud Function: $e');
      }
      // Any other error (missing plugin, network, timeout) means we could not
      // reach a working verification backend. Treat it as functions-unavailable
      // so a real Google Play purchase is not lost — the client fallback grants
      // the coins and records the purchase as unverified/untrusted.
      return {
        'ok': false,
        'coinsAdded': null,
        'newBalance': null,
        'consumed': false,
        'functionsUnavailable': true,
        'error': 'Unexpected error: $e',
      };
    }
  }

  /// Indicates whether server verification is available.
  /// Returns true if user is authenticated (Cloud Functions are always available if Firebase is initialized).
  Future<bool> isServerVerificationAvailable() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user != null;
    } catch (_) {
      return false;
    }
  }
}

