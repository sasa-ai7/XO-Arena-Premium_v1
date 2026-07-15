import 'package:flutter/material.dart';

import '../core/app_theme.dart';

typedef StartupPageRouteBuilder = Route<void> Function(String routeName);

/// Short, premium, Flutter-built intro shown on EVERY cold launch.
///
/// The "X" glides in from the left, the "O" glides in from the right, then the
/// "ARENA" wordmark rises below — over a dark blue/purple stage with gently
/// drifting XO glyphs. It resolves the startup route in parallel and, once both
/// the ~2.2s animation and the route are ready, replaces itself with the target
/// (Home / Offline Setup). It never forces login and is never gated by a
/// "seen" flag, so it plays on every fresh open.
class IntroScreen extends StatefulWidget {
  final Future<String> startupRouteFuture;
  final StartupPageRouteBuilder startupRouteBuilder;

  const IntroScreen({
    super.key,
    required this.startupRouteFuture,
    required this.startupRouteBuilder,
  });

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bgFade;
  late final Animation<double> _xFade;
  late final Animation<Offset> _xSlide;
  late final Animation<double> _oFade;
  late final Animation<Offset> _oSlide;
  late final Animation<double> _arenaFade;
  late final Animation<Offset> _arenaSlide;
  late final Animation<double> _loaderFade;

  bool _didNavigate = false;
  bool _didFinishIntro = false;
  String? _resolvedRoute;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _bgFade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.0, 0.30, curve: Curves.easeOut));

    _xFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.05, 0.32, curve: Curves.easeOut));
    _xSlide = Tween<Offset>(begin: const Offset(-1.4, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.05, 0.42, curve: Curves.easeOutCubic)));

    _oFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.28, 0.55, curve: Curves.easeOut));
    _oSlide = Tween<Offset>(begin: const Offset(1.4, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.28, 0.64, curve: Curves.easeOutCubic)));

    _arenaFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.55, 0.82, curve: Curves.easeOut));
    _arenaSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.55, 0.86, curve: Curves.easeOutCubic)));

    _loaderFade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.80, 1.0, curve: Curves.easeOut));

    _resolveStartupRoute();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Warm the auth/setup assets while the intro plays so the next screen
      // paints instantly (no first-frame decode jank).
      precacheImage(const AssetImage('assets/xo.webp'), context,
          onError: (_, __) {});
      _runIntroSequence();
    });
  }

  Future<void> _runIntroSequence() async {
    await _ctrl.forward();
    if (!mounted) return;
    _didFinishIntro = true;
    _navigateIfReady();
  }

  Future<void> _resolveStartupRoute() async {
    String next = '/offlineSetup';
    try {
      next = await widget.startupRouteFuture;
    } catch (error) {
      debugPrint('[IntroScreen] startup route resolution failed: $error');
    }
    if (!mounted) return;
    _resolvedRoute = next;
    _navigateIfReady();
  }

  void _navigateIfReady() {
    if (_didNavigate ||
        !_didFinishIntro ||
        !mounted ||
        _resolvedRoute == null) {
      return;
    }
    _didNavigate = true;
    Navigator.of(context).pushAndRemoveUntil(
      widget.startupRouteBuilder(_resolvedRoute!),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bgDepth,
      body: Stack(
        children: [
          // Static dark neon base — built once, const, cheap.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppPalette.homeBgBase,
                    AppPalette.homeBgSecondary,
                    AppPalette.bgDepth,
                  ],
                ),
              ),
            ),
          ),
          // Soft central glow for depth (static).
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.12),
                    radius: 0.95,
                    colors: [
                      AppPalette.homeBlue.withValues(alpha: 0.14),
                      AppPalette.homePurple.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Gently drifting XO glyphs — isolated in its own RepaintBoundary so
          // only this layer repaints as the drift value changes.
          Positioned.fill(
            child: RepaintBoundary(
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: _bgFade,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) => CustomPaint(
                      size: Size.infinite,
                      painter: _DriftingXOPainter(progress: _ctrl.value),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Foreground X · O · ARENA. Each piece is driven by its own
          // transition, so the static painters never rebuild.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SlideTransition(
                        position: _xSlide,
                        child: FadeTransition(
                          opacity: _xFade,
                          child: const SizedBox(
                            width: 118,
                            height: 118,
                            child: CustomPaint(
                              painter: _GlowXPainter(color: AppPalette.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SlideTransition(
                        position: _oSlide,
                        child: FadeTransition(
                          opacity: _oFade,
                          child: const SizedBox(
                            width: 118,
                            height: 118,
                            child: CustomPaint(
                              painter:
                                  _GlowOPainter(color: AppPalette.accentPurple),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SlideTransition(
                  position: _arenaSlide,
                  child: FadeTransition(
                    opacity: _arenaFade,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('ARENA', style: brandFont(context, fontSize: 44)),
                        const SizedBox(height: 8),
                        Text(
                          'PREMIUM CYBER BATTLES',
                          style: homeLabelFont(
                            context,
                            fontSize: 10,
                            color: AppPalette.goldHighlight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Minimal loading hint near the bottom, fades in at the end.
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: FadeTransition(
              opacity: _loaderFade,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppPalette.homeCyan),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faint, drifting XO glyphs for the intro backdrop. Plain low-opacity strokes
/// (NO mask-filter blur) so a full field of them stays cheap to paint.
class _DriftingXOPainter extends CustomPainter {
  final double progress;
  const _DriftingXOPainter({required this.progress});

  static const List<_Glyph> _glyphs = <_Glyph>[
    _Glyph(0.12, 0.14, true, 26),
    _Glyph(0.82, 0.10, false, 30),
    _Glyph(0.20, 0.40, false, 22),
    _Glyph(0.90, 0.44, true, 24),
    _Glyph(0.08, 0.66, true, 28),
    _Glyph(0.72, 0.70, false, 26),
    _Glyph(0.30, 0.86, false, 24),
    _Glyph(0.60, 0.22, true, 18),
    _Glyph(0.50, 0.56, false, 16),
    _Glyph(0.16, 0.90, true, 20),
    _Glyph(0.88, 0.86, true, 22),
    _Glyph(0.40, 0.06, false, 20),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final drift = progress * 14.0; // gentle motion over the intro
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final g in _glyphs) {
      final cx = g.fx * size.width + (g.isX ? drift : -drift) * 0.4;
      final cy = g.fy * size.height + drift;
      final r = g.size / 2;
      paint.color = (g.isX ? AppPalette.homeCyan : AppPalette.homePurple)
          .withValues(alpha: 0.10);
      if (g.isX) {
        canvas.drawLine(Offset(cx - r, cy - r), Offset(cx + r, cy + r), paint);
        canvas.drawLine(Offset(cx + r, cy - r), Offset(cx - r, cy + r), paint);
      } else {
        canvas.drawCircle(Offset(cx, cy), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DriftingXOPainter old) =>
      old.progress != progress;
}

class _Glyph {
  final double fx;
  final double fy;
  final bool isX;
  final double size;
  const _Glyph(this.fx, this.fy, this.isX, this.size);
}

class _GlowXPainter extends CustomPainter {
  final Color color;
  const _GlowXPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.width * 0.15;
    final p1 = Offset(pad, pad);
    final p2 = Offset(size.width - pad, size.height - pad);
    final p3 = Offset(size.width - pad, pad);
    final p4 = Offset(pad, size.height - pad);

    final glow = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawLine(p1, p2, glow);
    canvas.drawLine(p3, p4, glow);

    final main = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, main);
    canvas.drawLine(p3, p4, main);
  }

  @override
  bool shouldRepaint(covariant _GlowXPainter old) => old.color != color;
}

class _GlowOPainter extends CustomPainter {
  final Color color;
  const _GlowOPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = 20
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color
          ..strokeWidth = 8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _GlowOPainter old) => old.color != color;
}
