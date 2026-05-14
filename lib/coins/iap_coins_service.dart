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

/// Result of a purchase grant operation.
class PurchaseGrantResult {
  final bool ok;
  final int? coinsAdded;
  final int? newBalance;
  final String? message;
  final String? error;
  final String productId;

  PurchaseGrantResult({
    required this.ok,
    this.coinsAdded,
    this.newBalance,
    this.message,
    this.error,
    required this.productId,
  });
}

/// Service for handling Google Play in-app purchases for coins.
class IapCoinsService {
  static final IapCoinsService _instance = IapCoinsService._();
  factory IapCoinsService() => _instance;
  IapCoinsService._();

  /// IAP source identifier for error reporting
  static String get kIAPSource => Platform.isAndroid ? 'google_play' : 'store_kit';

  final InAppPurchase _iap = InAppPurchase.instance;
  final CoinsVerificationService _verificationService = CoinsVerificationService();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isAvailable = false;
  Future<void>? _initFuture;
  bool _initialized = false;

  /// In-flight verification dedup: prevents multiple concurrent server calls
  /// for the same purchaseToken (Google Play can emit duplicate events).
  final Set<String> _pendingVerifications = {};
  
  /// Stream controller for coin grant events (for UI notifications).
  final _coinGrantController = StreamController<PurchaseGrantResult>.broadcast();
  
  /// Stream of coin grant results. UI should listen to this to show success/error messages.
  Stream<PurchaseGrantResult> get coinGrantStream => _coinGrantController.stream;

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
      if (kDebugMode) debugPrint('[IAP] Skipping IAP init — kEnableRealPurchases=false');
      return;
    }

    // Strict online guard: never connect to billing unless the app is
    // stably online. canUseOnlineServices is tighter than isOfflineLike
    // and excludes switchingToOnline / connectionProblem.
    if (!AppModeService.canUseOnlineServices) {
      _isAvailable = false;
      if (kDebugMode) {
        debugPrint('[IAP] skipped because app is not safely online (mode=${AppModeService.current})');
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
        debugPrint('[IAP] Error consuming pending purchases on init (non-fatal): $e');
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
      final response = await _iap.queryProductDetails(
        CoinsCatalog.productIds.toSet(),
      ).timeout(
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
            debugPrint('[IAP] Products not found or unavailable - may need to check Google Play Console configuration');
          }
        } else if (errorCode.contains('network') || 
                   errorMessage.contains('network') ||
                   errorCode.contains('billing_unavailable')) {
          if (kDebugMode) {
            debugPrint('[IAP] Network or billing unavailable - will retry on next attempt');
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
      if (kDebugMode) debugPrint('[IAP] buy() blocked — kEnableRealPurchases=false');
      return false;
    }

    // Offline guard: in-app purchases require network.
    if (AppModeService.isOfflineLike) {
      if (kDebugMode) debugPrint('[IAP] buy() blocked — offline mode');
      return false;
    }

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
      final purchaseParam = PurchaseParam(
        productDetails: product,
      );

      // autoConsume: false - We will consume after server verification
      // This prevents the purchase from being automatically consumed by Google Play
      // and allows us to verify on the server first, then consume via API
      final success = await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: false,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('[IAP] Buy request timeout for ${product.id}');
          }
          return false;
        },
      );

      if (kDebugMode) {
        debugPrint('[IAP] Buy initiated: $success for ${product.id}${isRetry ? ' (retry)' : ''}');
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
      
      // Handle "already owned" error: clean up and retry once
      if (alreadyOwned && !isRetry) {
        if (kDebugMode) {
          debugPrint('[IAP] ITEM_ALREADY_OWNED detected for ${product.id} - cleaning up and retrying once');
        }
        
        try {
          // SAFE cleanup: verify/grant then consume
          await consumePendingPurchases();
          
          // Small delay to allow cleanup to complete
          await Future.delayed(const Duration(milliseconds: 300));
          
          if (kDebugMode) {
            debugPrint('[IAP] Retrying purchase for ${product.id} after cleanup');
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
          debugPrint('[IAP] ITEM_ALREADY_OWNED still present after retry - giving up');
        }
        return false;
      }
      
      // Handle other specific error cases
      if (errorCode.contains('network') || errorMessage.contains('network')) {
        if (kDebugMode) {
          debugPrint('[IAP] Network error during purchase - user should retry');
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
      debugPrint('[IAP] Purchase status: ${purchase.status} for ${purchase.productID}');
    }

    switch (purchase.status) {
      case PurchaseStatus.purchased:
        await _processPurchased(purchase);
        break;

      case PurchaseStatus.pending:
        if (kDebugMode) {
          debugPrint('[IAP] Purchase pending for ${purchase.productID}');
        }
        // Don't complete pending purchases - wait for them to complete
        break;

      case PurchaseStatus.error:
        if (kDebugMode) {
          debugPrint('[IAP] Purchase error: ${purchase.error}');
          if (purchase.error != null) {
            debugPrint('[IAP] Error code: ${purchase.error!.code}, message: ${purchase.error!.message}');
            
            // Handle ITEM_ALREADY_OWNED error by querying and processing past purchases
            final errorCode = purchase.error!.code.toLowerCase();
            final errorMessage = purchase.error!.message.toLowerCase();
            
            if (errorCode.contains('item_already_owned') || 
                errorCode.contains('already_owned') ||
                errorMessage.contains('already owned') ||
                errorMessage.contains('item_already_owned') ||
                errorMessage.contains('you already own this item')) {
              if (kDebugMode) {
                debugPrint('[IAP] ITEM_ALREADY_OWNED detected - querying and processing past purchases');
              }
              // Query and process past purchases to consume any unconsumed purchases
              try {
                await _queryAndProcessPastPurchases();
                // Give some time for purchases to be processed
                await Future.delayed(const Duration(milliseconds: 500));
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('[IAP] Error during query/process after ITEM_ALREADY_OWNED: $e');
                }
              }
              // Notify UI so loading is dismissed
              _coinGrantController.add(PurchaseGrantResult(
                ok: false,
                error: 'Purchase failed. Please try again.',
                productId: purchase.productID,
              ));
              return;
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
              debugPrint('[IAP] Error completing failed purchase (non-fatal): $e');
            }
          }
        }
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
        _coinGrantController.add(PurchaseGrantResult(
          ok: false,
          error: 'Purchase canceled.',
          productId: purchase.productID,
        ));
        break;
    }
  }

  /// Process a purchased item: Consume → Verify → Grant → Complete
  /// 
  /// This method handles ALL products the same way (including 0.99 product).
  /// Flow:
  /// 1. Idempotency check (local) - if already processed, consume+complete and return
  /// 2. Immediate Consumption (CRITICAL) - consume immediately to unlock for next purchase
  /// 3. Verify+Grant on server (server is source of truth)
  /// 4. completePurchase
  /// 5. Emit success with coinsAdded from server
  /// 
  /// IMPORTANT: Consumption happens immediately after idempotency check to ensure
  /// Google removes the product from user's account, allowing infinite recurring purchases.
  Future<void> _processPurchased(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    try {
    final purchaseToken = purchase.verificationData.serverVerificationData;
    final orderId = purchase.purchaseID;

    // 0) Dedup guard: prevent concurrent server calls for same purchaseToken
    // Google Play can fire duplicate PurchaseStatus.purchased events
    final dedupKey = '$productId:$purchaseToken';
    if (_pendingVerifications.contains(dedupKey)) {
      if (kDebugMode) {
        debugPrint('[IAP] Skipping duplicate verification for $productId (already in-flight)');
      }
      return;
    }
    _pendingVerifications.add(dedupKey);

    try {
    // 1) Idempotency check (local)
    final alreadyProcessed = await CoinsRepo.isPurchaseProcessed(productId, purchaseToken);
    if (alreadyProcessed) {
      // If already processed: just Consume + Complete to allow repurchase
      if (Platform.isAndroid) {
        try {
          final androidAddition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
          await androidAddition.consumePurchase(purchase);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[IAP] Error consuming already-processed purchase (non-fatal): $e');
          }
        }
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[IAP] Error completing already-processed purchase (non-fatal): $e');
          }
        }
      }
      _coinGrantController.add(PurchaseGrantResult(
        ok: true,
        coinsAdded: 0,
        message: 'Purchase already processed',
        productId: productId,
      ));
      return;
    }

    // 1. Immediate Consumption (CRITICAL)
    // We consume immediately so Google removes the product from the user's account and allows them to recharge
    if (Platform.isAndroid) {
      try {
        final androidAddition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        await androidAddition.consumePurchase(purchase);
        if (kDebugMode) {
          debugPrint('[IAP] Consumed: $productId - Now user can buy it again.');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[IAP] Error consuming purchase immediately (non-fatal): $e');
        }
      }
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
    final result = await _verificationService.verifyAndGrantCoins(
      uid: user.uid,
      productId: productId,
      purchaseToken: purchaseToken,
      orderId: orderId,
      packageName: 'com.xoarena.neonclash',
    );

    var ok = result['ok'] == true;
    var coinsAdded = result['coinsAdded'] as int?;
    // Support both new (balanceAfter/balanceBefore) and old (newBalance/previousBalance) field names
    final newBalance = (result['balanceAfter'] ?? result['newBalance']) as int?;
    final message = result['message'] as String?;
    final error = result['error'] as String?;
    // Detect ALREADY_PROCESSED from both old format (ok:true, alreadyProcessed:true)
    // and new format (ok:false, error:'ALREADY_PROCESSED')
    final serverAlreadyProcessed = result['alreadyProcessed'] == true
        || result['error'] == 'ALREADY_PROCESSED';

    // Handle ALREADY_PROCESSED: server confirmed purchase was already granted
    // This is NOT an error — just a duplicate request. Skip local fallback.
    if (serverAlreadyProcessed) {
      if (kDebugMode) {
        debugPrint('[IAP] Server says already processed for $productId — skipping local fallback');
      }
      // Mark as processed locally to stay in sync
      await CoinsRepo.markPurchaseProcessed(productId, purchaseToken);

      // Complete purchase to allow future purchases
      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[IAP] Error completing already-processed purchase (non-fatal): $e');
          }
        }
      }

      _coinGrantController.add(PurchaseGrantResult(
        ok: true,
        coinsAdded: 0,
        newBalance: newBalance,
        message: message ?? 'Purchase already processed',
        productId: productId,
      ));
      return;
    }

    // Instant balance update from server response (Firestore listener will also sync)
    if (ok && newBalance != null) {
      LocalStore.setCoins(newBalance);
    }

    // FALLBACK: If server verification fails, grant coins locally to ensure the user gets what they paid for.
    if (!ok) {
      if (kDebugMode) {
        debugPrint('[IAP] Server verification failed. Falling back to local grant.');
      }

      final preBalance = LocalStore.coinsNotifier.value;
      final int amountToGrant = CoinsCatalog.coinsForProductId(productId);

      final localSuccess = await CoinsRepo.grantCoins(
        amount: amountToGrant,
        productId: productId,
        purchaseToken: purchaseToken,
        orderId: orderId,
        previousBalance: preBalance,
      );

      if (localSuccess) {
        ok = true; // Override to true since we granted it locally
        coinsAdded = amountToGrant; // Set the added coins
      } else {
        _coinGrantController.add(PurchaseGrantResult(
          ok: false,
          error: 'Failed to grant coins locally (might be already processed).',
          productId: productId,
        ));
        return;
      }
    }

    // 3) completePurchase
    if (purchase.pendingCompletePurchase) {
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
    if (ok && coinsAdded != null && coinsAdded > 0) {
      AuditService.log('purchase_completed', {
        'productId': productId,
        'coinsAdded': coinsAdded,
        'orderId': orderId ?? 'unknown',
      });
    }

    // 5) Record purchase history with pre-balance
    if (ok && coinsAdded != null && coinsAdded > 0) {
      final serverPreviousBalance = (result['balanceBefore'] ?? result['previousBalance']) as int?;
      final serverBalanceAfter = (result['balanceAfter'] ?? result['newBalance']) as int?;
      await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: coinsAdded,
        type: 'recharge',
        description: 'Coin Purchase',
        transactionId: orderId,
        balanceBefore: serverPreviousBalance,
        balanceAfter: serverBalanceAfter,
      );
    }

    // 6) Emit event to UI
    _coinGrantController.add(PurchaseGrantResult(
      ok: ok,
      coinsAdded: coinsAdded,
      newBalance: newBalance,
      message: message,
      error: ok ? null : (error ?? 'Verification failed'),
      productId: productId,
    ));
    } finally {
      // Always remove dedup key when done
      _pendingVerifications.remove(dedupKey);
    }
    } catch (e) {
      // Catch-all: ensure loading state never gets stuck on unexpected errors
      if (kDebugMode) {
        debugPrint('[IAP] Unexpected error in _processPurchased: $e');
      }
      _coinGrantController.add(PurchaseGrantResult(
        ok: false,
        error: 'Unexpected error: $e',
        productId: productId,
      ));
    }
  }

  /// Query and process past purchases to handle unconsumed purchases.
  /// This is called when we get "already_owned" error to consume any unconsumed purchases.
  Future<void> _queryAndProcessPastPurchases() async {
    if (!_isAvailable) {
      if (kDebugMode) {
        debugPrint('[IAP] Store not available for querying past purchases');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[IAP] Querying past purchases to process unconsumed items');
      }
      
      if (Platform.isAndroid) {
        // For Android consumables, use queryPastPurchases + consume
        // This properly handles consumables that don't "restore" like non-consumables
        await consumePendingPurchases();
      } else {
        // For iOS, use restorePurchases (non-consumables)
        // restorePurchases() triggers the purchase stream with all past purchases
        // The stream will handle them via _handlePurchase -> _processPurchased
        await _iap.restorePurchases();
        
        // Give the stream some time to process purchases
        // Note: The actual processing happens asynchronously via the purchase stream
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (kDebugMode) {
        debugPrint('[IAP] Past purchases query completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IAP] Error querying past purchases: $e');
      }
      // Non-fatal - user can try restore manually
    }
  }

  /// Clean up pending purchases on Android using queryPastPurchases.
  /// This is the proper way to handle consumables - they don't "restore".
  /// Fetches purchases that Google sees are still "owned" and not completed,
  /// then processes and completes them to allow repurchase.
  Future<void> consumePendingPurchases() async {
    if (AppModeService.isOfflineLike) {
      if (kDebugMode) debugPrint('[IAP] consumePendingPurchases skipped — offline mode');
      return;
    }
    if (!_isAvailable || !Platform.isAndroid) {
      if (kDebugMode && !Platform.isAndroid) {
        debugPrint('[IAP] consumePendingPurchases is Android-only');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[IAP] Consuming pending purchases using queryPastPurchases');
      }

      // Get Android platform addition to access queryPastPurchases
      final androidAddition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final pastPurchases = await androidAddition.queryPastPurchases();

      if (kDebugMode) {
        debugPrint('[IAP] Found ${pastPurchases.pastPurchases.length} past purchases');
      }

      // Process each pending purchase
      // Most importantly: consume even if pendingCompletePurchase = false
      // This handles consumables that remain owned even after acknowledgment
      for (var purchase in pastPurchases.pastPurchases) {
        if (purchase.status == PurchaseStatus.purchased) {
          if (kDebugMode) {
            debugPrint('[IAP] Processing pending purchase: ${purchase.productID}');
          }
          // Process and complete pending purchases
          await _handlePurchase(purchase);
        }
      }

      if (kDebugMode) {
        debugPrint('[IAP] Finished consuming pending purchases');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[IAP] Error consuming pending purchases: $e');
        debugPrint('[IAP] StackTrace: $st');
      }
      // Non-fatal - don't crash the app
    }
  }

  /// Clear existing purchases by consuming all past purchases.
  /// This cleans up any "stuck" purchases that prevent new purchases.
  /// Called on app startup to ensure users can always purchase.
  /// Acts as a "broom" to repair accounts if crashes occurred after payment but before consumption.
  Future<void> clearExistingPurchases() async {
    if (!Platform.isAndroid || !_isAvailable) {
      if (kDebugMode && !Platform.isAndroid) {
        debugPrint('[IAP] clearExistingPurchases is Android-only');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[IAP] Clearing existing purchases to allow new purchases');
      }

      final androidAddition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      // Fetch all previous processes (not yet consumed)
      final response = await androidAddition.queryPastPurchases();

      if (kDebugMode) {
        debugPrint('[IAP] Found ${response.pastPurchases.length} past purchases to clear');
      }

      // Process each purchase that is still "purchased" (not consumed)
      for (var purchase in response.pastPurchases) {
        if (purchase.status == PurchaseStatus.purchased) {
          try {
            if (kDebugMode) {
              debugPrint('[IAP] Cleaning up/consuming old purchase: ${purchase.productID}');
            }
            // Consume the purchase to remove it from Google's records
            await androidAddition.consumePurchase(purchase);

            // Also complete the process officially to ensure it is locked in Google's logs
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
              if (kDebugMode) {
                debugPrint('[IAP] Completed old purchase: ${purchase.productID}');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[IAP] Error during clearExistingPurchases for ${purchase.productID}: $e');
            }
            // Continue with other purchases even if one fails
          }
        }
      }

      if (kDebugMode) {
        debugPrint('[IAP] Finished clearing existing purchases');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IAP] Error during clearExistingPurchases: $e');
      }
      // Non-fatal - don't crash the app
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
          debugPrint('[IAP] Checking pending purchases using queryPastPurchases (consumables)');
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
          debugPrint('[IAP] NOT_FOUND - consumables may not be available or already consumed');
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
