/// App-wide configuration (support contact, refunds, etc.).
class AppConfig {
  // ── Runtime feature flags ─────────────────────────────────────────────────

  /// Cloud Functions are deployed and active (requires Blaze plan).
  static const bool kUseCloudFunctions = true;

  /// Google Play IAP products are live. IAP purchases go through server verification.
  static const bool kEnableRealPurchases = true;

  /// Legacy alias — kept so existing callers compile.
  /// As of 2026-05 the client wallet is the single source of truth for
  /// coin balances; the Cloud Function never grants coins.
  /// New code should use [kEnableServerCoinRewards] and
  /// [kEnableMatchStatsCloudFunction] directly.
  static const bool kEnableServerRewards = false;

  /// Server-authoritative coin rewards via Cloud Function.
  /// **Must stay false.** The client wallet is the source of truth; setting
  /// this true would re-introduce the double-reward bug fixed in 2026-05.
  static const bool kEnableServerCoinRewards = false;

  /// Call the stats-only Cloud Function (`grantMatchReward`) after each
  /// match to record idempotent match_rewards/{uid}_{matchId} + Stats
  /// increments + an audit transaction (amount=0).
  /// **The CF must NOT mutate Wallet.coins** — see functions/src/index.ts.
  /// Set to false if the CF is not deployed; the client wallet remains
  /// authoritative either way.
  static const bool kEnableMatchStatsCloudFunction = true;

  // ── Firestore sync flags ──────────────────────────────────────────────────

  /// Sync Wallet.coins to Firestore after each local update.
  static const bool kEnableFirestoreWalletSync = true;

  /// Sync Stats (wins/losses/draws/gamesPlayed) to Firestore after each game.
  static const bool kEnableFirestoreStatsSync = true;

  /// Sync Cosmetics/Inventory to Firestore after equip/purchase changes.
  static const bool kEnableFirestoreInventorySync = true;

  /// Write transaction records to users/{uid}/transactions subcollection.
  static const bool kEnableFirestoreTransactions = true;

  /// Write audit log entries from client (best-effort, non-fatal).
  static const bool kEnableFirestoreAuditLogs = true;

  /// Write Session info to Firestore on sign-in.
  static const bool kEnableFirestoreSessionWrite = true;
  /// Support account email for the game. Used for Contact Support and policies.
  static const String supportEmail = "xandomanger@gmail.com";

  /// Refund contact email. Shown in Contact Support dialog.
  static const String refundEmail = "xandomanger@gmail.com";

  /// Short refund rules text shown in Contact Support / Refunds dialog.
  static const String refundRulesText =
      "• Refund requests: Contact us at the email below with your order details.\n"
      "• Eligibility: Refunds may apply per our terms and store policy.\n"
      "• Response: We will reply within a few business days.";

  /// Privacy Policy URL
  static const String privacyPolicyUrl = "https://sites.google.com/view/xo-game-policies/privacy-policy";

  /// Terms of Service URL
  static const String termsUrl = "https://sites.google.com/view/xo-game-policies/terms";

  /// Account Deletion Information URL
  static const String accountDeletionUrl = "https://sites.google.com/view/xo-game-policies/account-deletion";

  /// Google Policies URL
  static const String googlePoliciesUrl = "https://www.termsfeed.com/live/27d1303a-4c17-4d58-a16b-6d032142b26a";
}
