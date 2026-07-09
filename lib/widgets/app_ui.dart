import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/coin_format.dart';
import '../core/app_theme.dart';

/// ==========================
///   REUSABLE UI
/// ==========================
enum AppBackgroundVariant { defaultTheme, homeNeon }

enum CoinPillVariant { defaultTheme, homeNeon }

/// The animated "XO ARENA" logo backed by `assets/xo.webp`.
///
/// Flutter decodes animated WebP natively and loops it forever via its
/// multi-frame image stream, so the badge keeps animating on its own.
/// [gaplessPlayback] keeps the last frame painted during any reload so it
/// never blinks out, and [cacheHeight] down-samples the source so decoding
/// stays memory-safe. If the animated asset ever fails, the static
/// `assets/xo.png` is shown (then a neutral icon) so the logo is never blank.
///
/// Reused by the startup gate, the login screen and the offline setup screen
/// so the branded logo is identical everywhere.
class ArenaLogo extends StatelessWidget {
  final double height;
  const ArenaLogo({super.key, this.height = 170});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cache = (height * dpr).clamp(160.0, 1400.0).round();
    return Image.asset(
      'assets/xo.webp',
      height: height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      cacheHeight: cache,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/xo.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.grid_3x3_rounded,
          size: height * 0.6,
          color: AppPalette.primary,
        ),
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  final Widget child;
  final AppBackgroundVariant variant;

  const AppBackground({
    super.key,
    required this.child,
    this.variant = AppBackgroundVariant.defaultTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (variant == AppBackgroundVariant.homeNeon) {
      return DecoratedBox(
        decoration: const BoxDecoration(
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
        child: Stack(
          children: [
            // Static background layers cached in RepaintBoundary to reduce GPU ops
            RepaintBoundary(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.34,
                        child: CustomPaint(
                          painter: _AmbientGridPainter(
                            lineColor: AppPalette.homeCyan.withOpacity(0.035),
                            dotColor: AppPalette.homeSky.withOpacity(0.13),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.35),
                          radius: 1.3,
                          colors: [
                            AppPalette.homeBlue.withOpacity(0.08),
                            AppPalette.homePurple.withOpacity(0.03),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.02),
                              Colors.transparent,
                              Colors.black.withOpacity(0.12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Dynamic glow layers rendered on top
            Positioned(
              top: -170,
              left: -120,
              child: _BackgroundGlow(
                size: 420,
                colors: [
                  AppPalette.homeCyan.withOpacity(0.16),
                  AppPalette.homeSky.withOpacity(0.07),
                  Colors.transparent,
                ],
              ),
            ),
            Positioned(
              top: -110,
              right: -120,
              child: _BackgroundGlow(
                size: 320,
                colors: [
                  AppPalette.homePurple.withOpacity(0.14),
                  AppPalette.homePink.withOpacity(0.06),
                  Colors.transparent,
                ],
              ),
            ),
            Positioned(
              bottom: -210,
              left: -120,
              child: _BackgroundGlow(
                size: 390,
                colors: [
                  AppPalette.homeBlue.withOpacity(0.16),
                  AppPalette.homeCyan.withOpacity(0.06),
                  Colors.transparent,
                ],
              ),
            ),
            Positioned(
              bottom: -180,
              right: -140,
              child: _BackgroundGlow(
                size: 360,
                colors: [
                  AppPalette.gold.withOpacity(0.07),
                  AppPalette.homeSky.withOpacity(0.03),
                  Colors.transparent,
                ],
              ),
            ),
            child,
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.bgTop, AppPalette.bgBottom, AppPalette.bgDepth],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -150,
            left: -110,
            child: _BackgroundGlow(
              size: 360,
              colors: [
                AppPalette.primary.withValues(alpha: 0.14),
                AppPalette.primary2.withValues(alpha: 0.06),
                Colors.transparent,
              ],
            ),
          ),
          Positioned(
            top: 80,
            right: -120,
            child: _BackgroundGlow(
              size: 300,
              colors: [
                AppPalette.accentPurple.withValues(alpha: 0.10),
                AppPalette.accentPurple.withValues(alpha: 0.035),
                Colors.transparent,
              ],
            ),
          ),
          Positioned(
            bottom: -150,
            right: -120,
            child: _BackgroundGlow(
              size: 400,
              colors: [
                AppPalette.primary2.withValues(alpha: 0.09),
                AppPalette.gold.withValues(alpha: 0.04),
                Colors.transparent,
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.22,
                child: CustomPaint(
                  painter: _AmbientGridPainter(
                    lineColor: AppPalette.primary.withValues(alpha: 0.035),
                    dotColor: AppPalette.primary2.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.02),
                      Colors.transparent,
                      Colors.black.withOpacity(0.12),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Full-screen auth background built around the `XO-BACK.png` artwork.
///
/// Used by the Login and Create Account screens. The `XO-BACK.png` scene (which
/// already contains the XO Arena hero logo at the top and an empty neon stage at
/// the bottom) IS the whole page background — there is no separate Flutter
/// decoration, glow panel, or blur layer behind the form. The image fills the
/// entire screen with `BoxFit.cover`, anchored to the top so the hero logo stays
/// visible on any aspect ratio. A single, continuous dark gradient (transparent
/// across the hero, easing to a strong dark tint at the very bottom) is the only
/// overlay — just enough to keep a bottom-anchored form readable over the stage,
/// with no hard band so the top and bottom read as one cohesive screen.
class AuthImageBackground extends StatelessWidget {
  final Widget child;

  const AuthImageBackground({
    super.key,
    required this.child,
  });

  static const String backgroundAsset = 'assets/XO-BACK.png';

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Down-sample the 941×1672 source to the device pixel width so decode and
    // memory stay light — it is only ever shown full-bleed.
    final cacheW = (mq.size.width * mq.devicePixelRatio).round();
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) The XO-BACK.png scene — the single, unified visual base for the
        //    whole page. Anchored to the top so the baked-in hero logo is
        //    preserved when `cover` crops on very tall/short screens.
        Image.asset(
          backgroundAsset,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          cacheWidth: cacheW,
          errorBuilder: (context, error, stackTrace) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppPalette.homeBgBase, AppPalette.bgDepth],
              ),
            ),
          ),
        ),
        // 2) One continuous readability gradient — NO blur, NO frosted fog band.
        //    Fully transparent across the hero area, then eases into a darker
        //    tint toward the bottom where the form sits. A single smooth ramp
        //    means there is no hard edge / "two screens" break.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    AppPalette.bgDepth.withOpacity(0.30),
                    AppPalette.bgDepth.withOpacity(0.68),
                    AppPalette.bgDepth.withOpacity(0.90),
                  ],
                  stops: const [0.0, 0.40, 0.62, 0.82, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 3) Foreground content (forms, buttons, etc.).
        child,
      ],
    );
  }
}

class AppGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final List<BoxShadow>? boxShadow;

  const AppGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1.2,
    this.radius = AppPalette.radius,
    this.boxShadow,
  });

  static final List<BoxShadow> _defaultShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.34),
      blurRadius: 28,
      offset: const Offset(0, 18),
    ),
    BoxShadow(
      color: AppPalette.primary.withValues(alpha: 0.08),
      blurRadius: 24,
      spreadRadius: -8,
    ),
    BoxShadow(
      color: AppPalette.accentPurple.withValues(alpha: 0.04),
      blurRadius: 30,
      spreadRadius: -12,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color:
            gradient == null ? backgroundColor ?? AppPalette.homePanel : null,
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (backgroundColor ?? AppPalette.homePanelStrong)
                    .withValues(alpha: 0.98),
                AppPalette.panelDeep.withValues(alpha: 0.97),
              ],
            ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppPalette.stroke,
          width: borderWidth,
        ),
        boxShadow: boxShadow ?? _defaultShadow,
      ),
      child: child,
    );
  }
}

class AppPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final Color? fill;
  final Color? stroke;
  final double? minHeight;
  final bool allowWrapLabel;
  final bool fitLabel;
  final double? labelFontSize;
  final double? labelLetterSpacing;
  final double leadingSlotWidth;

  const AppPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.iconColor,
    this.leading,
    this.fill,
    this.stroke,
    this.minHeight,
    this.allowWrapLabel = false,
    this.fitLabel = false,
    this.labelFontSize,
    this.labelLetterSpacing,
    this.leadingSlotWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final resolvedFill = fill ?? AppPalette.primary;
    final resolvedStroke = stroke ?? AppPalette.strokeStrong;
    final gradientColors = [
      Color.lerp(resolvedFill, Colors.white, 0.10)!,
      Color.lerp(resolvedFill, AppPalette.homeBlue, 0.20)!,
    ];

    return IgnorePointer(
      ignoring: disabled,
      child: Opacity(
        opacity: disabled ? 0.55 : 1.0,
        child: SizedBox(
          height: minHeight ?? 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: resolvedStroke,
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: resolvedFill.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: AppPalette.accentPurple.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: disabled ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: AppPalette.text,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        if (leading != null) ...[
                          SizedBox(
                            width: leadingSlotWidth > 0 ? leadingSlotWidth : null,
                            child: Center(child: leading!),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (icon != null && leading == null) ...[
                          Icon(icon,
                              size: 16, color: iconColor ?? Colors.white),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: fitLabel
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: Text(
                                    label,
                                    style: buttonFont(context).copyWith(
                                      fontSize: labelFontSize,
                                      letterSpacing: labelLetterSpacing,
                                    ),
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : Text(
                                  label,
                                  style: buttonFont(context).copyWith(
                                    fontSize: labelFontSize,
                                    letterSpacing: labelLetterSpacing,
                                  ),
                                  overflow: allowWrapLabel
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  maxLines: allowWrapLabel ? 2 : 1,
                                  textAlign: TextAlign.center,
                                ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final double radius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color iconColor;
  final List<BoxShadow>? boxShadow;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 20,
    this.radius = 14,
    this.backgroundColor,
    this.borderColor,
    this.iconColor = Colors.white,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppPalette.primary.withValues(alpha: 0.06),
                blurRadius: 18,
                spreadRadius: -6,
              ),
            ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (backgroundColor ?? AppPalette.panelElevated)
                    .withValues(alpha: 0.98),
                AppPalette.panelDeep.withValues(alpha: 0.94),
              ],
            ),
            border: Border.all(color: borderColor ?? AppPalette.stroke),
            borderRadius: borderRadius,
          ),
          child: InkResponse(
            onTap: onTap,
            radius: 28,
            containedInkWell: true,
            highlightShape: BoxShape.rectangle,
            child: Center(
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumBalanceBar extends StatelessWidget {
  final int coins;
  final bool guest;
  final bool compact;
  final String? label;
  final String assetPath;
  final double? width;

  const PremiumBalanceBar({
    super.key,
    required this.coins,
    this.guest = false,
    this.compact = false,
    this.label,
    this.assetPath = 'assets/coin/COIN-SHOP.png',
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? (guest ? 'ACCOUNT' : 'BALANCE');
    final displayText = guest ? 'Sign in' : formatCoins(coins, compact: true);
    final accent = guest ? AppPalette.gold : AppPalette.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultWidth = compact ? 156.0 : 228.0;
        final requestedWidth = width ?? defaultWidth;
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : requestedWidth;
        final resolvedWidth = max(
          96.0,
          min(requestedWidth, availableWidth.isFinite ? availableWidth : requestedWidth),
        );
        final tightLayout = resolvedWidth < (compact ? 142.0 : 184.0);
        final showWalletLabel = !guest && !tightLayout && resolvedWidth >= 214.0;
        final barPadding = EdgeInsets.symmetric(
          horizontal: tightLayout ? 10 : (compact ? 14 : 18),
          vertical: tightLayout ? 9 : (compact ? 11 : 14),
        );
        final iconWidth = tightLayout
            ? 30.0
            : (compact ? 40.0 : (resolvedWidth < 210.0 ? 48.0 : 64.0));
        final iconHeight = tightLayout ? 28.0 : (compact ? 38.0 : 52.0);
        final iconGap = tightLayout ? 10.0 : 14.0;

        return SizedBox(
          width: resolvedWidth,
          child: Container(
            padding: barPadding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.homePanelDeep.withValues(alpha: 0.98),
                  AppPalette.panelElevated.withValues(alpha: 0.96),
                ],
              ),
              borderRadius: BorderRadius.circular(compact ? 22 : 24),
              border: Border.all(
                color:
                    guest ? AppPalette.gold.withOpacity(0.36) : AppPalette.stroke,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: compact ? 20 : 26,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.10),
                  blurRadius: compact ? 18 : 24,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeLabelFont(
                          context,
                          fontSize: tightLayout ? 7 : (compact ? 8 : 9),
                          color:
                              guest ? AppPalette.goldHighlight : AppPalette.primary,
                        ),
                      ),
                      SizedBox(height: tightLayout ? 4 : 6),
                      Text(
                        displayText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeOrbitron(
                          fontSize: tightLayout ? 12 : (compact ? 14 : 18),
                          fontWeight: FontWeight.w900,
                          letterSpacing: tightLayout ? 0.2 : 0.5,
                          color: AppPalette.homeTitle,
                        ),
                      ),
                      if (showWalletLabel) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Arena wallet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: homeBodyFont(
                            context,
                            fontSize: 11,
                            color: AppPalette.homeMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: iconGap),
                SizedBox(
                  width: iconWidth,
                  height: iconHeight,
                  child: Center(
                    child: guest
                        ? Icon(
                            Icons.lock_outline,
                            size: tightLayout ? 16 : (compact ? 18 : 22),
                            color: AppPalette.gold,
                          )
                        : Image.asset(
                            assetPath,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CoinPill extends StatelessWidget {
  final int coins;
  final CoinPillVariant variant;
  final String? label;
  final double? width;

  const CoinPill({
    super.key,
    required this.coins,
    this.variant = CoinPillVariant.defaultTheme,
    this.label,
    this.width,
  });

  bool get _isGuest {
    try {
      return FirebaseAuth.instance.currentUser == null;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHomeVariant = variant == CoinPillVariant.homeNeon;

    return PremiumBalanceBar(
      coins: coins,
      guest: _isGuest,
      compact: !isHomeVariant,
      label: label,
      width: width,
      assetPath:
          isHomeVariant ? 'assets/coin/COIN-SHOP.png' : 'assets/coin/COIN.png',
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _BackgroundGlow({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _AmbientGridPainter extends CustomPainter {
  final Color lineColor;
  final Color dotColor;

  const _AmbientGridPainter({
    required this.lineColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 46.0;
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double x = -spacing; x <= size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = -spacing; y <= size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final dotPaint = Paint()..color = dotColor;
    for (int i = 0; i < 22; i++) {
      final dx = (i * spacing * 1.37) % max(size.width, 1);
      final dy = (i * spacing * 1.91 + spacing * (i.isEven ? 0.6 : 1.2)) %
          max(size.height, 1);
      canvas.drawCircle(Offset(dx, dy), i % 5 == 0 ? 1.8 : 1.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.dotColor != dotColor;
  }
}

/// ==========================
///   TOP NOTIFICATION
/// ==========================
bool _isNotificationShowing = false;
OverlayEntry? _currentNotificationEntry;

void showTopNotification(
  BuildContext context,
  String message, {
  Color color = AppPalette.primary,
  Duration duration = const Duration(milliseconds: 1400),
}) {
  if (_isNotificationShowing) return;

  _isNotificationShowing = true;
  _currentNotificationEntry?.remove();

  final overlay = Overlay.of(context);
  _currentNotificationEntry = OverlayEntry(
    builder: (context) => _TopNotification(
      message: message,
      color: color,
      duration: duration,
      onDismiss: () {
        _isNotificationShowing = false;
        _currentNotificationEntry?.remove();
        _currentNotificationEntry = null;
      },
    ),
  );

  overlay.insert(_currentNotificationEntry!);
}

class _TopNotification extends StatefulWidget {
  final String message;
  final Color color;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopNotification({
    required this.message,
    required this.color,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopNotification> createState() => _TopNotificationState();
}

class _TopNotificationState extends State<_TopNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _slide = Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _c, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );
    _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _c, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );

    _c.forward();
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _c.reverse();
      if (!mounted) return;
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final icon = widget.color == AppPalette.danger
        ? Icons.warning_amber_rounded
        : widget.color == AppPalette.warning
            ? Icons.info_outline
            : Icons.check_circle;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: top + 10, left: 14, right: 14),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppPalette.panelElevated.withValues(alpha: 0.96),
                    AppPalette.panelDeep.withValues(alpha: 0.96),
                  ],
                ),
                border: Border.all(
                    color: widget.color.withValues(alpha: 0.55), width: 1.2),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.20),
                    blurRadius: 18,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: widget.color, size: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: safeInter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Auth form field (email, password, etc.)
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? Function(String?)? validator;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      style: safeInter(
        fontSize: 15,
        color: AppPalette.text,
        fontWeight: FontWeight.w600,
      ),
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppPalette.panelDeep.withValues(alpha: 0.96),
        prefixIcon: Icon(icon, color: AppPalette.primary),
        hintText: hint,
        hintStyle: safeInter(
          fontSize: 14,
          color: AppPalette.textSubtle,
          fontWeight: FontWeight.w600,
        ),
        errorStyle: safeInter(
          fontSize: 14,
          color: AppPalette.danger,
          fontWeight: FontWeight.w700,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        counterText: maxLength != null ? '' : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppPalette.strokeSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
              color: AppPalette.primary.withValues(alpha: 0.85), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
              color: AppPalette.danger.withValues(alpha: 0.85), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
              color: AppPalette.danger.withValues(alpha: 0.95), width: 1.4),
        ),
      ),
    );
  }
}

class ArenaField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? Function(String?)? validator;

  /// Outer margin. Defaults to the standard side inset; pass [EdgeInsets.zero]
  /// (e.g. from the login card) to let the field span the full content width.
  final EdgeInsetsGeometry? margin;

  const ArenaField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.validator,
    this.margin,
  });

  @override
  State<ArenaField> createState() => _ArenaFieldState();
}

class _ArenaFieldState extends State<ArenaField> {
  bool _obscure = true;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.panelElevated.withValues(alpha: 0.98),
              AppPalette.panelDeep.withValues(alpha: 0.94),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isFocused ? AppPalette.primary : AppPalette.stroke,
            width: _isFocused ? 1.5 : 1,
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.18),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword ? _obscure : false,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          validator: widget.validator,
          style: safeOrbitron(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppPalette.text,
            letterSpacing: 1.3,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            counterText: widget.maxLength != null ? '' : null,
            errorStyle: safeInter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppPalette.danger,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            prefixIcon: Icon(
              widget.icon,
              color: _isFocused ? AppPalette.primary : AppPalette.textSubtle,
              size: 20,
            ),
            hintText: widget.hint,
            hintStyle: safeOrbitron(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppPalette.textSubtle,
              letterSpacing: 1,
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _isFocused
                          ? AppPalette.primary
                          : AppPalette.textSubtle,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class XOLogo extends StatelessWidget {
  final double size;
  const XOLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _XOLogoPainter(),
      ),
    );
  }
}

class _XOLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    const x = AppPalette.primary;
    const o = AppPalette.gold;

    // Background glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [AppPalette.primary.withOpacity(0.22), Colors.transparent],
      ).createShader(
          Rect.fromCircle(center: center, radius: size.width * 0.62));
    canvas.drawCircle(center, size.width * 0.55, glowPaint);

    // O circle with glow
    final oPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..color = o
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.20, center.dy - size.height * 0.10),
      size.width * 0.24,
      oPaint,
    );

    // X strokes with glow
    final xPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round
      ..color = x
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    final xCenter =
        Offset(center.dx + size.width * 0.20, center.dy + size.height * 0.10);
    final r = size.width * 0.20;

    canvas.drawLine(xCenter + Offset(-r, -r), xCenter + Offset(r, r), xPaint);
    canvas.drawLine(xCenter + Offset(r, -r), xCenter + Offset(-r, r), xPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

