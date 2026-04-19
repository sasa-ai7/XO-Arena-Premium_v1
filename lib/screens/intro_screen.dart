import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../widgets/app_ui.dart';

typedef StartupPageRouteBuilder = Route<void> Function(String routeName);

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
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _xFade;
  late Animation<double> _oFade;
  late Animation<double> _arenaFade;
  late Animation<Offset> _arenaSlide;
  late Animation<double> _loaderFade;
  late Animation<double> _transitionGlow;
  bool _didNavigate = false;
  bool _isAwaitingStartup = false;
  bool _didFinishIntro = false;
  bool _isRouting = false;
  String? _resolvedRoute;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _xFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.27, curve: Curves.easeOut)));

    _oFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.27, 0.53, curve: Curves.easeOut)));

    _arenaFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.53, 0.80, curve: Curves.easeOut)));

    _arenaSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.53, 0.80, curve: Curves.easeOut)));

    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOut)));

    _transitionGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.72, 1.0, curve: Curves.easeOut)));

    _ctrl.addListener(_handleAnimationTick);
    _resolveStartupRoute();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runIntroSequence();
    });
  }

  void _handleAnimationTick() {
    if (_isAwaitingStartup || !mounted || _ctrl.value < 0.76) return;
    setState(() => _isAwaitingStartup = true);
  }

  Future<void> _runIntroSequence() async {
    await _ctrl.forward();
    if (!mounted || _didNavigate) return;
    _didFinishIntro = true;
    if (!_isAwaitingStartup) {
      setState(() => _isAwaitingStartup = true);
    }
    await _navigateIfReady();
  }

  Future<void> _resolveStartupRoute() async {
    String nextRoute = '/login';
    try {
      nextRoute = await widget.startupRouteFuture;
    } catch (error) {
      debugPrint('[IntroScreen] Startup route resolution failed: $error');
    }

    if (!mounted || _didNavigate) return;
    setState(() => _resolvedRoute = nextRoute);
    await _navigateIfReady();
  }

  Future<void> _navigateIfReady() async {
    final nextRoute = _resolvedRoute;
    if (_didNavigate || !_didFinishIntro || !mounted || nextRoute == null) {
      return;
    }

    _didNavigate = true;
    setState(() => _isRouting = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      widget.startupRouteBuilder(nextRoute),
      (_) => false,
    );
  }

  String _statusMessage() {
    if (_isRouting) {
      return _resolvedRoute == '/home'
          ? 'Opening your arena hub'
          : 'Opening sign in';
    }
    if (_resolvedRoute != null) {
      return 'Destination ready. Starting transition';
    }
    if (_isAwaitingStartup) {
      return 'Syncing session and loading destination';
    }
    return 'Preparing startup systems';
  }

  @override
  void dispose() {
    _ctrl.removeListener(_handleAnimationTick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bgDepth,
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.22,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _ArenaGridPainter(),
                      ),
                    ),
                  ),
                ),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  alignment: _ctrl.value > 0.0
                      ? const Alignment(-0.55, -0.05)
                      : const Alignment(-3.0, -0.05),
                  child: FadeTransition(
                    opacity: _xFade,
                    child: const SizedBox(
                      width: 100,
                      height: 100,
                      child: CustomPaint(
                        painter: _GlowXPainter(color: AppPalette.primary),
                      ),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _ctrl.value > 0.38 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Align(
                    alignment: const Alignment(0, -0.05),
                    child: Container(
                      width: 1.5,
                      height: 68,
                      color: AppPalette.homeStrokeStrong.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  alignment: _ctrl.value > 0.27
                      ? const Alignment(0.55, -0.05)
                      : const Alignment(3.0, -0.05),
                  child: FadeTransition(
                    opacity: _oFade,
                    child: const SizedBox(
                      width: 100,
                      height: 100,
                      child: CustomPaint(
                        painter: _GlowOPainter(color: AppPalette.accentPurple),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 0.30),
                  child: SlideTransition(
                    position: _arenaSlide,
                    child: FadeTransition(
                      opacity: _arenaFade,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'XO ARENA',
                            style: brandFont(context, fontSize: 40),
                          ),
                          const SizedBox(height: 12),
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
                ),
                IgnorePointer(
                  child: FadeTransition(
                    opacity: _transitionGlow,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.08),
                          radius: 1.0,
                          colors: [
                            AppPalette.homeCyan.withValues(alpha: 0.16),
                            AppPalette.homePurple.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _isRouting ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppPalette.homeCyan.withValues(alpha: 0.08),
                            AppPalette.homePurple.withValues(alpha: 0.12),
                            AppPalette.homeBlue.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 0.76),
                  child: FadeTransition(
                    opacity: _loaderFade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppPalette.homePanelStrong.withValues(alpha: 0.92),
                            AppPalette.homePanel.withValues(alpha: 0.88),
                          ],
                        ),
                        border: Border.all(
                          color: AppPalette.homeStrokeStrong
                              .withValues(alpha: 0.34),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppPalette.homeCyan,
                              ),
                              backgroundColor:
                                  AppPalette.homeStroke.withValues(alpha: 0.22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ENTERING XO ARENA',
                                style: homeLabelFont(
                                  context,
                                  fontSize: 9,
                                  color: AppPalette.goldHighlight,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _statusMessage(),
                                style: homeBodyFont(
                                  context,
                                  fontSize: 11,
                                  color: AppPalette.homeBody,
                                  fontWeight: FontWeight.w600,
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
            );
          },
        ),
      ),
    );
  }
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
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawLine(p1, p2, glow);
    canvas.drawLine(p3, p4, glow);

    final main = Paint()
      ..color = color
      ..strokeWidth = 7
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
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _GlowOPainter old) => old.color != color;
}

class _ArenaGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppPalette.primary.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;

    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final accent = Paint()
      ..color = AppPalette.primary.withValues(alpha: 0.16)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(24, 60), const Offset(24, 90), accent);
    canvas.drawLine(const Offset(24, 60), const Offset(54, 60), accent);
    canvas.drawLine(
        Offset(size.width - 24, 60), Offset(size.width - 24, 90), accent);
    canvas.drawLine(
        Offset(size.width - 24, 60), Offset(size.width - 54, 60), accent);
  }

  @override
  bool shouldRepaint(_) => false;
}
