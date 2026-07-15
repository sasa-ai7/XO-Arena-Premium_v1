import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/game_avatar.dart';
import '../services/local_store.dart';
import '../services/mission_service.dart';
import '../services/connectivity_service.dart';
import 'coins_catalog.dart';

/// Tracks ownership of the one-time premium avatar entitlements:
///   • xo_avatar_premium       → premium_avatar_29 → catalog avatar id 29 (Golden Halo)
///   • xo_avatar_premium1      → premium_avatar_30 → catalog avatar id 30 (Star Crown)
///
/// Listens to `users/{uid}.Inventory.avatars` and exposes reactive notifiers
/// the UI can bind to so the shop hides the relevant avatar offer the moment
/// Cloud Functions writes the entitlement.
class PremiumAvatarService {
  PremiumAvatarService._();
  static final PremiumAvatarService instance = PremiumAvatarService._();

  /// Reactive: true when the original Inferno premium avatar is owned.
  ///
  /// Kept as a stand-alone notifier (rather than a derived map) so existing
  /// listeners (avatar_store_tab, store_page, etc.) keep working unchanged.
  final ValueNotifier<bool> owned = ValueNotifier<bool>(false);

  /// Reactive: true when the Apex premium avatar is owned.
  final ValueNotifier<bool> ownedApex = ValueNotifier<bool>(false);

  String? _activeUid;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _refreshInFlight = false;
  bool _connectivityListenerBound = false;

  /// Legacy alias retained for callers that referenced the original entitlement.
  static const String entitlementId = CoinsCatalog.premiumAvatarEntitlement;

  /// True if [productId] refers to any premium avatar product (any of the
  /// two non-consumable offers).
  static bool isPremiumAvatarProduct(String productId) =>
      CoinsCatalog.isAvatarProduct(productId);

  /// True when [GameAvatar.id] is a premium IAP avatar.
  static bool isPremiumAvatar(GameAvatar avatar) {
    if (!avatar.isPremiumIap) return false;
    return avatar.id == CoinsCatalog.premiumAvatarId ||
        avatar.id == CoinsCatalog.premiumAvatarApexId;
  }

  /// Bind / rebind to the currently signed-in user. Safe to call on every
  /// auth change — duplicate binds for the same uid are no-ops.
  Future<void> bind() async {
    _bindConnectivityRetry();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _activeUid = null;
      _retryTimer?.cancel();
      owned.value = false;
      ownedApex.value = false;
      return;
    }
    if (uid == _activeUid) {
      await _hydrateFromLocalSafely();
      unawaited(_refreshFromFirestore());
      return;
    }
    _retryTimer?.cancel();
    _retryAttempt = 0;
    _activeUid = uid;
    await _hydrateFromLocalSafely();
    // Server convergence is never part of screen startup. Cached ownership is
    // immediately usable and Firestore refreshes silently in the background.
    unawaited(_refreshFromFirestore());
  }

  void _bindConnectivityRetry() {
    if (_connectivityListenerBound) return;
    _connectivityListenerBound = true;
    ConnectivityService().isOnline.addListener(() {
      if (!ConnectivityService().isOnline.value || _activeUid == null) return;
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 350), () {
        unawaited(_refreshFromFirestore());
      });
    });
  }

  Future<void> _hydrateFromLocal() async {
    final ids = await LocalStore.ownedAvatars();
    owned.value = ids.contains(CoinsCatalog.premiumAvatarId);
    ownedApex.value = ids.contains(CoinsCatalog.premiumAvatarApexId);
  }

  Future<void> _hydrateFromLocalSafely() async {
    try {
      await _hydrateFromLocal();
    } catch (_) {
      // Keep the last in-memory values. Local cache failures must not make the
      // store unusable or surface an unhandled error from an unawaited bind.
      if (kDebugMode) {
        debugPrint(
            '[PremiumAvatarService] cached ownership temporarily unavailable');
      }
    }
  }

  /// One-shot pull from Firestore. The shop calls this on screen open and
  /// after every IAP completion to converge ownership state quickly.
  Future<void> _refreshFromFirestore() async {
    final uid = _activeUid;
    if (uid == null || _refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final data = snap.data();
      if (data == null) return;
      if (_activeUid != uid) return;
      final inventory = data['Inventory'];
      final avatars = inventory is Map ? inventory['avatars'] : null;
      if (avatars is! List) return;
      final entitlementStrings =
          avatars.map((e) => e?.toString()).whereType<String>().toSet();
      if (!owned.value &&
          entitlementStrings.contains(CoinsCatalog.premiumAvatarEntitlement)) {
        await markOwnedLocally(CoinsCatalog.premiumAvatarId);
      }
      if (!ownedApex.value &&
          entitlementStrings
              .contains(CoinsCatalog.premiumAvatarApexEntitlement)) {
        await markOwnedLocally(CoinsCatalog.premiumAvatarApexId);
      }
      _retryAttempt = 0;
      _retryTimer?.cancel();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' ||
          e.code == 'deadline-exceeded' ||
          e.code == 'network-request-failed') {
        _scheduleRetry();
        if (kDebugMode) {
          debugPrint(
              '[PremiumAvatarService] refresh deferred: connection unavailable');
        }
      } else if (kDebugMode) {
        debugPrint(
            '[PremiumAvatarService] refresh deferred: temporary service issue');
      }
    } catch (_) {
      _scheduleRetry();
      if (kDebugMode) {
        debugPrint(
            '[PremiumAvatarService] refresh deferred: temporary service issue');
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  void _scheduleRetry() {
    if (_activeUid == null || _retryTimer?.isActive == true) return;
    const delays = <Duration>[
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 45),
      Duration(minutes: 2),
    ];
    final delay = delays[_retryAttempt.clamp(0, delays.length - 1)];
    if (_retryAttempt < delays.length - 1) _retryAttempt++;
    _retryTimer = Timer(delay, () {
      if (_activeUid != null && ConnectivityService().isOnline.value) {
        unawaited(_refreshFromFirestore());
      } else {
        _retryTimer = null;
        _scheduleRetry();
      }
    });
  }

  /// Apply the entitlement to local stores. Pass the catalog [avatarId]
  /// (29 for Golden Halo or 30 for Star Crown). Defaults to the first premium
  /// avatar so legacy callers continue to compile unchanged.
  Future<void> markOwnedLocally([int? avatarId]) async {
    final id = avatarId ?? CoinsCatalog.premiumAvatarId;
    await LocalStore.addOwnedAvatar(id);
    if (id == CoinsCatalog.premiumAvatarId) {
      owned.value = true;
    } else if (id == CoinsCatalog.premiumAvatarApexId) {
      ownedApex.value = true;
    }
    // One-time "buy a premium avatar" milestone (capped + claim-once, so a
    // repeat hydrate can never double-count).
    await MissionService.instance.trackEvent('premium_avatar_bought');
  }
}
