import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../wallet_ledger_types.dart';
import 'referral_service.dart';

/// One pending-reward record materialised from
/// `pending_referral_rewards/{referrerUid_inviteeUid}`.
class PendingReferralReward {
  final String id;
  final String referrerUid;
  final String inviteeUid;
  final String inviteeName;
  final String inviteePhotoURL;
  final int coins;
  final String message;
  final DateTime? createdAt;

  const PendingReferralReward({
    required this.id,
    required this.referrerUid,
    required this.inviteeUid,
    required this.inviteeName,
    required this.inviteePhotoURL,
    required this.coins,
    required this.message,
    required this.createdAt,
  });

  factory PendingReferralReward.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final raw = doc.data() ?? const <String, dynamic>{};
    final ts = raw['createdAt'];
    return PendingReferralReward(
      id: doc.id,
      referrerUid: (raw['referrerUid'] ?? raw['uid'] ?? '').toString(),
      inviteeUid: (raw['inviteeUid'] ?? '').toString(),
      inviteeName: (raw['inviteeName'] ?? '').toString(),
      inviteePhotoURL: (raw['inviteePhotoURL'] ?? '').toString(),
      coins: (raw['coins'] as num?)?.toInt() ??
          ReferralService.kRewardPerFriend,
      message: (raw['message'] ?? 'Your friend accepted your invite').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

/// Reads + writes for the `pending_referral_rewards` collection.
///
/// Sorted client-side so no composite Firestore index is required.
class PendingReferralRewardService {
  PendingReferralRewardService._();
  static final PendingReferralRewardService instance =
      PendingReferralRewardService._();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// All unseen referral-accepted records targeted at the current user,
  /// oldest-first. Returns an empty list on any read error.
  Future<List<PendingReferralReward>> fetchUnseenForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const <PendingReferralReward>[];
    try {
      final qs = await _fs
          .collection('pending_referral_rewards')
          .where('uid', isEqualTo: uid)
          .where('seen', isEqualTo: false)
          .get();
      final list = qs.docs.map(PendingReferralReward.fromDoc).toList();
      list.sort((a, b) {
        final ax = a.createdAt;
        final bx = b.createdAt;
        if (ax == null && bx == null) return 0;
        if (ax == null) return 1;
        if (bx == null) return -1;
        return ax.compareTo(bx);
      });
      return list;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[REFERRAL] fetch pending rewards failed: $e');
      }
      return const <PendingReferralReward>[];
    }
  }

  /// Flip `seen: true` on a pending-reward record. Also lazily writes the
  /// referrer's own `wallet_ledger` entry the first time they claim the
  /// popup — the invitee can't write into the referrer's subcollection from
  /// the client, so this is the safe place to back-fill it.
  Future<void> markSeen(PendingReferralReward reward) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (uid != reward.referrerUid) return;
    final ref = _fs.collection('pending_referral_rewards').doc(reward.id);
    try {
      await ref.update(<String, dynamic>{
        'seen': true,
        'seenAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[REFERRAL] markSeen failed: $e');
    }
    // Lazy referrer ledger write (idempotent via deterministic doc id).
    try {
      final ledgerId = 'ref_${reward.inviteeUid}_referrer';
      final ledgerRef = _fs
          .collection('users')
          .doc(uid)
          .collection('wallet_ledger')
          .doc(ledgerId);
      final existing = await ledgerRef.get();
      if (!existing.exists) {
        await ledgerRef.set(<String, dynamic>{
          'uid': uid,
          'type': LedgerType.referralReferrerReward,
          'source': 'pending_referral_claim',
          'delta': reward.coins,
          'transactionId': ledgerId,
          'title': 'Referral accepted',
          'message': reward.inviteeName.isEmpty
              ? '${reward.coins} coins received from a referral'
              : '${reward.inviteeName} accepted your invite. You received ${reward.coins} coins.',
          'friendUid': reward.inviteeUid,
          'friendName': reward.inviteeName,
          'friendPhotoURL': reward.inviteePhotoURL,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[REFERRAL] referrer ledger backfill failed: $e');
    }
  }
}
