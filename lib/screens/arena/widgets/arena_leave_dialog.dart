import 'package:flutter/material.dart';

import '../../../core/app_l10n.dart';
import '../../../core/app_theme.dart';

/// Premium dark-glass leave/forfeit confirmation dialog used by both the
/// Arena lobby and the in-match screen.
///
/// Returns `true` when the user confirms leave, `false` for Stay or barrier
/// dismiss. Body copy adapts to whether the match is mid-play and whether
/// the player has a locked coin bet at risk.
Future<bool> showArenaLeaveDialog(
  BuildContext context, {
  required bool beforePlay,
  required bool hasBet,
  String? overrideTitle,
}) async {
  final l10n = AppL10n.of(context);
  final title = overrideTitle ??
      (beforePlay ? l10n.leaveRoomTitle : l10n.leaveRoomTitle);

  final body = _bodyFor(l10n, beforePlay: beforePlay, hasBet: hasBet);

  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: [
              AppPalette.panel.withValues(alpha: 0.96),
              AppPalette.panelDeep.withValues(alpha: 0.98),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: AppPalette.danger.withValues(alpha: 0.85),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: AppPalette.danger.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppPalette.danger.withValues(alpha: 0.14),
                border: Border.all(
                  color: AppPalette.danger.withValues(alpha: 0.7),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppPalette.danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.text,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.text.withValues(alpha: 0.78),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: l10n.stayBtn,
                    color: AppPalette.primary,
                    filled: false,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogButton(
                    label: l10n.leaveRoom,
                    color: AppPalette.danger,
                    filled: true,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return res == true;
}

String _bodyFor(AppL10n l10n,
    {required bool beforePlay, required bool hasBet}) {
  if (beforePlay) {
    return l10n.leaveRoomConfirm;
  }
  // Betting is disabled for release; hasBet is always false at runtime.
  return l10n.leaveCountsAsLoss;
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              filled ? color.withValues(alpha: 0.2) : Colors.transparent,
          foregroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color, width: 1.3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
