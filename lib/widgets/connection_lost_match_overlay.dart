import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import '../services/app_mode_service.dart';
import '../services/local_store.dart';
import '../widgets/app_ui.dart';

class ConnectionLostMatchOverlay extends StatefulWidget {
  final VoidCallback onRestartOffline;
  final VoidCallback onWaitForConnection;
  final VoidCallback onExitHome;

  const ConnectionLostMatchOverlay({
    required this.onRestartOffline,
    required this.onWaitForConnection,
    required this.onExitHome,
  });

  @override
  State<ConnectionLostMatchOverlay> createState() =>
      _ConnectionLostMatchOverlayState();
}

class _ConnectionLostMatchOverlayState
    extends State<ConnectionLostMatchOverlay> {
  bool _waitingForConnection = false;

  @override
  void initState() {
    super.initState();
    // Listen for reconnection when user chose "Wait for Connection".
    AppModeService.modeNotifier.addListener(_onModeChanged);
  }

  @override
  void dispose() {
    AppModeService.modeNotifier.removeListener(_onModeChanged);
    super.dispose();
  }

  void _onModeChanged() {
    if (!mounted) return;
    if (_waitingForConnection &&
        AppModeService.current == AppMode.online) {
      if (kDebugMode) {
        debugPrint('[RECONNECT] connection restored during paused online match');
        debugPrint('[RECONNECT] online profile reloaded');
        debugPrint('[RECONNECT] match resume allowed=false');
      }
      // Do NOT resume the match — pop back to online home to avoid duplicate rewards.
      widget.onWaitForConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Container(
        color: Colors.black.withOpacity(0.88),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00CFFF).withOpacity(0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00CFFF).withOpacity(0.18),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00CFFF).withOpacity(0.12),
                      border: Border.all(
                        color: const Color(0xFF00CFFF).withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      color: Color(0xFF00CFFF),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Title
                  Text(
                    l10n.connectionLost,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF00CFFF),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Body
                  Text(
                    l10n.connectionLostMatchBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Match status chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFF6B35).withOpacity(0.45),
                      ),
                    ),
                    child: Text(
                      l10n.matchInterrupted,
                      style: const TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Button: Restart in Offline Mode
                  OverlayButton(
                    label: l10n.restartInOfflineMode,
                    icon: Icons.offline_bolt_outlined,
                    isPrimary: true,
                    onTap: widget.onRestartOffline,
                  ),
                  const SizedBox(height: 12),

                  // Button: Wait for Connection
                  OverlayButton(
                    label: _waitingForConnection
                        ? l10n.waitForConnection + '...'
                        : l10n.waitForConnection,
                    icon: Icons.wifi_find_outlined,
                    isPrimary: false,
                    onTap: () {
                      setState(() => _waitingForConnection = true);
                      // The listener in _onModeChanged will handle auto-dismiss.
                    },
                  ),
                  const SizedBox(height: 12),

                  // Button: Exit to Home
                  OverlayButton(
                    label: l10n.exitToHome,
                    icon: Icons.home_outlined,
                    isPrimary: false,
                    onTap: widget.onExitHome,
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

class OverlayButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const OverlayButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFF00CFFF), Color(0xFF0066CC)],
                  )
                : null,
            color: isPrimary ? null : const Color(0xFF162032),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : const Color(0xFF00CFFF).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isPrimary ? Colors.white : const Color(0xFF00CFFF)),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ==========================
///   COIN MATCH GAME PAGE
/// ==========================
