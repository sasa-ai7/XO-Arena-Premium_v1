import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import 'app_ui.dart';

class ModeTransitionOverlay extends StatefulWidget {
  final bool isReconnecting;

  const ModeTransitionOverlay({super.key, required this.isReconnecting});

  @override
  State<ModeTransitionOverlay> createState() => _ModeTransitionOverlayState();
}

class _ModeTransitionOverlayState extends State<ModeTransitionOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _scan;
  late final AnimationController _fade;
  late final Animation<double> _scanAnim;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scanAnim = CurvedAnimation(parent: _scan, curve: Curves.easeInOut);
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _scan.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isRecon = widget.isReconnecting;
    final accentColor = isRecon ? AppPalette.homeCyan : AppPalette.warning;
    final icon = isRecon ? Icons.wifi_rounded : Icons.wifi_off_rounded;
    final headline = isRecon ? l10n.connectionRestored : l10n.connectionLost;
    final subtext =
        isRecon ? l10n.syncingOnlineAccount : l10n.switchingToOfflineMode;

    return FadeTransition(
      opacity: _fadeIn,
      child: IgnorePointer(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black.withOpacity(0.65),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AppGlassCard(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  backgroundColor: AppPalette.homePanelStrong.withOpacity(0.97),
                  borderColor: accentColor.withOpacity(0.35),
                  radius: 28,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.22),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated icon with neon ring
                      AnimatedBuilder(
                        animation: _scanAnim,
                        builder: (_, __) => Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withOpacity(0.10),
                            border: Border.all(
                              color: accentColor
                                  .withOpacity(0.30 + _scanAnim.value * 0.40),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(
                                    0.10 + _scanAnim.value * 0.25),
                                blurRadius: 20 + _scanAnim.value * 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(icon, size: 30, color: accentColor),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: safeOrbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtext,
                        textAlign: TextAlign.center,
                        style: safeInter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Scanning progress bar
                      AnimatedBuilder(
                        animation: _scanAnim,
                        builder: (_, __) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                Container(
                                  height: 3,
                                  color: accentColor.withOpacity(0.12),
                                ),
                                FractionallySizedBox(
                                  widthFactor: _scanAnim.value,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          accentColor.withOpacity(0.0),
                                          accentColor,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
