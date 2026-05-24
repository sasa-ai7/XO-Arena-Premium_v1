import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/keys.dart';
import '../local_store.dart';
import 'arena_repo.dart';

/// Returns the equipped cosmetics map to spread into an Arena room's
/// `players[uid]` entry. Reads SharedPreferences first (fast / offline-safe)
/// then best-effort merges newer values from `users/{uid}.Cosmetics` in
/// Firestore so a fresh device reflects the latest equipped items.
///
/// Shape:
///   selectedAvatar : int    (avatar id; 0 = none equipped)
///   selectedXSkin  : String (skin id; 'default' = built-in)
///   selectedOSkin  : String
///   coinsAtJoin    : int    (snapshot of local coin balance)
Future<Map<String, dynamic>> loadArenaPlayerCosmetics() async {
  final prefs = await SharedPreferences.getInstance();
  int equippedAvatar = prefs.getInt(Keys.equippedAvatar) ?? 0;
  String selectedXSkin = prefs.getString(Keys.selectedXSkin) ?? 'default';
  String selectedOSkin = prefs.getString(Keys.selectedOSkin) ?? 'default';

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null && uid.isNotEmpty) {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final cosmetics = snap.data()?['Cosmetics'];
      if (cosmetics is Map) {
        final serverAvatar = cosmetics['equippedAvatar'];
        final serverXSkin = cosmetics['selectedXSkin'];
        final serverOSkin = cosmetics['selectedOSkin'];
        if (serverAvatar is num) equippedAvatar = serverAvatar.toInt();
        if (serverXSkin is String && serverXSkin.isNotEmpty) {
          selectedXSkin = serverXSkin;
        }
        if (serverOSkin is String && serverOSkin.isNotEmpty) {
          selectedOSkin = serverOSkin;
        }
        await prefs.setInt(Keys.equippedAvatar, equippedAvatar);
        await prefs.setString(Keys.selectedXSkin, selectedXSkin);
        await prefs.setString(Keys.selectedOSkin, selectedOSkin);
      }
    } catch (_) {
      // Network/permission error → fall back to local prefs.
    }
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
  final selectedAvatar = prefs.getInt(Keys.equippedAvatar) ?? 0;

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
