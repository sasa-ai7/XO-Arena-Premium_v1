import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../core/app_config.dart';
import '../services/app_mode_service.dart';
import '../services/local_store.dart';
import '../services/audit_service.dart';

import 'coins_catalog.dart';
import 'coins_repo.dart';
import 'coins_verification_service.dart';
import 'premium_avatar_service.dart';
import 'purchase_orders_logger.dart';

/// Type of product a [PurchaseGrantResult] describes.
enum PurchaseProductType { coins, avatar, unknown }

/// Result of a purchase grant operation.
class PurchaseGrantResult {
  final bool ok;
  final int? coinsAdded;
  final int? newBalance;
  final String? message;
  final String? error;
  final String productId;
  final PurchaseProductType productType;
  final String? avatarId;

  /// True for interim "pending" emits (Google Play not yet confirmed). UI
  /// should keep the purchase flow open and show a wait message rather than
  /// treating this as success or failure.
  final bool pending;

  PurchaseGrantResult({
    required this.ok,
    this.coinsAdded,
    this.newBalance,
    this.message,
    this.error,
    required this.productId,
    this.productType = PurchaseProductType.coins,
    this.avatarId,
    this.pending = false,
  });
}

/// Service for handling Google Play in-app purchases for coins.
class IapCoinsService {
  static final IapCoinsService _instance = IapCoinsService._();
  factory IapCoinsService() => _instance;
  IapCoinsService._();

  /// IAP source identifier for error reporting
  static String get kIAPSource =>
      Platform.isAndroid ? 'google_play' : 'store_kit';

  final InAppPurchase _iap = InAppPurchase.instance;
  final CoinsVerificationService _verificationService =
      CoinsVerificationService();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isAvailable = false;
  Future<void>? _initFuture;
  bool _initialized = false;

  /// In-flight verification dedup: prevents multiple concurrent server calls
  /// for the same purchaseToken (Google Play can emit duplicate events).
  final Set<String> _pendingVerifications = {};

  /// True while a buy() flow is in progress. Prevents double-tap.
  bool _billingFlowActive = false;

  /// Stream controller for coin grant events (for UI notifications).
  final _coinGrantController =
      StreamController<PurchaseGrantResult>.broadcast();

  /// Stream of coin grant results. UI should listen to this to show success/error messages.
  Stream<PurchaseGrantResult> get coinGrantStream =>
      _coinGrantController.stream;

  /// Initialize the IAP service and set up purchase stream.
  /// Also restores any unconsumed purchases on startup.
  Future<void> init() async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture!;
    _initFuture = _initInternal();
    try {
      await _initFuture;
      _initialized = true;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _initInternal() async {
    // Spark plan: skip Google Play Billing connection entirely.
    if (!AppConfig.kEnableRealPurchases) {
      _isAvailable = false;
      if (kDebugMode)
        debugPrint('[IAP] Skipping IAP init — kEnableRealPurchases=false');
      return;
    }

    // Strict online guard: never connect to billing unless the app is
    // stably online. canUseOnlineServices is tighter than isOfflineLike
    // and excludes switchingToOnline / connectionProblem.
    if (!AppModeService.canUseOnlineServices) {
      _isAvailable = false;
      if (kDebugMode) {
        debugPrint(
            '[IAP] skipped because app is not safely online (mode=${AppModeService.current})');
      }
      return;
    }

    // Auth guard: never start billing without a signed-in user. Without
    // a uid we can't credit purchases or call verifyGooglePlayPurchase.
    if (FirebaseAuth.instance.currentUser == null) {
      _isAvailable = false;
      if (kDebugMode) debugPrint('[IAP] skipped because user is null');
      return;
    }

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      if (kDebugMode) {
        debugPrint('[IAP] Store not available');
      }
      return;
    }

    // Listen to purchase updates
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () {
        _purchaseSubscription?.cancel();
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('[IAP] Purchase stream error: $error');
        }
      },
    );

    // Clean up any pending purchases on init (consumables don't "restore")
    // This prevents "You already own this item" errors
    try {
      await consumePendingPurchases();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[IAP] Error consuming pending purchases on init (non-fatal): $e');
      }
      // Don't crash - continue initialization
    }
  }

  /// Dispose resources.
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _initialized = false;
  }

  /// Load products from the store.
  /// Handles network errors, billing disconnection, and product unavailability.
  Future<List<ProductDetails>> loadProducts() async {
    // Check store availability first
    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        if (kDebugMode) {
          debugPrint('[IAP] Store not available');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IAP] Error checking store availability: $e');
      }
      _isAvailable = false;
      return [];
    }

    try {
      final response = await _iap
          .queryProductDetails(
            CoinsCatalog.productIds.toSet(),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.error != null) {
        final errorCode = response.error!.code.toLowerCase();
        final errorMessage = response.error!.message.toLowerCase();

        if (kDebugMode) {
          debugPrint('[IAP] Error loading products: ${response.error}');
        }

        // Handle specific error cases
        if (errorCode.contains('item_unavailable') ||
            errorCode.contains('not_found') ||
            errorMessage.contains('not_found') ||
            errorMessage.contains('item_unavailable')) {
          if (kDebugMode) {
            debugPrint(
                '[IAP] Products not found or unavailable - may need to check Google Play Console configuration');
          }
        } else if (errorCode.contains('network') ||
            errorMessage.contains('network') ||
            errorCode.contains('billing_unavailable')) {
          if (kDebugMode) {
            debugPrint(
                '[IAP] Network or billing unavailable - will retry on next attempt');
          }
        }

        return [];
      }

      return response.productDetails;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IAP] Exception loading products: $e');
      }
      return [];
    }
  }

  /// Buy a product.
  ///
  /// Uses autoConsume: false to allow server-side verification and consumption.
  /// This ensures:
  /// 1. Server verification happens before consuming
  /// 2. Prevents duplicate grants if verification fails
  /// 3. Allows manual control over consume timing
  /// 4. Required for proper security in production
  ///
  /// The purchase will be consumed on the server after successful verification.
  ///
  /// Handles network errors, billing disconnection, and "already owned" errors with retry logic.
  Future<bool> buy(ProductDetails product, {bool isRetry = false}) async {
    // Spark plan: purchases disabled.
    if (!AppConfig.kEnableRealPurchases) {
      if (kDebugMode)
        debugPrint('[IAP] buy() blocked — kEnableRealPurchases=false');
      return false;
    }

    // Offline guard: in-app purchases require network.
    if (AppModeService.isOfflineLike) {
      if (kDebugMode) debugPrint('[IAP] buy() blocked — offline mode');
      return false;
    }

    if (_billingFlowActive) {
      if (kDebugMode)
        debugPrint('[IAP] buy() blocked — billing flow already active');
      return false;
    }
    _billingFlowActive = true;

    try {
      // Check store availability first
      try {
        _isAvailable = await _iap.isAvailable();
        if (!_isAvailable) {
          if (kDebugMode) {
            debugPrint('[IAP] Store not available for purchase');
          }
          return false;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[IAP] Error checking store availability: $e');
        }
        _isAvailable = false;
        return false;
      }

      try {
        if (kDebugMode) {
          debugPrint('[IAP_LOG] buy tapped productId=${product.id}');
        }

        final purchaseParam = PurchaseParam(
          productDetails: product,
        );

        final isAvatar = CoinsCatalog.isAvatarProduct(product.id);

        // Coins: autoConsume:false → we consume after server verification.
        // Avatar (non-consumable): use buyNonConsumable so Google Play remembers
        // ownership and allows restore. NEVER autoConsume the avatar.
        final success = await (isAvatar
                ? _iap.buyNonConsumable(purchaseParam: purchaseParam)
                : _iap.buyConsumable(
                    purchaseParam: purchaseParam,
                    autoConsume: false,
                  ))
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (kDebugMode) {
              debugPrint('[IAP] Buy request timeout for ${product.id}');
            }
            return false;
          },
        );

        if (kDebugMode) {
          debugPrint('[IAP] Buy initiated: $success for ${product.id}'
              '${isRetry ? ' (retry)' : ''} avatar=$isAvatar');
        }

        return success;
      } on PlatformException catch (e) {
        // Handle platform-specific errors
        final errorCode = e.code.toLowerCase();
        final errorMessage = (e.message ?? '').toLowerCase();

        if (kDebugMode) {
          debugPrint('[IAP] Platform exception buying product: $e');
          debugPrint('[IAP] Error code: $errorCode, message: $errorMessage');
        }

        // Check if this is an "already owned" error
        final alreadyOwned = errorCode.contains('item_already_owned') ||
            errorCode.contains('already_owned') ||
            errorMessage.contains('already own') ||
            errorMessage.contains('already_owned') ||
            errorMessage.contains('item_already_owned');

        // For the non-consumable avatar, "already owned" means the user
        // already paid for the entitlement. We should NOT cleanup/consume
        // — instead surface a friendly notification and refresh ownership
        // from past purchases. The verification stream handles the grant.
        if (alreadyOwned && CoinsCatalog.isAvatarProduct(product.id)) {
          if (kDebugMode) {
            debugPrint(
                '[IAP] Avatar already owned for ${product.id} — restoring entitlement');
          }
          try {
            await _iap.restorePurchases();
          } catch (_) {}
          final avatarCatalogId =
              CoinsCatalog.avatarIdForProductId(product.id) ??
                  CoinsCatalog.premiumAvatarId;
          final entitlement =
              CoinsCatalog.entitlementForProductId(product.id) ??
                  CoinsCatalog.premiumAvatarEntitlement;
          _coinGrantController.add(PurchaseGrantResult(
            ok: true,
            coinsAdded: 0,
            message: 'Premium avatar already owned — restored.',
            productId: product.id,
            productType: PurchaseProductType.avatar,
            avatarId: entitlement,
          ));
          // Mark locally so the shop hides the card immediately.
          unawaited(
              PremiumAvatarService.instance.markOwnedLocally(avatarCatalogId));
          return true;
        }

        // Handle "already owned" error for consumables: clean up and retry once
        if (alreadyOwned && !isRetry) {
          if (kDebugMode) {
            debugPrint(
                '[IAP] ITEM_ALREADY_OWNED detected for ${product.id} - cleaning up and retrying once');
          }

          try {
            // SAFE cleanup: verify/grant then consume
            await consumePendingPurchases();

            // Small delay to allow cleanup to complete
            await Future.delayed(const Duration(milliseconds: 300));

            if (kDebugMode) {
              debugPrint(
                  '[IAP] Retrying purchase for ${product.id} after cleanup');
            }

            // Retry purchase ONCE (with retry flag to prevent infinite loops)
            return await buy(product, isRetry: true);
          } catch (retryError) {
            if (kDebugMode) {
              debugPrint('[IAP] Error during cleanup/retry: $retryError');
            }
            return false;
          }
        } else if (alreadyOwned && isRetry) {
          // Already retried once, don't retry again
          if (kDebugMode) {
            debugPrint(
                '[IAP] ITEM_ALREADY_OWNED still present after retry - giving up');
          }
          return false;
        }

        // Handle other specific error cases
        if (errorCode.contains('network') || errorMessage.contains('network')) {
          if (kDebugMode) {
            debugPrint(
                '[IAP] Network error during purchase - user should retry');
          }
        } else if (errorCode.contains('billing_unavailable') ||
            errorMessage.contains('billing_unavailable')) {
          if (kDebugMode) {
            debugPrint('[IAP] Billing unavailable - may need to reconnect');
          }
          // Try to reconnect
          try {
            _isAvailable = await _iap.isAvailable();
          } catch (_) {
            _isAvailable = false;
          }
        }

        return false;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[IAP] Exception buying product: $e');
        }
        return false;
      }
    } finally {
      _billingFlowActive = false;
    }
  }

  /// Handle purchase updates from the stream.
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  /// Handle a single purchase.
  ///
  /// Flow: Verify → Grant → Consume (server) → Complete Purchase (client)
  /// - completePurchase: Acknowledges purchase to Google Play, prevents re-delivery
  /// - consume: Marks consumable as used, allows re-purchase (done on server)
  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (kDebugMode) {
      debugPrint(
          '[IAP] Purchase status: ${purchase.status} for ${purchase.productID}');
      debugPrint('[IAP_LOG] purchase update received');
      debugPrint('[IAP_LOG] productId=${purchase.productID}');
      debugPrint('[IAP_LOG] status=${purchase.status.name}');
      debugPrint('[IAP_LOG] orderId=${purchase.purchaseID ?? '-'}');
    }

    switch (purchase.status) {
      case PurchaseStatus.purchased:
        await _processPurchased(purchase);
        break;

      case PurchaseStatus.pending:
        if (kDebugMode) {
          debugPrint('[IAP] Purchase pending for ${purchase.productID}');
        }
        // Surface to UI so the user sees a pending message and we dismiss
        // the loading dialog instead of leaving them staring at a spinner.
        _coinGrantController.add(PurchaseGrantResult(
          ok: true,
          pending: true,
          message:
              'Purchase pending. We will update it when Google Play confirms it.',
          productId: purchase.productID,
        ));
        // Don't complete pending purchases - wait for them to complete
        break;

      case PurchaseStatus.error:
        if (kDebugMode) {
          debugPrint('[IAP] Purchase error: ${purchase.error}');
          if (purchase.error != null) {
            debugPrint(
                '[IAP] Error code: ${purchase.error!.code}, message: ${purchase.error!.message}');

            // Handle ITEM_ALREADY_OWNED error by querying and processing past purchases
            final errorCode = purchase.error!.code.toLowerCase();
            final errorMessage = purchase.error!.message.toLowerCase();

            if (errorCode.contains('item_already_owned') ||
                errorCode.contains('already_owned') ||
                errorMessage.contains('already owned') ||
                errorMessage.contains('item_already_owned') ||
                errorMessage.contains('you already own this item')) {
              debugPrint(
                  '[IAP] ITEM_ALREADY_OWNED in error handler — will not re-grant here');
            }
          }
        }
        // Complete error purchases to prevent them from blocking future purchases
        // (only if not already_owned, which is handled above)
        if (purchase.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchase);
          } catch (e) {
            // Non-fatal if already acknowledged
            if (kDebugMode) {
              debugPrint(
                  '[IAP] Error completing failed purchase (non-fatal): $e');
            }
          }
        }
        _billingFlowActive = false;
        _coinGrantController.add(PurchaseGrantResult(
          ok: false,
          error: 'Purchase failed. Please try again.',
          productId: purchase.productID,
        ));
        break;

      case PurchaseStatus.restored:
        if (kDebugMode) {
          debugPrint('[IAP] Purchase restored: ${purchase.productID}');
        }
        try {
          await PurchaseOrdersLogger.instance.logRestored(purchase);
        } catch (e) {
          if (kDebugMode) debugPrint('[IAP_LOG] logRestored error: $e');
        }
        // Process restored purchases the same way as new purchases
        await _processPurchased(purchase);
        break;

      case PurchaseStatus.canceled:
        if (kDebugMode) {
          debugPrint('[IAP] Purchase canceled: ${purchase.productID}');
        }
        // Complete canceled purchases
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        _billingFlowActive = false;
        _coinGrantController.add(PurchaseGrantResult(
          ok: false,
          error: 'Purchase canceled.',
          productId: purchase.productID,
        ));
        break;
    }
  }

  /// Process a purchased item: Verify → Grant → Consume → Complete
  ///
  /// Flow:
  /// 1. Idempotency check (local cache, then Firestore transaction)
  /// 2. Verify + Grant on server (CF)
  /// 3. Consume (coins only — AFTER grant so crash can't lose the purchase)
  /// 4. completePurchase
  /// 5. Emit success with coinsAdded
  Future<void> _processPurchased(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    final isAvatar = CoinsCatalog.isAvatarProduct(productId);

    if (kDebugMode) {
      debugPrint('[IAP] purchase_received productId=$productId '
          'status=${purchase.status.name} orderId=${purchase.purchaseID ?? '-'}');
    }

    // Trust ONLY the hardcoded in-app catalog. Coin amounts are never read from
    // Firestore or supplied by the client/store payload — only the product id
    // is used to look up a fixed, trusted coin amount. Unknown product ids are
    // rejected and logged as suspicious; nothing is granted or consumed.
    if (!CoinsCatalog.isValidProductId(productId)) {
      if (kDebugMode) debugPrint('[IAP] unknown_product_rejected productId=$productId');
      _coinGrantController.add(PurchaseGrantResult(
        ok: false,
        error: 'Product is currently unavailable.',
        productId: productId,
      ));
      // Do NOT consume/complete an unknown product — leave it untouched so a
      // legitimate future build with the correct catalog can process it.
      return;
    }

    if (kDebugMode) {
      debugPrint('[IAP] product_validated productId=$productId '
          'type=${isAvatar ? 'avatar' : 'coins'}');
    }

    try {
      final purchaseToken = purchase.verificationData.serverVerificationData;
      final orderId = purchase.purchaseID;

      // 0) Dedup guard: prevent concurrent server calls for same purchaseToken
      // Google Play can fire duplicate PurchaseStatus.purchased events
      final dedupKey = '$productId:$purchaseToken';
      if (_pendingVerifications.contains(dedupKey)) {
        if (kDebugMode) {
          debugPrint(
              '[IAP] Skipping duplicate verification for $productId (already in-flight)');
        }
        return;
      }
      _pendingVerifications.add(dedupKey);

      if (kDebugMode) {
        final base = CoinsCatalog.baseCoinsForProductId(productId);
        final bonus = CoinsCatalog.bonusForProductId(productId);
        final total = CoinsCatalog.coinsForProductId(productId);
        debugPrint('[IAP] === Processing Purchase ===');
        debugPrint('[IAP]   productId=$productId isAvatar=$isAvatar');
        debugPrint('[IAP]   orderId=$orderId');
        debugPrint(
            '[IAP]   baseCoins=$base bonusCoins=$bonus totalCoins=$total');
      }

      try {
        // 0.5) Always log "purchased_client_reported" before we touch consume/verify
        // so admins see the timeline even if a later step crashes.
        try {
          await PurchaseOrdersLogger.instance
              .logPurchasedClientReported(purchase);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[IAP_LOG] logPurchasedClientReported error: $e');
          }
        }

        // 1) Idempotency check (local)
        final alreadyProcessed =
            await CoinsRepo.isPurchaseProcessed(productId, purchaseToken);
        if (alreadyProcessed) {
          try {
            await PurchaseOrdersLogger.instance.logAlreadyProcessed(purchase);
          } catch (_) {}
          // Coins: consume so the user can re-purchase. Avatar: acknowledge only.
          if (Platform.isAndroid && !isAvatar) {
            try {
              final androidAddition = _iap
                  .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
              await androidAddition.consumePurchase(purchase);
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                    '[IAP] Error consuming already-processed purchase (non-fatal): $e');
              }
            }
          }
          if (purchase.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchase);
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                    '[IAP] Error completing already-processed purchase (non-fatal): $e');
              }
            }
          }
          // Re-assert local entitlement so the shop card hides on cold start.
          if (isAvatar) {
            await PremiumAvatarService.instance
                .markOwnedLocally(CoinsCatalog.avatarIdForProductId(productId));
          }
          _coinGrantController.add(PurchaseGrantResult(
            ok: true,
            coinsAdded: 0,
            message: isAvatar
                ? 'Premium avatar already owned.'
                : 'Purchase already processed',
            productId: productId,
            productType: isAvatar
                ? PurchaseProductType.avatar
                : PurchaseProductType.coins,
            avatarId: isAvatar
                ? (CoinsCatalog.entitlementForProductId(productId) ??
                    CoinsCatalog.premiumAvatarEntitlement)
                : null,
          ));
          return;
        }

        // 2) Verify + Grant on server (server is the source of truth)
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          _coinGrantController.add(PurchaseGrantResult(
            ok: false,
            error: 'User not logged in',
            productId: productId,
          ));
          return;
        }

        // Token refresh handled inside verifyAndGrantCoins() — no need to refresh here
        if (kDebugMode) {
          debugPrint('[IAP] server_verify_attempt productId=$productId');
        }
        final result = await _verificationService.verifyAndGrantCoins(
          uid: user.uid,
          productId: productId,
          purchaseToken: purchaseToken,
          orderId: orderId,
          packageName: 'com.xoarena.neonclash',
        );

        // FREE CLIENT-SIDE FALLBACK (no Blaze / no Cloud Functions).
        //
        // When `verifyGooglePlayPurchase` is not deployed (Spark/free plan) the
        // callable returns NOT_FOUND / UNAVAILABLE. The verification service maps
        // those to functionsUnavailable=true. Rather than failing a REAL Google
        // Play purchase (status == purchased), we grant the coins/avatar locally
        // through a deterministic, idempotent Firestore transaction. Every record
        // it writes is marked verified:false / trustedRevenue:false.
        //
        // SECURITY LIMITATION: this is NOT equivalent to server-side Google Play
        // verification (Google Play Developer API / Cloud Functions). It trusts
        // the in-memory purchase object from the billing client. Add backend
        // verification later for production-grade, trusted revenue.
        if (result['functionsUnavailable'] == true) {
          if (kDebugMode) {
            debugPrint(
                '[IAP] server_verify_skipped_functions_not_available productId=$productId');
          }
          await _grantViaClientFallback(purchase);
          return;
        }

        var ok = result['ok'] == true;
        var coinsAdded = result['coinsAdded'] as int?;
        // Support both new (balanceAfter/balanceBefore) and old (newBalance/previousBalance) field names
        final newBalance =
            (result['balanceAfter'] ?? result['newBalance']) as int?;
        final message = result['message'] as String?;
        final error = result['error'] as String?;
        final productType = result['productType'] as String?;
        final avatarId = result['avatarId'] as String?;
        final serverIsAvatar = isAvatar || productType == 'avatar';
        // Detect ALREADY_PROCESSED from both old format (ok:true, alreadyProcessed:true)
        // and new format (ok:false, error:'ALREADY_PROCESSED')
        final serverAlreadyProcessed = result['alreadyProcessed'] == true ||
            result['error'] == 'ALREADY_PROCESSED';

        // Handle ALREADY_PROCESSED: server confirmed purchase was already granted
        // This is NOT an error — just a duplicate request. Skip local fallback.
        if (serverAlreadyProcessed) {
          if (kDebugMode) {
            debugPrint(
                '[IAP] Server says already processed for $productId — skipping local fallback');
          }
          try {
            await PurchaseOrdersLogger.instance.logAlreadyProcessed(purchase);
          } catch (_) {}
          // Mark as processed locally to stay in sync
          await CoinsRepo.markPurchaseProcessed(productId, purchaseToken);
          if (serverIsAvatar) {
            await PremiumAvatarService.instance
                .markOwnedLocally(CoinsCatalog.avatarIdForProductId(productId));
          }

          // Complete purchase to allow future purchases
          if (purchase.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchase);
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                    '[IAP] Error completing already-processed purchase (non-fatal): $e');
              }
            }
          }

          _coinGrantController.add(PurchaseGrantResult(
            ok: true,
            coinsAdded: 0,
            newBalance: newBalance,
            message: message ??
                (serverIsAvatar
                    ? 'Premium avatar already owned.'
                    : 'Purchase already processed'),
            productId: productId,
            productType: serverIsAvatar
                ? PurchaseProductType.avatar
                : PurchaseProductType.coins,
            avatarId: serverIsAvatar
                ? (avatarId ??
                    CoinsCatalog.entitlementForProductId(productId) ??
                    CoinsCatalog.premiumAvatarEntitlement)
                : null,
          ));
          return;
        }

        // Instant balance update from server response (Firestore listener will also sync)
        if (ok && newBalance != null) {
          LocalStore.setCoins(newBalance);
        }

        // Server verification is authoritative. Do not grant locally when the
        // Cloud Function rejects or cannot verify the purchase; otherwise a
        // NOT_FOUND/failed-precondition response can unlock paid products.
        if (!ok) {
          if (kDebugMode) {
            debugPrint(
                '[IAP] Server verification failed. Purchase was not granted.');
          }
        } else if (serverIsAvatar) {
          // Server granted the avatar — sync local ownership immediately so the
          // shop card hides without waiting for the Firestore listener.
          await PremiumAvatarService.instance
              .markOwnedLocally(CoinsCatalog.avatarIdForProductId(productId));
        }

        // Mirror the CF outcome into purchase_orders so admins see the final
        // balance/avatar state. Always verified:false — the mirror does not
        // claim revenue trust.
        try {
          await PurchaseOrdersLogger.instance.logCfMirror(
            p: purchase,
            ok: ok,
            coinsAdded: coinsAdded,
            balanceAfter: newBalance,
            avatarId: serverIsAvatar
                ? (avatarId ??
                    CoinsCatalog.entitlementForProductId(productId) ??
                    CoinsCatalog.premiumAvatarEntitlement)
                : null,
            error: ok ? null : error,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('[IAP_LOG] logCfMirror error: $e');
        }

        // 3) Consume AFTER grant (coins only — never avatars).
        // If this fails, consumePendingPurchases() will pick it up on next launch
        // and consume without re-granting (already marked processed).
        if (Platform.isAndroid && !isAvatar && ok) {
          try {
            final androidAddition = _iap
                .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
            await androidAddition.consumePurchase(purchase);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[IAP] Error consuming after grant (non-fatal): $e');
            }
          }
        }

        // 4) completePurchase
        if (ok && purchase.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchase);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[IAP] Error completing purchase (non-fatal): $e');
            }
          }
        }

        // 4) Increment purchase count for limit tracking
        if (ok && coinsAdded != null && coinsAdded > 0) {
          try {
            await CoinsRepo.incrementPurchaseCount(productId);
          } catch (_) {}
        }

        // 4b) Audit log
        if (ok) {
          if (serverIsAvatar) {
            AuditService.log('avatar_purchase_completed', {
              'productId': productId,
              'avatarId': avatarId ??
                  CoinsCatalog.entitlementForProductId(productId) ??
                  CoinsCatalog.premiumAvatarEntitlement,
              'orderId': orderId ?? 'unknown',
            });
          } else if (coinsAdded != null && coinsAdded > 0) {
            AuditService.log('purchase_completed', {
              'productId': productId,
              'coinsAdded': coinsAdded,
              'orderId': orderId ?? 'unknown',
            });
          }
        }

        // 5) Record purchase history
        if (ok && serverIsAvatar) {
          await LocalStore.addTopupHistory(
            usd: 0.0,
            coins: 0,
            type: 'avatar',
            source: 'avatar_purchase',
            description: 'Premium Arena Avatar',
            transactionId: orderId ?? purchaseToken,
          );
        } else if (ok && coinsAdded != null && coinsAdded > 0) {
          final serverPreviousBalance =
              (result['balanceBefore'] ?? result['previousBalance']) as int?;
          final serverBalanceAfter =
              (result['balanceAfter'] ?? result['newBalance']) as int?;
          await LocalStore.addTopupHistory(
            usd: 0.0,
            coins: coinsAdded,
            type: 'recharge',
            source: 'iap_purchase',
            description: 'Coin Purchase',
            transactionId: orderId,
            balanceBefore: serverPreviousBalance,
            balanceAfter: serverBalanceAfter,
          );
        }

        // 6) Emit event to UI + release billing lock
        _billingFlowActive = false;
        _coinGrantController.add(PurchaseGrantResult(
          ok: ok,
          coinsAdded: coinsAdded,
          newBalance: newBalance,
          message: message,
          error: ok ? null : (error ?? 'Verification failed'),
          productId: productId,
          productType: serverIsAvatar
              ? PurchaseProductType.avatar
              : PurchaseProductType.coins,
          avatarId: serverIsAvatar
              ? (avatarId ??
                  CoinsCatalog.entitlementForProductId(productId) ??
                  CoinsCatalog.premiumAvatarEntitlement)
              : null,
        ));
      } finally {
        // Always remove dedup key when done
        _pendingVerifications.remove(dedupKey);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IAP] Unexpected error in _processPurchased: $e');
      }
      _billingFlowActive = false;
      _coinGrantController.add(PurchaseGrantResult(
        ok: false,
        error: 'Unexpected error: $e',
        productId: productId,
      ));
    }
  }

  /// Free client-side grant path used when Cloud Functions are not deployed.
  ///
  /// Coins are granted ONLY for a real Google Play purchase object that already
  /// reached this point with [PurchaseStatus.purchased] (validated, known
  /// product). The grant itself is performed inside a deterministic, idempotent
  /// Firestore transaction (see [PurchaseOrdersLogger.grantCoinsClientFallback]
  /// / [PurchaseOrdersLogger.unlockAvatarClientFallback]) keyed by a
  /// deterministic transactionId so repeated stream emits / app restarts can
  /// never double-grant.
  ///
  /// Order of operations is safety-critical:
  ///   1. Grant atomically in Firestore (throws on real failure).
  ///   2. Only AFTER a successful grant, consume (consumables) + complete.
  /// If the grant throws we DO NOT consume/complete — Google Play re-delivers
  /// the purchase and we retry on the next launch.
  ///
  /// SECURITY LIMITATION: client-side fallback only. Not equivalent to
  /// server-side Google Play verification. All records are verified:false /
  /// trustedRevenue:false until backend verification is added.
  Future<void> _grantViaClientFallback(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    final isAvatar = CoinsCatalog.isAvatarProduct(productId);
    final purchaseToken = purchase.verificationData.serverVerificationData;

    if (kDebugMode) {
      debugPrint('[IAP] client_fallback_start productId=$productId '
          'type=${isAvatar ? 'avatar' : 'coins'}');
    }

    try {
      if (isAvatar) {
        // ── Non-consumable avatar: unlock once, never grant coins, never
        //    consume. Acknowledge (complete) so Google Play stops re-delivering.
        final avatarCatalogId = CoinsCatalog.avatarIdForProductId(productId) ??
            CoinsCatalog.premiumAvatarId;
        final entitlement = CoinsCatalog.entitlementForProductId(productId) ??
            CoinsCatalog.premiumAvatarEntitlement;

        final firstUnlock =
            await PurchaseOrdersLogger.instance.unlockAvatarClientFallback(
          purchase: purchase,
          avatarCatalogId: avatarCatalogId,
          entitlement: entitlement,
        );

        if (kDebugMode) {
          debugPrint(firstUnlock
              ? '[IAP] client_fallback_granted avatar=$entitlement'
              : '[IAP] duplicate_purchase_ignored avatar=$entitlement');
        }

        await PremiumAvatarService.instance.markOwnedLocally(avatarCatalogId);
        await CoinsRepo.markPurchaseProcessed(productId, purchaseToken);

        // Acknowledge only — non-consumables are NOT consumed.
        if (purchase.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchase);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[IAP] Error completing avatar purchase (non-fatal): $e');
            }
          }
        }
        if (kDebugMode) debugPrint('[IAP] complete_purchase_done');

        _billingFlowActive = false;
        _coinGrantController.add(PurchaseGrantResult(
          ok: true,
          coinsAdded: 0,
          message: firstUnlock
              ? 'Purchase completed successfully.'
              : 'Purchase already processed.',
          productId: productId,
          productType: PurchaseProductType.avatar,
          avatarId: entitlement,
        ));
        return;
      }

      // ── Consumable coin pack: grant the exact hardcoded amount, then consume.
      final coins = CoinsCatalog.coinsForProductId(productId);
      final granted = await PurchaseOrdersLogger.instance
          .grantCoinsClientFallback(purchase: purchase, coinsToGrant: coins);

      if (kDebugMode) {
        debugPrint(granted
            ? '[IAP] client_fallback_granted productId=$productId coins=$coins'
            : '[IAP] duplicate_purchase_ignored productId=$productId');
      }

      // Mark processed locally as an extra (non-authoritative) guard. The
      // Firestore ledger doc is the real idempotency key.
      await CoinsRepo.markPurchaseProcessed(productId, purchaseToken);

      // Consume AFTER a successful grant (granted == true for a fresh grant,
      // false for an already-granted duplicate — both are safe to consume).
      // A real grant FAILURE throws above and never reaches here, so we never
      // consume a purchase whose coins were not granted.
      if (Platform.isAndroid) {
        try {
          final androidAddition =
              _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
          await androidAddition.consumePurchase(purchase);
          if (kDebugMode) debugPrint('[IAP] consume_complete');
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[IAP] Error consuming after fallback grant (non-fatal): $e');
          }
        }
      }

      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[IAP] Error completing purchase (non-fatal): $e');
          }
        }
      }
      if (kDebugMode) debugPrint('[IAP] complete_purchase_done');

      if (granted) {
        // NOTE: do NOT call LocalStore.addTopupHistory here — the canonical,
        // deterministic wallet_ledger doc + balance update are written by
        // grantCoinsClientFallback. addTopupHistory would create a SECOND
        // ledger doc keyed by the raw orderId in a different schema.
        try {
          await CoinsRepo.incrementPurchaseCount(productId);
        } catch (_) {}
      }

      _billingFlowActive = false;
      _coinGrantController.add(PurchaseGrantResult(
        ok: true,
        coinsAdded: granted ? coins : 0,
        message: granted
            ? 'Purchase completed successfully.'
            : 'Purchase already processed.',
        productId: productId,
        productType: PurchaseProductType.coins,
      ));
    } catch (e) {
      // Grant failed → DO NOT consume/complete. Leave the purchase pending so
      // Google Play re-delivers it and we retry on the next launch.
      if (kDebugMode) debugPrint('[IAP] failed productId=$productId error=$e');
      _billingFlowActive = false;
      _coinGrantController.add(PurchaseGrantResult(
        ok: false,
        error: 'Purchase failed. Please try again.',
        productId: productId,
      ));
    }
  }

  /// Safe cleanup of pending purchases on Android.
  ///
  /// For already-processed consumables: consume + complete only (NO re-grant).
  /// For unprocessed consumables: grant via Firestore tx, then consume.
  /// For avatars (non-consumable): always route through _processPurchased
  /// (Firestore tx prevents double-grant naturally).
  Future<void> consumePendingPurchases() async {
    if (AppModeService.isOfflineLike) {
      if (kDebugMode)
        debugPrint('[IAP] consumePendingPurchases skipped — offline mode');
      return;
    }
    if (!_isAvailable || !Platform.isAndroid) {
      if (kDebugMode && !Platform.isAndroid) {
        debugPrint('[IAP] consumePendingPurchases is Android-only');
      }
      return;
    }

    try {
      final androidAddition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final pastPurchases = await androidAddition.queryPastPurchases();

      if (kDebugMode) {
        debugPrint(
            '[IAP] Found ${pastPurchases.pastPurchases.length} past purchases');
      }

      for (var purchase in pastPurchases.pastPurchases) {
        if (purchase.status != PurchaseStatus.purchased) continue;

        final productId = purchase.productID;
        final isAvatar = CoinsCatalog.isAvatarProduct(productId);

        if (isAvatar) {
          // Non-consumable: _processPurchased checks Firestore tx for dups
          await _processPurchased(purchase);
        } else {
          final purchaseToken =
              purchase.verificationData.serverVerificationData;
          final alreadyProcessed =
              await CoinsRepo.isPurchaseProcessed(productId, purchaseToken);

          if (alreadyProcessed) {
            // Already granted — just consume + complete to clear from Google
            if (kDebugMode)
              debugPrint(
                  '[IAP] Past purchase $productId already processed — consuming only');
            try {
              await androidAddition.consumePurchase(purchase);
            } catch (_) {}
            if (purchase.pendingCompletePurchase) {
              try {
                await _iap.completePurchase(purchase);
              } catch (_) {}
            }
          } else {
            // Legitimate unprocessed purchase — grant via the safe path
            if (kDebugMode)
              debugPrint(
                  '[IAP] Past purchase $productId NOT processed — granting');
            await _processPurchased(purchase);
          }
        }
      }

      if (kDebugMode) debugPrint('[IAP] Finished consuming pending purchases');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[IAP] Error consuming pending purchases: $e');
        debugPrint('[IAP] StackTrace: $st');
      }
    }
  }

  /// Clear existing purchases safely. Grants unprocessed purchases via
  /// Firestore tx before consuming; already-processed ones are just consumed.
  Future<void> clearExistingPurchases() async {
    if (!Platform.isAndroid || !_isAvailable) {
      if (kDebugMode && !Platform.isAndroid) {
        debugPrint('[IAP] clearExistingPurchases is Android-only');
      }
      return;
    }

    try {
      final androidAddition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await androidAddition.queryPastPurchases();

      if (kDebugMode) {
        debugPrint(
            '[IAP] Found ${response.pastPurchases.length} past purchases to clear');
      }

      for (var purchase in response.pastPurchases) {
        if (purchase.status != PurchaseStatus.purchased) continue;

        final productId = purchase.productID;
        final isAvatar = CoinsCatalog.isAvatarProduct(productId);
        final purchaseToken = purchase.verificationData.serverVerificationData;
        final alreadyProcessed =
            await CoinsRepo.isPurchaseProcessed(productId, purchaseToken);

        if (!alreadyProcessed) {
          // Paid but never granted — run through the safe grant path first
          if (kDebugMode)
            debugPrint(
                '[IAP] clearExisting: $productId NOT processed — granting first');
          await _processPurchased(purchase);
        } else {
          // Already granted — consume + complete only
          if (!isAvatar) {
            try {
              await androidAddition.consumePurchase(purchase);
            } catch (_) {}
          }
          if (purchase.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchase);
            } catch (_) {}
          }
        }
      }

      if (kDebugMode) debugPrint('[IAP] Finished clearing existing purchases');
    } catch (e) {
      if (kDebugMode)
        debugPrint('[IAP] Error during clearExistingPurchases: $e');
    }
  }

  /// Check for and process pending purchases (consumables don't "restore").
  /// Uses queryPastPurchases() which is the proper way to handle consumables.
  /// This replaces the old restorePurchases() API which doesn't work for consumables.
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      if (kDebugMode) {
        debugPrint('[IAP] Store not available for checking pending purchases');
      }
      return;
    }

    try {
      // Check store availability again (handle BillingClient disconnect)
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        if (kDebugMode) {
          debugPrint('[IAP] Store became unavailable during check');
        }
        _isAvailable = false;
        return;
      }
      _isAvailable = isAvailable;

      // For Android, use queryPastPurchases() - the proper way for consumables
      if (Platform.isAndroid) {
        if (kDebugMode) {
          debugPrint(
              '[IAP] Checking pending purchases using queryPastPurchases (consumables)');
        }
        await consumePendingPurchases();
      } else {
        // For iOS, use restorePurchases (non-consumables)
        if (kDebugMode) {
          debugPrint('[IAP] Using restorePurchases for iOS');
        }
        await _iap.restorePurchases();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (kDebugMode) {
        debugPrint('[IAP] Pending purchases check completed');
      }
    } on PlatformException catch (e) {
      // Handle platform-specific errors
      final errorCode = e.code.toLowerCase();
      final errorMessage = (e.message ?? '').toLowerCase();

      if (errorCode.contains('not_found') ||
          errorMessage.contains('not_found') ||
          errorCode.contains('item_unavailable') ||
          errorMessage.contains('item_unavailable')) {
        if (kDebugMode) {
          debugPrint(
              '[IAP] NOT_FOUND - consumables may not be available or already consumed');
        }
        // This is non-fatal - consumables don't "restore" like non-consumables
      } else {
        if (kDebugMode) {
          debugPrint('[IAP] Platform error during check: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IAP] Error checking pending purchases: $e');
      }
    }
  }

  /// Check if store is available.
  bool get isAvailable => _isAvailable;

  /// Get the purchase stream for external listeners (e.g., UI).
  /// This allows the UI to listen for purchase updates and show success messages.
  Stream<List<PurchaseDetails>>? get purchaseStream => _iap.purchaseStream;
}
