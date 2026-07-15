import 'package:flutter/foundation.dart';

/// A single purchasable / equippable gameplay emoji.
///
/// Emojis are rendered from WebP art under `assets/emoji/`. Note that some
/// bundled art may carry mismatched byte signatures vs. their extension — always
/// decode through `Image.asset` (Flutter sniffs the codec) and never assume the
/// file extension equals the codec.
@immutable
class GameEmoji {
  /// Stable, network-safe id. Must match `^[a-z0-9_]{1,40}$` because it is sent
  /// as the RTDB reaction payload and validated by `database.rules.json`.
  final String id;

  /// Exact filename inside `assets/emoji/` (may contain spaces / parentheses).
  final String assetFile;

  /// Price in coins. `0` means free (implicitly owned by everyone).
  final int priceCoins;

  const GameEmoji({
    required this.id,
    required this.assetFile,
    required this.priceCoins,
  });

  bool get isFree => priceCoins <= 0;

  String get assetPath => 'assets/emoji/$assetFile';
}

/// The full XO Arena emoji catalog — the single source of truth for prices,
/// asset mapping and validation. Replaces the old hardcoded Unicode reaction
/// list (`kArenaQuickEmojis`).
class EmojiCatalog {
  EmojiCatalog._();

  /// Maximum emojis a player can have equipped for gameplay at once.
  static const int maxEquipped = 5;

  /// All catalog emojis in display order (free first, then by price).
  static const List<GameEmoji> all = <GameEmoji>[
    // ── Free defaults (equipped for new players) ──
    GameEmoji(id: 'arena1', assetFile: 'arena1.webp', priceCoins: 0),
    GameEmoji(id: 'arena2', assetFile: 'arena2.webp', priceCoins: 0),
    GameEmoji(id: 'arena3', assetFile: 'arena3.webp', priceCoins: 0),
    GameEmoji(id: 'arena4', assetFile: 'arena4.webp', priceCoins: 0),
    GameEmoji(id: 'arena5', assetFile: 'arena5.webp', priceCoins: 0),

    // ── 1500 coins ──
    GameEmoji(id: 'e512', assetFile: '512.webp', priceCoins: 1500),
    GameEmoji(id: 'e512_1', assetFile: '512 (1).webp', priceCoins: 1500),
    GameEmoji(id: 'e512_2', assetFile: '512 (2).webp', priceCoins: 1500),
    GameEmoji(id: 'e512_3', assetFile: '512 (3).webp', priceCoins: 1500),
    GameEmoji(id: 'e512_4', assetFile: '512 (4).webp', priceCoins: 1500),
    GameEmoji(id: 'e512_5', assetFile: '512 (5).webp', priceCoins: 1500),
    GameEmoji(id: 'e512_6', assetFile: '512 (6).webp', priceCoins: 1500),

    // ── 2500 coins ──
    GameEmoji(id: 'emoji1', assetFile: 'emoji1.webp', priceCoins: 2500),
    GameEmoji(id: 'emoji2', assetFile: 'emoji2.webp', priceCoins: 2500),

    // ── 3000 coins ──
    GameEmoji(id: 'emoji3', assetFile: 'emoji3.webp', priceCoins: 3000),
    GameEmoji(id: 'emoji4', assetFile: 'emoji4.webp', priceCoins: 3000),
    GameEmoji(id: 'emoji5', assetFile: 'emoji5.webp', priceCoins: 3000),
    GameEmoji(id: 'emoji6', assetFile: 'emoji6.webp', priceCoins: 3000),
    GameEmoji(id: 'emoji7', assetFile: 'emoji7.webp', priceCoins: 3000),
  ];

  static final Map<String, GameEmoji> _byId = <String, GameEmoji>{
    for (final e in all) e.id: e,
  };

  /// All catalog ids.
  static List<String> get allIds => all.map((e) => e.id).toList();

  /// Ids of the free emojis (implicitly owned by every player).
  static List<String> get freeIds =>
      all.where((e) => e.isFree).map((e) => e.id).toList();

  /// The 5 emojis new players start with equipped.
  static List<String> get defaultEquipped => freeIds;

  static GameEmoji? byId(String? id) => id == null ? null : _byId[id];

  static bool isValidId(String? id) => id != null && _byId.containsKey(id);

  static bool isFree(String id) => _byId[id]?.isFree ?? false;

  static int priceOf(String id) => _byId[id]?.priceCoins ?? 0;

  /// Resolves an id to its asset path, or null if the id is unknown.
  static String? assetPathOf(String? id) => byId(id)?.assetPath;
}
