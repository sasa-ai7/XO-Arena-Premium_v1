import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Compact, energetic crimson **VS** badge shown between the two lobby player
/// cards so they visually face off. Driven by a single repeating
/// [AnimationController] for an idle scale pulse, a crimson glow "breathing",
/// and a subtle rotating light sweep, plus a one-shot scale-in entrance.
///
/// Low cost: one controller, no image assets, no per-frame allocations beyond
/// trivial math. Honors OS reduced-motion: when
/// `MediaQuery.disableAnimations` is true it renders a static crimson badge.
class ArenaVsBadge extends StatefulWidget {
  final double size;
  const ArenaVsBadge({super.key, this.size = 46});

  @override
  State<ArenaVsBadge> createState() => _ArenaVsBadgeState();
}

class _ArenaVsBadgeState extends State<ArenaVsBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      // Static crimson badge — no animation, no controller-driven rebuilds.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _VsCore(size: widget.size, glow: 0.5, pulse: 1.0, sweep: 0),
      );
    }

    final animated = AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value; // 0..1
        final wave = math.sin(t * 2 * math.pi);
        // Breathing pulse (0.95..1.05) and glow breathing (0.42..0.78).
        final pulse = 1.0 + 0.05 * wave;
        final glow = 0.60 + 0.18 * wave;
        final sweep = t * 2 * math.pi;
        return _VsCore(
          size: widget.size,
          glow: glow,
          pulse: pulse,
          sweep: sweep,
        );
      },
    );

    // One-shot scale-in entrance when the lobby opens.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(
          scale: v.clamp(0.0, 1.2),
          child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
        ),
        child: animated,
      ),
    );
  }
}

class _VsCore extends StatelessWidget {
  final double size;

  /// Glow alpha (0..1) for the layered crimson shadows.
  final double glow;

  /// Scale multiplier for the idle breathing pulse.
  final double pulse;

  /// Light-sweep rotation in radians.
  final double sweep;

  const _VsCore({
    required this.size,
    required this.glow,
    required this.pulse,
    required this.sweep,
  });

  @override
  Widget build(BuildContext context) {
    const crimson = AppPalette.danger; // 0xFFFF5E6A
    const hot = Color(0xFFFF2D4B);
    const deep = Color(0xFF8A0F22);
    return Transform.scale(
      scale: pulse,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [hot, crimson, deep],
            stops: [0.0, 0.55, 1.0],
            center: Alignment(-0.2, -0.3),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: crimson.withValues(alpha: glow),
              blurRadius: 22,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: hot.withValues(alpha: glow * 0.55),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle rotating light sweep across the plate.
              Transform.rotate(
                angle: sweep,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.30),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.10, 0.26],
                    ),
                  ),
                ),
              ),
              Text(
                'VS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  fontFamily: 'Orbitron',
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
