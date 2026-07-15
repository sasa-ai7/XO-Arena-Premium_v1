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
    this.previewScale = 0.82,
    // Frame is drawn at the box size that the analyzer measured the hole in, so
    // it MUST stay 1.0 — any other scale shifts the opening away from the
    // composited photo and the avatar looks misaligned.
    this.frameScale = 1.0,
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
/// 2026-07 — the catalog was rebuilt around the new WebP frame art. Id 8 is a
/// real avatar again (Avatar__8.webp), so no ids are currently removed. Kept as
/// an extension point for future retirements.
const Set<int> kRemovedAvatarIds = <int>{};

/// Returns true when the given value (int id or string path/id) refers to an
/// avatar that has been removed from the catalog. Accepts ints, numeric
/// strings, and asset paths — useful for sanitizing legacy RTDB values where
/// `selectedAvatar` might be stored as any of those.
bool isRemovedAvatar(Object? value) {
  if (value == null) return false;
  if (value is num) return kRemovedAvatarIds.contains(value.toInt());
  final s = value.toString();
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
  return kGameAvatars.any((avatar) => avatar.id == id) ? id : 0;
}

/// Parses the numeric avatar IDs written by current and legacy room clients.
/// Unknown, removed, and malformed values resolve to 0 (no frame).
int parseEquippedAvatarId(Object? value) {
  if (value == null) return 0;
  if (value is num) return sanitizeEquippedAvatarId(value.toInt());

  final raw = value.toString().trim();
  final directId = int.tryParse(raw);
  if (directId != null) return sanitizeEquippedAvatarId(directId);

  for (final avatar in kGameAvatars) {
    if (raw == avatar.assetPath ||
        raw == 'avatar_${avatar.id}' ||
        raw == 'premium_avatar_${avatar.id}') {
      return avatar.id;
    }
  }
  return 0;
}

/// Resolves a room/cache value directly to its catalog frame metadata.
GameAvatar? gameAvatarFromStoredValue(Object? value) =>
    gameAvatarByIdOrNull(parseEquippedAvatarId(value));

// Catalog rebuilt 2026-07 around the new WebP frame art. Coin avatars
// (ids 1–17) are listed first, premium IAP avatars (ids 29, 30) last, so the
// store's 2-col grid groups them. All frames are transparent-center rings; the
// profile photo is composited into the hole detected at runtime by
// [AvatarAnalyzerService]. The per-avatar `innerCircleScale` / `verticalOffset`
// fine-tune that fit; a handful of off-centre frames also have an explicit
// override entry in the analyzer (see `_assetDimensionOverrides`).
//
//   * ids 29, 30 — premium IAP (Golden Halo / Star Crown), unlocked via the
//     `xo_avatar_premium` / `xo_avatar_premium1` products (NOT coins). See
//     [CoinsCatalog]. `price` is display-only.
//   * id 7 (Riot) — a normal coin avatar that is ALSO granted for free by the
//     7-day-login milestone mission (`milestone_login_7day`). Whichever comes
//     first wins; ownership is a set so it never double-grants.
const List<GameAvatar> kGameAvatars = [
  GameAvatar(
      id: 1,
      name: 'Classic',
      assetPath: 'assets/avatar/Avatar__1.webp',
      price: 13000,
      isGif: false),
  GameAvatar(
      id: 2,
      name: 'Echo',
      assetPath: 'assets/avatar/Avatar__2.webp',
      price: 10000,
      isGif: false),
  GameAvatar(
      id: 3,
      name: 'Titan',
      assetPath: 'assets/avatar/Avatar__3.webp',
      price: 16000,
      isGif: false),
  GameAvatar(
      id: 4,
      name: 'Frost',
      assetPath: 'assets/avatar/Avatar__4.webp',
      price: 9000,
      isGif: false),
  GameAvatar(
      id: 5,
      name: 'Storm',
      assetPath: 'assets/avatar/Avatar__5.webp',
      price: 15000,
      isGif: false),
  GameAvatar(
      id: 6,
      name: 'Phantom',
      assetPath: 'assets/avatar/Avatar__6.webp',
      price: 20000,
      isGif: false),
  GameAvatar(
      id: 7,
      name: 'Riot',
      assetPath: 'assets/avatar/Avatar__7.webp',
      price: 12000,
      isGif: false),
  GameAvatar(
      id: 8,
      name: 'Fable',
      assetPath: 'assets/avatar/Avatar__8.webp',
      price: 14000,
      isGif: false),
  GameAvatar(
      id: 9,
      name: 'Eclipse',
      assetPath: 'assets/avatar/Avatar__9.webp',
      price: 30000,
      isGif: false),
  GameAvatar(
      id: 10,
      name: 'Vortex',
      assetPath: 'assets/avatar/Avatar__10.webp',
      price: 22000,
      isGif: false),
  GameAvatar(
      id: 11,
      name: 'Hex',
      assetPath: 'assets/avatar/Avatar__11.webp',
      price: 18000,
      isGif: false),
  GameAvatar(
      id: 12,
      name: 'Honey',
      assetPath: 'assets/avatar/Avatar__12.webp',
      price: 11000,
      isGif: false),
  GameAvatar(
      id: 13,
      name: 'Bloom',
      assetPath: 'assets/avatar/Avatar__13.webp',
      price: 17000,
      isGif: false),
  GameAvatar(
      id: 14,
      name: 'Aureus',
      assetPath: 'assets/avatar/Avatar__14.webp',
      price: 19000,
      isGif: false),
  GameAvatar(
      id: 15,
      name: 'Onyx',
      assetPath: 'assets/avatar/Avatar__15.webp',
      price: 21000,
      isGif: false),
  GameAvatar(
      id: 16,
      name: 'Ember',
      assetPath: 'assets/avatar/Avatar__16.webp',
      price: 26000,
      isGif: false),
  GameAvatar(
      id: 17,
      name: 'Ronin',
      assetPath: 'assets/avatar/Avatar__17.webp',
      price: 28000,
      isGif: false),
  // ── Premium IAP avatars (real-money, not coins) ─────────────────────────
  GameAvatar(
      id: 29,
      name: 'Golden Halo',
      assetPath: 'assets/avatar/Avatar__29.webp',
      price: 0,
      isGif: false,
      isPremiumIap: true),
  GameAvatar(
      id: 30,
      name: 'Star Crown',
      assetPath: 'assets/avatar/Avatar__30.webp',
      price: 0,
      isGif: false,
      isPremiumIap: true),
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
