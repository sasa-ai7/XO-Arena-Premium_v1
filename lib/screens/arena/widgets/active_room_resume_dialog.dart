import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

/// The user's choice from the "Active Room Found" resume prompt.
enum ActiveRoomResumeChoice { returnToRoom, leaveAndPlay }

/// Custom XO Arena styled modal shown when the user reopens the app/online tab
/// with a still-valid active room. Dark glass panel with a cyan border/glow,
/// the room code highlighted, and two actions:
///   • Return to Room              (cyan primary)
///   • Leave Room & Play Normally  (crimson outline — this resolves the room)
///
/// Returns the user's [ActiveRoomResumeChoice], or `null` if dismissed without
/// choosing (the barrier is disabled, so this only happens on a back gesture).
Future<ActiveRoomResumeChoice?> showActiveRoomResumeDialog(
  BuildContext context, {
  required String roomCode,
  String? statusLabel,
}) {
  return showDialog<ActiveRoomResumeChoice>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => _ActiveRoomResumeDialog(
      roomCode: roomCode,
      statusLabel: statusLabel,
    ),
  );
}

/// Styled XO Arena notice shown when a previous room was closed (expired) or
/// settled while the user was away (e.g. opponent left → you won). Single
/// "OK" action. Reuses the resume-dialog glass-panel look so messaging stays
/// visually consistent.
Future<void> showRoomClosedDialog(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.info_outline_rounded,
  Color accent = AppPalette.primary,
  String? roomCode,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => _RoomNoticeDialog(
      title: title,
      message: message,
      icon: icon,
      accent: accent,
      roomCode: roomCode,
    ),
  );
}

BoxDecoration _panelDecoration(Color accent) => BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [AppPalette.homePanel, AppPalette.panelDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.4),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.30),
          blurRadius: 30,
          spreadRadius: 1,
        ),
      ],
    );

Widget _roomCodePill(String roomCode) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(
          color: AppPalette.primary.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Text(
        roomCode,
        style: const TextStyle(
          color: AppPalette.primary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
          fontFamily: 'Orbitron',
        ),
      ),
    );

class _ActiveRoomResumeDialog extends StatelessWidget {
  final String roomCode;
  final String? statusLabel;
  const _ActiveRoomResumeDialog({required this.roomCode, this.statusLabel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: _panelDecoration(AppPalette.primary),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.primary.withValues(alpha: 0.16),
                  border: Border.all(
                    color: AppPalette.primary.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.meeting_room_rounded,
                  color: AppPalette.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Active Room Found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 12),
              _roomCodePill(roomCode),
              if (statusLabel != null && statusLabel!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppPalette.accentPurple.withValues(alpha: 0.16),
                    border: Border.all(
                      color: AppPalette.accentPurple.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusLabel!,
                    style: const TextStyle(
                      color: AppPalette.accentPurple,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'You are still in room $roomCode. What do you want to do?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.textSubtle,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Return to Room — cyan primary.
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context)
                      .pop(ActiveRoomResumeChoice.returnToRoom),
                  child: const Text(
                    'Return to Room',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Leave Room & Play Normally — crimson outline. This resolves the
              // room (cancel/forfeit) per the lifecycle rules.
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.danger,
                    side: BorderSide(
                      color: AppPalette.danger.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context)
                      .pop(ActiveRoomResumeChoice.leaveAndPlay),
                  child: const Text(
                    'Leave Room & Play Normally',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomNoticeDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color accent;
  final String? roomCode;
  const _RoomNoticeDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
    this.roomCode,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: _panelDecoration(accent),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.16),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  fontFamily: 'Orbitron',
                ),
              ),
              if (roomCode != null && roomCode!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _roomCodePill(roomCode!),
              ],
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.textSubtle,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: 0.16),
                    foregroundColor: accent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: accent, width: 1.3),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
