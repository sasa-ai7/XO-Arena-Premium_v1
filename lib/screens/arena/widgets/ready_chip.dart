import 'package:flutter/material.dart';

import '../../../core/app_l10n.dart';
import '../../../core/app_theme.dart';

class ReadyChip extends StatelessWidget {
  final bool ready;
  const ReadyChip({super.key, required this.ready});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final color = ready ? AppPalette.success : AppPalette.textSubtle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            ready ? l10n.readyLabel : l10n.notReadyLabel,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
