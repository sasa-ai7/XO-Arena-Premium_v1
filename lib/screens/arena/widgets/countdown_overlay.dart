import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_l10n.dart';
import '../../../core/app_theme.dart';

/// Full-screen 3-2-1-Fight countdown overlay used when a friend room starts.
class CountdownOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const CountdownOverlay({super.key, required this.onComplete});

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _step = 0; // 0..3 → "3","2","1","Fight!"

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _tick();
  }

  void _tick() async {
    while (mounted && _step <= 3) {
      _ctrl.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _step++);
    }
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _label(AppL10n l10n) {
    if (_step >= 3) return l10n.fightWord;
    return '${3 - _step}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isFight = _step >= 3;
    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      alignment: Alignment.center,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1.2).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
        ),
        child: Text(
          _label(l10n),
          style: TextStyle(
            color: isFight ? AppPalette.gold : AppPalette.primary,
            fontSize: isFight ? 80 : 120,
            fontWeight: FontWeight.w900,
            fontFamily: 'Orbitron',
            letterSpacing: 4,
            shadows: [
              Shadow(
                color: (isFight ? AppPalette.gold : AppPalette.primary)
                    .withValues(alpha: 0.6),
                blurRadius: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
