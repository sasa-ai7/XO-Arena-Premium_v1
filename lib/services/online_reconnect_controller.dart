import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../coins/iap_coins_service.dart';
import 'app_mode_service.dart';
import 'connectivity_service.dart';
import 'local_store.dart';
import 'mission_service.dart';
import 'user_repo.dart';
import 'wallet_history_service.dart';

/// App-lifetime owner of connectivity and online-mode restoration.
/// Screen hooks improve live UI recovery, but the actual mode transition and
/// Firebase refresh never depend on a route being mounted.
class OnlineReconnectController {
  OnlineReconnectController._();
  static final OnlineReconnectController instance =
      OnlineReconnectController._();

  bool _initialized = false;
  bool _restoring = false;
  bool _lastOnline = true;
  VoidCallback? _cancelScreenListeners;
  Future<void> Function()? _onOnlineRestored;

  void init() {
    if (_initialized) return;
    _initialized = true;
    _lastOnline = ConnectivityService().isOnline.value;
    ConnectivityService().isOnline.addListener(_onConnectivityChanged);
    AppModeService.modeNotifier.addListener(_onModeChanged);
    AppModeService.registerConfirmedGoOnlineHandler(restoreOnline);
    if (kDebugMode) debugPrint('[ONLINE_SWITCH] handler registered');
  }

  void registerScreenHooks({
    VoidCallback? cancelOnlineListeners,
    Future<void> Function()? onOnlineRestored,
  }) {
    _cancelScreenListeners = cancelOnlineListeners;
    _onOnlineRestored = onOnlineRestored;
  }

  void clearScreenHooks() {
    _cancelScreenListeners = null;
    _onOnlineRestored = null;
  }

  void _onConnectivityChanged() {
    final online = ConnectivityService().isOnline.value;
    if (online == _lastOnline) return;
    _lastOnline = online;
    if (online) {
      if (kDebugMode) debugPrint('[CONNECTIVITY] online restored');
      _handleOnlineRestored();
    } else {
      if (kDebugMode) debugPrint('[CONNECTIVITY] offline detected');
      _handleOfflineDetected();
    }
  }

  void _handleOfflineDetected() {
    AppModeService.pendingOnlineSwitch.value = false;
    _cancelScreenListeners?.call();
    if (LocalStore.isInOnlineMatch.value) {
      AppModeService.setMode(AppMode.connectionLostDuringOnlineMatch);
    } else if (AppModeService.current == AppMode.online ||
        AppModeService.current == AppMode.switchingToOnline) {
      AppModeService.setMode(AppMode.connectionProblem);
    }
  }

  void _handleOnlineRestored() {
    final user = FirebaseAuth.instance.currentUser;
    if (AppModeService.current == AppMode.offline) {
      if (user != null && user.uid.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
              '[ONLINE_SWITCH] connection back while offline — asking user');
        }
        AppModeService.pendingOnlineSwitch.value = true;
      }
      return;
    }
    if (user != null &&
        (AppModeService.current == AppMode.connectionProblem ||
            AppModeService.current ==
                AppMode.connectionLostDuringOnlineMatch)) {
      unawaited(restoreOnline());
    }
  }

  void _onModeChanged() {
    if (AppModeService.current == AppMode.offline &&
        ConnectivityService().isOnline.value &&
        FirebaseAuth.instance.currentUser != null) {
      AppModeService.pendingOnlineSwitch.value = true;
      return;
    }
    if (AppModeService.current == AppMode.switchingToOnline && !_restoring) {
      unawaited(restoreOnline());
    }
  }

  Future<void> restoreOnline() async {
    if (_restoring) return;
    _restoring = true;
    AppModeService.pendingOnlineSwitch.value = false;
    if (kDebugMode) debugPrint('[ONLINE_SWITCH] restore requested');
    try {
      if (!await ConnectivityService().online) {
        throw const _ReconnectFailure('network unavailable');
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid.isEmpty) {
        AppModeService.setMode(AppMode.offline);
        throw const _ReconnectFailure('no authenticated user');
      }

      AppModeService.setMode(AppMode.switchingToOnline);
      await AppModeService.withReconnectToken((_) async {
        await FirebaseFirestore.instance.enableNetwork();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 6));
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null || currentUser.uid != user.uid) {
          throw const _ReconnectFailure('auth session changed');
        }
        final pulled = await UserRepo().pullServerToLocal(user.uid);
        if (!pulled) throw const _ReconnectFailure('server pull blocked');
        await LocalStore.restoreOnlineCoins();
        AppModeService.setMode(AppMode.online);
        unawaited(WalletHistoryService.instance
            .flushPending(user.uid)
            .catchError((Object error) {
          if (kDebugMode) {
            debugPrint('[WALLET_HISTORY] reconnect flush deferred: $error');
          }
        }));
      });

      await MissionService.instance.init();
      await _onOnlineRestored?.call();
      unawaited(IapCoinsService().init());
      if (kDebugMode) debugPrint('[ONLINE_SWITCH] restore success');
    } catch (error) {
      if (AppModeService.current != AppMode.offline) {
        AppModeService.setMode(AppMode.connectionProblem);
      }
      if (kDebugMode) {
        debugPrint('[ONLINE_SWITCH] restore failed reason=$error');
      }
    } finally {
      _restoring = false;
    }
  }
}

class _ReconnectFailure implements Exception {
  final String reason;
  const _ReconnectFailure(this.reason);
  @override
  String toString() => reason;
}
