/// Product catalog for coin purchases.
/// Product IDs must match exactly what's configured in Google Play Console.
// CATALOG_SYNC: 2026-03-23 | 10 packs | 200,400,600,800,1000,2000,3000,5000,10000,20000
class CoinsCatalog {
  /// All available product IDs for coin packs.
  static const List<String> productIds = [
    'coins_pack_200',
    'coins_pack_400',
    'coins_pack_600',
    'coins_pack_800',
    'coins_pack_1000',
    'coins_pack_2000',
    'coins_pack_3000',
    'coins_pack_5000',
    'coins_pack_10000',
    'coins_pack_20000',
  ];

  /// Get the coin amount for a given product ID.
  /// Returns 0 if product ID is not recognized.
  static int coinsForProductId(String productId) {
    switch (productId) {
      case 'coins_pack_200':
        return 200;
      case 'coins_pack_400':
        return 400;
      case 'coins_pack_600':
        return 600;
      case 'coins_pack_800':
        return 800;
      case 'coins_pack_1000':
        return 1000;
      case 'coins_pack_2000':
        return 2000;
      case 'coins_pack_3000':
        return 3000;
      case 'coins_pack_5000':
        return 5000;
      case 'coins_pack_10000':
        return 10000;
      case 'coins_pack_20000':
        return 20000;
      default:
        return 0;
    }
  }

  /// Check if a product ID is valid.
  static bool isValidProductId(String productId) {
    return productIds.contains(productId);
  }

  /// Maximum number of times each product can be purchased.
  static const Map<String, int> purchaseLimits = {
    'coins_pack_200': 5,
    'coins_pack_400': 5,
    'coins_pack_600': 5,
    'coins_pack_800': 5,
    'coins_pack_1000': 3,
    'coins_pack_2000': 3,
    'coins_pack_3000': 3,
    'coins_pack_5000': 2,
    'coins_pack_10000': 2,
    'coins_pack_20000': 1,
  };

  /// Get the purchase limit for a product. Defaults to 10 if not listed.
  static int maxPurchasesFor(String productId) =>
      purchaseLimits[productId] ?? 10;
}
