import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_l10n.dart';
import '../services/app_mode_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_store.dart';
import 'connection_lost_match_overlay.dart' show OverlayButton;

/// Full-screen Weak Connection overlay shown when [AppMode.connectionProblem]
/// is active outside an in-progress online match.
///
/// The user must explicitly choose:
///   • Restart in Offline Mode — calls [LocalStore.restartIntoOfflineMode]
///   • Try Reconnect — runs a connectivity + Firestore health check
///
/// We never silently auto-switch into offline mode anymore; the user always
/// chooses, which prevents accidental online/offline data merges.
class WeakConnectionOverlay extends StatefulWidget {
  const WeakConnectionOverlay({super.key});

  @override
  State<WeakConnectionOverlay> createState() => _WeakConnectionOverlayState();
}

class _WeakConnectionOverlayState extends State<WeakConnectionOverlay> {
  bool _busy = false;

  Future<void> _onRestartOffline() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await LocalStore.restartIntoOfflineMode();
      // AppMode is now AppMode.offline; the overlay is dismissed
      // automatically by the parent ValueListenableBuilder.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onTryReconnect() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (kDebugMode) debugPrint('[RECONNECT] try reconnect tapped');

    try {
      // Step 1: connectivity check.
      final online = await ConnectivityService().online;
      if (!online) {
        if (kDebugMode) debugPrint('[RECONNECT] still offline');
        if (mounted) {
          final l10n = AppL10n.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.connectionStillUnavailable)),
          );
        }
        return;
      }

      // Step 2: lightweight Firestore reachability check.
      if (kDebugMode) debugPrint('[RECONNECT] health check started');
      final ok = await _firestoreHealthCheck(const Duration(seconds: 4));
      if (!ok) {
        if (kDebugMode) debugPrint('[RECONNECT] health check failed');
        if (mounted) {
          final l10n = AppL10n.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.connectionStillUnavailable)),
          );
        }
        return;
      }
      if (kDebugMode) debugPrint('[RECONNECT] health check passed');

      // Step 3: hand off. Never set AppMode.online directly here — that
      // bypasses the auth check and listener restart inside HomeHub.
      // Instead, let HomeHub's connectivity listener observe the network
      // returning and run its own _handleReconnection (which checks
      // FirebaseAuth.currentUser, runs the health check, and only then
      // promotes to AppMode.online).
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid.isEmpty) {
        if (kDebugMode) {
          debugPrint('[RECONNECT] aborted — no authenticated user');
        }
        // Stay in connectionProblem so the overlay remains; let the user
        // restart offline or sign in again.
        return;
      }
      // Nudging the mode notifier triggers HomeHub's listeners which run
      // the full reconnect sequence (health check + pullServerToLocal +
      // listener restart).
      AppModeService.setMode(AppMode.switchingToOnline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _firestoreHealthCheck(Duration timeout) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // No signed-in user — we can't probe Firestore, but the OS says
      // online, so trust that.
      return true;
    }
    try {
      await FirebaseFirestore.instance.enableNetwork();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[RECONNECT] health check error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Material(
      color: Colors.black.withOpacity(0.88),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00CFFF).withOpacity(0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00CFFF).withOpacity(0.18),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00CFFF).withOpacity(0.12),
                    border: Border.all(
                      color: const Color(0xFF00CFFF).withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFF00CFFF),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.weakConnectionTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF00CFFF),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.weakConnectionBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                OverlayButton(
                  label: l10n.restartInOfflineMode,
                  icon: Icons.offline_bolt_outlined,
                  isPrimary: true,
                  onTap: _busy ? () {} : _onRestartOffline,
                ),
                const SizedBox(height: 12),
                OverlayButton(
                  label: _busy
                      ? l10n.tryingToReconnect
                      : l10n.tryReconnect,
                  icon: Icons.wifi_find_outlined,
                  isPrimary: false,
                  onTap: _busy ? () {} : _onTryReconnect,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay shown when the user is in [AppMode.offline] and internet just
/// came back. Asks "Go Online?" — never auto-switches.
class OnlineSwitchConfirmOverlay extends StatelessWidget {
  const OnlineSwitchConfirmOverlay({super.key});

  void _onStayOffline() {
    if (kDebugMode) debugPrint('[ONLINE_SWITCH] user chose stay offline');
    AppModeService.pendingOnlineSwitch.value = false;
  }

  Future<void> _onGoOnline() async {
    if (kDebugMode) debugPrint('[ONLINE_SWITCH] user chose go online');
    AppModeService.pendingOnlineSwitch.value = false;
    if (kDebugMode) {
      debugPrint('[ONLINE_SWITCH] offline data saved locally');
      debugPrint('[ONLINE_SWITCH] no offline data merged');
    }
    // Run the real confirmed reconnect sequence (health check + auth verify
    // + enable Firestore network + pullServerToLocal + restoreOnlineCoins +
    // AppMode.online + listener restart). We deliberately do NOT fake a
    // disconnect-then-reconnect event on ConnectivityService — that
    // produced the misleading "AppMode → connectionProblem / NETWORK
    // connection lost" log lines on a perfectly healthy network.
    await AppModeService.requestGoOnlineFromOffline();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Material(
      color: Colors.black.withOpacity(0.88),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00CFFF).withOpacity(0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00CFFF).withOpacity(0.18),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00CFFF).withOpacity(0.12),
                    border: Border.all(
                      color: const Color(0xFF00CFFF).withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.wifi_rounded,
                    color: Color(0xFF00CFFF),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.goOnlineTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF00CFFF),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.goOnlineBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                OverlayButton(
                  label: l10n.goOnlinePrimary,
                  icon: Icons.wifi_tethering_rounded,
                  isPrimary: true,
                  onTap: _onGoOnline,
                ),
                const SizedBox(height: 12),
                OverlayButton(
                  label: l10n.stayOffline,
                  icon: Icons.offline_bolt_outlined,
                  isPrimary: false,
                  onTap: _onStayOffline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Root-level wrapper that overlays [WeakConnectionOverlay] above any screen
/// when [AppMode.connectionProblem] is the current mode, and the
/// [OnlineSwitchConfirmOverlay] when [AppModeService.pendingOnlineSwitch]
/// is true.
///
/// Mounted via the [MaterialApp.builder] hook so it sits above every route
/// (home, store, settings, login, etc.) without needing per-screen wiring.
class AppModeOverlayHost extends StatelessWidget {
  final Widget child;
  const AppModeOverlayHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppMode>(
      valueListenable: AppModeService.modeNotifier,
      builder: (_, mode, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppModeService.pendingOnlineSwitch,
          builder: (_, pendingOnline, __) {
            final showWeak = mode == AppMode.connectionProblem;
            final showGoOnline = pendingOnline && mode == AppMode.offline;
            return Stack(
              children: [
                child,
                if (showWeak)
                  const Positioned.fill(child: WeakConnectionOverlay()),
                if (showGoOnline)
                  const Positioned.fill(child: OnlineSwitchConfirmOverlay()),
              ],
            );
          },
        );
      },
    );
  }
}

