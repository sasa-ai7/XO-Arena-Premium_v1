import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/game_avatar.dart';
import '../services/local_store.dart';
import 'coins_catalog.dart';

/// Tracks ownership of the one-time premium avatar entitlements:
///   • xo_avatar_premium       → premium_avatar_7  → catalog avatar id 7
///   • xo_avatar_premium_apex  → premium_avatar_10 → catalog avatar id 10
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == _activeUid) {
      await _hydrateFromLocal();
      return;
    }
    _activeUid = uid;
    if (uid == null) {
      owned.value = false;
      ownedApex.value = false;
      return;
    }
    await _hydrateFromLocal();
    await _refreshFromFirestore();
  }

  Future<void> _hydrateFromLocal() async {
    final ids = await LocalStore.ownedAvatars();
    owned.value = ids.contains(CoinsCatalog.premiumAvatarId);
    ownedApex.value = ids.contains(CoinsCatalog.premiumAvatarApexId);
  }

  /// One-shot pull from Firestore. The shop calls this on screen open and
  /// after every IAP completion to converge ownership state quickly.
  Future<void> _refreshFromFirestore() async {
    final uid = _activeUid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final data = snap.data();
      if (data == null) return;
      final inventory = data['Inventory'];
      final avatars = inventory is Map ? inventory['avatars'] : null;
      if (avatars is! List) return;
      final entitlementStrings =
          avatars.map((e) => e?.toString()).whereType<String>().toSet();
      if (entitlementStrings.contains(CoinsCatalog.premiumAvatarEntitlement)) {
        await markOwnedLocally(CoinsCatalog.premiumAvatarId);
      }
      if (entitlementStrings
          .contains(CoinsCatalog.premiumAvatarApexEntitlement)) {
        await markOwnedLocally(CoinsCatalog.premiumAvatarApexId);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PremiumAvatarService] refresh error: $e');
      }
    }
  }

  /// Apply the entitlement to local stores. Pass the catalog [avatarId]
  /// (7 for Inferno or 10 for Apex). Defaults to the original Inferno avatar
  /// so legacy callers continue to compile unchanged.
  Future<void> markOwnedLocally([int? avatarId]) async {
    final id = avatarId ?? CoinsCatalog.premiumAvatarId;
    await LocalStore.addOwnedAvatar(id);
    if (id == CoinsCatalog.premiumAvatarId) {
      owned.value = true;
    } else if (id == CoinsCatalog.premiumAvatarApexId) {
      ownedApex.value = true;
    }
  }
}
