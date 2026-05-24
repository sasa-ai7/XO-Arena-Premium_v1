import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../services/referral/referral_service.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/arena_toast.dart';
import '../arena/widgets/digit_keypad.dart';
import 'invite_friends_page.dart';

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
        ArenaToast.error(context, AppL10n.of(context).clipboardNoValidInviteCode);
      }
      return;
    }
    setState(() => _value = digits.substring(0, _length));
  }

  Future<void> _submit() async {
    if (_value.length != _length || _busy) return;
    final l10n = AppL10n.of(context);

    // Fast self-referral guard: avoid round-tripping Firestore if the entered
    // code matches the user's own.
    if (_selfCode != null && _selfCode == _value) {
      ArenaToast.error(context, l10n.referralCantUseOwn);
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await ReferralService.instance.redeem(code: _value);
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
      default:
        return l10n.referralRedeemError;
    }
  }

  Future<void> _showSuccessDialog(ReferralRedeemResult res) async {
    final l10n = AppL10n.of(context);
    final hasReferrer = (res.referrerName ?? '').isNotEmpty;
    final hasPhoto = (res.referrerPhotoURL ?? '').isNotEmpty;
    final friendName = hasReferrer ? res.referrerName! : 'a friend';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppPalette.primary.withValues(alpha: 0.85),
                    width: 2.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.35),
                      blurRadius: 22,
                    ),
                  ],
                  color: AppPalette.panelDeep,
                ),
                clipBehavior: Clip.antiAlias,
                child: hasPhoto
                    ? CachedNetworkImage(
                        imageUrl: res.referrerPhotoURL!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const _ReferrerFallback(),
                        errorWidget: (_, __, ___) =>
                            const _ReferrerFallback(),
                      )
                    : const _ReferrerFallback(),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.giftClaimed,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  shadows: [
                    Shadow(color: AppPalette.gold, blurRadius: 12),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/coin/COIN.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.monetization_on_rounded,
                      color: AppPalette.gold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${res.rewardCoins}',
                    style: const TextStyle(
                      color: AppPalette.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Orbitron',
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
                style: const TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.shareYourCode,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.textMuted.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const InviteFriendsPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary.withValues(alpha: 0.18),
                    foregroundColor: AppPalette.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: AppPalette.primary.withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.4,
                    ),
                  ),
                  child: Text(l10n.myInviteCode),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  l10n.close,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontWeight: FontWeight.w700,
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
                      l10n.enterInviteCodeTitle,
                      style: const TextStyle(
                        color: AppPalette.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padH),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.enterInviteCodeTitle,
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: DigitSlotsDisplay(
                          value: _value,
                          length: _length,
                          maxWidth: slotsMaxWidth,
                          maxSlotHeight: 50,
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
                      Center(
                        child: SizedBox(
                          width: keypadMaxWidth,
                          child: DigitKeypad(
                            onDigit: _addDigit,
                            onDelete: _delete,
                            onEnter: _submit,
                            enterEnabled:
                                _value.length == _length && !_busy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_busy)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
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
}

/// Default referrer avatar used while the network image is loading or if
/// the referrer has no photo. Asset is shipped with the app.
class _ReferrerFallback extends StatelessWidget {
  const _ReferrerFallback();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/account/man.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppPalette.panelDeep,
        alignment: Alignment.center,
        child: const Icon(
          Icons.person_rounded,
          color: AppPalette.textMuted,
          size: 40,
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
