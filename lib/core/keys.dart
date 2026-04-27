/// SharedPreferences and Firestore cache keys.
/// Password is NEVER stored.
class Keys {
  static const loggedIn = "loggedIn";
  static const username = "username";
  static const email = "email";
  // NO password key - never store passwords

  static const gamesPlayed = "gamesPlayed";
  static const wins = "wins";
  static const losses = "losses";
  static const draws = "draws";
  static const coins = "coins";

  static const xColor = "xColor";
  static const oColor = "oColor";
  static const ownedXColors = "ownedXColors";
  static const ownedOColors = "ownedOColors";
  static const equippedAvatar = "equippedAvatar";
  static const ownedAvatars = "ownedAvatars";
  static const profilePhotoPath = "profilePhotoPath";
  static const profilePhotoUrl = "profilePhotoUrl";
  static const customXColor = "customXColor";
  static const customOColor = "customOColor";
  static const customXConfigs = "customXConfigsV2"; 
  static const customOConfigs = "customOConfigsV2"; 
  static const topupHistory = "topupHistory";

  static const levelGameCurrentLevel = "levelGameCurrentLevel";
  static const levelGameCompleted = "levelGameCompleted";
  static const levelGameCompletions = "levelGameCompletions";

  /// Flag to prevent re-migration of local data to Firestore.
  static const migrated = "migrated";

  /// Flag to prevent auto sign-in after account deletion.
  static const justDeletedAccount = "justDeletedAccount";

  /// Processed purchase IDs/tokens for idempotency protection.
  static const processedPurchases = "processedPurchases";

  /// Transaction IDs already logged to history (prevents duplicate history entries).
  static const loggedTransactionIds = "loggedTransactionIds";

  /// Email verification resend policy tracking.
  static const verify_resend_count = "verify_resend_count";
  static const verify_last_sent_at_ms = "verify_last_sent_at_ms";
  static const verify_lockout_until_ms = "verify_lockout_until_ms";

  /// Saved login credentials (for convenience).
  static const savedEmail = "savedEmail";

  /// Guest mode display name.
  static const guestName = "guestName";

  /// First-launch intro completion flag.
  static const introCompleted = "introCompleted";

  /// Account deletion security: attempts and lockout.
  static const deleteAttempts = "deleteAttempts";
  static const deleteLastAttempt = "deleteLastAttempt";
  static const deleteLockedUntil = "deleteLockedUntil";

  /// Single-device session enforcer.
  static const sessionId = "sessionId";

  /// First-time welcome screen shown flag.
  static const hasSeenWelcomeScreen = "hasSeenWelcomeScreen";

  /// Guest has completed the initial in-home onboarding prompt.
  static const hasCompletedFirstEntry = "hasCompletedFirstEntry";

  /// Number of games played as guest (for conversion reminder trigger).
  static const guestGamesPlayed = "guestGamesPlayed";

  /// Offline guest mode state.
  static const offlineGuest = "offlineGuest";
  static const offlineCoins = "offlineCoins";

  /// Coin balance saved before network disconnect (for smart sync on reconnect).
  static const preDisconnectCoins = "preDisconnectCoins";
}
