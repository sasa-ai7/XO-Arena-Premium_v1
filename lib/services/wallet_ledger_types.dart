/// Canonical `type` values for `users/{uid}/wallet_ledger/{txId}` docs.
///
/// Every coin mutation in the app should write a ledger entry using one of
/// these constants so that downstream auditing, leaderboards, and the
/// admin dashboard can group transactions consistently.
///
/// Ledger record shape:
///   { uid, type, source, delta, before, after,
///     createdAt, transactionId, roomCode?, matchId? }
///
/// `delta` is signed (negative for debits). `transactionId` doubles as the
/// document id to enforce uniqueness — never use `add()`, always `set(...)`
/// on the doc reference.
class LedgerType {
  LedgerType._();

  /// Friend room: each player's entry-fee debit at countdown.
  static const String friendRoomBetEntry = 'friend_room_bet_entry';

  /// Friend room: winner's prize-pool credit.
  static const String friendRoomPrize = 'friend_room_prize';

  /// Friend room: refund when match aborts before play.
  static const String friendRoomRefund = 'friend_room_refund';

  /// Referral redeem (invitee side).
  static const String referralInviteeReward = 'referral_invitee_reward';

  /// Referral redeem (referrer side).
  static const String referralReferrerReward = 'referral_referrer_reward';

  /// IAP coin pack credit.
  static const String purchase = 'purchase';
  static const String iapPurchase = 'iap_purchase';

  /// Per-game reward (local games).
  static const String gameReward = 'game_reward';

  /// Daily/weekly mission reward — credited only on manual claim.
  static const String missionReward = 'mission_reward';
  static const String dailyReward = 'daily_reward';
  static const String weeklyReward = 'weekly_reward';
  static const String levelReward = 'level_reward';
  static const String aiReward = 'ai_reward';
  static const String storeXSkinPurchase = 'store_x_skin_purchase';
  static const String storeOSkinPurchase = 'store_o_skin_purchase';
  static const String avatarPurchase = 'avatar_purchase';
  static const String emojiPurchase = 'emoji_purchase';
  static const String xColorPurchase = 'x_color_purchase';
  static const String oColorPurchase = 'o_color_purchase';
  static const String disconnectForfeitPrize = 'disconnect_forfeit_prize';
}
