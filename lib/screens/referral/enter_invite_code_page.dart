import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../services/referral/referral_service.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_neon_widgets.dart';
import '../../widgets/arena_toast.dart';
import '../arena/widgets/digit_keypad.dart';
import '../store/store_page.dart';

class EnterInviteCodePage extends StatefulWidget {
  const EnterInviteCodePage({super.key});

  @override
  State<EnterInviteCodePage> createState() => _EnterInviteCodePageState();
}

class _EnterInviteCodePageState extends State<EnterInviteCodePage> {
  String _value = '';
  bool _busy = false;

  /// Current user's own referral code (cached so we can pre-check on submit).
  String? _selfCode;

  static const int _length = 9;

  @override
  void initState() {
    super.initState();
    _loadSelfCode();
  }

  Future<void> _loadSelfCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final self = await ReferralService.instance.readSelf(uid);
    if (!mounted) return;
    setState(() {
      _selfCode = self['code'] as String?;
    });
  }

  void _addDigit(String d) {
    if (_value.length >= _length || _busy) return;
    setState(() => _value = _value + d);
  }

  void _delete() {
    if (_value.isEmpty || _busy) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  Future<void> _paste() async {
    if (_busy) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < _length) {
      if (mounted) {
        ArenaToast.error(
            context, AppL10n.of(context).clipboardNoValidInviteCode);
      }
      return;
    }
    setState(() => _value = digits.substring(0, _length));
  }

  Future<void> _submit() async {
    if (_value.length != _length || _busy) return;
    final l10n = AppL10n.of(context);
    final startedAt = DateTime.now();

    // Fast self-referral guard: avoid round-tripping Firestore if the entered
    // code matches the user's own.
    if (_selfCode != null && _selfCode == _value) {
      ArenaToast.error(context, l10n.referralCantUseOwn);
      return;
    }

    setState(() => _busy = true);
    try {
      var res = await ReferralService.instance.redeem(code: _value);
      // Brand-new accounts may not be fully synced on the first attempt.
      // Retry once automatically after a short delay before giving up.
      if (!res.success && res.error == ReferralError.notReady) {
        if (kDebugMode) {
          debugPrint('[REFERRAL] notReady — auto-retrying once after sync delay');
        }
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        res = await ReferralService.instance.redeem(code: _value);
      }
      if (kDebugMode) {
        final ms = DateTime.now().difference(startedAt).inMilliseconds;
        debugPrint('[PERF] invite_code_submit_ms=$ms');
      }
      if (!mounted) return;
      if (res.success) {
        await _showSuccessDialog(res);
        return;
      }
      ArenaToast.error(context, _errorMessage(res.error, l10n));
    } finally {
      // Always clear the busy flag — previous code missed this on the
      // success path, leaving the keypad locked and (when combined with
      // re-mount edges) allowing a second submit on the next tap.
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorMessage(ReferralError? error, AppL10n l10n) {
    switch (error) {
      case ReferralError.invalidFormat:
        return l10n.referralCodeMustBe9;
      case ReferralError.selfReferral:
        return l10n.referralCantUseOwn;
      case ReferralError.alreadyUsed:
        return l10n.referralAlreadyUsed;
      case ReferralError.notFound:
        return l10n.referralCodeNotFound;
      case ReferralError.notEligible:
        return l10n.referralNotEligible;
      case ReferralError.capacityFull:
        return l10n.referralCompleted;
      case ReferralError.networkError:
        return l10n.referralNetworkError;
      case ReferralError.notReady:
        return l10n.somethingWentWrong;
      default:
        return l10n.referralRedeemError;
    }
  }

  Future<void> _openCoinsStore() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StorePage(initialTab: 2)),
    );
  }

  Future<void> _showSuccessDialog(ReferralRedeemResult res) async {
    final l10n = AppL10n.of(context);
    final hasReferrer = (res.referrerName ?? '').isNotEmpty;
    final friendName = hasReferrer ? res.referrerName! : l10n.defaultFriendName;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.74),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppPalette.homePanelStrong, AppPalette.panelDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppPalette.gold.withValues(alpha: 0.7),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.gold.withValues(alpha: 0.25),
                blurRadius: 32,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: 132,
                  width: double.infinity,
                  child: Image.asset(
                    kArenaInviteAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                    cacheWidth: 720,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.giftClaimed,
                textAlign: TextAlign.center,
                style: safeOrbitron(
                  color: AppPalette.goldHighlight,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  shadows: [
                    Shadow(color: AppPalette.gold, blurRadius: 12),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  missionCoinSmall(28),
                  const SizedBox(width: 8),
                  Text(
                    '+${res.rewardCoins}',
                    style: safeOrbitron(
                      color: AppPalette.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: AppPalette.gold, blurRadius: 16),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l10n.referralReceivedCoins(res.rewardCoins, friendName),
                textAlign: TextAlign.center,
                style: safeInter(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.rewardOnValidCode,
                textAlign: TextAlign.center,
                style: safeInter(
                  color: AppPalette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: NeonActionButton(
                  label: l10n.okBtn,
                  onTap: () => Navigator.of(ctx).pop(),
                  minWidth: 0,
                  height: 48,
                  accent: AppPalette.homeCyan,
                  accentSecondary: AppPalette.homeBlue,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  l10n.close,
                  style: safeInter(
                    color: AppPalette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final padH = 16.0;
    final keypadMaxWidth = min<double>(360, screenWidth - padH * 2);
    final slotsMaxWidth = min<double>(360, screenWidth - padH * 2);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: SafeArea(
          child: Directionality(
            textDirection: l10n.isAr ? TextDirection.rtl : TextDirection.ltr,
            child: Column(
              children: [
                XoArenaScreenHeader(
                  onBack: () => Navigator.of(context).maybePop(),
                  onCoinsTap: _openCoinsStore,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.enterInviteCodeTitle,
                        style: homeTitleFont(context, fontSize: 24),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        l10n.enterInviteCodeSubtitle,
                        style: homeBodyFont(
                          context,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.homeBody,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(padH, 0, padH, 22),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _InviteHeroCard(),
                      const SizedBox(height: 16),
                      AppGlassCard(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        radius: 24,
                        borderColor:
                            AppPalette.homeCyan.withValues(alpha: 0.38),
                        child: Column(
                          children: [
                            Text(
                              l10n.inviteCodeLabel,
                              style: homeLabelFont(
                                context,
                                fontSize: 13,
                                color: AppPalette.homeCyan,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: DigitSlotsDisplay(
                                value: _value,
                                length: _length,
                                maxWidth: slotsMaxWidth,
                                maxSlotHeight: 52,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: _PasteButton(
                                onTap: _paste,
                                label: l10n.pasteCode,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: NeonActionButton(
                                label: l10n.confirmCodeBtn,
                                onTap: _value.length == _length && !_busy
                                    ? _submit
                                    : null,
                                busy: _busy,
                                minWidth: 0,
                                height: 50,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.inviteOneTimeNote,
                              textAlign: TextAlign.center,
                              style: safeInter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: SizedBox(
                          width: keypadMaxWidth,
                          child: DigitKeypad(
                            onDigit: _addDigit,
                            onDelete: _delete,
                            onEnter: _submit,
                            enterEnabled: _value.length == _length && !_busy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteHeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppGlassCard(
      padding: EdgeInsets.zero,
      radius: 26,
      borderColor: AppPalette.homePurple.withValues(alpha: 0.42),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageWidth = constraints.maxWidth * 0.42;
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  SizedBox(
                    width: imageWidth,
                    height: 194,
                    child: RepaintBoundary(
                      child: Image.asset(
                        kArenaInviteAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.centerLeft,
                        cacheWidth: 760,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Directionality(
                      textDirection:
                          l10n.isAr ? TextDirection.rtl : TextDirection.ltr,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.enterInviteCodeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: homeTitleFont(context, fontSize: 21),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.enterInviteCodeHeroBody,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: homeBodyFont(
                                context,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.homeBody,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: AppPalette.gold.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: AppPalette.goldHighlight
                                      .withValues(alpha: 0.58),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  missionCoinSmall(18),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.plus100Coins,
                                    style: safeInter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: AppPalette.goldHighlight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PasteButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _PasteButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppPalette.primary.withValues(alpha: 0.6),
              width: 1.1,
            ),
            color: AppPalette.primary.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.content_paste_rounded,
                  size: 16, color: AppPalette.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppPalette.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
