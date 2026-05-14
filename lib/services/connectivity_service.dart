import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Exposes current network status via [isOnline] notifier.
///
/// Changes are debounced by 1.5 seconds to avoid rapid on/off flapping
/// from brief signal blips triggering premature offline transitions.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;

  ConnectivityService._() {
    _init();
  }

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounceTimer;

  Future<void> _init() async {
    await _checkAndUpdate();
    _sub = Connectivity()
        .onConnectivityChanged
        .listen((_) => _scheduleUpdate());
  }

  /// Asymmetric debounce: offline changes fire after 150 ms (fast reaction to
  /// prevent mid-match writes); online changes wait 1300 ms (avoids premature
  /// reconnect on flaky networks where signal briefly returns).
  void _scheduleUpdate() {
    _debounceTimer?.cancel();
    // Peek at the current raw result to pick the right delay.
    // If we can't determine direction, use the conservative online delay.
    Connectivity().checkConnectivity().then((result) {
      final willBeOnline = result.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
      final delay = willBeOnline
          ? const Duration(milliseconds: 1300)
          : const Duration(milliseconds: 150);
      _debounceTimer?.cancel();
      _debounceTimer = Timer(delay, _checkAndUpdate);
    }).catchError((_) {
      _debounceTimer = Timer(const Duration(milliseconds: 1300), _checkAndUpdate);
    });
  }

  Future<void> _checkAndUpdate() async {
    try {
      // Timeout conservatively: if the OS takes > 3 s, treat as offline.
      final result = await Connectivity().checkConnectivity().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('[ConnectivityService] checkConnectivity timed out — treating as offline');
          }
          return [ConnectivityResult.none];
        },
      );
      final nowOnline = result.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);

      if (isOnline.value != nowOnline) {
        if (kDebugMode) {
          debugPrint('[ConnectivityService] → ${nowOnline ? "online" : "offline"}');
        }
        isOnline.value = nowOnline;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ConnectivityService] _checkAndUpdate error: $e');
      }
      // On unexpected error, do not change state — keep current assumption.
    }
  }

  /// One-shot online check (re-polls the OS).
  Future<bool> get online async {
    await _checkAndUpdate();
    return isOnline.value;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _sub?.cancel();
  }
}
