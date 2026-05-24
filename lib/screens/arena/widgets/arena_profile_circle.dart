import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Compact neon-ringed profile circle for the Arena lobby and game screens.
///
/// Shows the player's profile photo (or first-letter fallback) and nothing
/// else — purchased game avatars are intentionally NOT rendered here. The
/// in-game lobby/match should always identify the *person* in front of the
/// device. Equipped X/O cosmetic skins live in their own preview widget
/// alongside this circle.
class ArenaProfileCircle extends StatelessWidget {
  final String name;
  final String? photoUrl;

  /// Outer diameter of the circle. Inner photo is 4px smaller (2px gradient
  /// ring on each side).
  final double size;

  /// Colors for the gradient ring. Defaults to a cool cyan→purple ring; pass
  /// a warmer green ring for the local player's card.
  final List<Color>? ringColors;

  const ArenaProfileCircle({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 76,
    this.ringColors,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ringColors ??
        const <Color>[AppPalette.primary, AppPalette.accentPurple];
    final initial = _initialOf(name);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 18,
          ),
        ],
      ),
      child: ClipOval(
        child: (photoUrl != null && photoUrl!.isNotEmpty)
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                // Don't flash black while the image is downloading — show
                // the initial-letter fallback in the panel color until
                // the first decoded frame is ready.
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return _InitialFallback(initial: initial, size: size);
                },
                errorBuilder: (_, __, ___) =>
                    _InitialFallback(initial: initial, size: size),
              )
            : _InitialFallback(initial: initial, size: size),
      ),
    );
  }

  static String _initialOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

class _InitialFallback extends StatelessWidget {
  final String initial;
  final double size;

  const _InitialFallback({required this.initial, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppPalette.panelDeep,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: AppPalette.text,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
