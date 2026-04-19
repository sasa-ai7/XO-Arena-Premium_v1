import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Exposes current online status. Used for offline banner and gating Firestore/coins.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;

  ConnectivityService._() {
    _init();
  }

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> _init() async {
    await _update();
    _sub = Connectivity().onConnectivityChanged.listen((_) => _update());
  }

  Future<void> _update() async {
    try {
      final result = await Connectivity().checkConnectivity().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          // If timeout, assume online to avoid blocking UI
          if (kDebugMode) {
            debugPrint('[ConnectivityService] checkConnectivity timeout - assuming online');
          }
          return [ConnectivityResult.wifi]; // Return wifi to assume online
        },
      );
      final online = result.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
      if (isOnline.value != online) {
        isOnline.value = online;
      }
    } catch (e) {
      // If error, assume online to avoid blocking UI
      if (kDebugMode) {
        debugPrint('[ConnectivityService] _update error: $e - assuming online');
      }
      if (!isOnline.value) {
        isOnline.value = true; // Assume online on error
      }
    }
  }

  /// Current value without listening.
  Future<bool> get online async {
    try {
      await _update();
      return isOnline.value;
    } catch (e) {
      // If error, assume online to avoid blocking UI
      if (kDebugMode) {
        debugPrint('[ConnectivityService] online getter error: $e - assuming online');
      }
      return true; // Assume online on error
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
