import 'package:cloud_firestore/cloud_firestore.dart';

import '../coins/coins_catalog.dart';
import 'game_avatar.dart';
import 'game_emoji.dart';

/// Profile data stored in Firestore.
class UserProfile {
  final String name;
  final String email;
  final String provider; // "email" | "google"
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool? welcomeGiftClaimed;
  final String? photoURL;
  final String? characterType; // 'male' | 'female'
  final bool? ageVerified;
  final bool? minimumAgePassed;
  final DateTime? ageVerifiedAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.name,
    required this.email,
    required this.provider,
    this.createdAt,
    this.lastLoginAt,
    this.welcomeGiftClaimed,
    this.photoURL,
    this.characterType,
    this.ageVerified,
    this.minimumAgePassed,
    this.ageVerifiedAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'provider': provider,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (lastLoginAt != null)
          'lastLoginAt': Timestamp.fromDate(lastLoginAt!),
        if (welcomeGiftClaimed != null)
          'welcomeGiftClaimed': welcomeGiftClaimed,
        if (photoURL != null) 'photoURL': photoURL,
        if (characterType != null) 'characterType': characterType,
        if (ageVerified != null) 'ageVerified': ageVerified,
        if (minimumAgePassed != null) 'minimumAgePassed': minimumAgePassed,
        if (ageVerifiedAt != null)
          'ageVerifiedAt': Timestamp.fromDate(ageVerifiedAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };

  factory UserProfile.fromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return const UserProfile(name: 'PLAYER', email: '', provider: 'email');
    }
    return UserProfile(
      name: m['name'] as String? ?? 'PLAYER',
      email: m['email'] as String? ?? '',
      provider: m['provider'] as String? ?? 'email',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (m['lastLoginAt'] as Timestamp?)?.toDate(),
      welcomeGiftClaimed: m['welcomeGiftClaimed'] as bool?,
      photoURL: m['photoURL'] as String?,
      characterType: m['characterType'] as String?,
      ageVerified: m['ageVerified'] as bool?,
      minimumAgePassed: m['minimumAgePassed'] as bool?,
      ageVerifiedAt: (m['ageVerifiedAt'] as Timestamp?)?.toDate(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Wallet data.
class UserWallet {
  final int coins;

  const UserWallet({this.coins = 0});

  Map<String, dynamic> toMap() => {'coins': coins};

  factory UserWallet.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const UserWallet();
    return UserWallet(
      coins: (m['coins'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Game statistics.
class UserStats {
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;

  const UserStats({
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
  });

  Map<String, dynamic> toMap() => {
        'gamesPlayed': gamesPlayed,
        'wins': wins,
        'losses': losses,
        'draws': draws,
      };

  factory UserStats.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const UserStats();
    return UserStats(
      gamesPlayed: (m['gamesPlayed'] as num?)?.toInt() ?? 0,
      wins: (m['wins'] as num?)?.toInt() ?? 0,
      losses: (m['losses'] as num?)?.toInt() ?? 0,
      draws: (m['draws'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Cosmetics (colors + avatar + XO image skins).
class UserCosmetics {
  final String xColor;
  final String oColor;
  final List<int> ownedXColors;
  final List<int> ownedOColors;
  final int equippedAvatar;
  final List<int> ownedAvatars;
  final List<String> ownedXSkins;
  final List<String> ownedOSkins;
  final String selectedXSkin;
  final String selectedOSkin;
  // Emoji system — catalog ids. Free emojis are implicitly owned; new
  // accounts start with the 5 free emojis equipped (resolved at read time).
  final List<String> ownedEmojis;
  final List<String> equippedEmojis;

  const UserCosmetics({
    required this.xColor,
    required this.oColor,
    this.ownedXColors = const [0],
    this.ownedOColors = const [0],
    // Avatar 1 is a paid store item — new accounts must start with NO
    // equipped avatar and NO owned avatars. The profile UI falls back to
    // the Google photo / character portrait when equippedAvatar == 0.
    this.equippedAvatar = 0,
    this.ownedAvatars = const [],
    this.ownedXSkins = const ['default'],
    this.ownedOSkins = const ['default'],
    this.selectedXSkin = 'default',
    this.selectedOSkin = 'default',
    this.ownedEmojis = const [],
    this.equippedEmojis = const [],
  });

  Map<String, dynamic> toMap() => {
        'xColor': xColor,
        'oColor': oColor,
        'ownedXColors': ownedXColors,
        'ownedOColors': ownedOColors,
        'equippedAvatar': equippedAvatar,
        'ownedAvatars': ownedAvatars,
        'ownedXSkins': ownedXSkins,
        'ownedOSkins': ownedOSkins,
        'selectedXSkin': selectedXSkin,
        'selectedOSkin': selectedOSkin,
        'ownedEmojis': ownedEmojis,
        'equippedEmojis': equippedEmojis,
      };

  factory UserCosmetics.fromMap(Map<String, dynamic>? m) {
    if (m == null) {
      // No Cosmetics map yet — new accounts start with no avatar.
      return const UserCosmetics(
        xColor: 'ffff3b30',
        oColor: 'ff0a84ff',
        ownedXColors: [0],
        ownedOColors: [0],
        equippedAvatar: 0,
        ownedAvatars: [],
        ownedXSkins: ['default'],
        ownedOSkins: ['default'],
        selectedXSkin: 'default',
        selectedOSkin: 'default',
        ownedEmojis: const [],
        equippedEmojis: const [],
      );
    }
    final ownedX = m['ownedXColors'];
    final ownedO = m['ownedOColors'];
    final ownedAvatarsRaw = m['ownedAvatars'];
    final ownedXSkinsRaw = m['ownedXSkins'];
    final ownedOSkinsRaw = m['ownedOSkins'];
    final ownedEmojisRaw = m['ownedEmojis'];
    final equippedEmojisRaw = m['equippedEmojis'];

    List<String> parseEmojiIds(dynamic raw) => raw is List
        ? raw
            .map((e) => e.toString())
            .where(EmojiCatalog.isValidId)
            .toList()
        : const <String>[];

    final parsedOwnedAvatars = ownedAvatarsRaw is List
        ? ownedAvatarsRaw
            .map(parseEquippedAvatarId)
            .where((id) => id > 0)
            .toSet()
            .toList()
        : const <int>[];
    final rawEquipped = parseEquippedAvatarId(m['equippedAvatar']);
    // Sanitize: if the equipped avatar is not actually owned, force 0.
    // Also reset to 0 if the id was removed from the catalog (see
    // [kRemovedAvatarIds] — currently only id 8). The owned list is kept
    // intact so a future re-introduction wouldn't need a re-grant, but the
    // UI never sees the removed id.
    int equipped;
    if (rawEquipped <= 0) {
      equipped = 0;
    } else if (kRemovedAvatarIds.contains(rawEquipped)) {
      equipped = 0;
    } else if (!parsedOwnedAvatars.contains(rawEquipped)) {
      equipped = 0;
    } else {
      equipped = rawEquipped;
    }

    return UserCosmetics(
      xColor: m['xColor'] as String? ?? 'ffff3b30',
      oColor: m['oColor'] as String? ?? 'ff0a84ff',
      ownedXColors: ownedX is List
          ? ownedX.map((e) => (e as num).toInt()).toList()
          : const [0],
      ownedOColors: ownedO is List
          ? ownedO.map((e) => (e as num).toInt()).toList()
          : const [0],
      equippedAvatar: equipped,
      ownedAvatars: parsedOwnedAvatars,
      ownedXSkins: ownedXSkinsRaw is List
          ? ownedXSkinsRaw.map((e) => e.toString()).toList()
          : const ['default'],
      ownedOSkins: ownedOSkinsRaw is List
          ? ownedOSkinsRaw.map((e) => e.toString()).toList()
          : const ['default'],
      selectedXSkin: m['selectedXSkin'] as String? ?? 'default',
      selectedOSkin: m['selectedOSkin'] as String? ?? 'default',
      ownedEmojis: parseEmojiIds(ownedEmojisRaw),
      equippedEmojis: parseEmojiIds(equippedEmojisRaw),
    );
  }
}

/// Progress (level game).
class UserProgress {
  final int levelGameCurrentLevel;
  final bool levelGameCompleted;

  const UserProgress({
    this.levelGameCurrentLevel = 1,
    this.levelGameCompleted = false,
  });

  Map<String, dynamic> toMap() => {
        'levelGameCurrentLevel': levelGameCurrentLevel,
        'levelGameCompleted': levelGameCompleted,
      };

  factory UserProgress.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const UserProgress();
    return UserProgress(
      levelGameCurrentLevel: (m['levelGameCurrentLevel'] as num?)?.toInt() ?? 1,
      levelGameCompleted: m['levelGameCompleted'] as bool? ?? false,
    );
  }
}

/// Transaction record for top-up history.
/// [type] is one of: 'win' | 'loss' | 'recharge'.
/// Legacy values 'purchase' and 'deduction' are mapped in [fromMap].
class TransactionRecord {
  final double usd;
  final int coins;
  final String type; // 'win' | 'loss' | 'recharge'
  final DateTime createdAt;
  final int? balanceBefore;
  final int? balanceAfter;
  final String? description;

  const TransactionRecord({
    required this.usd,
    required this.coins,
    required this.type,
    required this.createdAt,
    this.balanceBefore,
    this.balanceAfter,
    this.description,
  });

  /// Map legacy Firestore type values to new type system.
  static String mapLegacyType(String raw) {
    switch (raw) {
      case 'purchase':
        return 'recharge';
      case 'deduction':
        return 'loss';
      default:
        return raw;
    }
  }

  Map<String, dynamic> toMap() => {
        'usd': usd,
        'coins': coins,
        'type': type,
        'createdAt': Timestamp.fromDate(createdAt),
        if (balanceBefore != null) 'balanceBefore': balanceBefore,
        if (balanceAfter != null) 'balanceAfter': balanceAfter,
        if (description != null) 'description': description,
      };

  factory TransactionRecord.fromMap(Map<String, dynamic> m) {
    final rawType = m['type'] as String? ?? 'purchase';
    return TransactionRecord(
      usd: (m['usd'] as num?)?.toDouble() ?? 0,
      coins: (m['coins'] as num?)?.toInt() ?? 0,
      type: mapLegacyType(rawType),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      balanceBefore: (m['balanceBefore'] as num?)?.toInt() ??
          (m['previousBalance'] as num?)?.toInt(),
      balanceAfter: (m['balanceAfter'] as num?)?.toInt(),
      description: m['description'] as String?,
    );
  }

  Map<String, dynamic> toHistoryEntry() => {
        'dateTime': createdAt,
        'usd': usd,
        'coins': coins,
        'type': type,
        if (balanceBefore != null) 'balanceBefore': balanceBefore,
        if (balanceAfter != null) 'balanceAfter': balanceAfter,
        if (description != null) 'description': description,
      };
}

/// App settings — the only map the client is allowed to write in Firestore.
class UserSettings {
  final bool musicEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const UserSettings({
    this.musicEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  Map<String, dynamic> toMap() => {
        'musicEnabled': musicEnabled,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
      };

  factory UserSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const UserSettings();
    return UserSettings(
      musicEnabled: m['musicEnabled'] as bool? ?? true,
      soundEnabled: m['soundEnabled'] as bool? ?? true,
      vibrationEnabled: m['vibrationEnabled'] as bool? ?? true,
    );
  }
}

/// Aggregate user data from Firestore.
class UserData {
  final UserProfile profile;
  final UserWallet wallet;
  final UserStats stats;
  final UserCosmetics cosmetics;
  final UserProgress progress;
  final UserSettings settings;

  const UserData({
    required this.profile,
    required this.wallet,
    required this.stats,
    required this.cosmetics,
    required this.progress,
    this.settings = const UserSettings(),
  });

  /// Merge the server `Cosmetics` map with `Inventory.avatars` entitlements so
  /// premium-IAP avatars (written to Inventory by the Cloud Function) are
  /// treated as owned by the cosmetics pipeline. Returns a plain map suitable
  /// for [UserCosmetics.fromMap].
  static Map<String, dynamic> _mergeUserCosmetics({
    required Object? cosmeticsRaw,
    required Object? inventoryRaw,
  }) {
    final cosmetics = <String, dynamic>{
      if (cosmeticsRaw is Map)
        for (final entry in cosmeticsRaw.entries)
          entry.key.toString(): entry.value,
    };

    // Collect entitlement-derived avatar ids from Inventory.avatars.
    final inventoryAvatars =
        (inventoryRaw is Map) ? inventoryRaw['avatars'] : null;
    if (inventoryAvatars is List) {
      final entitlementIds = <int>{};
      for (final e in inventoryAvatars) {
        final id = CoinsCatalog.avatarIdForEntitlement(e.toString());
        if (id != null) entitlementIds.add(id);
      }
      if (entitlementIds.isNotEmpty) {
        final owned = <int>{};
        final existing = cosmetics['ownedAvatars'];
        if (existing is List) {
          for (final v in existing) {
            final n = v is int ? v : int.tryParse(v.toString());
            if (n != null) owned.add(n);
          }
        }
        owned.addAll(entitlementIds);
        cosmetics['ownedAvatars'] = owned.toList()..sort();
      }
    }
    return cosmetics;
  }

  factory UserData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final cosmeticsMap = _mergeUserCosmetics(
      cosmeticsRaw: data['Cosmetics'],
      inventoryRaw: data['Inventory'],
    );
    return UserData(
      profile: UserProfile.fromMap(data['Profile'] as Map<String, dynamic>?),
      wallet: UserWallet.fromMap(data['Wallet'] as Map<String, dynamic>?),
      stats: UserStats.fromMap(data['Stats'] as Map<String, dynamic>?),
      cosmetics: UserCosmetics.fromMap(cosmeticsMap),
      progress: UserProgress.fromMap(data['Progress'] as Map<String, dynamic>?),
      settings: UserSettings.fromMap(data['Settings'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'Profile': profile.toMap(),
        'Wallet': wallet.toMap(),
        'Stats': stats.toMap(),
        'Cosmetics': cosmetics.toMap(),
        'Progress': progress.toMap(),
        'Settings': settings.toMap(),
      };
}
