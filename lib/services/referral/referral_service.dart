import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_config.dart';
import '../app_mode_service.dart';
import '../local_store.dart';
import '../online_wallet_service.dart';
import '../wallet_ledger_types.dart';

/// Errors surfaced from [ReferralService.redeem].
enum ReferralError {
  invalidFormat,
  selfReferral,
  alreadyUsed,
  notFound,
  notEligible,
  capacityFull,
  /// Timeout / no connectivity / Cloud Function temporarily unavailable.
  /// Surfaces a distinct, actionable message instead of the generic
  /// "unknown" so the user understands a retry will likely succeed.
  networkError,
  unknown,
}

/// Outcome of a referral redeem call. Carries enough referrer profile
/// information for the invitee UI to render a rich success dialog without a
/// second round-trip.
class ReferralRedeemResult {
  final bool success;
  final ReferralError? error;
  final int rewardCoins;
  final int? newBalance;
  final String? referrerUid;
  final String? referrerName;
  final String? referrerPhotoURL;
  final bool usedFallback;

  const ReferralRedeemResult.ok({
    required this.rewardCoins,
    this.newBalance,
    this.referrerUid,
    this.referrerName,
    this.referrerPhotoURL,
    this.usedFallback = false,
  })  : success = true,
        error = null;

  const ReferralRedeemResult.fail(this.error)
      : success = false,
        rewardCoins = 0,
        newBalance = null,
        referrerUid = null,
        referrerName = null,
        referrerPhotoURL = null,
        usedFallback = false;
}

/// Per-user invite/referral state in Firestore.
class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  static const int kRewardPerFriend = 100;
  static const int kMaxFriends = 10;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final Random _rng = Random.secure();

  /// In-flight code currently being redeemed by this singleton. Belt-and-
  /// suspenders against duplicate redeem calls that slip past the UI's
  /// `_busy` guard (e.g. listener double-fire, keypad onEnter race).
  String? _inFlightCode;

  // Network timeouts. Tuned so that a typical Wi-Fi cold call (~1-3 s) is
  // never cut off, but a stuck request never spins the UI past ~15 s.
  static const Duration _kEnsureCodeTimeout = Duration(seconds: 12);
  static const Duration _kRedeemCallableTimeout = Duration(seconds: 15);
  static const Duration _kFallbackReadTimeout = Duration(seconds: 10);
  static const Duration _kFallbackCommitTimeout = Duration(seconds: 15);

  /// 9-digit invite code (e.g. "123456789").
  String _gen9() {
    // 100_000_000 .. 999_999_999 keeps it 9 digits.
    final n = _rng.nextInt(900000000) + 100000000;
    return n.toString();
  }

  /// Ensure the current user has a referral code allocated in
  /// `users/{uid}.Referral.code` and `referral_codes/{code}`.
  ///
  /// Idempotent: no-op if a code already exists.
  Future<String?> ensureCode(String uid) async {
    if (!AppConfig.kEnableReferralRewards) return null;
    if (!AppModeService.canUseOnlineServicesForReconnect) return null;
    if (kDebugMode) debugPrint('[REFERRAL] ensureCode start uid=$uid');
    try {
      final userRef = _fs.collection('users').doc(uid);
      final userSnap = await userRef.get().timeout(_kEnsureCodeTimeout);
      final existing =
          ((userSnap.data() ?? const {})['Referral'] as Map?)?['code'] as String?;
      if (existing != null && existing.length == 9) {
        if (kDebugMode) debugPrint('[REFERRAL] code already=$existing');
        return existing;
      }

      for (int i = 0; i < 6; i++) {
        final code = _gen9();
        final codeRef = _fs.collection('referral_codes').doc(code);
        final ok = await _fs.runTransaction<bool>((txn) async {
          final cs = await txn.get(codeRef);
          if (cs.exists) return false;
          txn.set(codeRef, <String, dynamic>{
            'uid': uid,
            'code': code,
            'createdAt': FieldValue.serverTimestamp(),
          });
          txn.set(
            userRef,
            <String, dynamic>{
              'Referral': <String, dynamic>{
                'code': code,
                'referredBy': null,
                'referralUsed': false,
                'validReferralCount': 0,
                'totalReferralCoinsEarned': 0,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              },
            },
            SetOptions(merge: true),
          );
          return true;
        }).timeout(_kEnsureCodeTimeout);
        if (ok) {
          if (kDebugMode) debugPrint('[REFERRAL] generated code=$code');
          return code;
        }
      }
      return null;
    } on TimeoutException {
      if (kDebugMode) debugPrint('[REFERRAL] ensureCode timeout uid=$uid');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[REFERRAL] ensureCode failed: $e');
      return null;
    }
  }

  /// Read the referral state map for the current user.
  Future<Map<String, dynamic>> readSelf(String uid) async {
    try {
      final snap = await _fs.collection('users').doc(uid).get();
      final r = (snap.data() ?? const {})['Referral'];
      if (r is Map) return r.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Best-effort lookup of `(name, photoURL)` for an arbitrary uid. Used to
  /// enrich both the invitee success dialog and the referrer pending-reward
  /// popup. Returns empty strings on failure.
  Future<({String name, String photoURL})> _readUserProfile(String uid) async {
    try {
      final snap = await _fs.collection('users').doc(uid).get();
      final raw = snap.data() ?? const <String, dynamic>{};
      // The app stores profile fields under both top-level and a nested
      // `profile`/`Profile` map across legacy schemas — try the most common
      // paths.
      String name = (raw['displayName'] ?? raw['name'] ?? '').toString();
      String photo = (raw['photoURL'] ?? '').toString();
      if (name.isEmpty || photo.isEmpty) {
        final profile = raw['profile'] ?? raw['Profile'];
        if (profile is Map) {
          if (name.isEmpty) {
            name = (profile['displayName'] ?? profile['name'] ?? '').toString();
          }
          if (photo.isEmpty) {
            photo = (profile['photoURL'] ?? '').toString();
          }
        }
      }
      return (name: name, photoURL: photo);
    } catch (_) {
      return (name: '', photoURL: '');
    }
  }

  /// Redeem another user's invite code for the current user.
  ///
  /// Tries the `redeemReferralCode` Cloud Function first. On `not-found` /
  /// `internal` / `unavailable` (i.e. CF not deployed in this build) falls back
  /// to a client-side Firestore batch that is allowed by the existing rules.
  ///
  /// TODO: Move referral reward redemption to a Cloud Function for production
  /// — the client fallback below is rules-safe but not server-authoritative.
  Future<ReferralRedeemResult> redeem({
    required String code,
  }) async {
    if (!AppConfig.kEnableReferralRewards) {
      return const ReferralRedeemResult.fail(ReferralError.unknown);
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const ReferralRedeemResult.fail(ReferralError.unknown);
    }
    final normalized = code.trim().replaceAll(RegExp(r'\D'), '');
    if (kDebugMode) {
      debugPrint('[REFERRAL] normalized code=$normalized');
    }
    if (normalized.length != 9) {
      if (kDebugMode) {
        debugPrint('[REFERRAL] enter code=$normalized → invalid format');
      }
      return const ReferralRedeemResult.fail(ReferralError.invalidFormat);
    }
    if (!AppModeService.canUseOnlineServices) {
      return const ReferralRedeemResult.fail(ReferralError.unknown);
    }

    // Service-level in-flight guard. Catches double-submit cases that slip
    // past the page's `_busy` flag (e.g. two listener ticks racing each
    // other before setState lands). Releases in the outer `finally`.
    if (_inFlightCode == normalized) {
      if (kDebugMode) {
        debugPrint('[REFERRAL] duplicate redeem ignored code=$normalized');
      }
      return const ReferralRedeemResult.fail(ReferralError.unknown);
    }
    _inFlightCode = normalized;

    final auth = FirebaseAuth.instance.currentUser;
    final inviteeName = auth?.displayName ?? '';
    final inviteePhotoURL = auth?.photoURL ?? '';

    try {
      // ── Pre-check: has this invitee already used ANY code? ──
      // Catches the confusing case where the code is valid but the user
      // already redeemed a different code. Without this, the user sees the
      // code-lookup succeed then gets a generic "already used" from the
      // transaction, which reads like "this code was already used by someone
      // else".
      try {
        final referralSnap = await _fs
            .collection('referrals')
            .doc(uid)
            .get()
            .timeout(_kFallbackReadTimeout);
        if (referralSnap.exists) {
          if (kDebugMode) {
            debugPrint('[REFERRAL] blocked because invitee already used a '
                'different code before uid=$uid');
          }
          return const ReferralRedeemResult.fail(ReferralError.alreadyUsed);
        }
      } on TimeoutException {
        // Could not verify — let the downstream logic handle it.
      }

      if (kDebugMode) {
        debugPrint('[REFERRAL] callable redeemReferralCode code=$normalized uid=$uid');
      }
      final callable = FirebaseFunctions.instance
          .httpsCallable('redeemReferralCode');
      final res = await callable
          .call(<String, dynamic>{'code': normalized})
          .timeout(_kRedeemCallableTimeout);
      final data = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : const <String, dynamic>{};
      final newBalance = (data['inviteeBalance'] as num?)?.toInt();
      if (newBalance != null) {
        try {
          await OnlineWalletService().setFromServer(
            newBalance,
            coinsNotifier: LocalStore.coinsNotifier,
          );
        } catch (_) {
          LocalStore.coinsNotifier.value = newBalance;
        }
      }
      if (kDebugMode) {
        debugPrint('[REFERRAL] redeem ok newBalance=$newBalance');
      }
      String? referrerUid;
      String referrerName = '';
      String referrerPhotoURL = '';
      try {
        final codeSnap =
            await _fs.collection('referral_codes').doc(code).get();
        referrerUid = (codeSnap.data() ?? const {})['uid'] as String?;
        if (referrerUid != null && referrerUid.isNotEmpty) {
          final p = await _readUserProfile(referrerUid);
          referrerName = p.name;
          referrerPhotoURL = p.photoURL;
          await _writePendingReferralReward(
            referrerUid: referrerUid,
            inviteeUid: uid,
            inviteeName: inviteeName,
            inviteePhotoURL: inviteePhotoURL,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[REFERRAL] post-CF profile/pending write failed: $e');
        }
      }
      return ReferralRedeemResult.ok(
        rewardCoins: kRewardPerFriend,
        newBalance: newBalance,
        referrerUid: referrerUid,
        referrerName: referrerName,
        referrerPhotoURL: referrerPhotoURL,
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[REFERRAL] redeem CF error code=${e.code} msg=${e.message}');
      }
      if (_shouldUseClientFallback(e.code)) {
        if (kDebugMode) {
          debugPrint('[REFERRAL] redeemReferralCode not available; using client fallback');
        }
        return _redeemWithClientFallback(
          code: code,
          uid: uid,
          inviteeName: inviteeName,
          inviteePhotoURL: inviteePhotoURL,
        );
      }
      return ReferralRedeemResult.fail(_mapCfError(e.code));
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[REFERRAL] callable redeem timeout — falling back to client');
      }
      return _redeemWithClientFallback(
        code: code,
        uid: uid,
        inviteeName: inviteeName,
        inviteePhotoURL: inviteePhotoURL,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[REFERRAL] redeem error: $e');
      return const ReferralRedeemResult.fail(ReferralError.unknown);
    } finally {
      if (_inFlightCode == normalized) _inFlightCode = null;
    }
  }

  bool _shouldUseClientFallback(String code) {
    return code == 'not-found' ||
        code == 'not-implemented' ||
        code == 'internal' ||
        code == 'unavailable';
  }

  /// Temporary fallback for builds where the `redeemReferralCode` Cloud
  /// Function is not deployed yet. Performs:
  ///   • code lookup + self-referral guard + duplicate-redeem guard
  ///   • +100 to invitee wallet (own doc — rules-safe)
  ///   • +100 to referrer wallet via `isReferralReferrerCredit` rule
  ///   • referrals/{inviteeUid} doc creation
  ///   • invitee wallet_ledger entry
  ///   • pending_referral_rewards/{referrerUid}_{inviteeUid} doc (popup
  ///     trigger when referrer next opens the app)
  ///
  /// The referrer's wallet_ledger entry is created lazily by the referrer's
  /// own client when they tap-through the pending popup — rules don't permit
  /// the invitee to write into another user's subcollection.
  ///
  /// TODO: Move referral reward application to a Cloud Function for production.
  Future<ReferralRedeemResult> _redeemWithClientFallback({
    required String code,
    required String uid,
    required String inviteeName,
    required String inviteePhotoURL,
  }) async {
    try {
      final codeRef = _fs.collection('referral_codes').doc(code);
      final inviteeRef = _fs.collection('users').doc(uid);
      final referralRef = _fs.collection('referrals').doc(uid);

      final codeSnap = await codeRef.get().timeout(_kFallbackReadTimeout);
      if (kDebugMode) {
        debugPrint('[REFERRAL] code exists=${codeSnap.exists} code=$code');
      }
      if (!codeSnap.exists) {
        return const ReferralRedeemResult.fail(ReferralError.notFound);
      }
      final codeData = codeSnap.data() ?? const <String, dynamic>{};
      final referrerUid = (codeData['uid'] ?? '').toString();
      if (referrerUid.isEmpty) {
        return const ReferralRedeemResult.fail(ReferralError.notFound);
      }
      if (referrerUid == uid) {
        if (kDebugMode) {
          debugPrint('[REFERRAL] blocked reason=ownCode code=$code');
        }
        return const ReferralRedeemResult.fail(ReferralError.selfReferral);
      }

      final referralSnap = await referralRef.get().timeout(_kFallbackReadTimeout);
      if (kDebugMode) {
        debugPrint('[REFERRAL] existing referral exists=${referralSnap.exists} uid=$uid');
      }
      if (referralSnap.exists) {
        if (kDebugMode) {
          debugPrint('[REFERRAL] blocked because invitee already used a '
              'different code before uid=$uid (fallback path)');
        }
        return const ReferralRedeemResult.fail(ReferralError.alreadyUsed);
      }

      final inviteeSnap =
          await inviteeRef.get().timeout(_kFallbackReadTimeout);
      final inviteeData = inviteeSnap.data() ?? const <String, dynamic>{};

      // Referrer capacity guard (best-effort — rules don't enforce this).
      final referrerProfile = await _readUserProfile(referrerUid);
      try {
        final refSnap = await _fs.collection('users').doc(referrerUid).get();
        final refReferral = (refSnap.data() ?? const {})['Referral'];
        if (refReferral is Map) {
          final count = (refReferral['validReferralCount'] as num?)?.toInt() ?? 0;
          if (count >= kMaxFriends) {
            return const ReferralRedeemResult.fail(ReferralError.capacityFull);
          }
        }
      } catch (_) {}

      final wallet = inviteeData['Wallet'];
      final oldBalance = (wallet is Map && wallet['coins'] is num)
          ? (wallet['coins'] as num).toInt()
          : LocalStore.coinsNotifier.value;
      final newBalance = oldBalance + kRewardPerFriend;

      final inviteeLedgerId = 'ref_${uid}_invitee';
      final inviteeLedgerRef =
          inviteeRef.collection('wallet_ledger').doc(inviteeLedgerId);
      final pendingRewardId = '${referrerUid}_$uid';
      final pendingRewardRef =
          _fs.collection('pending_referral_rewards').doc(pendingRewardId);

      final batch = _fs.batch();
      batch.set(referralRef, <String, dynamic>{
        'inviteeUid': uid,
        'inviteeName': inviteeName,
        'inviteePhotoURL': inviteePhotoURL,
        'referrerUid': referrerUid,
        'referrerName': referrerProfile.name,
        'referrerPhotoURL': referrerProfile.photoURL,
        'code': code,
        'rewardAmount': kRewardPerFriend,
        'rewardCoins': kRewardPerFriend,
        'inviteeRewardApplied': true,
        'referrerRewardApplied': true,
        'status': 'client_fallback_rewarded',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        inviteeRef,
        <String, dynamic>{
          'Wallet': <String, dynamic>{
            'coins': FieldValue.increment(kRewardPerFriend),
          },
          'Referral': <String, dynamic>{
            'referralUsed': true,
            'referredBy': referrerUid,
            'referredByCode': code,
            'inviteeRewardEarned': kRewardPerFriend,
            'inviteeRewardCoins': kRewardPerFriend,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );
      batch.set(
        _fs.collection('users').doc(referrerUid),
        <String, dynamic>{
          'Wallet': <String, dynamic>{
            'coins': FieldValue.increment(kRewardPerFriend),
          },
          'Referral': <String, dynamic>{
            'validReferralCount': FieldValue.increment(1),
            'totalReferralCoinsEarned': FieldValue.increment(kRewardPerFriend),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );
      // Invitee wallet_ledger row (rules-safe: owner writes own subcollection).
      batch.set(inviteeLedgerRef, <String, dynamic>{
        'uid': uid,
        'type': LedgerType.referralInviteeReward,
        'source': 'client_fallback',
        'delta': kRewardPerFriend,
        'before': oldBalance,
        'after': newBalance,
        'transactionId': inviteeLedgerId,
        'title': 'Friend invite reward',
        'message': referrerProfile.name.isEmpty
            ? 'You received $kRewardPerFriend coins'
            : 'You received $kRewardPerFriend coins from ${referrerProfile.name}',
        'friendUid': referrerUid,
        'friendName': referrerProfile.name,
        'friendPhotoURL': referrerProfile.photoURL,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Pending popup for the referrer.
      batch.set(pendingRewardRef, <String, dynamic>{
        'id': pendingRewardId,
        'type': 'referral_accepted',
        'uid': referrerUid,
        'referrerUid': referrerUid,
        'inviteeUid': uid,
        'inviteeName': inviteeName,
        'inviteePhotoURL': inviteePhotoURL,
        'coins': kRewardPerFriend,
        'message': 'Your friend accepted your invite',
        'seen': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit().timeout(_kFallbackCommitTimeout);
      try {
        await OnlineWalletService().setFromServer(
          newBalance,
          coinsNotifier: LocalStore.coinsNotifier,
        );
      } catch (_) {
        LocalStore.coinsNotifier.value = newBalance;
      }
      if (kDebugMode) {
        debugPrint('[REFERRAL] redeem success invitee=$uid referrer=$referrerUid coins=$kRewardPerFriend');
        debugPrint('[REFERRAL] client fallback ok newBalance=$newBalance');
      }
      return ReferralRedeemResult.ok(
        rewardCoins: kRewardPerFriend,
        newBalance: newBalance,
        referrerUid: referrerUid,
        referrerName: referrerProfile.name,
        referrerPhotoURL: referrerProfile.photoURL,
        usedFallback: true,
      );
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[REFERRAL] client fallback timeout — retryable network error');
      }
      return const ReferralRedeemResult.fail(ReferralError.networkError);
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('[REFERRAL] client fallback Firebase error code=${e.code} msg=${e.message}');
      }
      if (e.code == 'permission-denied') {
        return const ReferralRedeemResult.fail(ReferralError.unknown);
      }
      if (e.code == 'already-exists') {
        return const ReferralRedeemResult.fail(ReferralError.alreadyUsed);
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return const ReferralRedeemResult.fail(ReferralError.networkError);
      }
      return const ReferralRedeemResult.fail(ReferralError.unknown);
    } catch (e) {
      if (kDebugMode) debugPrint('[REFERRAL] client fallback error: $e');
      return const ReferralRedeemResult.fail(ReferralError.unknown);
    }
  }

  /// Standalone write of the pending-reward popup record. Used by the CF
  /// success path (where the CF doesn't currently create this doc).
  /// Failure is non-fatal — the wallet credit already succeeded.
  Future<void> _writePendingReferralReward({
    required String referrerUid,
    required String inviteeUid,
    required String inviteeName,
    required String inviteePhotoURL,
  }) async {
    final pendingRewardId = '${referrerUid}_$inviteeUid';
    final ref =
        _fs.collection('pending_referral_rewards').doc(pendingRewardId);
    try {
      final existing = await ref.get();
      if (existing.exists) return;
      await ref.set(<String, dynamic>{
        'id': pendingRewardId,
        'type': 'referral_accepted',
        'uid': referrerUid,
        'referrerUid': referrerUid,
        'inviteeUid': inviteeUid,
        'inviteeName': inviteeName,
        'inviteePhotoURL': inviteePhotoURL,
        'coins': kRewardPerFriend,
        'message': 'Your friend accepted your invite',
        'seen': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[REFERRAL] pending reward write failed: $e');
    }
  }

  ReferralError _mapCfError(String code) {
    switch (code) {
      case 'invalid-argument':
        return ReferralError.invalidFormat;
      case 'not-found':
        return ReferralError.notFound;
      case 'failed-precondition':
        // CF emits this for BOTH self-referral and App Check failures.
        // We can't distinguish without parsing the message, so we surface a
        // neutral error and log enough to diagnose. The client-side
        // self-referral guard in enter_invite_code_page.dart blocks the
        // common case before we ever get here.
        if (kDebugMode) {
          debugPrint('[REFERRAL] failed-precondition — likely App Check not '
              'configured on this build (or self-referral if client guard was '
              'bypassed). Check Firebase Console > App Check.');
        }
        return ReferralError.unknown;
      case 'already-exists':
        return ReferralError.alreadyUsed;
      case 'resource-exhausted':
        return ReferralError.capacityFull;
      case 'unauthenticated':
        if (kDebugMode) {
          debugPrint('[REFERRAL] unauthenticated — user not signed in to Firebase Auth');
        }
        // Surface as a network error: the most common practical cause is
        // that the auth token is mid-refresh / the client has lost connection.
        return ReferralError.networkError;
      case 'permission-denied':
        if (kDebugMode) {
          debugPrint('[REFERRAL] permission-denied — check function deployment & App Check enforcement');
        }
        return ReferralError.unknown;
      case 'deadline-exceeded':
        if (kDebugMode) {
          debugPrint('[REFERRAL] CF deadline-exceeded — treating as network error');
        }
        return ReferralError.networkError;
      case 'not-implemented':
      case 'internal':
      case 'unavailable':
        if (kDebugMode) {
          debugPrint('[REFERRAL] redeemReferralCode function missing or not '
              'deployed (code=$code). Run: firebase deploy --only functions:redeemReferralCode');
        }
        // We've already attempted the client fallback by the time this maps;
        // surfacing networkError tells the user the action is retryable.
        return ReferralError.networkError;
      default:
        return ReferralError.unknown;
    }
  }

  /// Debug-only: delete `referrals/{uid}` and reset the user's
  /// `Referral.referralUsed` flag so the same account can test the invite
  /// flow again.
  ///
  /// Usage from a debug button or console:
  /// ```dart
  /// await ReferralService.instance.debugResetReferral();
  /// ```
  ///
  /// Alternatively, delete the Firestore document manually:
  ///   Firestore Console → referrals/{uid} → Delete document
  ///   Firestore Console → users/{uid} → Referral.referralUsed = false
  Future<void> debugResetReferral() async {
    if (!kDebugMode) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[REFERRAL][DEBUG] no signed-in user');
      return;
    }
    try {
      await _fs.collection('referrals').doc(uid).delete();
      await _fs.collection('users').doc(uid).set(
        <String, dynamic>{
          'Referral': <String, dynamic>{
            'referralUsed': false,
            'referredBy': FieldValue.delete(),
            'referredByCode': FieldValue.delete(),
          },
        },
        SetOptions(merge: true),
      );
      debugPrint('[REFERRAL][DEBUG] reset complete for uid=$uid — '
          'referrals/$uid deleted, Referral.referralUsed=false');
    } catch (e) {
      debugPrint('[REFERRAL][DEBUG] reset failed: $e');
    }
  }
}
