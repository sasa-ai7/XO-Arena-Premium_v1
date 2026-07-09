import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_l10n.dart';
import '../../../core/app_theme.dart';
import '../../../models/game_avatar.dart';
import '../../../widgets/full_avatar_display.dart';

/// Full-screen overlay shown after each round resolves.
///
/// Shows the round winner's avatar + name + updated score, then either:
///   • auto-advances to the next round after [autoAdvanceDelay] (default 3 s)
///   • shows a "Next Round" button the user can tap early
///
/// When [isFinalRound] is true the layout switches to a premium match-result
/// variant with a larger trophy icon, final score, and optional coin delta.
///
/// Dismiss by tapping the button or waiting for the countdown.
class RoundResultOverlay extends StatefulWidget {
  /// Uid of the round winner. Null means draw (round replayed).
  final String? winnerUid;
  final String winnerName;
  final GameAvatar? winnerAvatar;
  final String? winnerPhotoUrl;

  /// Updated scores after this round.
  final int scoreHost;
  final int scoreGuest;

  /// Which round just finished (1-based).
  final int roundNumber;
  final int totalRounds;

  /// True when this is the final match result (not just a round).
  final bool isFinalRound;

  /// Coins won by the local player (shown only on final round + bet enabled).
  final int coinsWon;

  /// Called when the overlay should be dismissed (user tapped or timer fired).
  final VoidCallback onDismiss;

  final Duration autoAdvanceDelay;

  const RoundResultOverlay({
    super.key,
    required this.winnerUid,
    required this.winnerName,
    required this.winnerAvatar,
    this.winnerPhotoUrl,
    required this.scoreHost,
    required this.scoreGuest,
    required this.roundNumber,
    required this.totalRounds,
    required this.isFinalRound,
    required this.coinsWon,
    required this.onDismiss,
    this.autoAdvanceDelay = const Duration(seconds: 3),
  });

  @override
  State<RoundResultOverlay> createState() => _RoundResultOverlayState();
}

class _RoundResultOverlayState extends State<RoundResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  Timer? _autoTimer;
  int _countdown = 3;
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    _countdown = widget.autoAdvanceDelay.inSeconds.clamp(1, 9);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    _autoTimer = Timer(widget.autoAdvanceDelay, _dismiss);
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdown = (_countdown - 1).clamp(0, 9);
      });
    });
  }

  Future<void> _dismiss() async {
    _autoTimer?.cancel();
    _countdownTicker?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _countdownTicker?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isDraw = widget.winnerUid == null;

    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        alignment: Alignment.center,
        child: ScaleTransition(
          scale: _scale,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: AppPalette.panel,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDraw
                      ? AppPalette.primary.withValues(alpha: 0.55)
                      : widget.isFinalRound
                          ? AppPalette.gold.withValues(alpha: 0.7)
                          : AppPalette.success.withValues(alpha: 0.65),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDraw
                            ? AppPalette.primary
                            : widget.isFinalRound
                                ? AppPalette.gold
                                : AppPalette.success)
                        .withValues(alpha: 0.30),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Round / Match label ──────────────────────────────
                  _buildLabel(l10n, isDraw),
                  const SizedBox(height: 20),

                  // ── Winner avatar ────────────────────────────────────
                  if (!isDraw) _buildWinnerAvatar(),
                  if (isDraw) _buildDrawIcon(),
                  const SizedBox(height: 16),

                  // ── Winner name / draw text ──────────────────────────
                  _buildResultText(l10n, isDraw),
                  const SizedBox(height: 18),

                  // ── Score ────────────────────────────────────────────
                  _buildScore(),
                  const SizedBox(height: 8),

                  // ── Coins won (final round only) ─────────────────────
                  if (widget.isFinalRound && widget.coinsWon > 0)
                    _buildCoinsWon(l10n),

                  const SizedBox(height: 22),

                  // ── Action button ────────────────────────────────────
                  _buildButton(l10n, isDraw),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(AppL10n l10n, bool isDraw) {
    final String label;
    final Color color;
    if (widget.isFinalRound) {
      label = isDraw
          ? (l10n.isAr ? 'نتيجة المباراة' : 'MATCH RESULT')
          : (l10n.isAr ? 'نهاية المباراة' : 'MATCH OVER');
      color = AppPalette.gold;
    } else {
      label = isDraw
          ? (l10n.isAr ? 'تعادل — إعادة الجولة' : 'DRAW — REPLAY')
          : '${l10n.currentRoundLabel} ${widget.roundNumber} ${l10n.isAr ? "انتهت" : "OVER"}';
      color = isDraw ? AppPalette.primary : AppPalette.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.2,
          fontFamily: 'Orbitron',
        ),
      ),
    );
  }

  Widget _buildWinnerAvatar() {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CompositeAvatar(
            size: 88,
            assetPath: widget.winnerAvatar?.assetPath,
            photoUrl: widget.winnerPhotoUrl,
            fallbackName: widget.winnerName.isNotEmpty
                ? widget.winnerName.substring(0, 1).toUpperCase()
                : 'P',
            profileSizeRatio: widget.winnerAvatar?.previewScale ?? 0.80,
            frameScale: widget.winnerAvatar?.frameScale ?? 1.0,
            verticalOffset: widget.winnerAvatar?.verticalOffset ?? 0.0,
            innerCircleScale: widget.winnerAvatar?.innerCircleScale ?? 1.0,
          ),
          // Crown / trophy badge
          Positioned(
            top: -10,
            right: -10,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppPalette.gold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.gold.withValues(alpha: 0.55),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppPalette.primary.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.30),
            blurRadius: 22,
          ),
        ],
      ),
      child: const Icon(
        Icons.handshake_rounded,
        color: AppPalette.primary,
        size: 38,
      ),
    );
  }

  Widget _buildResultText(AppL10n l10n, bool isDraw) {
    if (isDraw) {
      return Text(
        l10n.drawReplayRound,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppPalette.primary,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      );
    }
    return Column(
      children: [
        Text(
          widget.winnerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppPalette.text,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.isFinalRound
              ? (l10n.isAr ? 'فاز بالمباراة!' : 'Wins the Match!')
              : (l10n.isAr ? 'فاز بالجولة!' : 'Wins the Round!'),
          style: TextStyle(
            color: widget.isFinalRound ? AppPalette.gold : AppPalette.success,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildScore() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _scoreBox(widget.scoreHost),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '—',
            style: const TextStyle(
              color: AppPalette.textSubtle,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _scoreBox(widget.scoreGuest),
      ],
    );
  }

  Widget _scoreBox(int score) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.panelDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.strokeStrong, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.12),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        '$score',
        style: const TextStyle(
          color: AppPalette.text,
          fontWeight: FontWeight.w900,
          fontSize: 26,
          fontFamily: 'Orbitron',
        ),
      ),
    );
  }

  Widget _buildCoinsWon(AppL10n l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppPalette.gold.withValues(alpha: 0.28),
              AppPalette.gold.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppPalette.gold.withValues(alpha: 0.65),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppPalette.gold.withValues(alpha: 0.30),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/coin/COIN-3.png',
              width: 26,
              height: 26,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.monetization_on,
                color: AppPalette.gold,
                size: 26,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${widget.coinsWon}',
              style: const TextStyle(
                color: AppPalette.gold,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontFamily: 'Orbitron',
              ),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.coinsWord,
              style: const TextStyle(
                color: AppPalette.gold,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(AppL10n l10n, bool isDraw) {
    final bool isFinal = widget.isFinalRound;
    final String label = isFinal
        ? (l10n.isAr ? 'متابعة' : 'Continue')
        : isDraw
            ? (l10n.isAr ? 'إعادة الجولة ($_countdown)' : 'Replay Round ($_countdown)')
            : (l10n.isAr
                ? 'الجولة التالية ($_countdown)'
                : 'Next Round ($_countdown)');
    final Color btnColor = isFinal
        ? AppPalette.gold
        : isDraw
            ? AppPalette.primary
            : AppPalette.success;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _dismiss,
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor.withValues(alpha: 0.22),
          foregroundColor: btnColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: btnColor.withValues(alpha: 0.65), width: 1.4),
          ),
          shadowColor: btnColor.withValues(alpha: 0.35),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: btnColor,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            fontFamily: 'Orbitron',
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
