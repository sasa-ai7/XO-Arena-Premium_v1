/// Local-only player profile for offline sessions.
///
/// This is completely separate from the Firebase online account.
/// It is never written to Firestore and never merged back on reconnect.
/// No Firebase uid, no Google email, no Google photo URL.
class OfflinePlayerProfile {
  final String offlineId;
  final String name;

  /// 'male' | 'female' — determines which character image is shown.
  final String characterType;

  final int coins;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;

  /// Always true — never sync to online account.
  final bool isOfflineProfile;

  // ── Cosmetics (local-only, never written to Firestore) ────────────────────

  /// IDs of avatars the offline player has purchased locally.
  final List<int> ownedAvatars;

  /// ID of the currently equipped avatar, or null if none equipped.
  /// Profile image falls back to [avatarAssetPath] when null.
  final int? selectedAvatar;

  /// IDs of owned X image skins.
  final List<String> ownedXSkins;

  /// Selected X skin, or null for the basic default.
  final String? selectedXSkin;

  /// IDs of owned O image skins.
  final List<String> ownedOSkins;

  /// Selected O skin, or null for the basic default.
  final String? selectedOSkin;

  const OfflinePlayerProfile({
    required this.offlineId,
    required this.name,
    required this.characterType,
    required this.coins,
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.draws,
    this.isOfflineProfile = true,
    this.ownedAvatars = const [],
    this.selectedAvatar,
    this.ownedXSkins = const [],
    this.selectedXSkin,
    this.ownedOSkins = const [],
    this.selectedOSkin,
  });

  /// Asset path for the character image (NEVER uses Google/Firebase URL).
  String get avatarAssetPath => characterType == 'female'
      ? 'assets/account/feminine.png'
      : 'assets/account/man.png';

  factory OfflinePlayerProfile.defaults({
    String id = '',
    String name = 'PLAYER',
    String characterType = 'male',
  }) {
    return OfflinePlayerProfile(
      offlineId: id,
      name: name,
      characterType: characterType,
      coins: 200,
      gamesPlayed: 0,
      wins: 0,
      losses: 0,
      draws: 0,
      isOfflineProfile: true,
      ownedAvatars: const [],
      selectedAvatar: null,
      ownedXSkins: const [],
      selectedXSkin: null,
      ownedOSkins: const [],
      selectedOSkin: null,
    );
  }

  OfflinePlayerProfile copyWith({
    String? offlineId,
    String? name,
    String? characterType,
    int? coins,
    int? gamesPlayed,
    int? wins,
    int? losses,
    int? draws,
    List<int>? ownedAvatars,
    Object? selectedAvatar = _sentinel,
    List<String>? ownedXSkins,
    Object? selectedXSkin = _sentinel,
    List<String>? ownedOSkins,
    Object? selectedOSkin = _sentinel,
  }) {
    return OfflinePlayerProfile(
      offlineId: offlineId ?? this.offlineId,
      name: name ?? this.name,
      characterType: characterType ?? this.characterType,
      coins: coins ?? this.coins,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      isOfflineProfile: true,
      ownedAvatars: ownedAvatars ?? this.ownedAvatars,
      selectedAvatar:
          identical(selectedAvatar, _sentinel) ? this.selectedAvatar : selectedAvatar as int?,
      ownedXSkins: ownedXSkins ?? this.ownedXSkins,
      selectedXSkin:
          identical(selectedXSkin, _sentinel) ? this.selectedXSkin : selectedXSkin as String?,
      ownedOSkins: ownedOSkins ?? this.ownedOSkins,
      selectedOSkin:
          identical(selectedOSkin, _sentinel) ? this.selectedOSkin : selectedOSkin as String?,
    );
  }
}

// Sentinel object used to distinguish "not provided" from explicit null in copyWith.
const _sentinel = Object();
