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

  // XO Image Skin system
  static const selectedXSkin = "selectedXSkin";  // "default" | "x5" | etc.
  static const selectedOSkin = "selectedOSkin";
  static const ownedXSkins = "ownedXSkins";       // comma-separated: "default,x5,x1"
  static const ownedOSkins = "ownedOSkins";
  static const xColorNames = "xColorNames";       // JSON map: {"0":"My Red"}
  static const oColorNames = "oColorNames";
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

  /// App language preference. Values: 'en' | 'ar'. Defaults to 'en'.
  static const appLanguage = "app_language";

  /// Cached online profile character type for offline avatar hint ('male' | 'female').
  static const characterType = 'characterType';

  /// Offline player profile — completely separate from the online account.
  static const offlineProfileExists = 'offline_profile_exists';
  static const offlinePlayerId = 'offline_player_id';
  static const offlinePlayerName = 'offline_player_name';
  static const offlineCharacterType = 'offline_character_type';
  static const offlineCoinsV2 = 'offline_coins_v2';
  static const offlineGamesPlayed = 'offline_games_played';
  static const offlineWins = 'offline_wins';
  static const offlineLosses = 'offline_losses';
  static const offlineDraws = 'offline_draws';

  /// Offline cosmetics — local-only, never written to Firestore.
  static const offlineOwnedAvatars   = 'offline_owned_avatars';
  static const offlineSelectedAvatar = 'offline_selected_avatar';
  static const offlineOwnedXSkins    = 'offline_owned_x_skins';
  static const offlineSelectedXSkin  = 'offline_selected_x_skin';
  static const offlineOwnedOSkins    = 'offline_owned_o_skins';
  static const offlineSelectedOSkin  = 'offline_selected_o_skin';

  /// Notifications: fired once on first Home entry, then never again.
  static const hasPromptedNotification = 'has_prompted_notification';

  /// Daily reminder toggle state (Settings → Daily Reminders).
  static const notificationsEnabled = 'notifications_enabled';
}
