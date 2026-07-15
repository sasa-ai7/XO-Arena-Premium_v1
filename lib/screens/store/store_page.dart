import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/keys.dart';
import '../../core/neon_colors.dart';
import '../../models/game_avatar.dart';
import '../../models/game_emoji.dart';
import '../../services/app_mode_service.dart';
import '../../services/local_store.dart';
import '../../services/mission_service.dart';
import '../../services/wallet_transaction_service.dart';
import '../../utils/navigation_utils.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/avatar_store_tab.dart';
import '../../widgets/emoji_store_tab.dart';
import '../../coins/coins_screen.dart';
import '../../coins/premium_avatar_service.dart';
import 'colors_tab.dart';
import 'store_category_image_tile.dart';

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

  // Emoji state
  List<String> _ownedEmojis = [];
  List<String> _equippedEmojis = [];
  bool _emojiTabVisited = false;

  // Lazily build the Avatar tab (heavy image grid) only after it is first
  // opened, mirroring the _visitedTabs lazy-tab pattern in home_hub. Colors
  // and Coins tabs stay eagerly built (Coins hosts billing UI — unchanged).
  bool _avatarTabVisited = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _avatarTabVisited = widget.initialTab == 1;
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
    _ownedEmojis = await LocalStore.ownedEmojis();
    _equippedEmojis = await LocalStore.equippedEmojis();
    setState(() => _coins = p.getInt(Keys.coins) ?? 0);
  }

  String _storeHeaderTitle(AppL10n l10n) {
    switch (_selectedTab) {
      case 1:
        return l10n.avatarGalleryTab;
      case 2:
        return l10n.buyCoins;
      case 3:
        return l10n.emojiGalleryTab;
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
      case 3:
        return l10n.emojiGallerySubtitle;
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
                      'assets/coin/COIN.webp',
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

  /// Whether the player can spend coins on cosmetics right now. Offline mode
  /// spends the offline wallet; online requires a signed-in account. Real-money
  /// coin PACKS remain online-only and are gated separately in the Coins tab.
  bool _canPurchaseCosmetics() {
    if (AppModeService.current == AppMode.offline) return true;
    return FirebaseAuth.instance.currentUser != null;
  }

  String get _purchaseSource =>
      AppModeService.current == AppMode.offline ? 'offline' : 'online';

  Future<void> _buyXColor(int i) async {
    if (_busy) return;
    if (!_canPurchaseCosmetics()) {
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
    final result = await WalletTransactionService.instance.applyDebit(
      coins: price,
      transactionId: 'store_x_color_${LocalStore.uid ?? 'offline'}_$i',
      source: 'x_color_purchase',
      title: 'Color Purchase',
      message: 'Cosmetic Purchase',
      itemType: 'x_color',
      itemId: '$i',
    );
    if (!result.success) {
      if (!mounted) return;
      setState(() => _busy = false);
      showTopNotification(context, 'Purchase failed — coins not deducted.',
          color: AppPalette.danger);
      return;
    }
    await LocalStore.addOwnedXColor(i);
    await MissionService.instance.trackAmount('coins_spent', price);
    await MissionService.instance.trackEvent('theme_bought');
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, "Purchased X color!",
        color: AppPalette.success);
  }

  Future<void> _buyOColor(int i) async {
    if (_busy) return;
    if (!_canPurchaseCosmetics()) {
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
    final result = await WalletTransactionService.instance.applyDebit(
      coins: price,
      transactionId: 'store_o_color_${LocalStore.uid ?? 'offline'}_$i',
      source: 'o_color_purchase',
      title: 'Color Purchase',
      message: 'Cosmetic Purchase',
      itemType: 'o_color',
      itemId: '$i',
    );
    if (!result.success) {
      if (!mounted) return;
      setState(() => _busy = false);
      showTopNotification(context, 'Purchase failed — coins not deducted.',
          color: AppPalette.danger);
      return;
    }
    await LocalStore.addOwnedOColor(i);
    await MissionService.instance.trackAmount('coins_spent', price);
    await MissionService.instance.trackEvent('theme_bought');
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, "Purchased O color!",
        color: AppPalette.success);
  }

  // ── XO Skin buy / select ─────────────────────────────────────────────────

  Future<void> _buyXSkin(String skinId, int price) async {
    if (_busy) return;
    if (!_canPurchaseCosmetics()) {
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
    final result = await WalletTransactionService.instance.applyDebit(
      coins: price,
      transactionId: 'store_x_skin_${LocalStore.uid ?? 'offline'}_$skinId',
      source: 'store_x_skin_purchase',
      title: 'X Skin Purchase',
      message: 'X Skin Purchase: $skinId',
      itemType: 'x_skin',
      itemId: skinId,
      assetPath: 'assets/x/$skinId.webp',
    );
    if (!result.success) {
      if (!mounted) return;
      setState(() => _busy = false);
      showTopNotification(context, 'Purchase failed — coins not deducted.',
          color: AppPalette.danger);
      return;
    }
    if (kDebugMode)
      debugPrint(
          '[STORE] purchase source=$_purchaseSource item=x_skin:$skinId');
    await LocalStore.addOwnedXSkin(skinId);
    await LocalStore.setSelectedXSkin(skinId);
    await MissionService.instance.trackAmount('coins_spent', price);
    await MissionService.instance.trackEvent('theme_bought');
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, 'X Skin equipped!', color: AppPalette.success);
  }

  Future<void> _buyOSkin(String skinId, int price) async {
    if (_busy) return;
    if (!_canPurchaseCosmetics()) {
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
    final result = await WalletTransactionService.instance.applyDebit(
      coins: price,
      transactionId: 'store_o_skin_${LocalStore.uid ?? 'offline'}_$skinId',
      source: 'store_o_skin_purchase',
      title: 'O Skin Purchase',
      message: 'O Skin Purchase: $skinId',
      itemType: 'o_skin',
      itemId: skinId,
      assetPath: 'assets/o/$skinId.webp',
    );
    if (!result.success) {
      if (!mounted) return;
      setState(() => _busy = false);
      showTopNotification(context, 'Purchase failed — coins not deducted.',
          color: AppPalette.danger);
      return;
    }
    if (kDebugMode)
      debugPrint(
          '[STORE] purchase source=$_purchaseSource item=o_skin:$skinId');
    await LocalStore.addOwnedOSkin(skinId);
    await LocalStore.setSelectedOSkin(skinId);
    await MissionService.instance.trackAmount('coins_spent', price);
    await MissionService.instance.trackEvent('theme_bought');
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotification(context, 'O Skin equipped!', color: AppPalette.success);
  }

  Future<void> _selectXSkin(String skinId) async {
    if (_busy) return;
    final sw = Stopwatch()..start();
    await LocalStore.setSelectedXSkin(skinId);
    if (!mounted) return;
    setState(() => _selectedXSkin = skinId);
    HapticFeedback.selectionClick();
    debugPrint('[PERF] skin_equip_ms=${sw.elapsedMilliseconds}');
    showTopNotification(context,
        skinId == 'default' ? 'Restored default X' : 'X Skin selected!',
        color: AppPalette.success);
  }

  Future<void> _selectOSkin(String skinId) async {
    if (_busy) return;
    final sw = Stopwatch()..start();
    await LocalStore.setSelectedOSkin(skinId);
    if (!mounted) return;
    setState(() => _selectedOSkin = skinId);
    HapticFeedback.selectionClick();
    debugPrint('[PERF] skin_equip_ms=${sw.elapsedMilliseconds}');
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
                      isX ? 'assets/x/$skinId.webp' : 'assets/o/$skinId.webp',
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
                    Image.asset('assets/coin/COIN.webp',
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
    if (!_canPurchaseCosmetics()) {
      showSignInRequiredDialog(context);
      return;
    }
    if (_ownedAvatars.contains(avatar.id)) {
      if (_equippedAvatar == avatar.id) {
        // Already equipped — tap again to unequip.
        await _equipAvatar(0); // 0 = no avatar equipped
        if (kDebugMode) {
          debugPrint('[STORE] avatar unequipped');
          debugPrint(
              '[PROFILE] selectedAvatar=null, using fallback profile image');
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

    final sw = Stopwatch()..start();
    debugPrint('[PERF] store_buy_start item=${avatar.id}');
    setState(() => _busy = true);
    if (avatar.price > 0) {
      final result = await WalletTransactionService.instance.applyDebit(
        coins: avatar.price,
        transactionId:
            'store_avatar_${LocalStore.uid ?? 'offline'}_${avatar.id}',
        source: 'avatar_purchase',
        title: 'Avatar Purchase',
        message: 'Avatar Purchase: ${avatar.name}',
        itemType: 'avatar',
        itemId: '${avatar.id}',
        assetPath: avatar.assetPath,
      );
      if (!result.success) {
        if (!mounted) return;
        setState(() => _busy = false);
        showTopNotification(context, 'Purchase failed — coins not deducted.',
            color: AppPalette.danger);
        return;
      }
      if (kDebugMode)
        debugPrint(
            '[STORE] purchase source=$_purchaseSource item=avatar:${avatar.id}');
      await MissionService.instance.trackAmount('coins_spent', avatar.price);
    }
    await LocalStore.addOwnedAvatar(avatar.id);
    await LocalStore.setEquippedAvatar(avatar.id);
    await MissionService.instance.trackEvent('avatar_equipped');
    debugPrint('[PERF] store_buy_local_done_ms=${sw.elapsedMilliseconds}');
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    HapticFeedback.mediumImpact();
    debugPrint('[PERF] store_buy_ui_updated_ms=${sw.elapsedMilliseconds}');
    showTopNotification(context, 'Purchased ${avatar.name}!',
        color: AppPalette.success);
  }

  Future<void> _equipAvatar(int id) async {
    if (_busy) return;
    final sw = Stopwatch()..start();
    await LocalStore.setEquippedAvatar(id);
    if (id != 0) {
      await MissionService.instance.trackEvent('avatar_equipped');
    }
    if (!mounted) return;
    setState(() => _equippedAvatar = id);
    HapticFeedback.selectionClick();
    debugPrint('[PERF] avatar_equip_ms=${sw.elapsedMilliseconds}');
    final l10n = AppL10n.of(context);
    if (id == 0) {
      showTopNotification(context, l10n.avatarUnequipped,
          color: AppPalette.textMuted);
    } else {
      showTopNotification(
          context, '${gameAvatarById(id).name} ${l10n.storeEquipped}!',
          color: AppPalette.success);
    }
  }

  // ── Emoji store actions ──────────────────────────────────────────────────

  Future<void> _buyEmoji(GameEmoji emoji) async {
    if (_busy) return;
    final l10n = AppL10n.of(context);
    if (!_canPurchaseCosmetics()) {
      showSignInRequiredDialog(context);
      return;
    }
    // Free or already owned → treat the tap as an equip request.
    if (emoji.isFree || _ownedEmojis.contains(emoji.id)) {
      await _equipEmoji(emoji.id);
      return;
    }
    if (_coins < emoji.priceCoins) {
      _showInsufficientCoinsDialog(context, emoji.priceCoins, _coins);
      return;
    }
    // Confirmation BEFORE any coin deduction.
    final confirmed = await _showEmojiPurchaseConfirmDialog(
      context: context,
      emoji: emoji,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await WalletTransactionService.instance.applyDebit(
        coins: emoji.priceCoins,
        transactionId: 'store_emoji_${LocalStore.uid ?? 'offline'}_${emoji.id}',
        source: 'emoji_purchase',
        title: 'Emoji Purchase',
        message: 'Emoji Purchase: ${emoji.id}',
        itemType: 'emoji',
        itemId: emoji.id,
        assetPath: EmojiCatalog.assetPathOf(emoji.id),
      );
      if (!result.success) {
        if (!mounted) return;
        setState(() => _busy = false);
        showTopNotification(context, 'Purchase failed — coins not deducted.',
            color: AppPalette.danger);
        return;
      }
      await MissionService.instance
          .trackAmount('coins_spent', emoji.priceCoins);
      await LocalStore.addOwnedEmoji(emoji.id);
      // Auto-equip into a free slot if one is available.
      if (_equippedEmojis.length < EmojiCatalog.maxEquipped) {
        await LocalStore.equipEmoji(emoji.id);
      }
      await _load();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showTopNotification(context, l10n.emojiPurchased,
          color: AppPalette.success);
    } catch (e) {
      if (kDebugMode) debugPrint('[STORE] emoji purchase error: $e');
      if (mounted) {
        showTopNotification(context, l10n.somethingWentWrong,
            color: AppPalette.danger);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showEmojiPurchaseConfirmDialog({
    required BuildContext context,
    required GameEmoji emoji,
  }) {
    final l10n = AppL10n.of(context);
    final path = EmojiCatalog.assetPathOf(emoji.id);
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
                  child: path == null
                      ? const Icon(Icons.emoji_emotions_outlined,
                          color: Colors.white24, size: 48)
                      : Image.asset(path,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.confirmPurchaseTitle,
                  style: safeOrbitron(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: AppPalette.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.emojiPurchaseLabel,
                  style: safeOrbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/coin/COIN.webp',
                        height: 18, fit: BoxFit.contain),
                    const SizedBox(width: 6),
                    Text(
                      '${emoji.priceCoins} coins',
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
                        label: l10n.cancelBtn,
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(context, false),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: l10n.confirmBtn,
                        fill: AppPalette.success,
                        stroke: AppPalette.success.withOpacity(0.55),
                        onPressed: () => Navigator.pop(context, true),
                        icon: Icons.shopping_bag_rounded,
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

  Future<void> _equipEmoji(String id) async {
    if (_busy) return;
    final l10n = AppL10n.of(context);
    // Guard the "slots full" case with a friendly message.
    if (!_equippedEmojis.contains(id) &&
        _equippedEmojis.length >= EmojiCatalog.maxEquipped) {
      showTopNotification(context, l10n.emojiSlotsFull,
          color: AppPalette.warning);
      return;
    }
    await LocalStore.equipEmoji(id);
    await _load();
    if (!mounted) return;
    HapticFeedback.selectionClick();
    showTopNotification(context, l10n.emojiEquipped, color: AppPalette.success);
  }

  Future<void> _unequipEmoji(String id) async {
    if (_busy) return;
    await LocalStore.unequipEmoji(id);
    await _load();
    if (!mounted) return;
    HapticFeedback.selectionClick();
  }

  Future<void> _equipEmojiToSlot(int slot, String id) async {
    if (_busy) return;
    await LocalStore.equipEmoji(id, slot: slot);
    await _load();
    if (!mounted) return;
    HapticFeedback.selectionClick();
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
            onTabSelected: (i) => setState(() {
              _selectedTab = i;
              if (i == 1) _avatarTabVisited = true;
              if (i == 3) _emojiTabVisited = true;
            }),
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
              _avatarTabVisited
                  ? AvatarStoreTab(
                      ownedAvatars: _ownedAvatars,
                      equippedAvatar: _equippedAvatar,
                      busy: _busy,
                      onBuyAvatar: _buyAvatar,
                      onEquipAvatar: _equipAvatar,
                    )
                  : const SizedBox.shrink(),
              const CoinsScreen(),
              _emojiTabVisited
                  ? EmojiStoreTab(
                      ownedEmojis: _ownedEmojis,
                      equippedEmojis: _equippedEmojis,
                      busy: _busy,
                      coins: _coins,
                      onBuyEmoji: _buyEmoji,
                      onEquipEmoji: _equipEmoji,
                      onUnequipEmoji: _unequipEmoji,
                      onEquipToSlot: _equipEmojiToSlot,
                    )
                  : const SizedBox.shrink(),
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
                padding: const EdgeInsets.fromLTRB(14, 6, 18, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => navigateToHomeHub(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _storeHeaderTitle(l10n),
                              style: titleFont(context).copyWith(fontSize: 22),
                            ),
                            const SizedBox(height: 3),
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
    // Category image tiles. The finished art (assets/e1..e4.webp) already
    // carries its own neon border + label, so the tiles add no frame — only a
    // subtle green/cyan highlight on the selected one.
    //   e1 = XO/Colors (index 0), e3 = Avatars (index 1),
    //   e2 = Emoji (index 3),      e4 = Coins   (index 2).
    final tiles = <_StoreCategory>[
      _StoreCategory(0, 'assets/e1.webp', l10n.xAndOColorsTab),
      _StoreCategory(1, 'assets/e3.webp', l10n.avatarGalleryTab),
      _StoreCategory(3, 'assets/e2.webp', l10n.emojiTabShort),
      _StoreCategory(2, 'assets/e4.webp', l10n.buyCoins),
    ];

    return Container(
      height: 106,
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
      decoration: BoxDecoration(
        color: AppPalette.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.08),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: StoreCategoryImageTile(
                assetPath: tiles[i].assetPath,
                selected: selectedIndex == tiles[i].index,
                semanticLabel: tiles[i].label,
                label: const ['XO', 'Avatar', 'Emoji', 'Coins'][i],
                onTap: () => onTabSelected(tiles[i].index),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoreCategory {
  final int index;
  final String assetPath;
  final String label;
  const _StoreCategory(this.index, this.assetPath, this.label);
}

/// ==========================
///   COINS HISTORY PAGE
/// ==========================
