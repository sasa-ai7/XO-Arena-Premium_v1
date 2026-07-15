import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:intl/intl.dart' hide TextDirection;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../coins/iap_coins_service.dart';
import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/keys.dart';
import '../../models/offline_profile.dart';
import '../../services/app_mode_service.dart';
import '../../services/arena/arena_repo.dart';
import '../../services/arena/arena_resume_flow.dart';
import '../../services/auth_service.dart';
import '../../services/audit_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_store.dart';
import '../../services/notification_service.dart';
import '../../services/online_reconnect_controller.dart';
import '../../services/fcm_service.dart';
import '../../services/referral/pending_referral_reward_service.dart';
import '../../services/session_service.dart';
import '../../services/sound_service.dart';
import '../../services/user_repo.dart';
import '../../services/wallet_history_service.dart';
import '../../screens/games/game_page.dart';
import '../../screens/games/setup_page.dart';
import '../../screens/games/friend_setup_page.dart';
import '../../screens/games/level_game_setup_page.dart';
import '../../utils/board_utils.dart';
import '../../screens/arena/arena_page.dart';
import '../../screens/arena/widgets/active_room_resume_dialog.dart';
import '../../screens/store/store_page.dart';
import '../../screens/settings/settings_page.dart';
import '../missions/missions_page.dart';
import '../missions/mission_widgets.dart';
import '../../core/app_config.dart';
import '../../utils/navigation_utils.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_toast.dart';
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
  OfflinePlayerProfile? _offlineProfile;
  String _playerName = '';
  StreamSubscription? _authSub;
  StreamSubscription? _sessionSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _firestoreSub;

  late final AnimationController _cardAnim;

  bool get _isGuest => FirebaseAuth.instance.currentUser == null;

  @override
  void initState() {
    super.initState();
    final startupStart = DateTime.now();
    WidgetsBinding.instance.addObserver(this);

    LocalStore.registerCancelListenersCallback(_cancelAllListeners);
    OnlineReconnectController.instance.registerScreenHooks(
      cancelOnlineListeners: _cancelAllListeners,
      onOnlineRestored: _onGlobalOnlineRestored,
    );

    _cardAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isGuest && LocalStore.offlineAvatarAssetNotifier.value != null) {
        LocalStore.offlineAvatarAssetNotifier.value = null;
      }
      final firstFrameMs =
          DateTime.now().difference(startupStart).inMilliseconds;
      if (kDebugMode) {
        debugPrint('[PERF] home_first_frame_ms=$firstFrameMs');
        debugPrint('[PERF] home_layout_ready_ms=$firstFrameMs');
      }

      Future<void>.delayed(const Duration(milliseconds: 120), () async {
        unawaited(_runBackgroundJob('connectivity snapshot', () async {
          final online = await ConnectivityService().online;
          if (mounted) setState(() => _offline = !online);
        }));
      });

      Future<void>.delayed(const Duration(milliseconds: 500), () {
        unawaited(_runBackgroundJob('local profile refresh', _refresh));
      });

      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user == null) {
          _cancelAllListeners();
          if (kDebugMode) {
            debugPrint('[HomeHub] auth=null — listeners cancelled');
          }
        }
      });

      Future<void>.delayed(const Duration(milliseconds: 850), () {
        unawaited(_runBackgroundJob('online listeners', () async {
          _startFirestoreListener();
          await _startSessionListener();
        }));
      });

      Future<void>.delayed(const Duration(milliseconds: 1300), () {
        unawaited(
            _runBackgroundJob('onboarding check', _checkNewUserOnboarding));
      });

      Future<void>.delayed(const Duration(milliseconds: 1800), () {
        unawaited(_runBackgroundJob(
          'pending referral rewards',
          _checkPendingReferralRewards,
        ));
      });

      Future<void>.delayed(const Duration(milliseconds: 2300), () {
        unawaited(_runBackgroundJob(
          'notification setup',
          _maybePromptNotificationPermission,
        ));
      });

      Future<void>.delayed(const Duration(milliseconds: 2800), () {
        if (!mounted) return;
        _initFcm();
        _scheduleIapInit();
      });

      Future<void>.delayed(const Duration(milliseconds: 3400), () {
        if (!mounted) return;
        _scheduleGlobalResumeCheck();
        unawaited(_runBackgroundJob('sound warm-up', SoundService().init));
        unawaited(_runBackgroundJob(
          'app-open audit',
          () async => AuditService.log('app_open'),
        ));
        if (kDebugMode) debugPrint('[MUSIC] init triggered from HomeHub');
      });

      Future<void>.delayed(const Duration(milliseconds: 4200), () {
        if (!mounted) return;
        _precacheHomeAssets();
      });
    });
  }

  Future<void> _runBackgroundJob(
    String name,
    Future<void> Function() job,
  ) async {
    if (!mounted) return;
    try {
      await job();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[HomeHub] deferred $name failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  void _precacheHomeAssets() {
    final paths = <String>[
      'assets/game/levels.webp',
      'assets/game/friend.webp',
      'assets/game/ai.webp',
      'assets/game/online-money.webp',
    ];
    for (var index = 0; index < paths.length; index++) {
      final path = paths[index];
      Future<void>.delayed(Duration(milliseconds: index * 180), () async {
        if (!mounted) return;
        try {
          await precacheImage(AssetImage(path), context, onError: (_, __) {});
        } catch (_) {}
      });
    }
  }

  Future<void> _onGlobalOnlineRestored() async {
    if (!mounted) return;
    _startFirestoreListener();
    _startSessionListener();
    await _refresh();
    unawaited(_checkPendingReferralRewards());
    unawaited(_initIap());
    if (mounted) {
      setState(() {
        _offline = false;
        _offlineProfile = null;
      });
    }
    if (kDebugMode) debugPrint('[ONLINE] listeners started');
  }

  /// Schedule the one-shot global "Active Room Found" check shortly after the
  /// home entrance settles, so the resume prompt appears immediately on app
  /// open (not only after the user opens the Online tab).
  void _scheduleGlobalResumeCheck() {
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      unawaited(_runBackgroundJob(
        'active room resume check',
        _maybeShowGlobalActiveRoomPrompt,
      ));
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
        debugPrint(
            '[IAP] skipped because app is not safely online (mode=${AppModeService.current})');
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
          debugPrint(
              '[IAP] delayed until stable online (mode=${AppModeService.current})');
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
    // Offline-first: the setup screen already collected name + character, so
    // never show the legacy in-home onboarding name prompt again.
    final offlineProfileExists =
        prefs.getBool(Keys.offlineProfileExists) ?? false;
    final done = prefs.getBool(Keys.hasCompletedFirstEntry) ?? false;
    if (offlineProfileExists || done || !mounted) return;
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
      final rewards = await PendingReferralRewardService.instance
          .fetchUnseenForCurrentUser();
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
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
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
      if (prefs.getBool(Keys.hasPromptedNotification) ?? false) {
        // Already prompted — re-apply the daily reminder from saved prefs so a
        // reinstall/upgrade keeps (or clears) the 9 PM schedule correctly.
        await NotificationService().init();
        await NotificationService().syncDailyReminderFromPrefs();
        return;
      }
      await NotificationService().init();
      final granted =
          await NotificationService().requestNotificationsPermission();
      await prefs.setBool(Keys.hasPromptedNotification, true);
      if (granted) {
        await prefs.setBool(Keys.notificationsEnabled, true);
        // Schedule the local daily 9 PM reminder and register the FCM token.
        await NotificationService().scheduleDailyPlayReminder();
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

  // ignore: unused_element
  void _onConnectivityChanged() {
    // While a controlled reconnect is in progress, ignore stale
    // connectivity-blip events (the Firestore SDK retries briefly during
    // enableNetwork and that can echo back as a transient lost/regained
    // pair). The reconnect sequence is responsible for its own success
    // /failure decision.
    if (AppModeService.isReconnecting) {
      if (kDebugMode) {
        debugPrint(
            '[RECONNECT] stale connectivity event ignored — reconnect token active');
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
      debugPrint(
          '[NETWORK] entering weak connection (no silent offline switch)');
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
        debugPrint(
            '[RECONNECT] connection restored during paused online match');
        debugPrint(
            '[RECONNECT] match resume allowed=false — returning to online home');
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
        debugPrint(
            '[ONLINE_SWITCH] connection back while offline — asking user');
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
  // ignore: unused_element
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
          debugPrint(
              '[RECONNECT] attemptId=$token aborted — no authenticated user');
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
          debugPrint(
              '[RECONNECT] attemptId=$token aborted — user signed out during health check');
        }
        AppModeService.setMode(AppMode.connectionProblem);
        if (mounted) setState(() => _isReconnecting = false);
        return;
      }
      if (kDebugMode) {
        debugPrint(
            '[RECONNECT] attemptId=$token auth user verified uid=${stillSignedIn.uid}');
      }

      // Step 5 — pull server state.
      bool pulled = false;
      try {
        pulled = await UserRepo().pullServerToLocal(stillSignedIn.uid);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '[RECONNECT] attemptId=$token pullServerToLocal failed: $e');
        }
      }
      if (!pulled) {
        if (kDebugMode) {
          debugPrint(
              '[RECONNECT] attemptId=$token pullServerToLocal returned false — aborting');
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
      unawaited(WalletHistoryService.instance
          .flushPending(stillSignedIn.uid)
          .catchError((Object error) {
        if (kDebugMode) {
          debugPrint('[WALLET_HISTORY] reconnect flush deferred: $error');
        }
      }));

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
        debugPrint(
            '[RECONNECT] attemptId=$token online account restored for uid=${stillSignedIn.uid} (reason=$reason)');
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
        debugPrint(
            '[FIRESTORE] blocked listener mode=${AppModeService.current}');
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
          // Startup/auth already hydrates the local cosmetics cache. Once the
          // player changes any cosmetic in this process, local state is the
          // runtime source of truth until its background mirror converges;
          // applying a delayed snapshot here could undo a fresh equip or
          // unequip (and could also erase newly purchased ownership).
          if (cosmetics != null && LocalStore.cosmeticsVersion.value == 0) {
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
                    .map((e) => (e is num)
                        ? e.toInt()
                        : int.tryParse(e.toString()) ?? 0)
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
            await p.setString(Keys.ownedAvatars, ownedAvatarsList.join(','));
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
            if (level != null) {
              await p.setInt(Keys.levelGameCurrentLevel, level);
            }
            if (completed != null) {
              await p.setBool(Keys.levelGameCompleted, completed);
            }
          }

          // Cache characterType locally for offline avatar hint
          final firestoreCharType = profile?['characterType'] as String?;
          await LocalStore.setOnlineCharacterType(firestoreCharType);

          // Sync profile photo URL
          final firestorePhoto = profile?['photoURL'] as String?;
          final authPhoto = FirebaseAuth.instance.currentUser?.photoURL;
          final profilePhotoUrl =
              (firestorePhoto != null && firestorePhoto.isNotEmpty)
                  ? firestorePhoto
                  : ((authPhoto != null && authPhoto.isNotEmpty)
                      ? authPhoto
                      : null);
          await LocalStore.setProfilePhotoUrl(profilePhotoUrl);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[HomeHub] SharedPreferences write-through error: $e');
          }
        }
      },
      onError: (e) {
        if (FirebaseAuth.instance.currentUser == null) {
          // permission-denied after sign-out is expected — cancel silently
          _firestoreSub?.cancel();
          _firestoreSub = null;
          if (kDebugMode) {
            debugPrint('[HomeHub] Firestore stream closed (signed out)');
          }
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
    OnlineReconnectController.instance.clearScreenHooks();
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
        debugPrint(
            '[FIRESTORE] blocked session listener mode=${AppModeService.current}');
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
          if (kDebugMode) {
            debugPrint('[SESSION] signOut during conflict failed: $e');
          }
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
      barrierColor: Colors.black.withValues(alpha: 0.7),
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
                                  color:
                                      AppPalette.danger.withValues(alpha: 0.4),
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
                            fill: AppPalette.primary.withValues(alpha: 0.9),
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
    final nextName = (_offline && _offlineProfile != null)
        ? _offlineProfile!.name
        : (p.getString(Keys.username) ?? '');
    if (LocalStore.profilePhotoUrlNotifier.value != nextPhoto ||
        _playerName != nextName) {
      LocalStore.profilePhotoUrlNotifier.value = nextPhoto;
      setState(() => _playerName = nextName);
    }
  }

  Future<void> _openHomeCoinsStore() async {
    // Store / coins are browsable by guests. The purchase actions inside
    // (StorePage / coins_screen) still guard on FirebaseAuth before starting
    // any Google Play Billing, so guests can look but not buy.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StorePage(initialTab: 2),
      ),
    );
    await _refresh();
  }

  Future<void> _handleHomeProfileTap() async {
    // Offline-first: tapping the avatar never forces login — opens the
    // guest-safe Settings screen.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    await _refresh();
  }

  Widget _buildHomeCoinButton({
    required bool compact,
    required bool landscape,
  }) {
    // Shared coin pill (same widget used on Settings/Missions/Online/Invite)
    // so the coin display is visually identical across the app.
    return ArenaCoinBalance(
      onTap: _openHomeCoinsStore,
      compact: compact || landscape,
      minWidth: landscape ? 116 : (compact ? 104 : 128),
    );
  }

  Widget _buildHomeAvatarButton({
    required double size,
    required bool compact,
  }) {
    // Just the profile photo + equipped frame — no decorative box behind it.
    // The avatar now fills what used to be the whole framed container so it
    // reads bigger and cleaner.
    final framePadding = compact ? 2.5 : 3.5;
    final avatarSize = size + framePadding * 2;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _handleHomeProfileTap,
        child: ArenaProfileAvatar.current(
          size: avatarSize,
          fallbackInitials: _playerName,
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.warning.withValues(alpha: 0.14),
        border: Border(
          bottom: BorderSide(color: AppPalette.warning.withValues(alpha: 0.30)),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final compact = width < 360;
          final minSideWidth = compact ? 104.0 : 128.0;
          final maxSideWidth = landscape ? 156.0 : 180.0;
          final desiredSideWidth = width * (landscape ? 0.25 : 0.34);
          final minCenterWidth = compact ? 88.0 : 96.0;
          final sideUpperBound = max(84.0, (width - minCenterWidth) / 2);
          final sideSlotWidth = min(
            min(maxSideWidth, sideUpperBound),
            max(minSideWidth, desiredSideWidth),
          );
          final centerWidth = max(0.0, width - sideSlotWidth * 2);
          final topBarHeight = landscape ? 72.0 : (compact ? 92.0 : 106.0);
          final avatarSize = landscape ? 50.0 : (compact ? 60.0 : 72.0);

          return Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: topBarHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: sideSlotWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppPalette.homeCyan
                                      .withValues(alpha: 0.20),
                                  blurRadius: 20,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: _buildHomeAvatarButton(
                              size: landscape ? avatarSize : avatarSize - 8,
                              compact: compact,
                            ),
                          ),
                          if (!landscape && _playerName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: SizedBox(
                                width: sideSlotWidth - 8,
                                child: Text(
                                  _playerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: safeInter(
                                    fontSize: compact ? 11.0 : 12.2,
                                    fontWeight: FontWeight.w900,
                                    color: AppPalette.homeTitle
                                        .withValues(alpha: 0.94),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: centerWidth,
                    child: Center(
                      child: _XoArenaTitle(
                        compact: compact,
                        landscape: landscape,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: sideSlotWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildHomeCoinButton(
                        compact: compact,
                        landscape: landscape,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
                  _buildHomeTopBar(),
                  if (_offline) _buildOfflineBanner(),
                  Expanded(
                    child: _buildHomeContent(),
                  ),
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

  // ── Mode navigation (shared by cards + featured card + CTA) ──────────────
  Future<void> _openAi() async {
    await Navigator.of(context).push(_fadeRoute(const SetupPage()));
    _refresh();
    unawaited(_onGameReturned());
  }

  Future<void> _openFriend() async {
    await Navigator.of(context).push(_fadeRoute(const FriendSetupPage()));
    _refresh();
    unawaited(_onGameReturned());
  }

  Future<void> _openLevels() async {
    await Navigator.of(context).push(_fadeRoute(const LevelGameSetupPage()));
    _refresh();
    unawaited(_onGameReturned());
  }

  Future<void> _openOnline() async {
    // Online requires sign-in and is NEVER a random match — it opens the
    // create/join Arena flow. Guests get the sign-in prompt.
    if (_isGuest) {
      showSignInRequiredDialog(context);
      return;
    }
    await Navigator.of(context).push(_fadeRoute(const ArenaPage()));
    _refresh();
    unawaited(_onGameReturned());
  }

  void _openMissions() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MissionsPage()));
  }

  Future<void> _openStore() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const StorePage()));
    await _refresh();
  }

  Widget _buildHomeContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        // Symmetric, small side margins so main content fills ~92-96% of the
        // screen width. The Store/Settings edge buttons below are a Stack
        // overlay (Positioned, drawn after the ListView) — they do not
        // reserve any layout width, they simply sit on top of the content's
        // right edge.
        final sidePad = compact ? 12.0 : 14.0;
        final dockTop = compact ? 56.0 : 66.0;
        final dockGap = compact ? 86.0 : 94.0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(sidePad, 4, sidePad, 14),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildFeaturedOnlineCard(),
                const SizedBox(height: 10),
                _buildModeCardsRow(),
                const SizedBox(height: 10),
                MissionPreviewPanel(onViewAll: _openMissions),
                const SizedBox(height: 14),
                _buildBottomCta(),
                const SizedBox(height: 8),
              ],
            ),
            Positioned(
              right: compact ? -20 : -22,
              top: dockTop,
              child: _homeEdgeShortcutButton(
                iconChild: Image.asset('assets/shop.png',
                    width: compact ? 50 : 54,
                    height: compact ? 50 : 54,
                    fit: BoxFit.contain,
                    cacheWidth: 174,
                    errorBuilder: (_, __, ___) => Icon(Icons.storefront_rounded,
                        color: AppPalette.homeGold, size: compact ? 31 : 34)),
                label: AppL10n.of(context).storeTab,
                accent: AppPalette.homeGold,
                fromLeft: false,
                onTap: _openStore,
              ),
            ),
            Positioned(
              right: compact ? -20 : -22,
              top: dockTop + dockGap,
              child: _homeEdgeShortcutButton(
                iconChild: _SettingsActionIcon(),
                label: AppL10n.of(context).settingsTab,
                accent: AppPalette.homeCyan,
                fromLeft: false,
                onTap: _handleHomeProfileTap,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _homeEdgeShortcutButton({
    required Widget iconChild,
    required String label,
    required VoidCallback onTap,
    required bool fromLeft,
    Widget? badge,
    Color accent = AppPalette.homeCyan,
  }) {
    final panelWidth = 78.0;
    final visibleWidth = 60.0;
    final panelHeight = 82.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: panelWidth,
        height: panelHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin:
                        fromLeft ? Alignment.centerLeft : Alignment.centerRight,
                    end:
                        fromLeft ? Alignment.centerRight : Alignment.centerLeft,
                    colors: [
                      AppPalette.bgDepth.withValues(alpha: 0.94),
                      AppPalette.homePanelStrong.withValues(alpha: 0.90),
                      Color.lerp(AppPalette.homePanelDeep, accent, 0.10)!
                          .withValues(alpha: 0.84),
                    ],
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.44),
                    width: 1.15,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: -6,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment:
                    fromLeft ? Alignment.centerRight : Alignment.centerLeft,
                child: SizedBox(
                  width: visibleWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 48,
                        child: Center(child: iconChild),
                      ),
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: homeLabelFont(
                              context,
                              fontSize: 9.5,
                              color:
                                  AppPalette.homeTitle.withValues(alpha: 0.94),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: panelHeight / 2 - 11,
              left: fromLeft ? null : 0,
              right: fromLeft ? 0 : null,
              child: Container(
                width: 2.5,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      accent.withValues(alpha: 0.64),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.32),
                      blurRadius: 9,
                    ),
                  ],
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: -5,
                right: fromLeft ? 8 : null,
                left: fromLeft ? null : 8,
                child: badge,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedOnlineCard() {
    final l10n = AppL10n.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = min(max(width * 0.54, 184.0), 220.0);
        final textWidth = min(max(width * 0.42, 138.0), 184.0);
        return GestureDetector(
          onTap: _openOnline,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: AppPalette.homeCyan.withValues(alpha: 0.56),
                  width: 1.15),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.homeCyan.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: AppPalette.homeBlue.withValues(alpha: 0.12),
                  blurRadius: 34,
                  spreadRadius: -14,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/game/online-money.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                    cacheWidth: 1000,
                    errorBuilder: (_, __, ___) => DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppPalette.homePanelDeep,
                            AppPalette.homeBlue.withValues(alpha: 0.30),
                          ],
                        ),
                      ),
                      child: Icon(Icons.public_rounded,
                          size: 78,
                          color: AppPalette.homeCyan.withValues(alpha: 0.65)),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppPalette.bgDepth.withValues(alpha: 0.02),
                          AppPalette.bgDepth.withValues(alpha: 0.28),
                          AppPalette.bgDepth.withValues(alpha: 0.92),
                        ],
                        stops: const [0.0, 0.52, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 18,
                    width: textWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.onlineFriendsTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: homeTitleFont(
                            context,
                            fontSize: width < 360 ? 21 : 26,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.onlineFriendsSubtitle,
                          style: homeBodyFont(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.homeBody,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: AppPillButton(
                            label: l10n.playNowBtn,
                            fitLabel: true,
                            minHeight: 48,
                            onPressed: _openOnline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeCardsRow() {
    final l10n = AppL10n.of(context);
    Widget card({
      required String title,
      required String subtitle,
      required String badge,
      required String asset,
      required Color accent,
      required Color accent2,
      required VoidCallback onTap,
      bool wide = false,
      Alignment imageAlignment = Alignment.center,
    }) {
      return Expanded(
        child: SizedBox(
          height: 154,
          child: BigModeCard(
            title: title,
            subtitle: subtitle,
            badge: badge,
            assetPath: asset,
            accent: accent,
            accentSecondary: accent2,
            onTap: onTap,
            wide: wide,
            imageAlignment: imageAlignment,
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              card(
                title: l10n.vsFriendTitle,
                subtitle: l10n.vsFriendSubtitle,
                badge: l10n.badgeHot,
                asset: 'assets/game/friend.webp',
                accent: AppPalette.homePurple,
                accent2: AppPalette.homePink,
                onTap: _openFriend,
                wide: true,
                imageAlignment: Alignment.center,
              ),
              const SizedBox(width: 10),
              card(
                title: l10n.vsAiTitle,
                subtitle: l10n.vsAiSubtitle,
                badge: l10n.badgeAi,
                asset: 'assets/game/ai.webp',
                accent: AppPalette.homeCyan,
                accent2: AppPalette.homeBlue,
                onTap: _openAi,
                wide: true,
                imageAlignment: Alignment.centerRight,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: BigModeCard(
              title: l10n.levelsTitle,
              subtitle: l10n.levelsSubtitle,
              badge: l10n.badgeReward,
              assetPath: 'assets/game/levels.webp',
              accent: AppPalette.homeSky,
              accentSecondary: AppPalette.homeBlue,
              onTap: _openLevels,
              wide: true,
              imageAlignment: Alignment.centerRight,
              textAlignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlayNowCta() async {
    await Navigator.of(context).push(_fadeRoute(
      GamePage(
        mode: GameMode.ai,
        difficulty: AIDifficulty.medium,
        playerSymbol: PlayerSymbol.x,
      ),
    ));
    _refresh();
    unawaited(_onGameReturned());
  }

  Widget _buildBottomCta() {
    final l10n = AppL10n.of(context);
    return GestureDetector(
      onTap: _handlePlayNowCta,
      child: Container(
        height: 66,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.goldHighlight,
              AppPalette.gold,
              AppPalette.goldDeep,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppPalette.gold.withValues(alpha: 0.4),
              blurRadius: 22,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: AppPalette.goldHighlight.withValues(alpha: 0.62),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: AppPalette.bgDepth, size: 32),
            const SizedBox(width: 10),
            Text(l10n.playNowBtn,
                style: safeOrbitron(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.4,
                    color: AppPalette.bgDepth)),
          ],
        ),
      ),
    );
  }
}

class _XoArenaTitle extends StatelessWidget {
  final bool compact;
  final bool landscape;

  const _XoArenaTitle({required this.compact, required this.landscape});

  @override
  Widget build(BuildContext context) {
    final xoSize = landscape ? 25.0 : (compact ? 31.0 : 36.0);
    final arenaSize = landscape ? 13.0 : (compact ? 16.0 : 19.0);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF9DF3FF),
                AppPalette.homeCyan,
                Color(0xFF287BFF),
              ],
            ).createShader(bounds),
            child: Text(
              'XO',
              style: safeOrbitron(
                fontSize: xoSize,
                fontWeight: FontWeight.w900,
                letterSpacing: compact ? 4.2 : 5.0,
                color: Colors.white,
                height: 0.95,
                shadows: [
                  Shadow(
                    color: AppPalette.homeCyan.withValues(alpha: 0.86),
                    blurRadius: 20,
                  ),
                  Shadow(
                    color: AppPalette.homeSky.withValues(alpha: 0.48),
                    blurRadius: 32,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFBFCBFF),
                AppPalette.homePurple,
              ],
            ).createShader(bounds),
            child: Text(
              'ARENA',
              style: safeOrbitron(
                fontSize: arenaSize,
                fontWeight: FontWeight.w900,
                letterSpacing: compact ? 3.8 : 4.4,
                color: Colors.white,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: AppPalette.homeCyan.withValues(alpha: 0.52),
                    blurRadius: 16,
                  ),
                  Shadow(
                    color: AppPalette.homePurple.withValues(alpha: 0.50),
                    blurRadius: 24,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppPalette.homeCyan.withValues(alpha: 0.22),
                AppPalette.homeBlue.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.homeCyan.withValues(alpha: 0.24),
                blurRadius: 14,
                spreadRadius: -6,
              ),
            ],
          ),
        ),
        Icon(
          Icons.settings_rounded,
          color: AppPalette.homeCyan,
          size: 40,
          shadows: [
            Shadow(
              color: AppPalette.homeBlue.withValues(alpha: 0.58),
              blurRadius: 10,
            ),
          ],
        ),
      ],
    );
  }
}
