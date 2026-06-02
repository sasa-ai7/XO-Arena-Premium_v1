import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../coins/iap_coins_service.dart';
import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/coin_format.dart';
import '../../core/keys.dart';
import '../../core/responsive_metrics.dart';
import '../../models/game_avatar.dart';
import '../../models/offline_profile.dart';
import '../../services/app_mode_service.dart';
import '../../services/arena/arena_repo.dart';
import '../../services/arena/arena_resume_flow.dart';
import '../../services/auth_service.dart';
import '../../services/audit_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_store.dart';
import '../../services/notification_service.dart';
import '../../services/fcm_service.dart';
import '../../services/referral/pending_referral_reward_service.dart';
import '../../services/session_service.dart';
import '../../services/sound_service.dart';
import '../../services/user_repo.dart';
import '../../screens/login_screen.dart';
import '../../screens/games/setup_page.dart';
import '../../screens/games/friend_setup_page.dart';
import '../../screens/games/level_game_setup_page.dart';
import '../../screens/arena/arena_page.dart';
import '../../screens/arena/widgets/active_room_resume_dialog.dart';
import '../../screens/store/store_page.dart';
import '../../screens/settings/settings_page.dart';
import '../../core/app_config.dart';
import '../../utils/navigation_utils.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_toast.dart';
import '../../widgets/avatar_store_tab.dart';
import '../../widgets/connection_lost_match_overlay.dart';
import '../../widgets/full_avatar_display.dart';
import '../../widgets/mode_transition_overlay.dart';
import '../../widgets/onboarding_sheet.dart';
import 'home_widgets.dart';

class HomeHub extends StatefulWidget {
  const HomeHub({super.key});

  @override
  State<HomeHub> createState() => _HomeHubState();
}

class _HomeHubState extends State<HomeHub>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _offline = false;
  bool _isForceLoggingOut = false;
  bool _isReconnecting = false;
  bool _isDisconnecting = false;
  bool _globalResumeChecked = false;
  int _currentTab = 0;
  OfflinePlayerProfile? _offlineProfile;
  // Tracks which tabs have been visited so their widgets are built lazily
  final _visitedTabs = <int>{0};
  StreamSubscription? _authSub;
  StreamSubscription? _sessionSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _firestoreSub;

  // Staggered card entrance animation
  late final AnimationController _cardAnim;
  late final List<Animation<double>> _cardFades;
  late final List<Animation<Offset>> _cardSlides;

  bool get _isGuest => FirebaseAuth.instance.currentUser == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuditService.log('app_open');

    // Register the listener-cancel hook so LocalStore.restartIntoOfflineMode()
    // can cancel Firestore/session streams without holding a HomeHub reference.
    LocalStore.registerCancelListenersCallback(_cancelAllListeners);

    // Register the confirmed "Go Online" handler so the offline-mode
    // overlay can trigger the real reconnect flow without faking
    // connectivity events.
    AppModeService.registerConfirmedGoOnlineHandler(_runConfirmedGoOnline);

    _refresh();
    ConnectivityService().isOnline.addListener(_onConnectivityChanged);
    ConnectivityService().online.then((online) {
      if (mounted) setState(() => _offline = !online);
    });

    // Cancel Firestore/session listeners the moment auth state becomes null
    // (handles sign-out from SettingsPage before HomeHub is disposed)
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _cancelAllListeners();
        if (kDebugMode) debugPrint('[HomeHub] auth=null — listeners cancelled');
      }
    });

    // Defer Firestore/session listeners + onboarding to after first frame
    // so the 600 ms card entrance animation is not disrupted by the first snapshot.
    // IAP is deferred further (stable-online + 1.5 s) so MediaPlayer / Billing
    // init don't compete with the entrance animation for the main thread.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startFirestoreListener();
        _startSessionListener();
      }
      _scheduleIapInit();
      if (mounted) _checkNewUserOnboarding();
      if (mounted) _checkPendingReferralRewards();
      if (mounted) _maybePromptNotificationPermission();
      _initFcm();
      _scheduleGlobalResumeCheck();
      // Trigger music init after the 600ms entrance animation completes.
      // Delayed to avoid competing with the animation for the main thread.
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          unawaited(SoundService().init());
          if (kDebugMode) debugPrint('[MUSIC] init triggered from HomeHub');
        }
      });
    });

    // Staggered entrance: smooth 600ms sequence
    const starts = <double>[0.0, 0.3];
    const ends = <double>[0.6, 1.0];
    _cardAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _cardFades = List.generate(2, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _cardAnim,
            curve: Interval(starts[i], ends[i], curve: Curves.easeOutCubic)),
      );
    });
    _cardSlides = List.generate(2, (i) {
      return Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(
        CurvedAnimation(
            parent: _cardAnim,
            curve: Interval(starts[i], ends[i], curve: Curves.easeOutCubic)),
      );
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _cardAnim.forward();
    });
  }

  /// Schedule the one-shot global "Active Room Found" check shortly after the
  /// home entrance settles, so the resume prompt appears immediately on app
  /// open (not only after the user opens the Online tab).
  void _scheduleGlobalResumeCheck() {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _maybeShowGlobalActiveRoomPrompt();
    });
  }

  /// Settle any room that ended/expired while away, then offer the styled
  /// "Active Room Found" prompt for a still-valid room — from the Home/startup
  /// flow. One-shot per app session; never loops or double-shows.
  Future<void> _maybeShowGlobalActiveRoomPrompt() async {
    if (_globalResumeChecked) return;
    _globalResumeChecked = true;
    if (_isGuest) return;
    if (!AppModeService.canUseOnlineServices) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Mutually exclude with the Arena-tab resume check.
    if (ArenaRepo.instance.resumeFlowBusy) return;
    ArenaRepo.instance.resumeFlowBusy = true;
    try {
      if (kDebugMode) {
        debugPrint('[ACTIVE_ROOM_GLOBAL] startup_check uid=$uid');
      }

      final outcome = await ArenaResumeFlow.settlePendingActiveRoom(uid);
      if (!mounted) return;
      if (outcome.kind != PendingRoomKind.none) {
        await ArenaResumeFlow.showSettlementNotice(context, outcome,
            isAr: AppL10n.of(context).isAr);
        return;
      }

      final check = await ArenaRepo.instance.validateActiveRoom(uid);
      if (!mounted) return;
      if (!check.isValid) return;
      final code = check.code!;
      if (ArenaRepo.instance.resumeDismissedThisSession.contains(code)) return;
      if (kDebugMode) {
        debugPrint('[ACTIVE_ROOM_GLOBAL] found uid=$uid room=$code '
            'status=${check.room!.status}');
        debugPrint('[ACTIVE_ROOM_GLOBAL] prompt_shown uid=$uid room=$code');
      }

      final choice = await showActiveRoomResumeDialog(
        context,
        roomCode: code,
        statusLabel: ArenaResumeFlow.statusLabel(check.room!.status),
      );
      if (!mounted) return;

      if (choice == ActiveRoomResumeChoice.returnToRoom) {
        // Re-validate — the room may have changed while the prompt was open.
        final recheck = await ArenaRepo.instance.validateActiveRoom(uid);
        if (!mounted) return;
        if (!recheck.isValid) {
          if (recheck.validity == ActiveRoomValidity.kicked) {
            ArenaToast.error(
                context, 'You were removed from this room by the host.');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('[ACTIVE_ROOM_GLOBAL] return_to_room uid=$uid room=$code '
              'target=${recheck.target}');
        }
        await ArenaResumeFlow.navigateToRoom(context, recheck.room!);
        return;
      }

      if (choice == ActiveRoomResumeChoice.leaveAndPlay) {
        if (kDebugMode) {
          debugPrint('[ACTIVE_ROOM_GLOBAL] leave_and_play uid=$uid room=$code');
        }
        await ArenaRepo.instance.resolvePlayerLeaveRoom(
          roomCode: code,
          leaverUid: uid,
          reason: 'resume_prompt_leave',
        );
        return;
      }

      // Back-dismissed: keep the room but suppress for the rest of this session.
      ArenaRepo.instance.resumeDismissedThisSession.add(code);
    } finally {
      ArenaRepo.instance.resumeFlowBusy = false;
    }
  }

  /// Initialize IAP service early to catch pending purchases from interrupted sessions.
  /// Uses static flag for idempotency to prevent duplicate initialization.
  static bool _iapInitialized = false;

  Future<void> _initIap() async {
    if (_isGuest) return; // Guests can't purchase
    if (_iapInitialized) return; // Skip if already initialized

    // Hard guard: never start Billing until the app is stably online.
    if (!AppModeService.canUseOnlineServices) {
      if (kDebugMode) {
        debugPrint('[IAP] skipped because app is not safely online (mode=${AppModeService.current})');
      }
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      if (kDebugMode) debugPrint('[IAP] skipped because user is null');
      return;
    }

    _iapInitialized = true;
    if (kDebugMode) {
      debugPrint('[IAP] starting after AppMode.online');
    }
    try {
      // IapCoinsService.init() includes purchase cleanup, no separate call needed
      await IapCoinsService().init();
      if (mounted) {
        _refresh(); // Refresh coins if any pending purchases were granted
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HomeHub] IAP init error (non-fatal): $e');
      }
    }
  }

  /// Schedule IAP init for ~1.5 s after the home entrance animation, but
  /// only if the app is stably online by then. If we're not online yet,
  /// arm a one-shot listener on [AppModeService.modeNotifier] so init runs
  /// the moment the controlled reconnect reaches [AppMode.online].
  void _scheduleIapInit() {
    if (_isGuest || _iapInitialized) return;

    void tryNow() {
      if (!mounted || _iapInitialized) return;
      if (!AppModeService.canUseOnlineServices) {
        if (kDebugMode) {
          debugPrint('[IAP] delayed until stable online (mode=${AppModeService.current})');
        }
        return;
      }
      _initIap();
    }

    Future<void>.delayed(const Duration(milliseconds: 1500), tryNow);

    // One-shot listener: if we boot offline, init the moment we hit online.
    void listener() {
      if (_iapInitialized) {
        AppModeService.modeNotifier.removeListener(listener);
        return;
      }
      if (AppModeService.current == AppMode.online) {
        AppModeService.modeNotifier.removeListener(listener);
        tryNow();
      }
    }
    AppModeService.modeNotifier.addListener(listener);
  }

  // ── Guest onboarding & conversion ──────────────────────────────────────

  Future<void> _checkNewUserOnboarding() async {
    if (!_isGuest) return; // only for guests
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(Keys.hasCompletedFirstEntry) ?? false;
    if (done || !mounted) return;
    await prefs.setBool(Keys.hasCompletedFirstEntry, true);
    if (!mounted) return;
    _showOnboardingSheet();
  }

  Future<void> _showOnboardingSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final existingName = prefs.getString(Keys.guestName) ?? '';
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OnboardingSheet(
        initialName: existingName,
        onSaveName: (name) async {
          final p = await SharedPreferences.getInstance();
          await p.setString(Keys.guestName, name);
          if (mounted) _refresh();
        },
        onCreateAccount: () {
          Navigator.of(context).pushNamed('/login');
        },
      ),
    );
  }

  // ── Referral pending-reward popup ─────────────────────────────────────
  //
  // When User B accepts User A's invite code, a doc is written at
  // `pending_referral_rewards/{A_B}` with seen:false. Next time User A opens
  // the app, surface a centered popup that congratulates them and shows the
  // remaining invite capacity. Tapping OK flips seen:true so it doesn't
  // re-appear.

  Future<void> _checkPendingReferralRewards() async {
    if (_isGuest) return;
    if (!AppConfig.kEnableReferralRewards) return;
    if (!AppModeService.canUseOnlineServices) return;
    try {
      final rewards =
          await PendingReferralRewardService.instance.fetchUnseenForCurrentUser();
      if (kDebugMode) {
        debugPrint('[REFERRAL_REWARD] pending_found '
            'uid=${FirebaseAuth.instance.currentUser?.uid} '
            'count=${rewards.length}');
      }
      if (rewards.isEmpty || !mounted) return;
      // Look up the user's current validReferralCount for the "X invites
      // remaining" line. Best-effort.
      int remaining = 0;
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final snap =
              await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final referral = (snap.data() ?? const {})['Referral'];
          if (referral is Map) {
            final count =
                (referral['validReferralCount'] as num?)?.toInt() ?? 0;
            remaining = (10 - count).clamp(0, 10).toInt();
          }
        }
      } catch (_) {}
      for (final reward in rewards) {
        if (!mounted) return;
        if (kDebugMode) {
          debugPrint('[REFERRAL_REWARD] popup_shown '
              'uid=${reward.referrerUid} notification=${reward.id}');
        }
        await _showReferralAcceptedDialog(reward, remaining);
        await PendingReferralRewardService.instance.markSeen(reward);
        if (kDebugMode) {
          debugPrint('[REFERRAL_REWARD] marked_seen '
              'uid=${reward.referrerUid} notification=${reward.id}');
        }
        if (remaining > 0) remaining = remaining - 1;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[REFERRAL] pending check failed: $e');
      }
    }
  }

  /// First-launch notification permission prompt. Fires once per install
  /// when the user first reaches Home. Gated by [Keys.hasPromptedNotification]
  /// so it never re-prompts. If granted, registers the FCM device token and
  /// flips [Keys.notificationsEnabled] so the Settings toggle reflects the live
  /// state. (No local scheduling — real notifications come from FCM only.)
  Future<void> _maybePromptNotificationPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(Keys.hasPromptedNotification) ?? false) return;
      await NotificationService().init();
      final granted =
          await NotificationService().requestNotificationsPermission();
      await prefs.setBool(Keys.hasPromptedNotification, true);
      if (granted) {
        await prefs.setBool(Keys.notificationsEnabled, true);
        // Real notifications come from FCM now — register the device token.
        await FcmService.instance.registerToken();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NOTIF] first-launch permission prompt failed: $e');
      }
    }
  }

  /// Wire FCM so a referral-reward push refreshes the in-app popup, and make
  /// sure the device token is registered when Home mounts.
  void _initFcm() {
    FcmService.onReferralReward = () {
      if (mounted) _checkPendingReferralRewards();
    };
    FcmService.instance.init();
  }

  Future<void> _showReferralAcceptedDialog(
      PendingReferralReward reward, int remaining) async {
    if (!mounted) return;
    final hasPhoto = reward.inviteePhotoURL.isNotEmpty;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppPalette.strokeStrong, width: 1),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppPalette.panelDeep,
                border: Border.all(color: AppPalette.gold, width: 1.6),
              ),
              child: hasPhoto
                  ? Image.network(
                      reward.inviteePhotoURL,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        color: AppPalette.gold,
                        size: 36,
                      ),
                    )
                  : const Icon(Icons.person_rounded,
                      color: AppPalette.gold, size: 36),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your friend accepted your invite!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reward.inviteeName.isEmpty
                  ? 'Someone used your referral code.'
                  : '${reward.inviteeName} used your referral code.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textSubtle,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You earned ${reward.coins} coins.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.gold,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 6),
              Text(
                '$remaining invites remaining',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Claim',
                style: TextStyle(
                  color: AppPalette.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onGameReturned() async {
    if (!_isGuest) return;
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(Keys.guestGamesPlayed) ?? 0) + 1;
    await prefs.setInt(Keys.guestGamesPlayed, count);
    if (count % 3 == 0 && mounted) {
      _showGuestConversionReminder();
    }
  }

  void _showGuestConversionReminder() {
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppL10n.of(ctx);
        return AlertDialog(
          backgroundColor: AppPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppPalette.stroke),
          ),
          title: Text(
            l10n.saveYourProgress,
            style: safeOrbitron(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppPalette.homeCyan,
              letterSpacing: 1.8,
            ),
          ),
          content: Text(
            l10n.saveYourProgressDesc,
            style: homeBodyFont(context, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.maybeLater,
                style: safeOrbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textSubtle,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/login');
              },
              child: Text(
                l10n.createAccount,
                style: safeOrbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.homeCyan,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────────────

  void _onConnectivityChanged() {
    // While a controlled reconnect is in progress, ignore stale
    // connectivity-blip events (the Firestore SDK retries briefly during
    // enableNetwork and that can echo back as a transient lost/regained
    // pair). The reconnect sequence is responsible for its own success
    // /failure decision.
    if (AppModeService.isReconnecting) {
      if (kDebugMode) {
        debugPrint('[RECONNECT] stale connectivity event ignored — reconnect token active');
      }
      return;
    }
    final wasOffline = _offline;
    final nowOnline = ConnectivityService().isOnline.value;
    if (mounted) setState(() => _offline = !nowOnline);
    if (wasOffline && nowOnline) {
      _handleReconnection();
    } else if (!wasOffline && !nowOnline) {
      _handleDisconnection();
    }
  }

  /// Handle internet loss — switch to offline profile cleanly, OR pause an active online match.
  ///
  /// If the user is currently in an online match, we must NOT switch to offline mode.
  /// Instead, we set [AppMode.connectionLostDuringOnlineMatch] so the active
  /// online match page shows its ConnectionLostMatchOverlay and blocks results.
  ///
  /// If the user is on home / store / settings, we switch to offline profile normally.
  /// Online account data (Google photo, Firestore coins) is never used offline.
  Future<void> _handleDisconnection() async {
    if (_isDisconnecting) return;
    if (kDebugMode) debugPrint('[NETWORK] connection lost');

    // ── Guard: user is inside an active online match ──────────────────────────
    if (LocalStore.isInOnlineMatch.value) {
      if (kDebugMode) {
        debugPrint('[NETWORK] connection lost during online match');
        debugPrint('[MATCH] online match paused due to connection loss');
      }
      // Block all Firestore writes/reads while the overlay is up.
      AppModeService.setMode(AppMode.connectionLostDuringOnlineMatch);
      return;
    }

    // ── Normal disconnection (home / store / settings, no active match) ──────
    //
    // IMPORTANT: We do NOT silently switch to offline mode anymore.
    // Instead we enter [AppMode.connectionProblem], cancel listeners,
    // and surface the Weak Connection overlay. The user must explicitly
    // choose "Restart in Offline Mode" or "Try Reconnect" — this prevents
    // any accidental data merge between online and offline profiles.
    if (mounted) setState(() => _isDisconnecting = true);
    AppModeService.setMode(AppMode.connectionProblem);
    if (kDebugMode) {
      debugPrint('[NETWORK] entering weak connection (no silent offline switch)');
    }

    // Cancel all online listeners immediately. The Firestore SDK network is
    // also disabled by AppModeService.setMode to stop WatchStream retries.
    _cancelAllListeners();
    if (kDebugMode) {
      debugPrint('[LISTENER] user listener cancelled');
      debugPrint('[LISTENER] session listener cancelled');
      debugPrint('[ONLINE] listeners cancelled');
    }

    if (mounted) {
      setState(() => _isDisconnecting = false);
    }
    // Offline profile is intentionally NOT loaded here. The overlay's
    // "Restart in Offline Mode" button calls LocalStore.restartIntoOfflineMode()
    // when the user opts in.
  }

  /// Handle reconnection — restore the online account cleanly.
  ///
  /// Offline data is NEVER merged back into Firestore.
  /// The server is always authoritative for the online account.
  Future<void> _handleReconnection() async {
    if (_isReconnecting) return;

    // ── Special case: reconnected while a match overlay was active ────────────
    if (AppModeService.current == AppMode.connectionLostDuringOnlineMatch) {
      if (kDebugMode) {
        debugPrint('[RECONNECT] connection restored during paused online match');
        debugPrint('[RECONNECT] match resume allowed=false — returning to online home');
      }
      // Run the controlled reconnect dance: enable network → pull → listeners
      // → AppMode.online. Done under a reconnect token so any stale
      // connectivity-loss event that fires during the dance is ignored.
      await _runReconnectSequence(reason: 'match_overlay_active');
      return;
    }

    // ── Confirmation guard: if the user is in fully-committed offline mode,
    // do NOT silently auto-switch back to online. Surface the
    // "Go Online?" overlay and let the user choose. The overlay's primary
    // button calls [_runConfirmedGoOnline] via AppModeService.
    if (AppModeService.current == AppMode.offline) {
      if (kDebugMode) {
        debugPrint('[ONLINE_SWITCH] connection back while offline — asking user');
      }
      AppModeService.pendingOnlineSwitch.value = true;
      return;
    }

    // ── Normal reconnection (was on home / store / settings while offline) ────
    await _runReconnectSequence(reason: 'connectivity_returned');
  }

  /// User-confirmed Go Online from the OnlineSwitchConfirmOverlay.
  /// Runs the same reconnect sequence as a connectivity-tick reconnect,
  /// but skips the "if offline ask user" guard (the user already chose).
  Future<void> _runConfirmedGoOnline() async {
    if (_isReconnecting) return;
    await _runReconnectSequence(reason: 'user_confirmed_go_online');
  }

  /// Single canonical reconnect sequence. Runs under [AppModeService.withReconnectToken]
  /// so stale connectivity events emitted during the flow are ignored.
  ///
  /// Order (hardened):
  ///   1. set _isReconnecting=true
  ///   2. verify FirebaseAuth.currentUser
  ///   3. enableNetwork (so the health probe can actually reach Firestore)
  ///   4. health check (server-side doc fetch with timeout)
  ///   5. re-verify auth (sign-out may race)
  ///   6. UserRepo.pullServerToLocal
  ///   7. LocalStore.restoreOnlineCoins
  ///   8. AppMode.online (this is the moment canUseOnlineServices flips true)
  ///   9. start Firestore + session listeners
  ///  10. refresh UI
  Future<void> _runReconnectSequence({required String reason}) async {
    if (mounted) setState(() => _isReconnecting = true);

    await AppModeService.withReconnectToken((token) async {
      if (kDebugMode) {
        debugPrint('[RECONNECT] attemptId=$token health check started');
      }

      // Step 1 — auth pre-check.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid.isEmpty) {
        if (kDebugMode) {
          debugPrint('[RECONNECT] attemptId=$token aborted — no authenticated user');
        }
        AppModeService.setMode(AppMode.connectionProblem);
        if (mounted) setState(() => _isReconnecting = false);
        return;
      }

      // Step 2 — enable Firestore network BEFORE the health probe so the
      // probe can actually reach the server. We use a low-level direct
      // enableNetwork() call here because canUseOnlineServices is still
      // false (we're inside the token).
      try {
        await FirebaseFirestore.instance.enableNetwork();
        if (kDebugMode) {
          debugPrint('[FIRESTORE] network enabled before pullServerToLocal');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[RECONNECT] enableNetwork failed: $e');
      }

      // Step 3 — health check.
      final healthy = await _runFirestoreHealthCheck(
        const Duration(seconds: 4),
      );
      if (!healthy) {
        if (kDebugMode) {
          debugPrint('[RECONNECT] attemptId=$token health check failed');
        }
        AppModeService.setMode(AppMode.connectionProblem);
        if (mounted) setState(() => _isReconnecting = false);
        return;
      }
      if (kDebugMode) {
        debugPrint('[RECONNECT] attemptId=$token health check passed');
      }

      // Step 4 — re-verify auth (sign-out may have raced).
      final stillSignedIn = FirebaseAuth.instance.currentUser;
      if (stillSignedIn == null || stillSignedIn.uid.isEmpty) {
        if (kDebugMode) {
          debugPrint('[RECONNECT] attemptId=$token aborted — user signed out during health check');
        }
        AppModeService.setMode(AppMode.connectionProblem);
        if (mounted) setState(() => _isReconnecting = false);
        return;
      }
      if (kDebugMode) {
        debugPrint('[RECONNECT] attemptId=$token auth user verified uid=${stillSignedIn.uid}');
      }

      // Step 5 — pull server state.
      bool pulled = false;
      try {
        pulled = await UserRepo().pullServerToLocal(stillSignedIn.uid);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[RECONNECT] attemptId=$token pullServerToLocal failed: $e');
        }
      }
      if (!pulled) {
        if (kDebugMode) {
          debugPrint('[RECONNECT] attemptId=$token pullServerToLocal returned false — aborting');
        }
        AppModeService.setMode(AppMode.connectionProblem);
        if (mounted) setState(() => _isReconnecting = false);
        return;
      }

      // Step 6 — restore online coin cache.
      await LocalStore.restoreOnlineCoins();

      // Step 7 — flip to online. canUseOnlineServices is now true; only
      // now is it safe to start listeners and IAP.
      AppModeService.setMode(AppMode.online);

      // Step 8 — listeners.
      if (mounted) {
        _startFirestoreListener();
        _startSessionListener();
        if (kDebugMode) debugPrint('[ONLINE] listeners started');
      }

      // Step 9 — UI refresh + clear offline profile reference.
      if (mounted) {
        setState(() {
          _offlineProfile = null;
          _isReconnecting = false;
        });
        _refresh();
      }

      if (kDebugMode) {
        debugPrint('[RECONNECT] attemptId=$token online account restored for uid=${stillSignedIn.uid} (reason=$reason)');
      }
    });
  }

  /// Real-time Firestore listener — Single Source of Truth for user data.
  /// Keeps coins, username, and stats in sync across devices and after
  /// Cloud Function updates (verifyGooglePlayPurchase).
  void _startFirestoreListener() {
    if (_isGuest) return;
    // Strict guard: only attach a Firestore listener when the app is
    // stably online (AppMode.online). Previously this only excluded the
    // [isOffline] subset, which allowed listeners during
    // connectionProblem / connectionLostDuringOnlineMatch /
    // switchingToOnline — exactly the modes that produced the
    // WatchStream / WriteStream retry spam in the logs.
    if (!AppModeService.canUseOnlineServices) {
      if (kDebugMode) {
        debugPrint('[FIRESTORE] blocked listener mode=${AppModeService.current}');
      }
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _firestoreSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (snap) async {
        if (!mounted) return;
        final data = snap.data();
        if (data == null) return;
        // Guard: if user signed out while snapshot was in flight
        if (FirebaseAuth.instance.currentUser == null) return;

        // Extract authoritative server data
        final wallet = data['Wallet'] as Map<String, dynamic>?;
        final profile = data['Profile'] as Map<String, dynamic>?;
        final stats = data['Stats'] as Map<String, dynamic>?;
        final cosmetics = data['Cosmetics'] as Map<String, dynamic>?;
        final progress = data['Progress'] as Map<String, dynamic>?;

        final serverCoins = (wallet?['coins'] as num?)?.toInt() ?? 0;
        final serverName = (profile?['name'] as String?) ?? 'PLAYER';

        // Update UI immediately + broadcast to other screens
        if (LocalStore.coinsNotifier.value != serverCoins) {
          LocalStore.coinsNotifier.value = serverCoins;
        }

        // Write-through to SharedPreferences cache (keeps other screens in sync)
        try {
          final p = await SharedPreferences.getInstance();
          if (p.getInt(Keys.coins) != serverCoins) {
            await p.setInt(Keys.coins, serverCoins);
          }
          if (p.getString(Keys.username) != serverName) {
            await p.setString(Keys.username, serverName);
          }

          // Sync stats
          if (stats != null) {
            await p.setInt(
                Keys.gamesPlayed,
                (stats['gamesPlayed'] as num?)?.toInt() ??
                    p.getInt(Keys.gamesPlayed) ??
                    0);
            await p.setInt(Keys.wins,
                (stats['wins'] as num?)?.toInt() ?? p.getInt(Keys.wins) ?? 0);
            await p.setInt(
                Keys.losses,
                (stats['losses'] as num?)?.toInt() ??
                    p.getInt(Keys.losses) ??
                    0);
            await p.setInt(Keys.draws,
                (stats['draws'] as num?)?.toInt() ?? p.getInt(Keys.draws) ?? 0);
          }

          // Sync cosmetics
          if (cosmetics != null) {
            final xColor = cosmetics['xColor'] as String?;
            final oColor = cosmetics['oColor'] as String?;
            final rawEquippedAvatar =
                (cosmetics['equippedAvatar'] as num?)?.toInt();
            if (xColor != null) await p.setString(Keys.xColor, xColor);
            if (oColor != null) await p.setString(Keys.oColor, oColor);

            // Parse owned avatars first so we can sanitize the equipped id
            // against actual ownership (defense against legacy accounts
            // that were auto-granted Avatar__1).
            final ownedAvatarsRaw = cosmetics['ownedAvatars'];
            final ownedAvatarsList = (ownedAvatarsRaw is List)
                ? ownedAvatarsRaw
                    .map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0)
                    .where((e) => e > 0)
                    .toSet()
                    .toList()
                : <int>[];

            int? sanitizedEquipped = rawEquippedAvatar;
            if (sanitizedEquipped != null) {
              if (sanitizedEquipped <= 0) {
                sanitizedEquipped = 0;
              } else if (!ownedAvatarsList.contains(sanitizedEquipped)) {
                if (kDebugMode) {
                  debugPrint(
                    '[COSMETICS] equipped avatar reset because not owned: id=$sanitizedEquipped',
                  );
                }
                sanitizedEquipped = 0;
              }
              await p.setInt(Keys.equippedAvatar, sanitizedEquipped);
              LocalStore.equippedAvatarNotifier.value = sanitizedEquipped;
            }

            final ownedX = cosmetics['ownedXColors'];
            final ownedO = cosmetics['ownedOColors'];
            final customXConf = cosmetics['customXConfigsV2'];
            final customOConf = cosmetics['customOConfigsV2'];

            if (ownedX is List) {
              await p.setString(
                  Keys.ownedXColors, ownedX.map((e) => e.toString()).join(','));
            }
            if (ownedO is List) {
              await p.setString(
                  Keys.ownedOColors, ownedO.map((e) => e.toString()).join(','));
            }
            // Always write owned avatars (empty string when none owned).
            await p.setString(
                Keys.ownedAvatars, ownedAvatarsList.join(','));
            if (customXConf is String) {
              await p.setString(Keys.customXConfigs, customXConf);
            }
            if (customOConf is String) {
              await p.setString(Keys.customOConfigs, customOConf);
            }
          }

          // Sync progress
          if (progress != null) {
            final level = (progress['levelGameCurrentLevel'] as num?)?.toInt();
            final completed = progress['levelGameCompleted'] as bool?;
            if (level != null)
              await p.setInt(Keys.levelGameCurrentLevel, level);
            if (completed != null)
              await p.setBool(Keys.levelGameCompleted, completed);
          }

          // Cache characterType locally for offline avatar hint
          final firestoreCharType = profile?['characterType'] as String?;
          await LocalStore.setOnlineCharacterType(firestoreCharType);

          // Sync profile photo URL
          final firestorePhoto = profile?['photoURL'] as String?;
          final authPhoto = FirebaseAuth.instance.currentUser?.photoURL;
          final profilePhotoUrl = (firestorePhoto != null && firestorePhoto.isNotEmpty)
              ? firestorePhoto
              : ((authPhoto != null && authPhoto.isNotEmpty) ? authPhoto : null);
          await LocalStore.setProfilePhotoUrl(profilePhotoUrl);
        } catch (e) {
          if (kDebugMode)
            debugPrint('[HomeHub] SharedPreferences write-through error: $e');
        }
      },
      onError: (e) {
        if (FirebaseAuth.instance.currentUser == null) {
          // permission-denied after sign-out is expected — cancel silently
          _firestoreSub?.cancel();
          _firestoreSub = null;
          if (kDebugMode) debugPrint('[HomeHub] Firestore stream closed (signed out)');
          return;
        }
        if (kDebugMode) debugPrint('[HomeHub] Firestore listener error: $e');
        // Fall back to local cache
        _refresh();
      },
    );
  }

  /// Cancel all active Firestore and session stream subscriptions.
  void _cancelAllListeners() {
    _firestoreSub?.cancel();
    _firestoreSub = null;
    _sessionSub?.cancel();
    _sessionSub = null;
  }

  /// Lightweight Firestore reachability check used by [_handleReconnection]
  /// before issuing any real reads/writes. Returns true if the server
  /// actually responded within [timeout].
  ///
  /// We re-enable the Firestore network (idempotent — [AppModeService]
  /// already does this when entering [AppMode.switchingToOnline]) and then
  /// try a tiny doc fetch against the current user. A timeout or an error
  /// means we should stay in weak-connection mode and NOT spam Firestore.
  Future<bool> _runFirestoreHealthCheck(Duration timeout) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _cancelAllListeners();
    // Unregister the cancel hook — this HomeHub instance is going away.
    LocalStore.registerCancelListenersCallback(null);
    AppModeService.registerConfirmedGoOnlineHandler(null);
    ConnectivityService().isOnline.removeListener(_onConnectivityChanged);
    _cardAnim.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AuditService.log('app_resumed');
    } else if (state == AppLifecycleState.paused) {
      AuditService.log('app_paused');
    }
  }

  /// Start listening for session conflicts (single-device enforcement).
  Future<void> _startSessionListener() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Guest — no session to enforce
    if (!AppModeService.canUseOnlineServices) {
      if (kDebugMode) {
        debugPrint('[FIRESTORE] blocked session listener mode=${AppModeService.current}');
      }
      return;
    }

    final sessionId = await SessionService.getLocalSessionId();
    if (sessionId == null) return; // No session written yet

    _sessionSub = SessionService.listenForConflict(
      uid: user.uid,
      sessionId: sessionId,
      onConflict: (newDevice, loginTime) async {
        // Prevent stacked dialogs from rapid session changes
        if (_isForceLoggingOut) return;
        _isForceLoggingOut = true;

        // Stop all listeners immediately
        _sessionSub?.cancel();
        _sessionSub = null;
        _firestoreSub?.cancel();
        _firestoreSub = null;

        await SessionService.clearLocal();
        try {
          await AuthService().signOut();
        } catch (e) {
          if (kDebugMode)
            debugPrint('[SESSION] signOut during conflict failed: $e');
        }
        if (mounted) _showForceLogoutDialog(newDevice, loginTime);
      },
    );
  }

  /// Show a non-dismissible, glassmorphism force-logout dialog.
  void _showForceLogoutDialog(String device, DateTime time) {
    final formattedTime = DateFormat('hh:mm a').format(time);
    final formattedDate = DateFormat('MMMM d, yyyy').format(time);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Force Logout',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, a1, a2, child) {
        return FadeTransition(
          opacity: a1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) {
        return PopScope(
          canPop: false, // Block back button
          child: Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Material(
                    color: Colors.transparent,
                    child: AppGlassCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Glowing shield icon
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppPalette.danger.withOpacity(0.4),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              size: 52,
                              color: AppPalette.danger,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "SESSION TERMINATED",
                            textAlign: TextAlign.center,
                            style: safeOrbitron(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Your account was accessed from another device. To protect your data, you have been logged out.",
                            textAlign: TextAlign.center,
                            style: safeInter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppPalette.textMuted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Device details card
                          AppGlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _sessionDetailRow(
                                  icon: Icons.phone_android,
                                  label: "Device",
                                  value: device,
                                ),
                                const SizedBox(height: 10),
                                _sessionDetailRow(
                                  icon: Icons.access_time,
                                  label: "Time",
                                  value: formattedTime,
                                ),
                                const SizedBox(height: 10),
                                _sessionDetailRow(
                                  icon: Icons.calendar_today,
                                  label: "Date",
                                  value: formattedDate,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          AppPillButton(
                            label: "BACK TO LOGIN",
                            icon: Icons.login,
                            fill: AppPalette.primary.withOpacity(0.9),
                            onPressed: () {
                              Navigator.of(ctx).pushNamedAndRemoveUntil(
                                '/login',
                                (_) => false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sessionDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppPalette.primary),
        const SizedBox(width: 10),
        Text(
          "$label: ",
          style: safeInter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppPalette.textMuted,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: safeInter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final nextPhoto = p.getString(Keys.profilePhotoUrl);
    if (LocalStore.profilePhotoUrlNotifier.value != nextPhoto) {
      LocalStore.profilePhotoUrlNotifier.value = nextPhoto;
      setState(() {});
    }
  }

  Future<void> _openHomeCoinsStore() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StorePage(initialTab: 2),
      ),
    );
    await _refresh();
  }

  Future<void> _handleHomeProfileTap() async {
    if (_isGuest) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
      await _refresh();
      return;
    }

    // Arena tab removed from bottom nav — Online Friends opens ArenaPage
    // via the Home card instead. Settings is always at index 2.
    const settingsIndex = 2;
    if (_currentTab != settingsIndex) {
      setState(() {
        _currentTab = settingsIndex;
        _visitedTabs.add(settingsIndex);
      });
    }
  }

  Widget _buildHomeCoinButton({
    required bool compact,
    required bool landscape,
    required double iconSize,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _openHomeCoinsStore,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: landscape ? (compact ? 4 : 5) : (compact ? 5 : 7),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPalette.homePanelStrong.withOpacity(0.95),
                AppPalette.homeBgSecondary.withOpacity(0.92),
              ],
            ),
            border: Border.all(
              color: AppPalette.homeStroke.withOpacity(0.38),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppPalette.gold.withOpacity(0.10),
                blurRadius: 12,
                spreadRadius: -4,
              ),
            ],
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: LocalStore.coinsNotifier,
            builder: (_, coins, __) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/coin/COIN-SHOP.png',
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: compact ? 6 : 8),
                    Text(
                      formatCoins(coins, compact: true),
                      style: homeOrbitron(
                        fontSize: landscape ? 18 : (compact ? 17 : 21),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: AppPalette.homeTitle,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHomeAvatarButton({
    required double size,
    required bool compact,
  }) {
    final framePadding = compact ? 2.0 : 4.0;
    final radius = size / 2 + framePadding;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: _handleHomeProfileTap,
        child: Padding(
          padding: EdgeInsets.all(framePadding),
          child: _offline && _offlineProfile != null
              ? _buildOfflineAvatarImage(size: size, profile: _offlineProfile!)
              : ValueListenableBuilder<int>(
                  valueListenable: LocalStore.equippedAvatarNotifier,
                  builder: (_, avatarId, ___) {
                    // Nullable resolver: avatarId == 0 or unknown id → no
                    // paid frame, profile photo / character portrait
                    // only. Never fall back to Avatar__1 (a paid item).
                    final avatar = gameAvatarByIdOrNull(avatarId);
                    if (kDebugMode && avatar == null) {
                      debugPrint('[PROFILE] no equipped avatar — showing profile image only');
                    }
                    return FullAvatarDisplay(
                      size: size,
                      avatar: avatar,
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildOfflineAvatarImage({
    required double size,
    required OfflinePlayerProfile profile,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppPalette.warning.withOpacity(0.70),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          profile.avatarAssetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person,
            size: size * 0.6,
            color: AppPalette.warning,
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.warning.withOpacity(0.14),
        border: Border(
          bottom: BorderSide(color: AppPalette.warning.withOpacity(0.30)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 13, color: AppPalette.warning),
          const SizedBox(width: 6),
          Text(
            _offlineProfile != null
                ? '${AppL10n.of(context).offlineMode}  ·  ${_offlineProfile!.name}'
                : AppL10n.of(context).offlineMode,
            style: safeOrbitron(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: AppPalette.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final compact = width < 360;
          final minSideWidth = 94.0;
          final maxSideWidth = landscape ? 148.0 : 162.0;
          final desiredSideWidth = width * (landscape ? 0.22 : 0.24);
          final sideSlotWidth = min(
            max(minSideWidth, desiredSideWidth),
            min(maxSideWidth, max(minSideWidth, (width - 120.0) / 2)),
          );
          final centerWidth = max(120.0, width - sideSlotWidth * 2);
          final topBarHeight = landscape ? 66.0 : (compact ? 74.0 : 84.0);
          final avatarSize = landscape ? 48.0 : (compact ? 50.0 : 60.0);
          final coinIconSize = landscape ? 26.0 : (compact ? 28.0 : 34.0);

          return SizedBox(
            height: topBarHeight,
            child: Row(
              children: [
                SizedBox(
                  width: sideSlotWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildHomeCoinButton(
                      compact: compact,
                      landscape: landscape,
                      iconSize: coinIconSize,
                    ),
                  ),
                ),
                SizedBox(
                  width: centerWidth,
                  child: Center(
                    child: IgnorePointer(
                      child: _buildHomeIdentityPanel(
                        compact: compact,
                        landscape: landscape,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: sideSlotWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildHomeAvatarButton(
                      size: avatarSize,
                      compact: compact,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeIdentityPanel({
    bool compact = false,
    bool landscape = false,
  }) {
    final xoSize = landscape ? 28.0 : (compact ? 34.0 : 40.0);
    final arenaSize = landscape ? 14.0 : (compact ? 16.0 : 18.0);

    final titleColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'XO',
          textAlign: TextAlign.center,
          style: homeOrbitron(
            fontSize: xoSize,
            fontWeight: FontWeight.w900,
            letterSpacing: landscape ? 1.8 : 2.4,
            color: AppPalette.homeTitle,
          ),
        ),
        SizedBox(height: compact ? 1 : 3),
        Text(
          'ARENA',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: brandFont(
            context,
            fontSize: arenaSize,
          ).copyWith(
            letterSpacing: landscape ? 2.2 : 3.0,
            color: AppPalette.homeSky,
          ),
        ),
      ],
    );

    final counterTile = AppGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      backgroundColor: AppPalette.homePanel.withOpacity(0.86),
      borderColor: AppPalette.homeStroke.withOpacity(0.30),
      radius: 18,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.24),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '4',
            style: homeOrbitron(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: AppPalette.homeTitle,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'MODES',
            style: homeLabelFont(
              context,
              fontSize: 6,
              color: AppPalette.homeSky,
            ),
          ),
        ],
      ),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          titleColumn,
          SizedBox(width: compact ? 8 : 12),
          counterTile,
        ],
      ),
    );
  }

  Widget _buildHomeSectionHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final l10n = AppL10n.of(context);
        final compact = constraints.maxWidth < 360;
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    l10n.selectMode,
                    style: homeLabelFont(
                      context,
                      color: AppPalette.homeCyan,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppPalette.homeCyan.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppPalette.homeCyan.withOpacity(0.24)),
                    ),
                    child: Text(
                      l10n.modesCount,
                      style: homeLabelFont(
                        context,
                        fontSize: 7.5,
                        color: AppPalette.homeCyan,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.chooseYourArena,
                style: homeTitleFont(
                  context,
                  fontSize: compact ? 22 : 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.arenaModesDesc,
                style: homeBodyFont(
                  context,
                  fontSize: compact ? 11 : 12,
                  color: AppPalette.homeMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.homeBgBase,
      body: Stack(
        children: [
          SafeArea(
            child: AppBackground(
              variant: AppBackgroundVariant.homeNeon,
              child: Column(
                children: [
                  if (_currentTab == 0) _buildHomeTopBar(),
                  if (_offline && _currentTab == 0) _buildOfflineBanner(),
                  Expanded(
                    child: IndexedStack(
                      index: _currentTab,
                      children: [
                        _buildHomeContent(),
                        _visitedTabs.contains(1)
                            ? const StorePage(embedded: true)
                            : const SizedBox.shrink(),
                        _visitedTabs.contains(2)
                            ? const SettingsPage(embedded: true)
                            : const SizedBox.shrink(),
                      ],
                    ),
                  ),
                  _buildBottomNav(),
                ],
              ),
            ),
          ),
          if (_isReconnecting || _isDisconnecting)
            Positioned.fill(
              child: ModeTransitionOverlay(
                isReconnecting: _isReconnecting,
              ),
            ),
        ],
      ),
    );
  }

  PageRoute<T> _fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  Widget _buildHomeContent() {
    final l10n = AppL10n.of(context);
    final modes = <HomeModeConfig>[
      HomeModeConfig(
        title: l10n.vsAiTitle,
        subtitle: l10n.vsAiSubtitle,
        badge: l10n.badgeAi,
        assetPath: 'assets/game/ai.gif',
        accent: AppPalette.homeCyan,
        accentSecondary: AppPalette.homeBlue,
        onTap: () async {
          await Navigator.of(context).push(_fadeRoute(const SetupPage()));
          _refresh();
          unawaited(_onGameReturned());
        },
      ),
      HomeModeConfig(
        title: l10n.vsFriendTitle,
        subtitle: l10n.vsFriendSubtitle,
        badge: l10n.badgeHot,
        assetPath: 'assets/game/friend.gif',
        accent: AppPalette.homePurple,
        accentSecondary: AppPalette.homePink,
        onTap: () async {
          await Navigator.of(context).push(_fadeRoute(const FriendSetupPage()));
          _refresh();
          unawaited(_onGameReturned());
        },
      ),
      HomeModeConfig(
        title: l10n.onlineFriendsTitle,
        subtitle: l10n.onlineFriendsSubtitle,
        badge: l10n.badgeMultiplayer,
        assetPath: 'assets/game/online-money.gif',
        accent: AppPalette.homeGold,
        accentSecondary: AppPalette.homePink,
        onTap: () async {
          await Navigator.of(context).push(_fadeRoute(const ArenaPage()));
          _refresh();
          unawaited(_onGameReturned());
        },
      ),
      HomeModeConfig(
        title: l10n.levelsTitle,
        subtitle: l10n.levelsSubtitle,
        badge: l10n.badgeReward,
        assetPath: 'assets/game/levels.gif',
        accent: AppPalette.homeSky,
        accentSecondary: AppPalette.homeBlue,
        onTap: () async {
          await Navigator.of(context).push(_fadeRoute(const LevelGameSetupPage()));
          _refresh();
          unawaited(_onGameReturned());
        },
      ),
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 2),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.orientationOf(context) == Orientation.landscape
                    ? 880
                    : 720,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics =
                  UiMetrics.of(constraints, MediaQuery.orientationOf(context));
              final gap = metrics.cardGap;

              Widget buildCard(int index) {
                final mode = modes[index];
                final animIdx = min(index ~/ 2, 1);
                return RepaintBoundary(
                  child: FadeTransition(
                    opacity: _cardFades[animIdx],
                    child: SlideTransition(
                      position: _cardSlides[animIdx],
                      child: BigModeCard(
                        title: mode.title,
                        subtitle: mode.subtitle,
                        badge: mode.badge,
                        assetPath: mode.assetPath,
                        accent: mode.accent,
                        accentSecondary: mode.accentSecondary,
                        onTap: mode.onTap,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHomeSectionHeader(),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: buildCard(0)),
                              SizedBox(width: gap),
                              Expanded(child: buildCard(1)),
                            ],
                          ),
                        ),
                        SizedBox(height: gap),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: buildCard(2)),
                              SizedBox(width: gap),
                              Expanded(child: buildCard(3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final l10n = AppL10n.of(context);
    final tabs = <NavTabData>[
      NavTabData(
          icon: Icons.home_outlined, activeIcon: Icons.home, label: l10n.home),
      NavTabData(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront,
          label: l10n.storeTab),
      NavTabData(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: l10n.settingsTab),
    ];

    final screenWidth = MediaQuery.sizeOf(context).width;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final compact = screenWidth < 360;
    final navHeight = landscape ? 66.0 : (compact ? 72.0 : 78.0);
    final outerPadding = EdgeInsets.fromLTRB(
      landscape ? 12 : 16,
      8,
      landscape ? 12 : 16,
      landscape ? 12 : 16,
    );
    final itemMargin = EdgeInsets.symmetric(horizontal: landscape ? 2 : 4);
    final itemRadius = landscape ? 18.0 : 20.0;
    final iconSize = landscape ? 24.0 : (compact ? 26.0 : 28.0);
    final labelSize = landscape ? 8.0 : (compact ? 8.5 : 9.0);

    return Padding(
      padding: outerPadding,
      child: Container(
        height: navHeight,
        padding: EdgeInsets.all(landscape ? 4 : (compact ? 5 : 6)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.homePanelStrong.withOpacity(0.98),
              AppPalette.homeBgSecondary.withOpacity(0.96),
            ],
          ),
          borderRadius: BorderRadius.circular(landscape ? 24 : 28),
          border: Border.all(
            color: AppPalette.homeStroke.withOpacity(0.28),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.34),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: AppPalette.homeCyan.withOpacity(0.06),
              blurRadius: 18,
              spreadRadius: -6,
            ),
          ],
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final tab = tabs[i];
            final isActive = _currentTab == i;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_currentTab != i) {
                    setState(() {
                      _currentTab = i;
                      _visitedTabs.add(i);
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                    margin: itemMargin,
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppPalette.homeSky.withOpacity(0.96),
                              AppPalette.homeBlue.withOpacity(0.88),
                            ],
                          )
                        : null,
                    color: isActive ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(itemRadius),
                    border: Border.all(
                      color: isActive
                          ? AppPalette.homeStrokeStrong.withOpacity(0.70)
                          : Colors.transparent,
                      width: 1.1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppPalette.homeSky.withOpacity(0.20),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: AppPalette.homePurple.withOpacity(0.08),
                              blurRadius: 14,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? tab.activeIcon : tab.icon,
                        size: iconSize,
                        color: isActive
                            ? AppPalette.homeTitle
                            : AppPalette.homeMuted,
                      ),
                      SizedBox(height: landscape ? 2 : 4),
                      Text(
                        tab.label,
                        style: homeLabelFont(
                          context,
                          fontSize: labelSize,
                          color: isActive
                              ? AppPalette.homeTitle
                              : AppPalette.homeMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

