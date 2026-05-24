import 'package:flutter/material.dart';

import '../../../core/app_l10n.dart';
import '../../../core/app_theme.dart';
import '../../../models/game_avatar.dart';
import '../../../services/local_store.dart';
import '../../../widgets/full_avatar_display.dart';
import 'arena_profile_circle.dart';
import 'arena_skin_preview.dart';

/// Premium player card used in the arena match header.
///
/// Layout (Column, top to bottom):
///   1. Top row — profile circle / equipped avatar frame + name + score.
///   2. "YOUR MARK" / "OPP MARK" label.
///   3. Equipped X/O cosmetic skin preview.
///
/// When the player has a paid [GameAvatar] equipped, the main circle shows
/// the user's profile photo composited inside the avatar frame (matching
/// the Store / Profile / Lobby rendering). Otherwise it falls back to a
/// neon-ringed profile circle so the screen always identifies the person.
///
/// When [isActiveTurn] is true the card pulses a green / purple glow so the
/// active player is obvious at a glance.
///
/// Use [ArenaPlayerCard.self] for the local user — the profile photo binds
/// to the live `LocalStore.profilePhotoUrlNotifier` so it updates if the
/// user changes their photo mid-match. [ArenaPlayerCard.opponent] takes a
/// static `photoUrl` plucked from `room.players[uid].photoURL`.
class ArenaPlayerCard extends StatelessWidget {
  /// "X" or "O" — empty string when the symbol slot is still pending.
  final String symbol;
  final String name;
  final int score;
  final bool isActiveTurn;
  final bool isYou;

  /// Equipped X skin (e.g. "x12"); null/"default" → premium fallback letter.
  final String? xSkin;

  /// Equipped O skin; null/"default" → premium fallback letter.
  final String? oSkin;

  /// Equipped paid avatar frame. Null → render the neon-ringed profile
  /// circle fallback (so accounts with no paid avatar still look polished).
  final GameAvatar? avatar;

  /// Either an explicit photoUrl (for opponents) or null to bind to the
  /// local `profilePhotoUrlNotifier` (for self).
  final String? photoUrl;
  final bool useBoundNotifiers;

  const ArenaPlayerCard._({
    required this.symbol,
    required this.name,
    required this.score,
    required this.isActiveTurn,
    required this.isYou,
    required this.avatar,
    required this.photoUrl,
    required this.useBoundNotifiers,
    required this.xSkin,
    required this.oSkin,
  });

  factory ArenaPlayerCard.self({
    required String symbol,
    required String name,
    required int score,
    required bool isActiveTurn,
    GameAvatar? avatar,
    String? xSkin,
    String? oSkin,
  }) =>
      ArenaPlayerCard._(
        symbol: symbol,
        name: name,
        score: score,
        isActiveTurn: isActiveTurn,
        isYou: true,
        avatar: avatar,
        photoUrl: null,
        useBoundNotifiers: true,
        xSkin: xSkin,
        oSkin: oSkin,
      );

  factory ArenaPlayerCard.opponent({
    required String symbol,
    required String name,
    required int score,
    required bool isActiveTurn,
    GameAvatar? avatar,
    String? photoUrl,
    String? xSkin,
    String? oSkin,
  }) =>
      ArenaPlayerCard._(
        symbol: symbol,
        name: name,
        score: score,
        isActiveTurn: isActiveTurn,
        isYou: false,
        avatar: avatar,
        photoUrl: photoUrl,
        useBoundNotifiers: false,
        xSkin: xSkin,
        oSkin: oSkin,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final glowColor = isYou ? AppPalette.success : AppPalette.accentPurple;
    final scoreColor = isYou ? AppPalette.primary : AppPalette.accentPurple;
    final borderColor = isActiveTurn
        ? glowColor
        : glowColor.withValues(alpha: 0.4);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppPalette.panel,
            AppPalette.panelDeep,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: isActiveTurn ? 1.6 : 1.0,
        ),
        boxShadow: [
          if (isActiveTurn)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: glowColor.withValues(alpha: 0.12),
              blurRadius: 12,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopRow(
            name: name,
            score: score,
            isYou: isYou,
            scoreColor: scoreColor,
            useBoundNotifiers: useBoundNotifiers,
            photoUrl: photoUrl,
            avatar: avatar,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              isYou ? l10n.yourMarkLabel : l10n.oppMarkLabel,
              style: TextStyle(
                color: AppPalette.text.withValues(alpha: 0.55),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: ArenaSkinPreview(
              symbol: symbol,
              xSkin: xSkin,
              oSkin: oSkin,
              size: 46,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  final String name;
  final int score;
  final bool isYou;
  final Color scoreColor;
  final bool useBoundNotifiers;
  final String? photoUrl;
  final GameAvatar? avatar;

  const _TopRow({
    required this.name,
    required this.score,
    required this.isYou,
    required this.scoreColor,
    required this.useBoundNotifiers,
    required this.photoUrl,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    const double avatarSize = 52;
    final ringColors = isYou
        ? const <Color>[AppPalette.success, AppPalette.primary]
        : const <Color>[AppPalette.accentPurple, AppPalette.primary];

    Widget circle;
    if (avatar != null) {
      // Paid avatar equipped → render full frame (photo composited inside).
      // Self uses bound notifiers via FullAvatarDisplay; opponent passes a
      // static photoUrl through CompositeAvatar directly.
      if (useBoundNotifiers) {
        circle = SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: FullAvatarDisplay(
            size: avatarSize,
            avatar: avatar,
            fallbackName: name,
          ),
        );
      } else {
        circle = SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: CompositeAvatar(
            assetPath: avatar!.assetPath,
            photoUrl: photoUrl,
            size: avatarSize,
            fallbackName: name,
            profileSizeRatio: avatar!.previewScale,
            frameScale: avatar!.frameScale,
            verticalOffset: avatar!.verticalOffset,
            innerCircleScale: avatar!.innerCircleScale,
          ),
        );
      }
    } else if (useBoundNotifiers) {
      circle = ValueListenableBuilder<String?>(
        valueListenable: LocalStore.profilePhotoUrlNotifier,
        builder: (_, photo, __) => ArenaProfileCircle(
          name: name,
          photoUrl: photo,
          size: avatarSize,
          ringColors: ringColors,
        ),
      );
    } else {
      circle = ArenaProfileCircle(
        name: name,
        photoUrl: photoUrl,
        size: avatarSize,
        ringColors: ringColors,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        circle,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  if (isYou) ...[
                    const SizedBox(width: 6),
                    _YouTag(color: AppPalette.success, label: l10n.youTag),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$score',
                  maxLines: 1,
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    fontFamily: 'Orbitron',
                    shadows: [
                      Shadow(
                        color: scoreColor.withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _YouTag extends StatelessWidget {
  final Color color;
  final String label;
  const _YouTag({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 9,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
