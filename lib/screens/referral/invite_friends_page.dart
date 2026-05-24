import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../services/referral/referral_service.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_toast.dart';
import '../arena/arena_share_helper.dart';

class InviteFriendsPage extends StatefulWidget {
  const InviteFriendsPage({super.key});

  @override
  State<InviteFriendsPage> createState() => _InviteFriendsPageState();
}

class _InviteFriendsPageState extends State<InviteFriendsPage> {
  String? _code;
  int _validCount = 0;
  int _totalEarned = 0;
  bool _loading = true;
  bool _loadError = false;
  int _retryAttempts = 0;
  bool _busyShare = false;
  bool _busyCopy = false;

  static const List<Duration> _kRetryBackoffs = [
    Duration(milliseconds: 800),
    Duration(milliseconds: 2500),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (kDebugMode) debugPrint('[REFERRAL] invite friends _load start');
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = false;
      });
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = true;
        });
      }
      return;
    }
    final ok = await _attemptLoad(uid);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _loading = false;
        _loadError = false;
      });
      return;
    }
    // Initial attempt failed — auto-retry with backoff before showing the
    // error/retry card to the user.
    for (final delay in _kRetryBackoffs) {
      _retryAttempts++;
      if (kDebugMode) {
        debugPrint(
            '[REFERRAL] invite friends auto-retry attempt=$_retryAttempts after=${delay.inMilliseconds}ms');
      }
      await Future<void>.delayed(delay);
      if (!mounted) return;
      final retried = await _attemptLoad(uid);
      if (!mounted) return;
      if (retried) {
        setState(() {
          _loading = false;
          _loadError = false;
        });
        return;
      }
    }
    setState(() {
      _loading = false;
      _loadError = true;
    });
  }

  /// Returns true when [_code] is populated with a 9-digit code after the call.
  Future<bool> _attemptLoad(String uid) async {
    try {
      final self = await ReferralService.instance.readSelf(uid);
      final storedCode = self['code'] as String?;
      if (storedCode != null && storedCode.length == 9) {
        if (!mounted) return false;
        setState(() {
          _code = storedCode;
          _validCount = (self['validReferralCount'] as num?)?.toInt() ?? 0;
          _totalEarned =
              (self['totalReferralCoinsEarned'] as num?)?.toInt() ?? 0;
        });
        if (kDebugMode) {
          debugPrint('[REFERRAL] invite code loaded code=$storedCode');
        }
        return true;
      }
      // No stored code yet — try to allocate one now.
      final code = await ReferralService.instance.ensureCode(uid);
      if (!mounted) return false;
      if (code == null) {
        if (kDebugMode) {
          debugPrint('[REFERRAL] ensureCode returned null');
        }
        return false;
      }
      final fresh = await ReferralService.instance.readSelf(uid);
      if (!mounted) return false;
      setState(() {
        _code = code;
        _validCount = (fresh['validReferralCount'] as num?)?.toInt() ?? 0;
        _totalEarned =
            (fresh['totalReferralCoinsEarned'] as num?)?.toInt() ?? 0;
      });
      if (kDebugMode) {
        debugPrint('[REFERRAL] invite code created code=$code');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[REFERRAL] _attemptLoad failed: $e');
      }
      return false;
    }
  }

  Future<void> _retryLoad() async {
    _retryAttempts = 0;
    await _load();
  }

  Future<void> _share() async {
    if (_busyShare) return;
    final code = _code;
    if (code == null || code.isEmpty) return;
    _busyShare = true;
    try {
      final l10n = AppL10n.of(context);
      if (kDebugMode) {
        debugPrint('[REFERRAL] share invite pressed code=$code');
      }
      final ok = await ArenaShareHelper.shareInvite(
        l10n: l10n,
        referralCode: code,
      );
      if (!mounted) return;
      if (!ok) {
        ArenaToast.info(context, l10n.copiedToClipboard);
      }
    } finally {
      _busyShare = false;
    }
  }

  Future<void> _copy() async {
    if (_busyCopy) return;
    final code = _code;
    if (code == null || code.isEmpty) return;
    _busyCopy = true;
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      ArenaToast.success(context, AppL10n.of(context).codeCopied);
      if (kDebugMode) {
        debugPrint('[REFERRAL] copy code success code=$code');
      }
    } finally {
      _busyCopy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final completed = _validCount >= ReferralService.kMaxFriends;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.inviteFriendsTitle,
                      style: const TextStyle(
                        color: AppPalette.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                            child: _ErrorRetryCard(
                              message: l10n.referralLoadFailed,
                              retryLabel: l10n.retry,
                              onRetry: _retryLoad,
                            ),
                          )
                        : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _codeCard(l10n),
                            const SizedBox(height: 14),
                            Text(
                              l10n.inviteFriendsBody,
                              style: const TextStyle(
                                color: AppPalette.text,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _progressCard(l10n, completed),
                            const SizedBox(height: 22),
                            if (completed)
                              _completedPill(l10n)
                            else
                              SizedBox(
                                height: 54,
                                child: ElevatedButton.icon(
                                  onPressed: _code == null ? null : _share,
                                  icon: const Icon(Icons.share_rounded),
                                  label: Text(l10n.shareInvite),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppPalette.gold,
                                    foregroundColor: AppPalette.bgTop,
                                    disabledBackgroundColor:
                                        AppPalette.panelDeep,
                                    disabledForegroundColor:
                                        AppPalette.textSubtle,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _codeCard(AppL10n l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.homePanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppPalette.gold.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.gold.withValues(alpha: 0.15),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            l10n.yourInviteCode,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          if (_code != null)
            Text(
              _code!,
              style: const TextStyle(
                color: AppPalette.text,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                fontFamily: 'Orbitron',
              ),
            )
          else
            const SizedBox(
              height: 28,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _code == null ? null : _copy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(l10n.copyCode),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(AppL10n l10n, bool completed) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.strokeSoft, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.referralProgress,
                  style: const TextStyle(color: AppPalette.textMuted),
                ),
              ),
              Text(
                '$_validCount / ${ReferralService.kMaxFriends}',
                style: const TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: _validCount / ReferralService.kMaxFriends,
              backgroundColor: AppPalette.panelDeep,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppPalette.gold),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.monetization_on,
                  size: 16, color: AppPalette.gold),
              const SizedBox(width: 6),
              Text(
                '${l10n.referralEarned}: $_totalEarned ${l10n.coinsWord}',
                style: const TextStyle(
                  color: AppPalette.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (completed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.referralCompleted,
                style: const TextStyle(
                  color: AppPalette.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _completedPill(AppL10n l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppPalette.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.success, width: 1.4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppPalette.success, size: 22),
          const SizedBox(width: 10),
          Text(
            '${l10n.referralCompletedShort} 10/10',
            style: const TextStyle(
              color: AppPalette.success,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Neon-styled card shown when the invite code fails to load after retries.
/// Mirrors the gold-glow design language of [_codeCard] so the screen
/// doesn't feel "broken" — just paused.
class _ErrorRetryCard extends StatelessWidget {
  final String message;
  final String retryLabel;
  final Future<void> Function() onRetry;

  const _ErrorRetryCard({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppPalette.homePanel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppPalette.danger.withValues(alpha: 0.55),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: AppPalette.danger.withValues(alpha: 0.18),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppPalette.danger,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.gold,
                  foregroundColor: AppPalette.bgTop,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
