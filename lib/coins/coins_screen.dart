import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/coin_format.dart';
import '../core/app_theme.dart';
import '../core/responsive_metrics.dart';
import '../screens/coins_history_page.dart';
import '../utils/navigation_utils.dart' show showSignInRequiredDialog;
import '../services/local_store.dart';
import '../services/connectivity_service.dart';
import '../widgets/app_ui.dart';
import 'coins_catalog.dart';
import 'coins_controller.dart';
import 'iap_coins_service.dart';

/// Coins purchase screen with Google Play Billing integration.
class CoinsScreen extends StatefulWidget {
  const CoinsScreen({super.key});

  @override
  State<CoinsScreen> createState() => _CoinsScreenState();
}

class _CoinsScreenState extends State<CoinsScreen> {
  late final CoinsController _controller;
  final IapCoinsService _iapService = IapCoinsService();
  int _coins = 0;
  StreamSubscription<PurchaseGrantResult>? _coinGrantSubscription;
  String? _pendingPurchaseProductId;
  bool _isLoadingPurchase = false;
  Timer? _loadingTimeout;
  bool _isDisposed = false;
  // Cached product presentations to avoid rebuilding price strings per frame
  final Map<String, _CoinPackPresentation> _presentationCache = {};

  @override
  void initState() {
    super.initState();
    try {
      _controller = CoinsController();
      _controller.addListener(_onControllerChanged);
      _coins = LocalStore.coinsNotifier.value;
      LocalStore.coinsNotifier.addListener(_onCoinsChanged);
      _setupPurchaseListener();
      
      // Defer heavy IAP work to after first render for faster screen appearance
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performDeferredInit();
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CoinsScreen] Init exception: $e');
        debugPrint('[CoinsScreen] StackTrace: $st');
      }
      // Don't crash - show error message instead if needed
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      _loadingTimeout?.cancel();
      LocalStore.coinsNotifier.removeListener(_onCoinsChanged);
      _coinGrantSubscription?.cancel();
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CoinsScreen] Dispose error: $e');
        debugPrint('[CoinsScreen] StackTrace: $st');
      }
      // Continue with disposal even if there's an error
    } finally {
      super.dispose();
    }
  }

  void _onCoinsChanged() {
    if (mounted) {
      setState(() => _coins = LocalStore.coinsNotifier.value);
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        _rebuildPresentationCache();
      });
    }
  }

  void _rebuildPresentationCache() {
    _presentationCache.clear();
    for (final product in _controller.products) {
      final coinAmount = CoinsCatalog.coinsForProductId(product.id);
      _presentationCache[product.id] =
          _presentationForProduct(product, coinAmount);
    }
  }

  Future<void> _performDeferredInit() async {
    if (!mounted || _isDisposed) return;
    try {
      if (!mounted || _isDisposed) return;
      await _controller.init();
      if (mounted && !_isDisposed) setState(() {});
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CoinsScreen] Controller init error: $e');
        debugPrint('[CoinsScreen] StackTrace: $st');
      }
      // Don't crash - continue with cached data
    }
  }

  /// Listen to coin grant stream to show success/error messages after verification
  void _setupPurchaseListener() {
    // Listen to coin grant stream (only shows success after actual verification)
    _coinGrantSubscription = _iapService.coinGrantStream.listen(
      (result) {
        if (result.ok && result.coinsAdded != null && result.coinsAdded! > 0) {
          _handlePurchaseSuccess(result.productId, result.coinsAdded!);
        } else if (result.ok && (result.coinsAdded == null || result.coinsAdded == 0)) {
          // Already processed — dismiss loading, show subtle info (not error)
          _hideLoadingDialog();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppPalette.primary, width: 1.5),
                ),
                backgroundColor: AppPalette.surface2,
                content: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        result.message ?? 'Purchase was already processed.',
                        style: safeInter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          _handlePurchaseFailure(result);
        }
      },
      onError: (error) {
        _hideLoadingDialog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppPalette.danger, width: 1.5),
              ),
              backgroundColor: AppPalette.surface2,
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Purchase failed or canceled.',
                      style: safeInter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }

  /// Handle successful purchase (only called after verification succeeds)
  void _handlePurchaseSuccess(String productId, int coins) async {
    // Close loading dialog first
    _hideLoadingDialog();
    
    // Use coinsNotifier directly — already updated by instant setCoins + Firestore listener
    final newBalance = LocalStore.coinsNotifier.value;
    
    if (mounted) {
      // Show beautiful success dialog
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AppGlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 64, color: AppPalette.success),
                  const SizedBox(height: 16),
                  Text(
                    "Success! Coins added to your wallet.",
                    style: safeOrbitron(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "$coins coins have been added to your account",
                    textAlign: TextAlign.center,
                    style: bodyFont(context).copyWith(height: 1.4, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppPalette.success.withOpacity(0.15),
                      border: Border.all(color: AppPalette.success.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "New balance: $newBalance coins",
                          style: safeOrbitron(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppPillButton(
                    label: "OK",
                    fill: AppPalette.success.withOpacity(0.9),
                    onPressed: () => Navigator.pop(context),
                    icon: Icons.check,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      // Auto-dismiss after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  /// Handle failed purchase verification (or already processed with 0 coins)
  void _handlePurchaseFailure(PurchaseGrantResult result) {
    _hideLoadingDialog();
    if (!result.ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppPalette.danger, width: 1.5),
          ),
          backgroundColor: AppPalette.surface2,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.error ?? 'Purchase failed.',
                  style: safeInter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadCoins() async {
    final coins = await LocalStore.coins();
    if (mounted) {
      setState(() {
        _coins = coins;
      });
    }
  }

  Future<void> _refreshCoins() async {
    await _loadCoins();
  }

  Future<void> _checkPendingPurchases() async {
    try {
      await _controller.restorePurchases();
      await _refreshCoins();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppPalette.success, width: 1.5),
          ),
          backgroundColor: AppPalette.surface2,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pending purchases checked. Check your balance.',
                  style: safeInter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppPalette.danger, width: 1.5),
          ),
          backgroundColor: AppPalette.surface2,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Check failed: ${e.toString().replaceAll('Exception: ', '')}',
                  style: safeInter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _buyPack(ProductDetails product, int coinAmount) async {
    if (FirebaseAuth.instance.currentUser == null) {
      showSignInRequiredDialog(context);
      return;
    }

    final isOnline = await ConnectivityService().online;
    if (!isOnline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppPalette.danger, width: 1.5),
          ),
          backgroundColor: AppPalette.surface2,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You need an internet connection to purchase coins',
                  style: safeInter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _pendingPurchaseProductId = product.id;
    });

    _showLoadingDialog();
    try {
      final success = await _controller.buyPack(product.id);
      if (!mounted) return;
      if (!success && _controller.errorMessage != null) {
        _hideLoadingDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppPalette.danger, width: 1.5),
            ),
            backgroundColor: AppPalette.surface2,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _controller.errorMessage!,
                    style: safeInter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingPurchaseProductId = null;
        });
      }
    }
  }

  /// Show loading dialog when purchase is processing
  void _showLoadingDialog() {
    if (_isLoadingPurchase) return; // Already showing

    _isLoadingPurchase = true;

    // Safety timeout: dismiss loading dialog after 60 seconds to prevent stuck UI
    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(const Duration(seconds: 10), () {
      if (_isLoadingPurchase && mounted) {
        _hideLoadingDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppPalette.warning, width: 1.5),
            ),
            backgroundColor: AppPalette.surface2,
            content: Row(
              children: [
                const Icon(Icons.timer_off, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Purchase timed out. Check your balance or try again.',
                    style: safeInter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppPalette.primary),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  "Processing purchase...",
                  style: titleFont(context).copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Please wait",
                  style: bodyFont(context).copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hide loading dialog and re-enable purchase buttons
  void _hideLoadingDialog() {
    _loadingTimeout?.cancel();
    if (_isLoadingPurchase && mounted) {
      _isLoadingPurchase = false;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      setState(() {});
    }
  }

  double? _parseDisplayedPriceValue(String rawPrice) {
    final cleaned = rawPrice.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (cleaned.isEmpty) return null;

    var normalized = cleaned;
    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');

    if (lastComma != -1 && lastDot != -1) {
      if (lastComma > lastDot) {
        normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = cleaned.replaceAll(',', '');
      }
    } else if (lastComma != -1) {
      normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else {
      final parts = cleaned.split('.');
      if (parts.length > 2) {
        normalized = '${parts.sublist(0, parts.length - 1).join()}.${parts.last}';
      }
    }

    return double.tryParse(normalized);
  }

  bool _matchesPrice(double? value, double target) {
    if (value == null) return false;
    return (value - target).abs() < 0.06;
  }

  _CoinPackPresentation _presentationForProduct(ProductDetails product, int coinAmount) {
    final priceValue = _parseDisplayedPriceValue(product.price);
    String assetPath;
    String? badge;

    if (_matchesPrice(priceValue, 0.99) || _matchesPrice(priceValue, 1.99)) {
      assetPath = 'assets/coin/COIN---2.png';
    } else if (_matchesPrice(priceValue, 2.99) || _matchesPrice(priceValue, 3.99)) {
      assetPath = 'assets/coin/COIN--3.png';
    } else if (_matchesPrice(priceValue, 4.99)) {
      assetPath = 'assets/coin/COIN--9.png';
      badge = 'POPULAR';
    } else if (_matchesPrice(priceValue, 9.99) || _matchesPrice(priceValue, 14.99)) {
      assetPath = 'assets/coin/COIN-44.png';
    } else if (_matchesPrice(priceValue, 24.99) || _matchesPrice(priceValue, 49.99)) {
      assetPath = 'assets/coin/COIN--55.png';
      if (_matchesPrice(priceValue, 24.99)) {
        badge = 'BEST VALUE';
      }
    } else if (coinAmount <= 400) {
      assetPath = 'assets/coin/COIN---2.png';
    } else if (coinAmount <= 800) {
      assetPath = 'assets/coin/COIN--3.png';
    } else if (coinAmount <= 1000) {
      assetPath = 'assets/coin/COIN--9.png';
    } else if (coinAmount <= 3000) {
      assetPath = 'assets/coin/COIN-44.png';
    } else {
      assetPath = 'assets/coin/COIN--55.png';
    }

    final featured = badge != null;
    final accent = badge == 'BEST VALUE'
        ? AppPalette.gold
        : badge == 'POPULAR'
            ? AppPalette.goldDeep
            : AppPalette.primary;
    final secondary = badge == 'POPULAR'
        ? AppPalette.accentPurple
        : badge == 'BEST VALUE'
            ? AppPalette.goldHighlight
            : AppPalette.homeBlue;
    final subtitle = badge == 'BEST VALUE'
        ? 'Extended arena value pack'
        : badge == 'POPULAR'
            ? 'Most-picked balance refill'
            : 'Fast top-up for your wallet';

    return _CoinPackPresentation(
      assetPath: assetPath,
      badge: badge,
      subtitle: subtitle,
      accent: accent,
      secondaryAccent: secondary,
      featured: featured,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Block IAP when offline
    if (!ConnectivityService().isOnline.value) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No internet connection.\nConnect to the internet to purchase coins.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: AppIconButton(
              icon: Icons.folder_outlined,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CoinsHistoryPage(),
                  ),
                );
                await _refreshCoins();
              },
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: Text(
                'Buy Coins',
                style: safeOrbitron(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppPalette.homeTitle,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.panelSoft.withOpacity(0.8),
                  AppPalette.panelSoft.withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppPalette.homeStroke.withOpacity(0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.homeStroke.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Image.asset(
                  'assets/coin/COIN-SHOP.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        formatCoins(_coins, compact: false),
                        style: safeOrbitron(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppPalette.homeTitle,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_controller.loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (!_controller.storeAvailable || _controller.products.isEmpty)
            _buildStoreUnavailableBanner()
          else
            ...[
              if (FirebaseAuth.instance.currentUser == null) _buildGuestPurchaseBanner(),
              _buildCoinPackGrid(),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: _controller.restoring ? null : _checkPendingPurchases,
                  child: Text(
                    _controller.restoring ? 'Checking...' : 'Check pending purchases',
                    style: safeInter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textSubtle,
                    ),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildGuestPurchaseBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderColor: AppPalette.gold.withOpacity(0.24),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppPalette.warning, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Register a verified arena account to purchase coin packs.',
                style: bodyFont(context).copyWith(color: AppPalette.warning, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreUnavailableBanner() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AppGlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: AppPalette.warning.withOpacity(0.24),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppPalette.warning, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _controller.errorMessage ??
                    "Coins store not configured yet. Please try again later.",
                style: bodyFont(context).copyWith(color: AppPalette.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinPackGrid() {
    // Sort products by coin amount (ascending)
    final sortedProducts = List.from(_controller.products)
      ..sort((a, b) {
        final coinsA = CoinsCatalog.coinsForProductId(a.id);
        final coinsB = CoinsCatalog.coinsForProductId(b.id);
        return coinsA.compareTo(coinsB);
      });

    final isGuest = FirebaseAuth.instance.currentUser == null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics =
            UiMetrics.of(constraints, MediaQuery.orientationOf(context));
        final width = constraints.maxWidth;
        final crossAxisCount = metrics.coinsColumns(width);
        final spacing = metrics.cardGap;
        final childAspectRatio = metrics.coinsCardAspectRatio;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: sortedProducts.length,
          itemBuilder: (context, i) {
            final product = sortedProducts[i];
            final coinAmount = CoinsCatalog.coinsForProductId(product.id);
            final isPending = _pendingPurchaseProductId == product.id;
            final isDisabled = isGuest ||
                _controller.purchasing ||
                !_controller.storeAvailable ||
                _isLoadingPurchase ||
                isPending;
            final presentation = _presentationCache[product.id] ??
                _presentationForProduct(product, coinAmount);

            return AppGlassCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          radius: metrics.cardRadius,
          backgroundColor: Color.lerp(
            AppPalette.panel,
            presentation.accent,
            presentation.featured ? 0.14 : 0.07,
          ),
          borderColor: presentation.accent.withOpacity(presentation.featured ? 0.44 : 0.24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: presentation.accent.withOpacity(presentation.featured ? 0.18 : 0.08),
              blurRadius: 22,
              spreadRadius: -8,
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: presentation.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: presentation.accent.withOpacity(0.24)),
                    ),
                    child: Text(
                      presentation.badge ?? 'COIN PACK',
                      style: homeLabelFont(
                        context,
                        fontSize: 8,
                        color: presentation.accent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.north_east_rounded,
                    size: 16,
                    color: presentation.secondaryAccent.withOpacity(0.88),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Image.asset(
                    presentation.assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                formatCoins(coinAmount, compact: true),
                textAlign: TextAlign.center,
                style: statNumberFont(
                  context,
                  fontSize: 24,
                  color: presentation.featured ? AppPalette.goldHighlight : Colors.white,
                ),
              ),
              Text(
                'XO COINS',
                textAlign: TextAlign.center,
                style: homeLabelFont(
                  context,
                  fontSize: 8.5,
                  color: presentation.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.price,
                textAlign: TextAlign.center,
                style: safeOrbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: presentation.featured ? AppPalette.goldHighlight : AppPalette.text,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                presentation.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: bodyFont(context).copyWith(
                  fontSize: 11,
                  color: AppPalette.textSubtle,
                ),
              ),
              const SizedBox(height: 12),
              AppPillButton(
                label: isPending ? 'PROCESSING' : 'BUY NOW',
                onPressed: isDisabled ? null : () => _buyPack(product, coinAmount),
                fill: presentation.featured ? AppPalette.goldDeep : AppPalette.primary2,
                stroke: presentation.featured
                    ? AppPalette.goldHighlight.withOpacity(0.55)
                    : AppPalette.primary.withOpacity(0.45),
                minHeight: 42,
                icon: presentation.featured
                    ? Icons.workspace_premium_outlined
                    : Icons.shopping_bag_outlined,
              ),
            ],
          ),
            );
          },
        );
      },
    );
  }
}

class _CoinPackPresentation {
  final String assetPath;
  final String? badge;
  final String subtitle;
  final Color accent;
  final Color secondaryAccent;
  final bool featured;

  const _CoinPackPresentation({
    required this.assetPath,
    required this.badge,
    required this.subtitle,
    required this.accent,
    required this.secondaryAccent,
    required this.featured,
  });
}
