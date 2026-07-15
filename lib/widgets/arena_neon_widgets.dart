import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import '../core/keys.dart';
import '../services/referral/referral_service.dart';
import 'app_ui.dart';
import 'arena_toast.dart';
import 'full_avatar_display.dart';

const String kArenaCreateRoomAsset = 'assets/online/ROOM.webp';
const String kArenaJoinRoomAsset = 'assets/online/JONROOM.webp';
const String kArenaInviteAsset = 'assets/online/hedy.webp';

User? _safeFirebaseUser() {
  try {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null;
  }
}

class XoArenaScreenHeader extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onCoinsTap;
  final bool showBack;

  const XoArenaScreenHeader({
    super.key,
    this.onBack,
    this.onCoinsTap,
    this.showBack = true,
  });

  @override
  State<XoArenaScreenHeader> createState() => _XoArenaScreenHeaderState();
}

class _XoArenaScreenHeaderState extends State<XoArenaScreenHeader> {
  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final authName = _safeFirebaseUser()?.displayName ?? '';
    final stored = prefs.getString(Keys.username) ?? '';
    final next = (stored.isNotEmpty ? stored : authName).trim();
    if (!mounted) return;
    setState(() => _name = next.isEmpty ? 'PLAYER' : next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 370;
          final sideWidth = compact ? 108.0 : 132.0;
          final avatarSize = compact ? 48.0 : 56.0;
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: compact ? 88 : 98,
              child: Row(
                children: [
                  SizedBox(
                    width: sideWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _HeaderProfile(
                        size: avatarSize,
                        name: _name,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _XoArenaNeonTitle(compact: compact),
                    ),
                  ),
                  SizedBox(
                    width: sideWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.showBack) ...[
                          AppIconButton(
                            icon: Icons.arrow_forward_ios_rounded,
                            size: compact ? 34 : 38,
                            iconSize: compact ? 16 : 18,
                            radius: 12,
                            onTap: widget.onBack ??
                                () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(height: 6),
                        ],
                        _HeaderCoins(
                          compact: compact,
                          onTap: widget.onCoinsTap,
                        ),
                      ],
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
}

class _HeaderProfile extends StatelessWidget {
  final double size;
  final String name;

  const _HeaderProfile({
    required this.size,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Just the photo + equipped frame, no decorative box behind it.
        ArenaProfileAvatar.current(
          size: size,
          fallbackInitials: name,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: size + 34,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: safeInter(
              fontSize: size < 54 ? 10.5 : 11.5,
              fontWeight: FontWeight.w900,
              color: AppPalette.homeTitle.withValues(alpha: 0.94),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderCoins extends StatelessWidget {
  final bool compact;
  final VoidCallback? onTap;

  const _HeaderCoins({
    required this.compact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Shared coin pill — same widget as Home/Settings so the coin display
    // is visually identical everywhere.
    return ArenaCoinBalance(
      onTap: onTap,
      compact: compact,
      minWidth: compact ? 98 : 116,
    );
  }
}

class _XoArenaNeonTitle extends StatelessWidget {
  final bool compact;

  const _XoArenaNeonTitle({required this.compact});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                fontSize: compact ? 27 : 32,
                fontWeight: FontWeight.w900,
                letterSpacing: compact ? 4.0 : 5.0,
                color: Colors.white,
                height: 0.95,
                shadows: [
                  Shadow(
                    color: AppPalette.homeCyan.withValues(alpha: 0.84),
                    blurRadius: 18,
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
                Colors.white,
                Color(0xFFBFCBFF),
                AppPalette.homePurple,
              ],
            ).createShader(bounds),
            child: Text(
              'ARENA',
              style: safeOrbitron(
                fontSize: compact ? 14.5 : 17,
                fontWeight: FontWeight.w900,
                letterSpacing: compact ? 3.4 : 4.2,
                color: Colors.white,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: AppPalette.homePurple.withValues(alpha: 0.54),
                    blurRadius: 22,
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

class NeonArenaActionCard extends StatelessWidget {
  final String assetPath;
  final String title;
  final List<String> subtitleLines;
  final String buttonLabel;
  final VoidCallback onPressed;
  final Color accent;
  final Color accentSecondary;

  const NeonArenaActionCard({
    super.key,
    required this.assetPath,
    required this.title,
    required this.subtitleLines,
    required this.buttonLabel,
    required this.onPressed,
    this.accent = AppPalette.homeCyan,
    this.accentSecondary = AppPalette.homeBlue,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = AppL10n.of(context).isAr;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final height = compact ? 166.0 : 184.0;
        final imageWidth = constraints.maxWidth * (compact ? 0.43 : 0.46);
        return GestureDetector(
          onTap: onPressed,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: accent.withValues(alpha: 0.52),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 26,
                  spreadRadius: -8,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base gradient — only visible if the hero art fails to load.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppPalette.homePanelDeep,
                          AppPalette.homePanelStrong.withValues(alpha: 0.96),
                          Color.lerp(AppPalette.homePanelDeep, accent, 0.10)!,
                        ],
                      ),
                    ),
                  ),
                  // Full-bleed hero art. These images are composed with the
                  // subject on the left and an intentionally dark right side —
                  // using them as the whole-card background lets the subject
                  // fill its side with no empty black gap, while the dark right
                  // becomes the backdrop for the text.
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.cover,
                        alignment: Alignment.centerLeft,
                        cacheWidth: 1080,
                        errorBuilder: (_, __, ___) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent.withValues(alpha: 0.18),
                                AppPalette.homePanelDeep,
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: accent,
                            size: 58,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Right-side scrim so the Arabic title / button stay legible
                  // over the art. Left stays clear so the subject reads cleanly.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              AppPalette.bgDepth.withValues(alpha: 0.30),
                              AppPalette.bgDepth.withValues(alpha: 0.72),
                            ],
                            stops: const [0.30, 0.60, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Text + button on the right; the left is left clear for art.
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        SizedBox(width: imageWidth),
                        Expanded(
                          child: Directionality(
                            textDirection:
                                isAr ? TextDirection.rtl : TextDirection.ltr,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                compact ? 10 : 14,
                                16,
                                compact ? 14 : 18,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: homeTitleFont(
                                      context,
                                      fontSize: compact ? 22 : 25,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final line in subtitleLines)
                                    Text(
                                      line,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: homeBodyFont(
                                        context,
                                        fontSize: compact ? 12.5 : 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppPalette.homeBody,
                                      ),
                                    ),
                                  const SizedBox(height: 14),
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: NeonActionButton(
                                      label: buttonLabel,
                                      onTap: onPressed,
                                      accent: accent,
                                      accentSecondary: accentSecondary,
                                      minWidth: compact ? 104 : 126,
                                      height: compact ? 42 : 46,
                                    ),
                                  ),
                                ],
                              ),
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
        );
      },
    );
  }
}

class NeonActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color accent;
  final Color accentSecondary;
  final double minWidth;
  final double height;
  final bool busy;

  const NeonActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.accent = AppPalette.homeCyan,
    this.accentSecondary = AppPalette.homeBlue,
    this.minWidth = 118,
    this.height = 44,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: onTap == null ? 0.55 : 1,
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [accent, accentSecondary]),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.42),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.36),
                blurRadius: 18,
                spreadRadius: -5,
              ),
            ],
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: safeInter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class InviteCodePanel extends StatefulWidget {
  final VoidCallback onEnterCode;
  final bool compact;
  final bool missionsVariant;

  const InviteCodePanel({
    super.key,
    required this.onEnterCode,
    this.compact = false,
    this.missionsVariant = false,
  });

  @override
  State<InviteCodePanel> createState() => _InviteCodePanelState();
}

class _InviteCodePanelState extends State<InviteCodePanel> {
  String? _code;
  int _validCount = 0;
  bool _loading = true;
  bool _loadError = false;
  bool _busyCopy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _safeFirebaseUser()?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
      return;
    }
    try {
      var self = await ReferralService.instance.readSelf(uid);
      var code = self['code'] as String?;
      if (code == null || code.length != 9) {
        code = await ReferralService.instance.ensureCode(uid);
        self = await ReferralService.instance.readSelf(uid);
      }
      if (!mounted) return;
      setState(() {
        _code = code;
        _validCount = (self['validReferralCount'] as num?)?.toInt() ?? 0;
        _loading = false;
        _loadError = code == null || code.isEmpty;
      });
      if (kDebugMode) {
        debugPrint(
            '[REFERRAL] invite panel loaded code=$code count=$_validCount');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[REFERRAL] invite panel load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
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
    } finally {
      _busyCopy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final title = l10n.inviteFriendsTitle;
    final subtitle = widget.missionsVariant
        ? l10n.inviteFriendsSubtitle
        : l10n.inviteFriendsSubtitleShort;
    return AppGlassCard(
      padding: EdgeInsets.zero,
      radius: 26,
      borderColor: AppPalette.homeGold.withValues(alpha: 0.44),
      boxShadow: [
        BoxShadow(
          color: AppPalette.homeGold.withValues(alpha: 0.14),
          blurRadius: 24,
          spreadRadius: -8,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: AppPalette.homePurple.withValues(alpha: 0.12),
          blurRadius: 30,
          spreadRadius: -12,
        ),
      ],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 380 || widget.compact;
            final panelHeight = constraints.maxWidth < 345
                ? 296.0
                : compact
                    ? 282.0
                    : 294.0;
            final contentStart = constraints.maxWidth * (compact ? 0.47 : 0.49);
            return Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                height: panelHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: AppPalette.bgDepth),
                    RepaintBoundary(
                      child: Image.asset(
                        kArenaInviteAsset,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        cacheWidth: 1200,
                        errorBuilder: (_, __, ___) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppPalette.homePurple.withValues(alpha: 0.28),
                                AppPalette.homePanelDeep,
                              ],
                            ),
                          ),
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Icon(
                                Icons.card_giftcard_rounded,
                                color: AppPalette.gold,
                                size: 72,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              AppPalette.bgDepth.withValues(alpha: 0.16),
                              AppPalette.bgDepth.withValues(alpha: 0.88),
                              AppPalette.bgDepth.withValues(alpha: 0.97),
                            ],
                            stops: const [0.32, 0.48, 0.67, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: contentStart,
                      top: 0,
                      right: 0,
                      bottom: 0,
                      child: Directionality(
                        textDirection:
                            l10n.isAr ? TextDirection.rtl : TextDirection.ltr,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 8 : 12,
                            compact ? 14 : 16,
                            compact ? 12 : 16,
                            compact ? 12 : 15,
                          ),
                          child: _loading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : _loadError
                                  ? _InvitePanelError(onRetry: _load)
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: homeTitleFont(
                                            context,
                                            fontSize: compact ? 18 : 21,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: homeBodyFont(
                                            context,
                                            fontSize: compact ? 10.8 : 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppPalette.homeBody,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          l10n.yourInviteCode,
                                          style: safeInter(
                                            fontSize: compact ? 9.5 : 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppPalette.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        _InviteCodeBox(
                                            code: _code ?? '---------'),
                                        const SizedBox(height: 7),
                                        Text(
                                          l10n.inviteUsedByPlayers(_validCount),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: safeInter(
                                            fontSize: compact ? 10 : 11,
                                            fontWeight: FontWeight.w800,
                                            color: AppPalette.homeTitle
                                                .withValues(alpha: 0.88),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _MiniInviteButton(
                                                label: l10n.copyCode,
                                                icon: Icons.copy_rounded,
                                                onTap: _copy,
                                                color: AppPalette.homeGold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _MiniInviteButton(
                                                label: l10n.enterCodeShort,
                                                icon: Icons.login_rounded,
                                                onTap: widget.onEnterCode,
                                                color: AppPalette.homeCyan,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 7),
                                        Row(
                                          children: [
                                            missionCoinSmall(15),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                l10n.inviteRewardPerFriend,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: safeInter(
                                                  fontSize:
                                                      compact ? 10.2 : 11.2,
                                                  fontWeight: FontWeight.w900,
                                                  color:
                                                      AppPalette.goldHighlight,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget missionCoinSmall(double size) {
  return Image.asset(
    'assets/coin/COIN.webp',
    width: size,
    height: size,
    cacheWidth: (size * 3).round(),
    errorBuilder: (_, __, ___) => Icon(
      Icons.monetization_on_rounded,
      color: AppPalette.gold,
      size: size,
    ),
  );
}

class _InvitePanelError extends StatelessWidget {
  final VoidCallback onRetry;

  const _InvitePanelError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SizedBox(
      height: 156,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.inviteLoadFailedShort,
            style: safeInter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppPalette.homeTitle,
            ),
          ),
          const SizedBox(height: 10),
          _MiniInviteButton(
            label: l10n.retryBtn,
            icon: Icons.refresh_rounded,
            onTap: onRetry,
            color: AppPalette.homeCyan,
          ),
        ],
      ),
    );
  }
}

class _InviteCodeBox extends StatelessWidget {
  final String code;

  const _InviteCodeBox({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.homeGold.withValues(alpha: 0.18),
            AppPalette.homePanelDeep.withValues(alpha: 0.90),
          ],
        ),
        border: Border.all(
          color: AppPalette.homeGold.withValues(alpha: 0.54),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.homeGold.withValues(alpha: 0.16),
            blurRadius: 14,
            spreadRadius: -6,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          code,
          textDirection: TextDirection.ltr,
          style: safeOrbitron(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
            color: AppPalette.homeTitle,
            shadows: [
              Shadow(
                color: AppPalette.homeGold.withValues(alpha: 0.36),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInviteButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _MiniInviteButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withValues(alpha: 0.13),
          border: Border.all(color: color.withValues(alpha: 0.48)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.14),
              blurRadius: 13,
              spreadRadius: -6,
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                maxLines: 1,
                style: safeInter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
