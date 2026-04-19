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

  const UserProfile({
    required this.name,
    this.age,
    required this.email,
    required this.provider,
    this.createdAt,
    this.lastLoginAt,
    this.welcomeGiftClaimed,
    this.photoURL,
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

/// Cosmetics (colors + avatar).
class UserCosmetics {
  final String xColor;
  final String oColor;
  final List<int> ownedXColors;
  final List<int> ownedOColors;
  final int equippedAvatar;
  final List<int> ownedAvatars;

  const UserCosmetics({
    required this.xColor,
    required this.oColor,
    this.ownedXColors = const [0],
    this.ownedOColors = const [0],
    this.equippedAvatar = 1,
    this.ownedAvatars = const [1],
  });

  Map<String, dynamic> toMap() => {
        'xColor': xColor,
        'oColor': oColor,
        'ownedXColors': ownedXColors,
        'ownedOColors': ownedOColors,
        'equippedAvatar': equippedAvatar,
        'ownedAvatars': ownedAvatars,
      };

  factory UserCosmetics.fromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return const UserCosmetics(
        xColor: 'ffff3b30',
        oColor: 'ff0a84ff',
        ownedXColors: [0],
        ownedOColors: [0],
        equippedAvatar: 1,
        ownedAvatars: [1],
      );
    }
    final ownedX = m['ownedXColors'];
    final ownedO = m['ownedOColors'];
    final ownedAvatars = m['ownedAvatars'];
    return UserCosmetics(
      xColor: m['xColor'] as String? ?? 'ffff3b30',
      oColor: m['oColor'] as String? ?? 'ff0a84ff',
      ownedXColors: ownedX is List
          ? ownedX.map((e) => (e as num).toInt()).toList()
          : const [0],
      ownedOColors: ownedO is List
          ? ownedO.map((e) => (e as num).toInt()).toList()
          : const [0],
      equippedAvatar: (m['equippedAvatar'] as num?)?.toInt() ?? 1,
      ownedAvatars: ownedAvatars is List
          ? ownedAvatars.map((e) => (e as num).toInt()).toList()
          : const [1],
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

/// Aggregate user data from Firestore.
class UserData {
  final UserProfile profile;
  final UserWallet wallet;
  final UserStats stats;
  final UserCosmetics cosmetics;
  final UserProgress progress;

  const UserData({
    required this.profile,
    required this.wallet,
    required this.stats,
    required this.cosmetics,
    required this.progress,
  });

  factory UserData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserData(
      profile: UserProfile.fromMap(data['Profile'] as Map<String, dynamic>?),
      wallet: UserWallet.fromMap(data['Wallet'] as Map<String, dynamic>?),
      stats: UserStats.fromMap(data['Stats'] as Map<String, dynamic>?),
      cosmetics:
          UserCosmetics.fromMap(data['Cosmetics'] as Map<String, dynamic>?),
      progress:
          UserProgress.fromMap(data['Progress'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'Profile': profile.toMap(),
        'Wallet': wallet.toMap(),
        'Stats': stats.toMap(),
        'Cosmetics': cosmetics.toMap(),
        'Progress': progress.toMap(),
      };
}
