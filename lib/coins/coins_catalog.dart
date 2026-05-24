/// Product catalog for in-app purchases.
///
/// All product IDs MUST match exactly what is configured in Google Play
/// Console. Coin packs are consumable and may be purchased repeatedly.
/// Premium avatars are one-time, non-consumable entitlements.
///
/// CATALOG_SYNC: 2026-05-24 — XO Arena rev. shop redesign
/// • 10 coin packs (xo_arena_2000 … xo_arena_200000)
/// • 2 premium avatars (xo_avatar_premium → Inferno, xo_avatar_premium_apex → Apex)
class CoinsCatalog {
  // ── Avatar entitlements ───────────────────────────────────────────────────

  /// Inferno (animated) — one-time premium avatar, $2.99 (orig $4.99).
  static const String premiumAvatarProductId = 'xo_avatar_premium';

  /// Apex (animated) — one-time premium avatar, $3.99 (orig $5.99).
  static const String premiumAvatarApexProductId = 'xo_avatar_premium_apex';

  /// Catalog id of the avatar unlocked by [premiumAvatarProductId] (Inferno).
  static const int premiumAvatarId = 7;

  /// Catalog id of the avatar unlocked by [premiumAvatarApexProductId] (Apex).
  static const int premiumAvatarApexId = 10;

  /// Asset path for the original premium avatar (Inferno).
  static const String premiumAvatarAsset = 'assets/avatar/Avatar__7.gif';

  /// Asset path for the second premium avatar (Apex).
  static const String premiumAvatarApexAsset = 'assets/avatar/Avatar__10.gif';

  /// Server-side entitlement id for Inferno avatar.
  static const String premiumAvatarEntitlement = 'premium_avatar_7';

  /// Server-side entitlement id for Apex avatar.
  static const String premiumAvatarApexEntitlement = 'premium_avatar_10';

  /// Display prices for premium avatar offers, used as a fallback when
  /// Google Play does not return localized pricing for the product yet.
  static const String premiumAvatarFallbackPrice = '\$2.99';
  static const String premiumAvatarApexFallbackPrice = '\$3.99';

  /// Original (pre-discount) price labels — used by the UI for strikethrough.
  static const String premiumAvatarOriginalPrice = '\$4.99';
  static const String premiumAvatarApexOriginalPrice = '\$5.99';

  /// Discount percentages displayed on each offer card.
  static const int premiumAvatarDiscountPct = 40;
  static const int premiumAvatarApexDiscountPct = 33;

  /// All consumable coin pack product IDs.
  static const List<String> coinProductIds = [
    'xo_arena_2000',
    'xo_arena_4000',
    'xo_arena_6000',
    'xo_arena_8000',
    'xo_arena_10000',
    'xo_arena_20000',
    'xo_arena_30000',
    'xo_arena_50000',
    'xo_arena_100000',
    'xo_arena_200000',
  ];

  /// All premium avatar (non-consumable) product IDs.
  static const List<String> avatarProductIds = [
    premiumAvatarProductId,
    premiumAvatarApexProductId,
  ];

  /// All product IDs we query Google Play for — coins + avatars.
  static List<String> get productIds => <String>[
        ...coinProductIds,
        ...avatarProductIds,
      ];

  /// True if [productId] is a premium avatar (non-consumable).
  static bool isAvatarProduct(String productId) =>
      avatarProductIds.contains(productId);

  /// True if [productId] is a recognised consumable coin pack.
  static bool isCoinProduct(String productId) =>
      coinProductIds.contains(productId);

  /// Catalog avatar id for a premium IAP product.
  static int? avatarIdForProductId(String productId) {
    switch (productId) {
      case premiumAvatarProductId:
        return premiumAvatarId;
      case premiumAvatarApexProductId:
        return premiumAvatarApexId;
      default:
        return null;
    }
  }

  /// Server-side entitlement id for a premium IAP product.
  static String? entitlementForProductId(String productId) {
    switch (productId) {
      case premiumAvatarProductId:
        return premiumAvatarEntitlement;
      case premiumAvatarApexProductId:
        return premiumAvatarApexEntitlement;
      default:
        return null;
    }
  }

  /// Catalog avatar id for a server-side entitlement id.
  static int? avatarIdForEntitlement(String entitlement) {
    switch (entitlement) {
      case premiumAvatarEntitlement:
        return premiumAvatarId;
      case premiumAvatarApexEntitlement:
        return premiumAvatarApexId;
      default:
        return null;
    }
  }

  /// Asset path used inside the shop hero card.
  static String avatarAssetForProductId(String productId) {
    switch (productId) {
      case premiumAvatarProductId:
        return premiumAvatarAsset;
      case premiumAvatarApexProductId:
        return premiumAvatarApexAsset;
      default:
        return premiumAvatarAsset;
    }
  }

  /// Total coins (base + bonus) granted for [productId]. Returns 0 if the
  /// product is not a coin pack.
  static int coinsForProductId(String productId) {
    switch (productId) {
      case 'xo_arena_2000':
        return 2000;
      case 'xo_arena_4000':
        return 4000;
      case 'xo_arena_6000':
        return 6000;
      case 'xo_arena_8000':
        return 8000;
      case 'xo_arena_10000':
        return 10000;
      case 'xo_arena_20000':
        return 22000; // 20,000 + 2,000 bonus
      case 'xo_arena_30000':
        return 33000; // 30,000 + 3,000 bonus
      case 'xo_arena_50000':
        return 57500; // 50,000 + 7,500 bonus
      case 'xo_arena_100000':
        return 120000; // 100,000 + 20,000 bonus
      case 'xo_arena_200000':
        return 240000; // 200,000 + 40,000 bonus
      default:
        return 0;
    }
  }

  /// Bonus coins for [productId] (already included in [coinsForProductId]).
  /// Used by the UI to render a "+N bonus" chip.
  static int bonusForProductId(String productId) {
    switch (productId) {
      case 'xo_arena_20000':
        return 2000;
      case 'xo_arena_30000':
        return 3000;
      case 'xo_arena_50000':
        return 7500;
      case 'xo_arena_100000':
        return 20000;
      case 'xo_arena_200000':
        return 40000;
      default:
        return 0;
    }
  }

  /// Base coins (without bonus) for [productId]. Used by the UI to render
  /// the headline coin amount; the bonus is shown as a separate chip.
  static int baseCoinsForProductId(String productId) =>
      coinsForProductId(productId) - bonusForProductId(productId);

  /// Asset path for the coin icon shown on each pack card.
  static String assetForCoinProduct(String productId) {
    switch (productId) {
      case 'xo_arena_2000':
      case 'xo_arena_4000':
        return 'assets/coin/COIN-2.png';
      case 'xo_arena_6000':
      case 'xo_arena_8000':
        return 'assets/coin/COIN-3.png';
      case 'xo_arena_10000':
        return 'assets/coin/COIN-9.png';
      case 'xo_arena_20000':
      case 'xo_arena_30000':
      case 'xo_arena_50000':
        return 'assets/coin/COIN-55.png';
      case 'xo_arena_100000':
      case 'xo_arena_200000':
        return 'assets/coin/COIN-44.png';
      default:
        return 'assets/coin/COIN.png';
    }
  }

  /// Packs that get a gold "MOST POPULAR" / premium-highlight treatment.
  static const Set<String> popularProductIds = <String>{
    'xo_arena_6000',  // $2.99
    'xo_arena_10000', // $4.99
  };

  static bool isPopular(String productId) =>
      popularProductIds.contains(productId);

  /// True if [productId] is a recognised product ID (coin or avatar).
  static bool isValidProductId(String productId) =>
      productIds.contains(productId);
}
