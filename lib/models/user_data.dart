import 'package:cloud_firestore/cloud_firestore.dart';

/// Profile data stored in Firestore.
class UserProfile {
  final String name;
  final int? age;
  final String email;
  final String provider; // "email" | "google"
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool? welcomeGiftClaimed;
  final String? photoURL;
  final String? characterType; // 'male' | 'female'
  final DateTime? birthDate;
  final bool? ageVerified;
  final bool? minimumAgePassed;
  final DateTime? updatedAt;

  const UserProfile({
    required this.name,
    this.age,
    required this.email,
    required this.provider,
    this.createdAt,
    this.lastLoginAt,
    this.welcomeGiftClaimed,
    this.photoURL,
    this.characterType,
    this.birthDate,
    this.ageVerified,
    this.minimumAgePassed,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        if (age != null) 'age': age,
        'email': email,
        'provider': provider,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (lastLoginAt != null) 'lastLoginAt': Timestamp.fromDate(lastLoginAt!),
        if (welcomeGiftClaimed != null) 'welcomeGiftClaimed': welcomeGiftClaimed,
        if (photoURL != null) 'photoURL': photoURL,
        if (characterType != null) 'characterType': characterType,
        if (birthDate != null) 'birthDate': '${birthDate!.year.toString().padLeft(4, '0')}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
        if (ageVerified != null) 'ageVerified': ageVerified,
        if (minimumAgePassed != null) 'minimumAgePassed': minimumAgePassed,
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };

  factory UserProfile.fromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return const UserProfile(name: 'PLAYER', email: '', provider: 'email');
    }
    return UserProfile(
      name: m['name'] as String? ?? 'PLAYER',
      age: (m['age'] as num?)?.toInt(),
      email: m['email'] as String? ?? '',
      provider: m['provider'] as String? ?? 'email',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (m['lastLoginAt'] as Timestamp?)?.toDate(),
      welcomeGiftClaimed: m['welcomeGiftClaimed'] as bool?,
      photoURL: m['photoURL'] as String?,
      characterType: m['characterType'] as String?,
      birthDate: m['birthDate'] != null ? DateTime.tryParse(m['birthDate'] as String) : null,
      ageVerified: m['ageVerified'] as bool?,
      minimumAgePassed: m['minimumAgePassed'] as bool?,
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
      );
    }
    final ownedX = m['ownedXColors'];
    final ownedO = m['ownedOColors'];
    final ownedAvatarsRaw = m['ownedAvatars'];
    final ownedXSkinsRaw = m['ownedXSkins'];
    final ownedOSkinsRaw = m['ownedOSkins'];

    final parsedOwnedAvatars = ownedAvatarsRaw is List
        ? ownedAvatarsRaw.map((e) => (e as num).toInt()).toList()
        : const <int>[];
    final rawEquipped = (m['equippedAvatar'] as num?)?.toInt() ?? 0;
    // Sanitize: if the equipped avatar is not actually owned, force 0.
    // This is the safety net for legacy accounts that were auto-granted
    // avatar 1 before the paid-only fix landed.
    int equipped;
    if (rawEquipped <= 0) {
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
      balanceBefore: (m['balanceBefore'] as num?)?.toInt() ?? (m['previousBalance'] as num?)?.toInt(),
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

  factory UserData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    // Dual-key read: new documents use 'Inventory', legacy documents use 'Cosmetics'.
    final inventoryMap =
        (data['Inventory'] ?? data['Cosmetics']) as Map<String, dynamic>?;
    return UserData(
      profile: UserProfile.fromMap(data['Profile'] as Map<String, dynamic>?),
      wallet: UserWallet.fromMap(data['Wallet'] as Map<String, dynamic>?),
      stats: UserStats.fromMap(data['Stats'] as Map<String, dynamic>?),
      cosmetics: UserCosmetics.fromMap(inventoryMap),
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
