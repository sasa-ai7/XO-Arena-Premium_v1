import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Current app connectivity / session mode.
/// This is the single source of truth for which data layer is active.
enum AppMode {
  /// Fully online: Firestore listeners active, server is authoritative.
  online,

  /// Fully offline: no Firestore ops, offline profile is authoritative.
  offline,

  /// Transition: cancelling online listeners, loading offline profile.
  switchingToOffline,

  /// Transition: pulling server data, restoring online account.
  switchingToOnline,

  /// Connection lost while user is inside an active online match.
  /// The match is paused; the overlay is shown. No result, no Firestore writes.
  /// The offline profile is NOT activated — we simply block everything.
  connectionLostDuringOnlineMatch,

  /// General connection problem on the home / store / settings screens.
  /// Used to show a non-modal warning banner without switching to offline profile.
  connectionProblem,

  /// Cleaning up all online state to restart cleanly into offline mode.
  /// Every Firestore operation is blocked during this transition.
  restartingToOffline,
}

class AppModeService {
  AppModeService._();

  /// Reactive mode notifier — HomeHub and widgets listen to this.
  static final ValueNotifier<AppMode> modeNotifier =
      ValueNotifier<AppMode>(AppMode.online);

  static AppMode get current => modeNotifier.value;

  /// True when connectivity returned while the user is in [AppMode.offline]
  /// and we are waiting for them to confirm the switch to online. The
  /// overlay host listens to this and renders the "Go Online?" dialog.
  static final ValueNotifier<bool> pendingOnlineSwitch =
      ValueNotifier<bool>(false);

  // ── Convenience getters ───────────────────────────────────────────────────

  /// True when Firestore reads/writes are unsafe.
  /// Covers every non-online mode except [switchingToOnline].
  static bool get isOfflineLike =>
      current == AppMode.offline ||
      current == AppMode.switchingToOffline ||
      current == AppMode.connectionLostDuringOnlineMatch ||
      current == AppMode.connectionProblem ||
      current == AppMode.restartingToOffline;

  /// True only when it is completely safe to use Firestore and online services.
  ///
  /// Hardened (2026-05): we no longer return true during
  /// [AppMode.switchingToOnline]. That transitional mode is set BEFORE the
  /// reconnect health check + auth re-verification finish, and allowing
  /// wallet writes / IAP / new listeners during that window is what made
  /// the stake-after-disconnect bug possible. Reconnect-internal steps that
  /// must run pre-online (health check, pullServerToLocal, enableNetwork)
  /// bypass this gate via [withReconnectToken].
  static bool get canUseOnlineServices => current == AppMode.online;

  /// True only when the app is fully and stably in [AppMode.online].
  /// Alias for callers that want an unambiguous name.
  static bool get isStableOnline => current == AppMode.online;

  // ── Reconnect token ───────────────────────────────────────────────────────

  /// Active "Go Online" reconnect attempt id.
  ///
  /// Set by the reconnect controller before the controlled steps run
  /// (health check, auth verify, enable network, pull server data) and
  /// cleared once the sequence either reaches [AppMode.online] or aborts.
  ///
  /// While non-null, connectivity listeners should ignore stale `connection
  /// lost` events — a brief Firestore retry blip is part of the reconnect
  /// dance and must not flip the app back to [connectionProblem] mid-flow.
  static String? _activeReconnectToken;

  /// True while a Go Online reconnect sequence is in progress.
  static bool get isReconnecting => _activeReconnectToken != null;

  /// Run [body] under a reconnect token so that controlled steps which
  /// legitimately need to use Firestore before [AppMode.online] is reached
  /// can do so. The token is valid for the lifetime of [body].
  ///
  /// If [body] throws, the token is cleared automatically and the caller is
  /// expected to set an appropriate failure mode (e.g.
  /// [AppMode.connectionProblem]).
  static Future<T> withReconnectToken<T>(Future<T> Function(String token) body) async {
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    _activeReconnectToken = token;
    if (kDebugMode) debugPrint('[RECONNECT] attemptId=$token started');
    try {
      return await body(token);
    } finally {
      if (_activeReconnectToken == token) {
        _activeReconnectToken = null;
        if (kDebugMode) debugPrint('[RECONNECT] attemptId=$token finished');
      }
    }
  }

  /// True if a reconnect-internal step is permitted to bypass the strict
  /// [canUseOnlineServices] gate. Used by [LocalStore] paths that the
  /// reconnect controller calls intentionally (health check, pull, enable).
  static bool get canUseOnlineServicesForReconnect =>
      canUseOnlineServices || isReconnecting;

  // ── Confirmed Go Online hook ──────────────────────────────────────────────
  //
  // The "Go Online?" overlay (shown while offline once connectivity returns)
  // must NOT fake connectivity-lost/regained events to nudge the reconnect
  // flow. Instead, it registers a callback here that HomeHub installs at
  // mount time. The callback runs the real reconnect sequence under a
  // reconnect token.

  static Future<void> Function()? _onConfirmedGoOnline;

  static void registerConfirmedGoOnlineHandler(
    Future<void> Function()? handler,
  ) {
    _onConfirmedGoOnline = handler;
  }

  /// Invoke the registered "Go Online" reconnect flow. Returns immediately
  /// if no handler is registered (e.g. HomeHub not mounted).
  static Future<void> requestGoOnlineFromOffline() async {
    final handler = _onConfirmedGoOnline;
    if (handler == null) {
      if (kDebugMode) {
        debugPrint('[ONLINE_SWITCH] no handler registered — request ignored');
      }
      return;
    }
    await handler();
  }

  /// True when the app is fully in offline mode (offline profile active).
  static bool get isOffline =>
      current == AppMode.offline ||
      current == AppMode.switchingToOffline ||
      current == AppMode.restartingToOffline;

  /// True during any transitional state.
  static bool get isSwitching =>
      current == AppMode.switchingToOffline ||
      current == AppMode.switchingToOnline ||
      current == AppMode.restartingToOffline;

  /// True when there is a connection problem (match or general).
  static bool get hasConnectionProblem =>
      current == AppMode.connectionLostDuringOnlineMatch ||
      current == AppMode.connectionProblem;

  static void setMode(AppMode mode) {
    if (modeNotifier.value == mode) return; // No-op if already in this mode
    if (kDebugMode) debugPrint('[AppMode] → $mode');
    final previous = modeNotifier.value;
    modeNotifier.value = mode;
    _applyFirestoreNetworkPolicy(previous, mode);
  }

  /// Whether we've already asked the Firestore SDK to disable its network.
  /// Prevents redundant calls and keeps the SDK from spinning up new
  /// WatchStream/WriteStream retries while offline.
  static bool _firestoreNetworkDisabled = false;

  /// Toggle the Firestore SDK network based on the new app mode.
  ///
  /// When we move into an offline-like mode, ask Firestore to stop its
  /// internal stream/retry machinery. When we move back to a safely-online
  /// mode, re-enable it. This is what silences the "Unable to resolve host
  /// firestore.googleapis.com" / WatchStream / WriteStream log spam.
  static void _applyFirestoreNetworkPolicy(AppMode previous, AppMode next) {
    final shouldDisable = next == AppMode.offline ||
        next == AppMode.switchingToOffline ||
        next == AppMode.restartingToOffline ||
        next == AppMode.connectionProblem ||
        next == AppMode.connectionLostDuringOnlineMatch;

    // Only re-enable the Firestore network when we've actually committed
    // to AppMode.online. We deliberately do NOT enable on
    // [AppMode.switchingToOnline] — that mode is set BEFORE the reconnect
    // health check and auth re-verification run. Enabling there would let
    // listeners + retry streams start before we've confirmed we can reach
    // the server, which is exactly the spam the logs showed.
    final shouldEnable = next == AppMode.online;

    // Fire-and-forget — these futures don't block the UI and the SDK is
    // already idempotent about repeated calls.
    if (shouldDisable && !_firestoreNetworkDisabled) {
      _firestoreNetworkDisabled = true;
      FirebaseFirestore.instance.disableNetwork().catchError((Object e) {
        if (kDebugMode) {
          debugPrint('[FIRESTORE] disableNetwork failed (non-fatal): $e');
        }
      });
      if (kDebugMode) {
        debugPrint('[FIRESTORE] network disabled (mode=$next)');
      }
    } else if (shouldEnable && _firestoreNetworkDisabled) {
      _firestoreNetworkDisabled = false;
      FirebaseFirestore.instance.enableNetwork().catchError((Object e) {
        if (kDebugMode) {
          debugPrint('[FIRESTORE] enableNetwork failed (non-fatal): $e');
        }
      });
      if (kDebugMode) {
        debugPrint('[FIRESTORE] network enabled (mode=$next)');
      }
    }
  }
}
