class GameAvatar {
  final int id;
  final String name;
  final String assetPath;
  final int price;
  final bool isGif;
  final double previewScale;
  final double frameScale;
  final double verticalOffset;
  final double innerCircleScale;

  /// When true, this avatar is unlocked via a Google Play IAP entitlement
  /// (e.g. `xo_avatar_premium`) — NOT via the coin shop. `price` is then
  /// shown for display only; the gallery routes the buy button to the IAP
  /// flow instead of debiting coins.
  final bool isPremiumIap;

  const GameAvatar({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.price,
    required this.isGif,
    this.isPremiumIap = false,
    this.previewScale = 0.86,
    this.frameScale = 1.06,
    this.verticalOffset = 0.0,
    this.innerCircleScale = 1.08,
  });
}

/// Avatar IDs that were once part of the catalog and are now permanently
/// removed. Used by:
///   * [gameAvatarByIdOrNull] — defensive null return.
///   * [UserCosmetics.fromMap] — sanitizes a legacy `equippedAvatar`.
///   * [LocalStore.initCoinsNotifier] — resets stale SharedPreferences value.
///   * [loadArenaPlayerCosmetics] — never writes a removed ID into the room.
///
/// 2026-05-24 — id 7 (Inferno / Avatar__7.gif) was re-added as the
/// `xo_avatar_premium` IAP entitlement. id 8 remains permanently removed.
const Set<int> kRemovedAvatarIds = <int>{8};

/// Returns true when the given value (int id or string path/id) refers to an
/// avatar that has been removed from the catalog. Accepts ints, numeric
/// strings, and asset paths — useful for sanitizing legacy RTDB values where
/// `selectedAvatar` might be stored as any of those.
bool isRemovedAvatar(Object? value) {
  if (value == null) return false;
  if (value is num) return kRemovedAvatarIds.contains(value.toInt());
  final s = value.toString();
  if (s.contains('Avatar__7.gif')) return true;
  if (s.contains('Avatar__8.gif')) return true;
  final asInt = int.tryParse(s);
  if (asInt != null) return kRemovedAvatarIds.contains(asInt);
  return false;
}

/// Sanitize a stored avatar id: returns 0 if the id has been removed from
/// the catalog or is otherwise invalid. Use this whenever a legacy stored
/// value flows into the equipped-avatar pipeline.
int sanitizeEquippedAvatarId(int id) {
  if (id <= 0) return 0;
  if (kRemovedAvatarIds.contains(id)) return 0;
  return id;
}

// Non-GIF avatars first (sorted by price ascending), then GIF avatars
// (Apex=50000, Inferno=premium-IAP) so the 2-col grid groups them. Id 7
// (Inferno) is the premium IAP avatar — gated by the `xo_avatar_premium`
// entitlement, NOT purchasable with coins. Id 8 remains permanently
// removed — see [kRemovedAvatarIds] above for the safe-fallback contract.
const List<GameAvatar> kGameAvatars = [
  GameAvatar(id: 1, name: 'Classic',   assetPath: 'assets/avatar/Avatar__1.png',  price: 13000, isGif: false),
  GameAvatar(id: 2, name: 'Echo',      assetPath: 'assets/avatar/Avatar_2.png',   price: 10000, isGif: false),
  GameAvatar(id: 3, name: 'Titan',     assetPath: 'assets/avatar/Avatar__3.png',  price: 16000, isGif: false),
  GameAvatar(id: 4, name: 'Frost',     assetPath: 'assets/avatar/Avatar__4.png',  price:  9000, isGif: false),
  GameAvatar(id: 5, name: 'Storm',     assetPath: 'assets/avatar/Avatar__5.png',  price: 15000, isGif: false),
  GameAvatar(id: 6, name: 'Phantom',   assetPath: 'assets/avatar/Avatar__6.png',  price: 20000, isGif: false),
  GameAvatar(id: 9, name: 'Eclipse',   assetPath: 'assets/avatar/Avatar__9.png',  price: 30000, isGif: false),
  // Apex was previously coin-priced (50,000 coins). It is now a premium
  // IAP entitlement (xo_avatar_premium1) shown in the coin shop's
  // featured avatar carousel. Users who already purchased it with coins
  // keep it in their ownedAvatars list — the gallery treats them as
  // owners and never re-charges.
  GameAvatar(id: 10, name: 'Apex',     assetPath: 'assets/avatar/Avatar__10.gif', price: 0, isGif: true,
      isPremiumIap: true,
      previewScale: 0.66, frameScale: 1.08, verticalOffset: 0.02, innerCircleScale: 1.0),
  // Inferno — unlocked via xo_avatar_premium (one-time IAP). The gallery
  // surfaces this as a locked card with a "Premium" badge until the
  // entitlement lands in Inventory.avatars.
  GameAvatar(id: 7, name: 'Inferno',   assetPath: 'assets/avatar/Avatar__7.gif',  price: 0, isGif: true,
      isPremiumIap: true,
      previewScale: 0.66, frameScale: 1.08, verticalOffset: 0.02, innerCircleScale: 1.0),
];

/// Returns the catalog entry for [id] or null if [id] is 0, removed, or not
/// in the catalog. Profile-display call sites MUST use this resolver so that
/// an unequipped, unknown, or removed avatar id does NOT fall back to
/// Avatar__1 (a paid item).
GameAvatar? gameAvatarByIdOrNull(int id) {
  if (id <= 0) return null;
  if (kRemovedAvatarIds.contains(id)) return null;
  for (final avatar in kGameAvatars) {
    if (avatar.id == id) return avatar;
  }
  return null;
}

/// Catalog lookup for known-valid ids (e.g. store item cards). Throws if
/// the id is missing — callers in profile/UI surfaces should use
/// [gameAvatarByIdOrNull] and treat null as "no frame".
GameAvatar gameAvatarById(int id) {
  final found = gameAvatarByIdOrNull(id);
  if (found != null) return found;
  throw StateError('gameAvatarById: unknown avatar id=$id');
}
