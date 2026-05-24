import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Visual variants of the Arena in-game toast.
enum ArenaToastKind { info, success, warning, error }

/// Custom neon overlay toast used by all Arena and Referral screens.
///
/// Replaces the default Material `SnackBar` so messages match the game's
/// neon aesthetic. Anchored 16 px below the top safe-area inset so it does
/// not collide with the bottom navigation bar.
class ArenaToast {
  ArenaToast._();

  static OverlayEntry? _entry;

  static void show(
    BuildContext context,
    String message, {
    ArenaToastKind kind = ArenaToastKind.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _entry?.remove();
    final controllerKey = GlobalKey<_ArenaToastBodyState>();
    final entry = OverlayEntry(
      builder: (_) => _ArenaToastBody(
        key: controllerKey,
        message: message,
        kind: kind,
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    Future.delayed(duration, () async {
      final state = controllerKey.currentState;
      if (state != null) {
        await state.dismiss();
      }
      if (_entry == entry) {
        entry.remove();
        _entry = null;
      } else {
        try {
          entry.remove();
        } catch (_) {}
      }
    });
  }

  static void info(BuildContext context, String message,
          {Duration duration = const Duration(seconds: 3)}) =>
      show(context, message, kind: ArenaToastKind.info, duration: duration);

  static void success(BuildContext context, String message,
          {Duration duration = const Duration(seconds: 3)}) =>
      show(context, message, kind: ArenaToastKind.success, duration: duration);

  static void warning(BuildContext context, String message,
          {Duration duration = const Duration(seconds: 3)}) =>
      show(context, message, kind: ArenaToastKind.warning, duration: duration);

  static void error(BuildContext context, String message,
          {Duration duration = const Duration(seconds: 4)}) =>
      show(context, message, kind: ArenaToastKind.error, duration: duration);
}

class _ArenaToastBody extends StatefulWidget {
  final String message;
  final ArenaToastKind kind;
  const _ArenaToastBody({super.key, required this.message, required this.kind});

  @override
  State<_ArenaToastBody> createState() => _ArenaToastBodyState();
}

class _ArenaToastBodyState extends State<_ArenaToastBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  Future<void> dismiss() async {
    if (!mounted) return;
    try {
      await _ctrl.reverse();
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accent {
    switch (widget.kind) {
      case ArenaToastKind.success:
        return AppPalette.success;
      case ArenaToastKind.warning:
        return AppPalette.gold;
      case ArenaToastKind.error:
        return AppPalette.danger;
      case ArenaToastKind.info:
        return AppPalette.primary;
    }
  }

  IconData get _icon {
    switch (widget.kind) {
      case ArenaToastKind.success:
        return Icons.check_circle_rounded;
      case ArenaToastKind.warning:
        return Icons.warning_amber_rounded;
      case ArenaToastKind.error:
        return Icons.error_outline_rounded;
      case ArenaToastKind.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final accent = _accent;
    return Positioned(
      top: topInset + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppPalette.homePanel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.65),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.28),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.32),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.55),
                                width: 1),
                          ),
                          child: Icon(_icon, color: accent, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: AppPalette.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
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
