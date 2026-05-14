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

  const GameAvatar({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.price,
    required this.isGif,
    this.previewScale = 0.86,
    this.frameScale = 1.06,
    this.verticalOffset = 0.0,
    this.innerCircleScale = 1.08,
  });
}

// Non-GIF avatars first (sorted by price ascending), then GIF avatars
// (Inferno=50000, Apex=50000, Celestial=60000) so the 2-col grid groups them.
const List<GameAvatar> kGameAvatars = [
  GameAvatar(id: 1, name: 'Classic',   assetPath: 'assets/avatar/Avatar__1.png',  price: 13000, isGif: false),
  GameAvatar(id: 2, name: 'Echo',      assetPath: 'assets/avatar/Avatar_2.png',   price: 10000, isGif: false),
  GameAvatar(id: 3, name: 'Titan',     assetPath: 'assets/avatar/Avatar__3.png',  price: 16000, isGif: false),
  GameAvatar(id: 4, name: 'Frost',     assetPath: 'assets/avatar/Avatar__4.png',  price:  9000, isGif: false),
  GameAvatar(id: 5, name: 'Storm',     assetPath: 'assets/avatar/Avatar__5.png',  price: 15000, isGif: false),
  GameAvatar(id: 6, name: 'Phantom',   assetPath: 'assets/avatar/Avatar__6.png',  price: 20000, isGif: false),
  GameAvatar(id: 9, name: 'Eclipse',   assetPath: 'assets/avatar/Avatar__9.png',  price: 30000, isGif: false),
  GameAvatar(id: 7, name: 'Inferno',   assetPath: 'assets/avatar/Avatar__7.gif',  price: 50000, isGif: true,
      previewScale: 0.66, frameScale: 1.10, verticalOffset: 0.04, innerCircleScale: 1.16),
  GameAvatar(id: 10, name: 'Apex',     assetPath: 'assets/avatar/Avatar__10.gif', price: 50000, isGif: true,
      previewScale: 0.66, frameScale: 1.10, verticalOffset: 0.05, innerCircleScale: 1.18),
  GameAvatar(id: 8, name: 'Celestial', assetPath: 'assets/avatar/Avatar__8.gif',  price: 60000, isGif: true,
      previewScale: 0.67, frameScale: 1.10, verticalOffset: 0.03, innerCircleScale: 1.15),
];

/// Returns the catalog entry for [id] or null if [id] is 0 / not in the
/// catalog. Profile-display call sites MUST use this resolver so that an
/// unequipped or unknown avatar id does NOT fall back to Avatar__1
/// (a paid item).
GameAvatar? gameAvatarByIdOrNull(int id) {
  if (id <= 0) return null;
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
