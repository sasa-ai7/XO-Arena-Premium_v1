import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import '../core/keys.dart';
import '../services/local_store.dart';
import '../widgets/app_ui.dart';

/// Shows a confirmation dialog, then a loading overlay, then applies the
/// new locale. Call from any screen that has a language-toggle control.
Future<void> confirmAndSwitchLanguage(BuildContext context) async {
  final l10n = AppL10n.of(context);

  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, __) => Center(child: _LanguageConfirmDialog(l10n: l10n)),
  );

  if (confirmed != true || !context.mounted) return;

  // Non-dismissible loading overlay
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _LanguageSwitchingOverlay(l10n: l10n),
  );

  final newLang = l10n.isAr ? 'en' : 'ar';
  await Future.delayed(const Duration(milliseconds: 700));
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(Keys.appLanguage, newLang);
  LocalStore.localeNotifier.value = Locale(newLang);

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppL10n(newLang).languageChangedSuccessfully,
          style: safeInter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppPalette.primary.withValues(alpha: 0.92),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Confirmation dialog
// ─────────────────────────────────────────────────────────────────────────────

class _LanguageConfirmDialog extends StatelessWidget {
  final AppL10n l10n;

  const _LanguageConfirmDialog({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final msg = l10n.isAr ? l10n.changeLanguageToEnglishMsg : l10n.changeLanguageToArabicMsg;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: AppGlassCard(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            backgroundColor: AppPalette.homePanelStrong,
            borderColor: AppPalette.primary.withValues(alpha: 0.35),
            radius: 28,
            boxShadow: [
              BoxShadow(
                color: AppPalette.primary.withValues(alpha: 0.20),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Globe icon with neon glow
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.primary.withValues(alpha: 0.10),
                    border: Border.all(
                      color: AppPalette.primary.withValues(alpha: 0.40),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.primary.withValues(alpha: 0.22),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.language_rounded, size: 28, color: AppPalette.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.changeLanguageTitle,
                  textAlign: TextAlign.center,
                  style: safeOrbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: safeInter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: l10n.cancelBtn,
                        fill: AppPalette.homePanel,
                        stroke: AppPalette.stroke,
                        minHeight: 46,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: l10n.switchLanguageBtn,
                        fill: AppPalette.primary,
                        minHeight: 46,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Switching overlay — matches _ModeTransitionOverlay style
// ─────────────────────────────────────────────────────────────────────────────

class _LanguageSwitchingOverlay extends StatefulWidget {
  final AppL10n l10n;

  const _LanguageSwitchingOverlay({required this.l10n});

  @override
  State<_LanguageSwitchingOverlay> createState() => _LanguageSwitchingOverlayState();
}

class _LanguageSwitchingOverlayState extends State<_LanguageSwitchingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan;
  late final Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scanAnim = CurvedAnimation(parent: _scan, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: Colors.black.withValues(alpha: 0.65),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AppGlassCard(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  backgroundColor: AppPalette.homePanelStrong.withValues(alpha: 0.97),
                  borderColor: AppPalette.primary.withValues(alpha: 0.35),
                  radius: 28,
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.22),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _scanAnim,
                        builder: (_, __) => Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppPalette.primary.withValues(alpha: 0.10),
                            border: Border.all(
                              color: AppPalette.primary
                                  .withValues(alpha: 0.30 + _scanAnim.value * 0.40),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.primary.withValues(
                                    alpha: 0.10 + _scanAnim.value * 0.25),
                                blurRadius: 20 + _scanAnim.value * 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.language_rounded,
                            size: 30,
                            color: AppPalette.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.l10n.switchingLanguage,
                        textAlign: TextAlign.center,
                        style: safeOrbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _scanAnim,
                        builder: (_, __) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                Container(
                                  height: 3,
                                  color: AppPalette.primary.withValues(alpha: 0.12),
                                ),
                                FractionallySizedBox(
                                  widthFactor: _scanAnim.value,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppPalette.primary.withValues(alpha: 0.0),
                                          AppPalette.primary,
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
    );
  }
}
