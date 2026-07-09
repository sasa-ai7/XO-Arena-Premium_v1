import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../core/app_config.dart';
import '../services/app_mode_service.dart';

import 'coins_catalog.dart';
import 'coins_repo.dart';
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

  /// Short, log-safe SHA-256 prefix of [token] for debug logs. The raw
  /// purchaseToken is NEVER logged.
  static String _shortTokenHash(String token) {
    if (token.isEmpty) return '-';
    final hash = sha256.convert(utf8.encode(token)).toString();
    return '${hash.substring(0, 12)}…';
  }

  final InAppPurchase _iap = InAppPurchase.instance;
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
    // a uid we can't credit the wallet or write the wallet_ledger.
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
  /// Uses autoConsume: false so WE control consume timing. This ensures:
  /// 1. Coins are granted (idempotent Firestore transaction) BEFORE consuming.
  /// 2. If granting fails, we do NOT consume, so Google Play re-delivers the
  ///    purchase and it is retried on the next launch (no lost purchase).
  /// 3. The same individual purchase can never grant coins twice.
  ///
  /// This is the **Google Play Client Only** flow — it does NOT use Cloud
  /// Functions or the Google Play Developer API for verification.
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

  /// Handle a single purchase (Google Play Client Only flow).
  ///
  /// Only [PurchaseStatus.purchased] (and [PurchaseStatus.restored]) continue to
  /// validation + granting. pending/canceled/error never grant, never consume,
  /// and never completePurchase.
  /// - consume: marks a consumable as used so the pack can be bought again —
  ///   done ONLY after coins are granted + logged.
  /// - completePurchase: acknowledges to Google Play — done ONLY after grant.
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
        // Log clearly. Do NOT grant, do NOT consume, do NOT completePurchase.
        if (kDebugMode) {
          debugPrint('[IAP] purchase_error productId=${purchase.productID} '
              'code=${purchase.error?.code ?? '-'} '
              'message=${purchase.error?.message ?? '-'}');
        }
        try {
          await PurchaseOrdersLogger.instance.logError(purchase);
        } catch (_) {}
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
        // User backed out. Do NOT grant, do NOT consume, do NOT completePurchase.
        if (kDebugMode) {
          debugPrint('[IAP] purchase_canceled productId=${purchase.productID}');
        }
        try {
          await PurchaseOrdersLogger.instance.logCancelled(purchase);
        } catch (_) {}
        _billingFlowActive = false;
        _coinGrantController.add(PurchaseGrantResult(
          ok: false,
          error: 'Purchase canceled.',
          productId: purchase.productID,
        ));
        break;
    }
  }

  /// Process a purchased item using the **Google Play Client Only** flow.
  ///
  /// This flow does NOT use Cloud Functions or the Google Play Developer API.
  /// Coin amounts come only from the hardcoded [CoinsCatalog]; the grant is
  /// performed inside a deterministic, idempotent Firestore transaction keyed by
  /// the SHA-256 of the Google Play purchaseToken. Every record it writes is
  /// marked verified:false / trustedRevenue:false.
  ///
  /// Order (safety-critical):
  ///   1. Validate productId against CoinsCatalog (reject unknown).
  ///   2. Validate purchaseToken is present (reject empty).
  ///   3. Grant atomically in Firestore (idempotent by purchaseTokenHash).
  ///   4. ONLY after a successful grant: consume (consumables) + completePurchase.
  /// If granting throws we do NOT consume/complete, so Google Play re-delivers
  /// the purchase and we retry on the next launch (no lost purchase).
  Future<void> _processPurchased(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    final isAvatar = CoinsCatalog.isAvatarProduct(productId);
    final purchaseToken = purchase.verificationData.serverVerificationData;
    final tokenHashShort = _shortTokenHash(purchaseToken);

    if (kDebugMode) {
      debugPrint('[IAP] purchase_received productId=$productId '
          'status=${purchase.status.name} orderId=${purchase.purchaseID ?? '-'} '
          'tokenHash=$tokenHashShort');
    }

    // 1) Validate productId. Trust ONLY the hardcoded in-app catalog. Coin
    // amounts are never read from the UI/store payload — only the productId is
    // used to look up a fixed, trusted amount. Unknown ids are rejected and left
    // untouched (no consume/complete) so a correct future build can process them.
    if (!CoinsCatalog.isValidProductId(productId)) {
      if (kDebugMode) {
        debugPrint('[IAP] unknown_product_rejected productId=$productId');
      }
      _coinGrantController.add(PurchaseGrantResult(
        ok: false,
        error: 'Product is currently unavailable.',
        productId: productId,
      ));
      return;
    }

    // 2) Validate purchaseToken. A real Google Play purchase must carry a
    // token; without it we cannot build a stable idempotency key, so we reject
    // without granting and without consuming/completing.
    if (purchaseToken.isEmpty) {
      if (kDebugMode) {
        debugPrint('[IAP] empty_purchase_token_rejected productId=$productId');
      }
      _coinGrantController.add(PurchaseGrantResult(
        ok: false,
        error: 'Purchase could not be validated. Please contact support.',
        productId: productId,
      ));
      return;
    }

    if (kDebugMode) {
      debugPrint('[IAP] product_validated productId=$productId '
          'type=${isAvatar ? 'avatar' : 'coins'} tokenHash=$tokenHashShort');
    }

    // Dedup guard: Google Play can fire duplicate purchased/restored events for
    // the same token. Prevent concurrent processing of the same purchaseToken.
    final dedupKey = '$productId:$purchaseToken';
    if (_pendingVerifications.contains(dedupKey)) {
      if (kDebugMode) {
        debugPrint('[IAP] duplicate_event_skipped productId=$productId '
            'tokenHash=$tokenHashShort (already in-flight)');
      }
      return;
    }
    _pendingVerifications.add(dedupKey);

    try {
      // Always log the client-reported purchase first so admins see the
      // timeline even if a later step throws.
      try {
        await PurchaseOrdersLogger.instance
            .logPurchasedClientReported(purchase);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[IAP_LOG] logPurchasedClientReported error: $e');
        }
      }

      // Fast local idempotency check (SharedPrefs). The Firestore ledger doc is
      // the authoritative idempotency key; this is a cheap early-out that also
      // lets us finish consume/complete for an already-granted purchase so it
      // does not remain stuck in Google Play.
      final alreadyProcessed =
          await CoinsRepo.isPurchaseProcessed(productId, purchaseToken);
      if (alreadyProcessed) {
        if (kDebugMode) {
          debugPrint('[IAP] alreadyGranted=true productId=$productId '
              'tokenHash=$tokenHashShort — finishing consume/complete only');
        }
        try {
          await PurchaseOrdersLogger.instance.logAlreadyProcessed(purchase);
        } catch (_) {}
        await _finishConsumeAndComplete(purchase, isAvatar: isAvatar);
        // Re-assert local entitlement so the shop card hides on cold start.
        if (isAvatar) {
          await PremiumAvatarService.instance
              .markOwnedLocally(CoinsCatalog.avatarIdForProductId(productId));
        }
        _billingFlowActive = false;
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

      // Must be signed in to credit a wallet / write the ledger.
      if (FirebaseAuth.instance.currentUser == null) {
        if (kDebugMode) {
          debugPrint('[IAP] grant_blocked_no_user productId=$productId');
        }
        _coinGrantController.add(PurchaseGrantResult(
          ok: false,
          error: 'Please sign in to receive your purchase.',
          productId: productId,
        ));
        return;
      }

      // Google Play Client Only grant. NO Cloud Functions, NO Google Play
      // Developer API. Grant + consume + complete all happen inside here, in the
      // safety-critical order (grant → consume → complete).
      await _grantViaClientFallback(purchase);
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
    } finally {
      // Always remove the dedup key when done.
      _pendingVerifications.remove(dedupKey);
    }
  }

  /// Finish an already-granted purchase without granting again: consume
  /// consumables (Android) and completePurchase if still pending. Safe to call
  /// for already-processed purchases so they don't stay stuck in Google Play.
  Future<void> _finishConsumeAndComplete(PurchaseDetails purchase,
      {required bool isAvatar}) async {
    // Coins are consumable → consume so the pack can be bought again.
    // Avatars are non-consumable → acknowledge only, never consume.
    if (Platform.isAndroid && !isAvatar) {
      try {
        final androidAddition =
            _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        await androidAddition.consumePurchase(purchase);
        if (kDebugMode) debugPrint('[IAP] consume success (already-granted)');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[IAP] consume failure (already-granted, non-fatal): $e');
        }
      }
    }
    if (purchase.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(purchase);
        if (kDebugMode) {
          debugPrint('[IAP] completePurchase success (already-granted)');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '[IAP] completePurchase failure (already-granted, non-fatal): $e');
        }
      }
    }
  }

  /// Google Play Client Only grant path (no Cloud Functions, no Google Play
  /// Developer API).
  ///
  /// Coins are granted ONLY for a real Google Play purchase object that already
  /// reached this point with [PurchaseStatus.purchased] (validated productId,
  /// non-empty purchaseToken). The grant itself is performed inside a
  /// deterministic, idempotent Firestore transaction (see
  /// [PurchaseOrdersLogger.grantCoinsClientFallback] /
  /// [PurchaseOrdersLogger.unlockAvatarClientFallback]) keyed by the SHA-256 of
  /// the purchaseToken so repeated stream emits / app restarts can never
  /// double-grant, while a NEW purchaseToken (a fresh purchase of the same pack)
  /// always grants again.
  ///
  /// Order of operations is safety-critical:
  ///   1. Grant atomically in Firestore (throws on real failure).
  ///   2. Only AFTER a successful grant, consume (consumables) + complete.
  /// If the grant throws we DO NOT consume/complete — Google Play re-delivers
  /// the purchase and we retry on the next launch.
  ///
  /// SECURITY LIMITATION: Google Play client-only fulfillment. NOT equivalent to
  /// server-side Google Play verification. All records are verified:false /
  /// trustedRevenue:false until backend verification is added.
  Future<void> _grantViaClientFallback(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    final isAvatar = CoinsCatalog.isAvatarProduct(productId);
    final purchaseToken = purchase.verificationData.serverVerificationData;
    final tokenHashShort = _shortTokenHash(purchaseToken);

    if (kDebugMode) {
      debugPrint('[IAP] client_only_grant_start productId=$productId '
          'type=${isAvatar ? 'avatar' : 'coins'} tokenHash=$tokenHashShort');
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
        debugPrint('[IAP] client_only_grant_result productId=$productId '
            'tokenHash=$tokenHashShort '
            'alreadyGranted=${!granted} '
            'coinsGranted=${granted ? coins : 0}');
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
          if (kDebugMode) debugPrint('[IAP] consume success productId=$productId');
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[IAP] consume failure (non-fatal) productId=$productId: $e');
          }
        }
      }

      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
          if (kDebugMode) {
            debugPrint('[IAP] completePurchase success productId=$productId');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[IAP] completePurchase failure (non-fatal) productId=$productId: $e');
          }
        }
      }

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
