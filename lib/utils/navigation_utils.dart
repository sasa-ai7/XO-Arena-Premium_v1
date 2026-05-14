import 'package:flutter/material.dart';

import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import '../screens/home/home_hub.dart';
import '../screens/login_screen.dart';
import '../widgets/app_ui.dart';

// Game enums, board utils, and AI engine are in:
//   lib/utils/board_utils.dart  (PlayerSymbol, GameMode, AIDifficulty, MatchBoardConfig, board geometry)
//   lib/utils/ai_engine.dart    (AI move selection)

/// ==========================
///   NAVIGATION HELPER
/// ==========================
void navigateToHomeHub(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const HomeHub(),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
    (route) => false,
  );
}

/// Top-level fade route helper for game screens — 200ms forward, 180ms reverse.
PageRoute<T> xoFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

/// Show sign-in required dialog for guests trying to make purchases.
void showSignInRequiredDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final l10n = AppL10n.of(ctx);
      return Dialog(
        backgroundColor: Colors.transparent,
        child: AppGlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppPalette.warning),
              const SizedBox(height: 16),
              Text(
                l10n.signInRequiredTitle,
                style: titleFont(context).copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.signInRequiredDesc,
                style: bodyFont(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppPillButton(
                      label: l10n.notNow,
                      fill: Colors.white.withOpacity(0.08),
                      stroke: AppPalette.strokeStrong,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPillButton(
                      label: l10n.signInBtn,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}


// _buildStartupPageRoute moved to lib/core/startup.dart
