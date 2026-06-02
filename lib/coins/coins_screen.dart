import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/coin_format.dart';
import '../core/app_theme.dart';
import '../core/responsive_metrics.dart';
import '../models/game_avatar.dart';
import '../screens/coins_history_page.dart';
import '../services/local_store.dart';
import '../services/connectivity_service.dart';
import '../utils/navigation_utils.dart' show showSignInRequiredDialog;
import '../widgets/app_ui.dart';
import '../widgets/full_avatar_display.dart';
import 'coins_catalog.dart';
import 'coins_controller.dart';
import 'iap_coins_service.dart';
import 'premium_avatar_service.dart';

/// Coins purchase screen with Google Play Billing integration.
///
/// Layout:
///   • Sticky balance header — never scrolls away, COIN-SHOP.png + plain
///     numeric balance + tap-to-open transaction history.
///   • Featured premium avatar carousel — rotates between the two one-time
///     avatar offers every ~2s with a smooth slide transition. Each slide
///     is fully tappable and shows the user's profile inside the frame.
///   • Coin grid — 10 packs, sorted ascending, gold accents on $2.99 / $4.99,
///     larger coin art, whole card tappable to purchase.
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

  @override
  void initState() {
    super.initState();
    try {
      _controller = CoinsController();
      _controller.addListener(_onControllerChanged);
      _coins = LocalStore.coinsNotifier.value;
      LocalStore.coinsNotifier.addListener(_onCoinsChanged);
      PremiumAvatarService.instance.owned.addListener(_onAvatarChanged);
      PremiumAvatarService.instance.ownedApex.addListener(_onAvatarChanged);
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
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      _loadingTimeout?.cancel();
      LocalStore.coinsNotifier.removeListener(_onCoinsChanged);
      PremiumAvatarService.instance.owned.removeListener(_onAvatarChanged);
      PremiumAvatarService.instance.ownedApex.removeListener(_onAvatarChanged);
      _coinGrantSubscription?.cancel();
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CoinsScreen] Dispose error: $e');
        debugPrint('[CoinsScreen] StackTrace: $st');
      }
    } finally {
      super.dispose();
    }
  }

  void _onCoinsChanged() {
    if (mounted) {
      setState(() => _coins = LocalStore.coinsNotifier.value);
    }
  }

  void _onAvatarChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _performDeferredInit() async {
    if (!mounted || _isDisposed) return;
    try {
      await PremiumAvatarService.instance.bind();
      if (!mounted || _isDisposed) return;
      await _controller.init();
      if (mounted && !_isDisposed) setState(() {});
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CoinsScreen] Controller init error: $e');
        debugPrint('[CoinsScreen] StackTrace: $st');
      }
    }
  }

  // ── Purchase lifecycle ────────────────────────────────────────────────

  void _setupPurchaseListener() {
    _coinGrantSubscription = _iapService.coinGrantStream.listen(
      (result) {
        if (result.pending) {
          _hideLoadingDialog();
          if (mounted) {
            _showFloatingMessage(
              result.message ??
                  'Purchase pending. We will update it when Google Play confirms it.',
              icon: Icons.hourglass_top_rounded,
              color: AppPalette.primary,
            );
          }
          return;
        }
        if (!result.ok) {
          _handlePurchaseFailure(result);
          return;
        }
        if (result.productType == PurchaseProductType.avatar) {
          _handleAvatarPurchaseSuccess(result);
        } else if (result.coinsAdded != null && result.coinsAdded! > 0) {
          _handlePurchaseSuccess(result.productId, result.coinsAdded!);
        } else {
          _hideLoadingDialog();
          if (mounted) {
            _showFloatingMessage(
              result.message ?? 'Purchase was already processed.',
              icon: Icons.info_outline,
              color: AppPalette.primary,
            );
          }
        }
      },
      onError: (error) {
        _hideLoadingDialog();
        if (mounted) {
          _showFloatingMessage(
            'Purchase failed or canceled.',
            icon: Icons.error_outline,
            color: AppPalette.danger,
          );
        }
      },
    );
  }

  void _showFloatingMessage(String text,
      {required IconData icon, required Color color, int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color, width: 1.5),
        ),
        backgroundColor: AppPalette.surface2,
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: safeInter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: seconds),
      ),
    );
  }

  /// Fast success toast shown right after coin purchase completes. Disappears
  /// in ~1s so the user is not blocked. Uses the app's branded top
  /// notification widget (matches the rest of the store/wallet flows).
  void _showCoinSuccessToast(int coinsAdded) {
    if (!mounted) return;
    showTopNotification(
      context,
      '+${formatCoins(coinsAdded, compact: false)} XO Coins added',
      color: AppPalette.success,
      duration: const Duration(milliseconds: 1200),
    );
  }

  void _handlePurchaseSuccess(String productId, int coins) {
    _hideLoadingDialog();
    if (!mounted) return;
    _showCoinSuccessToast(coins);
  }

  void _handleAvatarPurchaseSuccess(PurchaseGrantResult result) {
    _hideLoadingDialog();
    if (!mounted) return;
    // Resolve which avatar was purchased so the dialog can show the right
    // animated preview and enable the Equip CTA after purchase.
    final avatarId = CoinsCatalog.avatarIdForProductId(result.productId) ??
        (result.avatarId != null
            ? CoinsCatalog.avatarIdForEntitlement(result.avatarId!)
            : null) ??
        CoinsCatalog.premiumAvatarId;
    final avatar = gameAvatarByIdOrNull(avatarId);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AppGlassCard(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            borderColor: AppPalette.gold.withOpacity(0.55),
            boxShadow: [
              BoxShadow(
                color: AppPalette.gold.withOpacity(0.30),
                blurRadius: 32,
                spreadRadius: -6,
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppPalette.gold.withOpacity(0.35),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: AppPalette.gold.withOpacity(0.7),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: FullAvatarDisplay(size: 108, avatar: avatar),
                ),
                const SizedBox(height: 18),
                Text(
                  'Thank you!',
                  style: safeOrbitron(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: AppPalette.goldHighlight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your premium avatar has been unlocked.\nDo you want to equip it now?',
                  style: bodyFont(context).copyWith(
                    height: 1.45,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: 'MAYBE LATER',
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context),
                        icon: Icons.schedule,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: 'EQUIP NOW',
                        fill: AppPalette.gold.withOpacity(0.92),
                        stroke: AppPalette.goldHighlight.withOpacity(0.65),
                        onPressed: () async {
                          Navigator.pop(context);
                          await LocalStore.setEquippedAvatar(avatarId);
                          if (!mounted) return;
                          showTopNotification(
                            context,
                            '${avatar?.name ?? 'Premium avatar'} equipped!',
                            color: AppPalette.success,
                          );
                        },
                        icon: Icons.workspace_premium_outlined,
                        iconColor: const Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePurchaseFailure(PurchaseGrantResult result) {
    _hideLoadingDialog();
    final raw = result.error ?? 'Purchase was not completed.';
    // Normalise the two terminal failure copies to a single user-friendly
    // line. Backend-detail errors fall through unchanged.
    final friendly = (raw == 'Purchase failed. Please try again.' ||
            raw == 'Purchase canceled.')
        ? 'Purchase was not completed.'
        : raw;
    _showFloatingMessage(
      friendly,
      icon: Icons.error_outline,
      color: AppPalette.danger,
    );
  }

  // ── Purchase entry points ─────────────────────────────────────────────

  Future<void> _checkPendingPurchases() async {
    try {
      await _controller.restorePurchases();
      if (!mounted) return;
      _showFloatingMessage(
        'Pending purchases checked. Check your balance.',
        icon: Icons.check_circle,
        color: AppPalette.success,
        seconds: 2,
      );
    } catch (e) {
      if (!mounted) return;
      _showFloatingMessage(
        'Check failed: ${e.toString().replaceAll('Exception: ', '')}',
        icon: Icons.error_outline,
        color: AppPalette.danger,
      );
    }
  }

  Future<void> _buyProduct(ProductDetails product) async {
    if (FirebaseAuth.instance.currentUser == null) {
      showSignInRequiredDialog(context);
      return;
    }

    final isOnline = await ConnectivityService().online;
    if (!isOnline) {
      if (!mounted) return;
      _showFloatingMessage(
        'You need an internet connection to purchase.',
        icon: Icons.error_outline,
        color: AppPalette.danger,
      );
      return;
    }

    setState(() => _pendingPurchaseProductId = product.id);
    _showLoadingDialog();
    try {
      final success = await _controller.buyPack(product.id);
      if (!mounted) return;
      if (!success && _controller.errorMessage != null) {
        _hideLoadingDialog();
        _showFloatingMessage(
          _controller.errorMessage!,
          icon: Icons.error_outline,
          color: AppPalette.danger,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingPurchaseProductId = null);
      }
    }
  }

  void _showLoadingDialog() {
    if (_isLoadingPurchase) return;
    _isLoadingPurchase = true;

    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(const Duration(seconds: 10), () {
      if (_isLoadingPurchase && mounted) {
        _hideLoadingDialog();
        _showFloatingMessage(
          'Purchase timed out. Check your balance or try again.',
          icon: Icons.timer_off,
          color: AppPalette.warning,
          seconds: 4,
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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppPalette.primary),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  'Processing purchase...',
                  style: titleFont(context).copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait',
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

  void _hideLoadingDialog() {
    _loadingTimeout?.cancel();
    if (_isLoadingPurchase && mounted) {
      _isLoadingPurchase = false;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      setState(() {});
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  ProductDetails? _findProduct(String productId) {
    for (final p in _controller.products) {
      if (p.id == productId) return p;
    }
    return null;
  }

  void _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CoinsHistoryPage()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!ConnectivityService().isOnline.value) {
      return _OfflineBanner();
    }

    final isGuest = FirebaseAuth.instance.currentUser == null;
    final coinProducts = _controller.products
        .where((p) => CoinsCatalog.isCoinProduct(p.id))
        .toList()
      ..sort((a, b) {
        final ca = CoinsCatalog.coinsForProductId(a.id);
        final cb = CoinsCatalog.coinsForProductId(b.id);
        return ca.compareTo(cb);
      });

    // Build the rotating premium avatar offer list. Each offer that the user
    // has NOT already unlocked is included — once an avatar is owned we drop
    // it from the carousel so the section never re-advertises an owned skin.
    final avatarOffers = <_PremiumAvatarOffer>[];
    if (!PremiumAvatarService.instance.owned.value) {
      final p = _findProduct(CoinsCatalog.premiumAvatarProductId);
      avatarOffers.add(_PremiumAvatarOffer(
        productId: CoinsCatalog.premiumAvatarProductId,
        avatarId: CoinsCatalog.premiumAvatarId,
        title: 'Inferno Premium Avatar',
        subtitle: 'Animated Inferno frame — unlocked forever.',
        assetPath: CoinsCatalog.premiumAvatarAsset,
        priceLabel: p?.price ?? CoinsCatalog.premiumAvatarFallbackPrice,
        originalPriceLabel: CoinsCatalog.premiumAvatarOriginalPrice,
        discountPct: CoinsCatalog.premiumAvatarDiscountPct,
        product: p,
        primary: AppPalette.gold,
        primaryDeep: AppPalette.goldDeep,
        secondary: AppPalette.goldHighlight,
      ));
    }
    if (!PremiumAvatarService.instance.ownedApex.value) {
      final p = _findProduct(CoinsCatalog.premiumAvatarApexProductId);
      avatarOffers.add(_PremiumAvatarOffer(
        productId: CoinsCatalog.premiumAvatarApexProductId,
        avatarId: CoinsCatalog.premiumAvatarApexId,
        title: 'Apex Premium Avatar',
        subtitle: 'Animated Apex frame — unlocked forever.',
        assetPath: CoinsCatalog.premiumAvatarApexAsset,
        priceLabel: p?.price ?? CoinsCatalog.premiumAvatarApexFallbackPrice,
        originalPriceLabel: CoinsCatalog.premiumAvatarApexOriginalPrice,
        discountPct: CoinsCatalog.premiumAvatarApexDiscountPct,
        product: p,
        primary: AppPalette.accentPurple,
        primaryDeep: AppPalette.accentBlue,
        secondary: AppPalette.homeSky,
      ));
    }

    return Column(
      children: [
        // ── Sticky header (never scrolls) ────────────────────────────────
        _StickyShopHeader(
          coins: _coins,
          onOpenHistory: _openHistory,
        ),
        // ── Scrollable body ───────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_controller.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (!_controller.storeAvailable ||
                    _controller.products.isEmpty)
                  _buildStoreUnavailableBanner()
                else ...[
                  if (isGuest) _buildGuestPurchaseBanner(),
                  if (avatarOffers.isNotEmpty) ...[
                    _FeaturedAvatarCarousel(
                      offers: avatarOffers,
                      busy: _isLoadingPurchase,
                      pendingProductId: _pendingPurchaseProductId,
                      disabled: isGuest,
                      onBuy: (offer) {
                        if (offer.product != null) {
                          _buyProduct(offer.product!);
                        } else {
                          _showFloatingMessage(
                            'This offer is not available right now. Please try again later.',
                            icon: Icons.info_outline,
                            color: AppPalette.warning,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildCoinPackGrid(coinProducts, isGuest),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: _controller.restoring
                          ? null
                          : _checkPendingPurchases,
                      child: Text(
                        _controller.restoring
                            ? 'Checking...'
                            : 'Check pending purchases',
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
          ),
        ),
      ],
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
            const Icon(Icons.info_outline,
                color: AppPalette.warning, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Register a verified arena account to purchase items.',
                style: bodyFont(context)
                    .copyWith(color: AppPalette.warning, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreUnavailableBanner() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AppGlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: AppPalette.warning.withOpacity(0.24),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                color: AppPalette.warning, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _controller.errorMessage ??
                    'Coin store not configured yet. Please try again later.',
                style: bodyFont(context).copyWith(color: AppPalette.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinPackGrid(List<ProductDetails> products, bool isGuest) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics =
            UiMetrics.of(constraints, MediaQuery.orientationOf(context));
        final width = constraints.maxWidth;
        final crossAxisCount = metrics.coinsColumns(width);
        final spacing = metrics.cardGap;
        // Slightly taller cards so the coin art has more room. The previous
        // aspect ratio left the coin image looking small relative to the
        // chrome — bump height by ~12% for prominence.
        final childAspectRatio = metrics.coinsCardAspectRatio * 0.88;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: products.length,
          itemBuilder: (context, i) {
            final product = products[i];
            final isPending = _pendingPurchaseProductId == product.id;
            final isDisabled = isGuest ||
                _controller.purchasing ||
                !_controller.storeAvailable ||
                _isLoadingPurchase ||
                isPending;
            return _CoinPackCard(
              product: product,
              radius: metrics.cardRadius,
              isPending: isPending,
              disabled: isDisabled,
              onBuy: () => _buyProduct(product),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Offline placeholder
// ─────────────────────────────────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
}

// ─────────────────────────────────────────────────────────────────────────
// Sticky shop header — never scrolls. Includes large COIN-SHOP.png and a
// plain numeric balance (no compaction on this page). Tap anywhere to open
// the transaction history page.
// ─────────────────────────────────────────────────────────────────────────
class _StickyShopHeader extends StatelessWidget {
  final int coins;
  final VoidCallback onOpenHistory;

  const _StickyShopHeader({
    required this.coins,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: title + history icon
          Row(
            children: [
              Expanded(
                child: Text(
                  'COIN STORE',
                  style: safeOrbitron(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                    color: AppPalette.homeTitle,
                  ),
                ),
              ),
              Tooltip(
                message: 'History',
                child: AppIconButton(
                  icon: Icons.history_rounded,
                  onTap: onOpenHistory,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Premium hero card — fully tappable to open history
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenHistory,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppPalette.homeBlue.withOpacity(0.34),
                      AppPalette.accentPurple.withOpacity(0.18),
                      AppPalette.panelDeep.withOpacity(0.95),
                    ],
                  ),
                  border: Border.all(
                      color: AppPalette.homeStroke.withOpacity(0.55)),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.homeBlue.withOpacity(0.28),
                      blurRadius: 32,
                      spreadRadius: -10,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Large hero image (significantly bigger than before)
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: Image.asset(
                        'assets/coin/COIN-SHOP.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'YOUR BALANCE',
                            style: safeInter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.4,
                              color: AppPalette.text.withOpacity(0.65),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Plain numeric balance — NO compaction on this page.
                          _ExactBalancePill(coins: coins),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 14,
                                color: AppPalette.text.withOpacity(0.55),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Tap to view history',
                                  overflow: TextOverflow.ellipsis,
                                  style: bodyFont(context).copyWith(
                                    fontSize: 11,
                                    color: AppPalette.text.withOpacity(0.65),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExactBalancePill extends StatelessWidget {
  final int coins;
  const _ExactBalancePill({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.goldDeep.withOpacity(0.34),
            AppPalette.gold.withOpacity(0.16),
          ],
        ),
        border: Border.all(color: AppPalette.gold.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.gold.withOpacity(0.22),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/coin/COIN.png', width: 22, height: 22),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatCoins(coins, compact: false),
                style: safeOrbitron(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: AppPalette.goldHighlight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Featured premium avatar offer (data class).
// ─────────────────────────────────────────────────────────────────────────
class _PremiumAvatarOffer {
  final String productId;
  final int avatarId;
  final String title;
  final String subtitle;
  final String assetPath;
  final String priceLabel;
  final String originalPriceLabel;
  final int discountPct;
  final ProductDetails? product;
  final Color primary;
  final Color primaryDeep;
  final Color secondary;

  const _PremiumAvatarOffer({
    required this.productId,
    required this.avatarId,
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.priceLabel,
    required this.originalPriceLabel,
    required this.discountPct,
    required this.product,
    required this.primary,
    required this.primaryDeep,
    required this.secondary,
  });
}

// ─────────────────────────────────────────────────────────────────────────
// Animated featured premium avatar carousel.
//   • Rotates between offers every ~2 seconds.
//   • Right-to-left slide transition for a premium feel.
//   • Pauses rotation while the user is interacting (pressed / hovered)
//     so they don't tap a different offer than the one they aimed at.
// ─────────────────────────────────────────────────────────────────────────
class _FeaturedAvatarCarousel extends StatefulWidget {
  final List<_PremiumAvatarOffer> offers;
  final bool busy;
  final String? pendingProductId;
  final bool disabled;
  final ValueChanged<_PremiumAvatarOffer> onBuy;

  const _FeaturedAvatarCarousel({
    required this.offers,
    required this.busy,
    required this.pendingProductId,
    required this.disabled,
    required this.onBuy,
  });

  @override
  State<_FeaturedAvatarCarousel> createState() =>
      _FeaturedAvatarCarouselState();
}

class _FeaturedAvatarCarouselState extends State<_FeaturedAvatarCarousel> {
  Timer? _rotateTimer;
  int _index = 0;
  bool _interacting = false;

  static const _interval = Duration(seconds: 2);
  static const _transition = Duration(milliseconds: 520);

  @override
  void initState() {
    super.initState();
    _scheduleRotation();
  }

  @override
  void didUpdateWidget(covariant _FeaturedAvatarCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offers.length != widget.offers.length) {
      if (_index >= widget.offers.length) {
        _index = 0;
      }
      _scheduleRotation();
    }
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    super.dispose();
  }

  void _scheduleRotation() {
    _rotateTimer?.cancel();
    if (widget.offers.length < 2) return;
    _rotateTimer = Timer.periodic(_interval, (_) {
      if (!mounted) return;
      if (_interacting) return;
      setState(() => _index = (_index + 1) % widget.offers.length);
    });
  }

  void _pauseRotation() {
    if (_interacting) return;
    _interacting = true;
  }

  void _resumeRotation() {
    if (!_interacting) return;
    _interacting = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();
    final offer = widget.offers[_index.clamp(0, widget.offers.length - 1)];
    final busy = widget.busy || widget.pendingProductId == offer.productId;
    final disabled = widget.disabled || offer.product == null;

    return Listener(
      onPointerDown: (_) => _pauseRotation(),
      onPointerUp: (_) => _resumeRotation(),
      onPointerCancel: (_) => _resumeRotation(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AnimatedSwitcher(
          duration: _transition,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final inFrom = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(
              position: inFrom,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          layoutBuilder: (current, previous) {
            return Stack(
              alignment: Alignment.center,
              children: [
                ...previous,
                if (current != null) current,
              ],
            );
          },
          child: KeyedSubtree(
            key: ValueKey<String>(offer.productId),
            child: _PremiumAvatarSlide(
              offer: offer,
              busy: busy,
              disabled: disabled,
              onBuy: () => widget.onBuy(offer),
              total: widget.offers.length,
              currentIndex: _index,
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumAvatarSlide extends StatelessWidget {
  final _PremiumAvatarOffer offer;
  final bool busy;
  final bool disabled;
  final VoidCallback onBuy;
  final int total;
  final int currentIndex;

  const _PremiumAvatarSlide({
    required this.offer,
    required this.busy,
    required this.disabled,
    required this.onBuy,
    required this.total,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = !disabled && !busy;
    final accent = offer.primary;
    final accentDeep = offer.primaryDeep;
    final secondary = offer.secondary;
    final avatar = gameAvatarByIdOrNull(offer.avatarId);

    return _PressedScale(
      onTap: canTap ? onBuy : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withOpacity(0.22),
              accentDeep.withOpacity(0.18),
              AppPalette.panelDeep.withOpacity(0.96),
            ],
          ),
          border: Border.all(color: accent.withOpacity(0.55)),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.26),
              blurRadius: 30,
              spreadRadius: -8,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: accent.withOpacity(0.14),
                    border: Border.all(color: accent.withOpacity(0.55)),
                  ),
                  child: Text(
                    'PREMIUM • ONE-TIME',
                    style: safeOrbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      color: secondary,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppPalette.success.withOpacity(0.18),
                    border:
                        Border.all(color: AppPalette.success.withOpacity(0.55)),
                  ),
                  child: Text(
                    '${offer.discountPct}% OFF',
                    style: safeOrbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppPalette.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Larger avatar preview — composite shows user's profile
                // picture INSIDE the avatar frame so the buyer can imagine
                // how it'll look once equipped.
                SizedBox(
                  width: 116,
                  height: 116,
                  child: FullAvatarDisplay(size: 116, avatar: avatar),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        offer.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: safeOrbitron(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        offer.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: bodyFont(context).copyWith(
                          fontSize: 12,
                          color: AppPalette.text.withOpacity(0.78),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(
                            offer.priceLabel,
                            style: safeOrbitron(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: secondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            offer.originalPriceLabel,
                            style: safeOrbitron(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.textSubtle,
                            ).copyWith(
                              decoration: TextDecoration.lineThrough,
                              decorationColor:
                                  AppPalette.textSubtle.withOpacity(0.75),
                              decorationThickness: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppPillButton(
              label: busy ? 'PROCESSING' : 'UNLOCK NOW',
              fill: accent.withOpacity(0.94),
              stroke: secondary.withOpacity(0.65),
              minHeight: 44,
              onPressed: canTap ? onBuy : null,
              icon: Icons.workspace_premium_outlined,
            ),
            if (total > 1) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(total, (i) {
                  final active = i == currentIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      width: active ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: active
                            ? secondary.withOpacity(0.95)
                            : Colors.white.withOpacity(0.22),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Coin pack card (whole card tappable). Bigger coin art, lighter chrome.
// ─────────────────────────────────────────────────────────────────────────
class _CoinPackCard extends StatelessWidget {
  final ProductDetails product;
  final double radius;
  final bool isPending;
  final bool disabled;
  final VoidCallback onBuy;

  const _CoinPackCard({
    required this.product,
    required this.radius,
    required this.isPending,
    required this.disabled,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final productId = product.id;
    final isPopular = CoinsCatalog.isPopular(productId);
    final baseCoins = CoinsCatalog.baseCoinsForProductId(productId);
    final bonus = CoinsCatalog.bonusForProductId(productId);
    final accent = isPopular ? AppPalette.gold : AppPalette.primary;
    final secondaryAccent =
        isPopular ? AppPalette.goldHighlight : AppPalette.homeBlue;
    final canTap = !disabled;

    return _PressedScale(
      onTap: canTap ? onBuy : null,
      child: AppGlassCard(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
        radius: radius,
        backgroundColor: Color.lerp(
          AppPalette.panel,
          accent,
          isPopular ? 0.16 : 0.06,
        ),
        borderColor: accent.withOpacity(isPopular ? 0.58 : 0.24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: accent.withOpacity(isPopular ? 0.24 : 0.08),
            blurRadius: 22,
            spreadRadius: -8,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(isPopular ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withOpacity(0.35)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isPopular ? 'MOST POPULAR' : 'COIN PACK',
                        style: homeLabelFont(
                          context,
                          fontSize: 8,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (bonus > 0)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppPalette.success.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppPalette.success.withOpacity(0.5)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '+${formatCoins(bonus, compact: true)} BONUS',
                          style: safeOrbitron(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: AppPalette.success,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.north_east_rounded,
                    size: 16,
                    color: secondaryAccent.withOpacity(0.88),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Much larger coin art — uses the full available space for the
            // image while keeping a compact title/price block below.
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Image.asset(
                  CoinsCatalog.assetForCoinProduct(productId),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatCoins(baseCoins, compact: true),
              textAlign: TextAlign.center,
              style: statNumberFont(
                context,
                fontSize: 22,
                color: isPopular ? AppPalette.goldHighlight : Colors.white,
              ),
            ),
            Text(
              'XO COINS',
              textAlign: TextAlign.center,
              style: homeLabelFont(
                context,
                fontSize: 8.5,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product.price,
              textAlign: TextAlign.center,
              style: safeOrbitron(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isPopular ? AppPalette.goldHighlight : AppPalette.text,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            AppPillButton(
              label: isPending ? 'PROCESSING' : 'BUY NOW',
              onPressed: canTap ? onBuy : null,
              fill: isPopular
                  ? AppPalette.goldDeep
                  : AppPalette.primary2,
              stroke: isPopular
                  ? AppPalette.goldHighlight.withOpacity(0.55)
                  : AppPalette.primary.withOpacity(0.45),
              minHeight: 38,
              icon: isPopular
                  ? Icons.workspace_premium_outlined
                  : Icons.shopping_bag_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Reusable press-scale wrapper. Makes the whole card behave like a button.
// ─────────────────────────────────────────────────────────────────────────
class _PressedScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressedScale({required this.child, this.onTap});

  @override
  State<_PressedScale> createState() => _PressedScaleState();
}

class _PressedScaleState extends State<_PressedScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
