import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/keys.dart';
import '../../models/game_avatar.dart';
import '../local_store.dart';
import 'arena_repo.dart';

/// Returns the equipped cosmetics map to spread into an Arena room's
/// `players[uid]` entry. SharedPreferences is the immediate source of truth:
/// auth bootstrap has already hydrated it from Firestore, while a Store equip
/// may still be waiting for its background Firestore mirror. Reading the
/// server again here could revert a newly equipped frame before room creation.
///
/// Shape:
///   selectedAvatar : int    (avatar id; 0 = none equipped)
///   selectedXSkin  : String (skin id; 'default' = built-in)
///   selectedOSkin  : String
///   coinsAtJoin    : int    (snapshot of local coin balance)
Future<Map<String, dynamic>> loadArenaPlayerCosmetics() async {
  final prefs = await SharedPreferences.getInstance();
  final rawAvatar = prefs.getInt(Keys.equippedAvatar) ?? 0;
  final equippedAvatar = parseEquippedAvatarId(rawAvatar);
  final selectedXSkin = prefs.getString(Keys.selectedXSkin) ?? 'default';
  final selectedOSkin = prefs.getString(Keys.selectedOSkin) ?? 'default';

  if (rawAvatar != equippedAvatar) {
    await prefs.setInt(Keys.equippedAvatar, equippedAvatar);
    if (kDebugMode) {
      debugPrint('[ARENA_COSMETICS] sanitized avatar '
          'from=$rawAvatar to=$equippedAvatar');
    }
  }
  if (LocalStore.equippedAvatarNotifier.value != equippedAvatar) {
    LocalStore.equippedAvatarNotifier.value = equippedAvatar;
  }

  return <String, dynamic>{
    'selectedAvatar': equippedAvatar,
    'selectedXSkin': selectedXSkin,
    'selectedOSkin': selectedOSkin,
    'coinsAtJoin': LocalStore.coinsNotifier.value,
  };
}

/// Push the current user's equipped cosmetics into their active Arena room
/// player entry. Call after buying/equipping a skin or avatar while in lobby.
Future<void> syncCurrentCosmeticsToActiveArenaRoom() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  final activeRoomCode = await ArenaRepo.instance.getActiveRoomCode(uid);
  if (activeRoomCode == null) return;

  final prefs = await SharedPreferences.getInstance();
  final selectedXSkin = prefs.getString(Keys.selectedXSkin) ?? 'default';
  final selectedOSkin = prefs.getString(Keys.selectedOSkin) ?? 'default';
  final rawAvatar = prefs.getInt(Keys.equippedAvatar) ?? 0;
  final selectedAvatar = parseEquippedAvatarId(rawAvatar);
  if (selectedAvatar != rawAvatar) {
    await prefs.setInt(Keys.equippedAvatar, selectedAvatar);
  }
  if (LocalStore.equippedAvatarNotifier.value != selectedAvatar) {
    LocalStore.equippedAvatarNotifier.value = selectedAvatar;
  }

  try {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kArenaDatabaseUrl,
    );
    await db.ref('rooms/$activeRoomCode/players/$uid').update({
      'selectedXSkin': selectedXSkin,
      'selectedOSkin': selectedOSkin,
      'selectedAvatar': selectedAvatar,
    });
    if (kDebugMode) {
      debugPrint('[ARENA_COSMETICS] synced to room=$activeRoomCode '
          'xSkin=$selectedXSkin oSkin=$selectedOSkin avatar=$selectedAvatar');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[ARENA_COSMETICS] sync failed: $e');
    }
  }
}
