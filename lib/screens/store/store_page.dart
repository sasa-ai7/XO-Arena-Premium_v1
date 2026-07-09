import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/keys.dart';
import '../../core/neon_colors.dart';
import '../../core/responsive_metrics.dart';
import '../../models/game_avatar.dart';
import '../../services/local_store.dart';
import '../../utils/navigation_utils.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/avatar_store_tab.dart';
import '../../coins/coins_screen.dart';
import '../../coins/premium_avatar_service.dart';
import 'colors_tab.dart';

class StorePage extends StatefulWidget {
  final int initialTab;
  final bool embedded;
  const StorePage({super.key, this.initialTab = 0, this.embedded = false});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage>
    with SingleTickerProviderStateMixin {
  late int _selectedTab;
  int _coins = 0;
  List<int> _ownedX = [];
  List<int> _ownedO = [];
  List<int> _ownedAvatars = [];
  int _equippedAvatar = 0;
  int _selectedXIndex = 0;
  int _selectedOIndex = 0;
  bool _busy = false;

  // XO Skin state
  String _selectedXSkin = 'default';
  String _selectedOSkin = 'default';
  List<String> _ownedXSkins = ['default'];
  List<String> _ownedOSkins = ['default'];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    LocalStore.coinsNotifier.addListener(_onCoinsChanged);
    PremiumAvatarService.instance.owned.addListener(_onPremiumAvatarChanged);
    // Bind premium avatar entitlement listener so ownership is fresh.
    PremiumAvatarService.instance.bind();
    _load();
  }

  @override
  void dispose() {
    LocalStore.coinsNotifier.removeListener(_onCoinsChanged);
    PremiumAvatarService.instance.owned.removeListener(_onPremiumAvatarChanged);
    super.dispose();
  }

  void _onPremiumAvatarChanged() {
    if (mounted) _load();
  }

  void _onCoinsChanged() {
    if (mounted) setState(() => _coins = LocalStore.coinsNotifier.value);
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _ownedX = await LocalStore.ownedXColors();
    _ownedO = await LocalStore.ownedOColors();
    final currentX = await LocalStore.xPieceColor();
    final currentO = await LocalStore.oPieceColor();
    _selectedXIndex = max(
        0,
        NeonColors.xColors
            .indexWhere((c) => c.toARGB32() == currentX.toARGB32()));
    _selectedOIndex = max(
        0,
        NeonColors.oColors
            .indexWhere((c) => c.toARGB32() == currentO.toARGB32()));
    _ownedAvatars = await LocalStore.ownedAvatars();
    _equippedAvatar = await LocalStore.equippedAvatar();
    _ownedXSkins = await LocalStore.ownedXSkins();
    _ownedOSkins = await LocalStore.ownedOSkins();
    _selectedXSkin = await LocalStore.selectedXSkin();
    _selectedOSkin = await LocalStore.selectedOSkin();
    setState(() => _coins = p.getInt(Keys.coins) ?? 0);
  }

  String _storeHeaderTitle(AppL10n l10n) {
    switch (_selectedTab) {
      case 1:
        return l10n.avatarGalleryTab;
      case 2:
        return l10n.buyCoins;
      case 0:
      default:
        return l10n.storeTab;
    }
  }

  String _storeHeaderSubtitle(AppL10n l10n) {
    switch (_selectedTab) {
      case 1:
        return l10n.avatarGallerySubtitle;
      case 2:
        return l10n.buyCoinsSubtitle;
      case 0:
      default:
        return l10n.storeSubtitle;
    }
  }

  /// Show dialog when user doesn't have enough coins
  void _showInsufficientCoinsDialog(
      BuildContext context, int required, int current) {
    final needed = required - current;
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
                Icon(Icons.warning_amber_rounded,
                    size: 56, color: AppPalette.warning),
                const SizedBox(height: 16),
                Text(
                  "Not Enough Coins",
                  style: safeOrbitron(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "You need $required coins to purchase this item.\nYou currently have $current coins.",
                  textAlign: TextAlign.center,
                  style: bodyFont(context)
                      .copyWith(height: 1.4, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppPalette.warning.withOpacity(0.15),
                    border:
                        Border.all(color: AppPalette.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_rounded,
                          color: Color(0xFFFFD700), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Need $needed more coins",
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
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: AppL10n.of(context).cancelBtn,
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: "BUY COINS",
                        fill: AppPalette.goldDeep,
                        stroke: AppPalette.goldHighlight.withOpacity(0.55),
                        onPressed: () {
                          Navigator.pop(context);
                          // Switch to coins tab
                          setState(() => _selectedTab = 2);
                        },
                        icon: Icons.monetization_on_rounded,
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

  Future<bool?> _showPurchaseConfirmDialog({
    required BuildContext context,
    required bool isX,
    required Color color,
    required int price,
  }) {
    return showDialog<bool>(
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
                Text(
                  isX ? 'X' : 'O',
                  style: safeOrbitron(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: color,
                    shadows: [
                      Shadow(
                          color: color.withValues(alpha: 0.6), blurRadius: 20),
                      Shadow(
                          color: color.withValues(alpha: 0.3), blurRadius: 40),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unlock ${isX ? "X" : "O"} Color?',
                  style: safeOrbitron(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/coin/COIN.png',
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 6),
                    Text('$price',
                        style: safeOrbitron(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFFD700))),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: AppL10n.of(context).cancelBtn,
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context, false),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: 'CONFIRM',
                        fill: AppPalette.primary.withOpacity(0.9),
                        onPressed: () => Navigator.pop(context, true),
                        icon: Icons.check,
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

  Future<void> _buyXColor(int i) async {
    if (_busy) return;
    // Check if guest
    if (FirebaseAuth.instance.currentUser == null) {
      showSignInRequiredDialog(context);
      return;
    }
    if (_ownedX.contains(i)) {
      showTopNotification(context, "Already owned!", color: AppPalette.danger);
      return;
    }
    final price = priceForColorIndex(i);
    if (_coins < price) {
      _showInsufficientCoinsDialog(context, price, _coins);
      return;
    }
    // Show confirmation dialog
    final confirmed = await _showPurchaseConfirmDialog(
      context: context,
      isX: true,
      color: NeonColors.xColors[i],
      price: price,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final before = LocalStore.coinsNotifier.value;
    await LocalStore.updateCoins(-price);
    await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: price,
        type: 'loss',
        description: 'Cosmetic Purchase',
        balanceBefore: before,
        balanceAfter: before - price);
    await LocalStore.addOwnedXColor(i);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, "Purchased X color!",
        color: AppPalette.success);
  }

  Future<void> _buyOColor(int i) async {
    if (_busy) return;
    // Check if guest
    if (FirebaseAuth.instance.currentUser == null) {
      showSignInRequiredDialog(context);
      return;
    }
    if (_ownedO.contains(i)) {
      showTopNotification(context, "Already owned!", color: AppPalette.danger);
      return;
    }
    final price = priceForColorIndex(i);
    if (_coins < price) {
      _showInsufficientCoinsDialog(context, price, _coins);
      return;
    }
    // Show confirmation dialog
    final confirmed = await _showPurchaseConfirmDialog(
      context: context,
      isX: false,
      color: NeonColors.oColors[i],
      price: price,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final before = LocalStore.coinsNotifier.value;
    await LocalStore.updateCoins(-price);
    await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: price,
        type: 'loss',
        description: 'Cosmetic Purchase',
        balanceBefore: before,
        balanceAfter: before - price);
    await LocalStore.addOwnedOColor(i);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, "Purchased O color!",
        color: AppPalette.success);
  }

  // ── XO Skin buy / select ─────────────────────────────────────────────────

  Future<void> _buyXSkin(String skinId, int price) async {
    if (_busy) return;
    if (FirebaseAuth.instance.currentUser == null) {
      showSignInRequiredDialog(context);
      return;
    }
    if (_ownedXSkins.contains(skinId)) {
      await _selectXSkin(skinId);
      return;
    }
    if (_coins < price) {
      _showInsufficientCoinsDialog(context, price, _coins);
      return;
    }
    final confirmed = await _showSkinPurchaseConfirmDialog(
        context: context, isX: true, skinId: skinId, price: price);
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final before = LocalStore.coinsNotifier.value;
    await LocalStore.updateCoins(-price);
    await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: price,
        type: 'loss',
        description: 'X Skin Purchase: $skinId',
        balanceBefore: before,
        balanceAfter: before - price);
    await LocalStore.addOwnedXSkin(skinId);
    await LocalStore.setSelectedXSkin(skinId);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, 'X Skin equipped!', color: AppPalette.success);
  }

  Future<void> _buyOSkin(String skinId, int price) async {
    if (_busy) return;
    if (FirebaseAuth.instance.currentUser == null) {
      showSignInRequiredDialog(context);
      return;
    }
    if (_ownedOSkins.contains(skinId)) {
      await _selectOSkin(skinId);
      return;
    }
    if (_coins < price) {
      _showInsufficientCoinsDialog(context, price, _coins);
      return;
    }
    final confirmed = await _showSkinPurchaseConfirmDialog(
        context: context, isX: false, skinId: skinId, price: price);
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final before = LocalStore.coinsNotifier.value;
    await LocalStore.updateCoins(-price);
    await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: price,
        type: 'loss',
        description: 'O Skin Purchase: $skinId',
        balanceBefore: before,
        balanceAfter: before - price);
    await LocalStore.addOwnedOSkin(skinId);
    await LocalStore.setSelectedOSkin(skinId);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, 'O Skin equipped!', color: AppPalette.success);
  }

  Future<void> _selectXSkin(String skinId) async {
    if (_busy) return;
    await LocalStore.setSelectedXSkin(skinId);
    if (!mounted) return;
    setState(() => _selectedXSkin = skinId);
    showTopNotification(context,
        skinId == 'default' ? 'Restored default X' : 'X Skin selected!',
        color: AppPalette.success);
  }

  Future<void> _selectOSkin(String skinId) async {
    if (_busy) return;
    await LocalStore.setSelectedOSkin(skinId);
    if (!mounted) return;
    setState(() => _selectedOSkin = skinId);
    showTopNotification(context,
        skinId == 'default' ? 'Restored default O' : 'O Skin selected!',
        color: AppPalette.success);
  }

  Future<bool?> _showSkinPurchaseConfirmDialog({
    required BuildContext context,
    required bool isX,
    required String skinId,
    required int price,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AppGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      isX
                          ? 'assets/x/$skinId.png'
                          : 'assets/o/$skinId.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isX ? 'X SKIN' : 'O SKIN',
                  style: safeOrbitron(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: isX ? AppPalette.homeCyan : AppPalette.accentPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/coin/COIN.png',
                        height: 18, fit: BoxFit.contain),
                    const SizedBox(width: 6),
                    Text(
                      '$price coins',
                      style: safeOrbitron(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: AppL10n.of(context).cancelBtn,
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context, false),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: 'BUY & EQUIP',
                        fill: AppPalette.goldDeep,
                        stroke: AppPalette.goldHighlight.withOpacity(0.55),
                        onPressed: () => Navigator.pop(context, true),
                        icon: Icons.shopping_bag_rounded,
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

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _buyAvatar(GameAvatar avatar) async {
    if (_busy) return;
    if (FirebaseAuth.instance.currentUser == null) {
      showSignInRequiredDialog(context);
      return;
    }
    if (_ownedAvatars.contains(avatar.id)) {
      if (_equippedAvatar == avatar.id) {
        // Already equipped — tap again to unequip.
        await _equipAvatar(0); // 0 = no avatar equipped
        if (kDebugMode) {
          debugPrint('[STORE] avatar unequipped');
          debugPrint('[PROFILE] selectedAvatar=null, using fallback profile image');
        }
      } else {
        await _equipAvatar(avatar.id);
        if (kDebugMode) debugPrint('[STORE] avatar equipped: ${avatar.name}');
      }
      return;
    }
    // Premium IAP avatar: route to the coin shop tab. It cannot be bought
    // with coins — only via Google Play Billing.
    if (avatar.isPremiumIap) {
      showTopNotification(
        context,
        'Unlock from the Coin Store',
        color: AppPalette.gold,
      );
      setState(() => _selectedTab = 2);
      return;
    }
    if (avatar.price > 0 && _coins < avatar.price) {
      _showInsufficientCoinsDialog(context, avatar.price, _coins);
      return;
    }
    final confirmed = await showAvatarPurchaseDialog(context, avatar);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    if (avatar.price > 0) {
      final before = LocalStore.coinsNotifier.value;
      await LocalStore.updateCoins(-avatar.price);
      await LocalStore.addTopupHistory(
        usd: 0.0,
        coins: avatar.price,
        type: 'loss',
        description: 'Avatar Purchase: ${avatar.name}',
        balanceBefore: before,
        balanceAfter: before - avatar.price,
      );
    }
    await LocalStore.addOwnedAvatar(avatar.id);
    await LocalStore.setEquippedAvatar(avatar.id);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, 'Purchased ${avatar.name}!',
        color: AppPalette.success);
  }

  Future<void> _equipAvatar(int id) async {
    if (_busy) return;
    await LocalStore.setEquippedAvatar(id);
    if (!mounted) return;
    setState(() => _equippedAvatar = id);
    final l10n = AppL10n.of(context);
    if (id == 0) {
      showTopNotification(context, l10n.avatarUnequipped,
          color: AppPalette.textMuted);
    } else {
      showTopNotification(context, '${gameAvatarById(id).name} ${l10n.storeEquipped}!',
          color: AppPalette.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _StoreTabBar(
            selectedIndex: _selectedTab,
            onTabSelected: (i) => setState(() => _selectedTab = i),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: [
              ColorsTab(
                ownedX: _ownedX,
                ownedO: _ownedO,
                selectedXIndex: _selectedXIndex,
                selectedOIndex: _selectedOIndex,
                onBuyX: _buyXColor,
                onBuyO: _buyOColor,
                busy: _busy,
                ownedXSkins: _ownedXSkins,
                ownedOSkins: _ownedOSkins,
                selectedXSkin: _selectedXSkin,
                selectedOSkin: _selectedOSkin,
                onBuyXSkin: _buyXSkin,
                onBuyOSkin: _buyOSkin,
                onSelectXSkin: _selectXSkin,
                onSelectOSkin: _selectOSkin,
                coins: _coins,
              ),
              AvatarStoreTab(
                ownedAvatars: _ownedAvatars,
                equippedAvatar: _equippedAvatar,
                busy: _busy,
                onBuyAvatar: _buyAvatar,
                onEquipAvatar: _equipAvatar,
              ),
              const CoinsScreen(),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          variant: AppBackgroundVariant.homeNeon,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    AppIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => navigateToHomeHub(context)),
                    const Spacer(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _storeHeaderTitle(l10n),
                      style: titleFont(context).copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _storeHeaderSubtitle(l10n),
                      style: bodyFont(context).copyWith(
                        fontSize: 13,
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-tab bar for X / O selection ────────────────────────────────────────

class _StoreTabBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;

  const _StoreTabBar(
      {required this.selectedIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final media = MediaQuery.sizeOf(context);
    final metrics = UiMetrics.fromSize(media, MediaQuery.orientationOf(context));
    Widget tab(int index, String label) {
      final selected = selectedIndex == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => onTabSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppPalette.homeSky, AppPalette.homeBlue],
                    )
                  : null,
              color: selected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppPalette.homeStrokeStrong.withOpacity(0.70)
                    : Colors.transparent,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppPalette.homeSky.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: safeOrbitron(
                  fontSize: metrics.tabLabelSize,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppPalette.textSubtle,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: metrics.tabBarHeight,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.panelElevated.withOpacity(0.96),
            AppPalette.panelDeep.withOpacity(0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.homeStroke.withOpacity(0.26)),
      ),
      child: Row(
        children: [
          tab(0, l10n.xAndOColorsTab),
          tab(1, l10n.avatarGalleryTab),
          tab(2, l10n.buyCoins),
        ],
      ),
    );
  }
}

/// ==========================
///   COINS HISTORY PAGE
/// ==========================
