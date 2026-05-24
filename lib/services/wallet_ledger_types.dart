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

  /// Per-game reward (local games).
  static const String gameReward = 'game_reward';
}
