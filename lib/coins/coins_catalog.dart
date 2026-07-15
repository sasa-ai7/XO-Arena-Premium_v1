/// Product catalog for in-app purchases.
///
/// All product IDs MUST match exactly what is configured in Google Play
/// Console. Coin packs are consumable and may be purchased repeatedly.
/// Premium avatars are one-time, non-consumable entitlements.
///
/// CATALOG_SYNC: 2026-07 — premium avatars repointed to the new WebP art.
/// The two Google Play products are UNCHANGED (`xo_avatar_premium`,
/// `xo_avatar_premium1`); only the catalog id / asset they unlock changed.
/// • 10 coin packs (xo_arena_2000 … xo_arena_200000)
/// • 2 premium avatars (xo_avatar_premium → Golden Halo, xo_avatar_premium1 → Star Crown)
class CoinsCatalog {
  // ── Avatar entitlements ───────────────────────────────────────────────────

  /// Golden Halo — one-time premium avatar, $2.99 (orig $4.99).
  static const String premiumAvatarProductId = 'xo_avatar_premium';

  /// Star Crown — one-time premium avatar, $3.99 (orig $5.99).
  /// Product id matches Google Play Console (`xo_avatar_premium1`).
  static const String premiumAvatarApexProductId = 'xo_avatar_premium1';

  /// Catalog id of the avatar unlocked by [premiumAvatarProductId] (Golden Halo).
  static const int premiumAvatarId = 29;

  /// Catalog id of the avatar unlocked by [premiumAvatarApexProductId] (Star Crown).
  static const int premiumAvatarApexId = 30;

  /// Asset path for the first premium avatar (Golden Halo).
  static const String premiumAvatarAsset = 'assets/avatar/Avatar__29.webp';

  /// Asset path for the second premium avatar (Star Crown).
  static const String premiumAvatarApexAsset = 'assets/avatar/Avatar__30.webp';

  /// Server-side entitlement id for the first premium avatar.
  static const String premiumAvatarEntitlement = 'premium_avatar_29';

  /// Server-side entitlement id for the second premium avatar.
  static const String premiumAvatarApexEntitlement = 'premium_avatar_30';

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

  /// Catalog avatar id for a server-side entitlement id. Legacy entitlement
  /// strings (`premium_avatar_7` / `premium_avatar_10`) from the pre-2026-07
  /// catalog are still recognised and resolve to the current premium avatars so
  /// any earlier purchaser keeps a premium frame.
  static int? avatarIdForEntitlement(String entitlement) {
    switch (entitlement) {
      case premiumAvatarEntitlement:
      case 'premium_avatar_7':
        return premiumAvatarId;
      case premiumAvatarApexEntitlement:
      case 'premium_avatar_10':
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
        return 20000;
      case 'xo_arena_30000':
        return 30000;
      case 'xo_arena_50000':
        return 52500; // 50,000 + 2,500 bonus
      case 'xo_arena_100000':
        return 107500; // 100,000 + 7,500 bonus
      case 'xo_arena_200000':
        return 220000; // 200,000 + 20,000 bonus
      default:
        return 0;
    }
  }

  /// Bonus coins for [productId] (already included in [coinsForProductId]).
  /// Used by the UI to render a "+N bonus" chip.
  static int bonusForProductId(String productId) {
    switch (productId) {
      case 'xo_arena_50000':
        return 2500;
      case 'xo_arena_100000':
        return 7500;
      case 'xo_arena_200000':
        return 20000;
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
        return 'assets/coin/COIN-2.webp';
      case 'xo_arena_6000':
      case 'xo_arena_8000':
        return 'assets/coin/COIN-3.webp';
      case 'xo_arena_10000':
        return 'assets/coin/COIN-9.webp';
      case 'xo_arena_20000':
      case 'xo_arena_30000':
      case 'xo_arena_50000':
        return 'assets/coin/COIN-55.webp';
      case 'xo_arena_100000':
      case 'xo_arena_200000':
        return 'assets/coin/COIN-44.webp';
      default:
        return 'assets/coin/COIN.webp';
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
