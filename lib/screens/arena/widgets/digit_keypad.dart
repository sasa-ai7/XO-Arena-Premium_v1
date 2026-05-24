import 'package:flutter/material.dart';

import '../../../core/app_l10n.dart';
import '../../../core/app_theme.dart';

/// Custom on-screen numeric keypad used for entering room codes (6 digits)
/// and referral codes (9 digits). Deliberately bypasses the mobile system
/// keyboard.
class DigitKeypad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onEnter;
  final bool enterEnabled;

  const DigitKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    required this.onEnter,
    required this.enterEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    Widget btn({
      String? label,
      VoidCallback? onTap,
      Color? bg,
      IconData? icon,
      Color? fg,
    }) {
      final disabled = onTap == null;
      final resolvedFg = disabled
          ? AppPalette.textSubtle
          : (fg ?? AppPalette.text);
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Material(
            color: bg ?? AppPalette.panelSoft,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppPalette.strokeSoft,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) Icon(icon, color: resolvedFg, size: 20),
                    if (icon != null && label != null)
                      const SizedBox(height: 2),
                    if (label != null)
                      Text(
                        label,
                        style: TextStyle(
                          color: resolvedFg,
                          fontSize: icon == null ? 22 : 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: icon == null ? 0 : 0.4,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          btn(label: '1', onTap: () => onDigit('1')),
          btn(label: '2', onTap: () => onDigit('2')),
          btn(label: '3', onTap: () => onDigit('3')),
        ]),
        Row(children: [
          btn(label: '4', onTap: () => onDigit('4')),
          btn(label: '5', onTap: () => onDigit('5')),
          btn(label: '6', onTap: () => onDigit('6')),
        ]),
        Row(children: [
          btn(label: '7', onTap: () => onDigit('7')),
          btn(label: '8', onTap: () => onDigit('8')),
          btn(label: '9', onTap: () => onDigit('9')),
        ]),
        Row(children: [
          btn(
            label: l10n.keypadDelete,
            icon: Icons.backspace_outlined,
            onTap: onDelete,
            fg: AppPalette.danger,
          ),
          btn(label: '0', onTap: () => onDigit('0')),
          btn(
            label: l10n.keypadEnter,
            icon: Icons.check_rounded,
            onTap: enterEnabled ? onEnter : null,
            bg: enterEnabled
                ? AppPalette.primary.withValues(alpha: 0.22)
                : AppPalette.panelDeep,
            fg: enterEnabled ? AppPalette.primary : AppPalette.textSubtle,
          ),
        ]),
      ],
    );
  }
}

/// Slot display for a fixed-length numeric input.
///
/// Slots shrink to fit narrow phones — on a 360 dp device a 9-digit display
/// stays inside the available width with comfortable spacing.
class DigitSlotsDisplay extends StatelessWidget {
  final String value;
  final int length;
  final double maxSlotHeight;
  final double maxWidth;

  const DigitSlotsDisplay({
    super.key,
    required this.value,
    required this.length,
    this.maxSlotHeight = 60,
    this.maxWidth = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final availableW = (maxWidth.isFinite && maxWidth < c.maxWidth)
            ? maxWidth
            : c.maxWidth;
        // Reserve 6 px gap on each side of each slot.
        final perSlotMax = (availableW / length) - 8;
        final slotW = perSlotMax.clamp(24.0, 48.0).toDouble();
        final slotH = (slotW * 1.4).clamp(36.0, maxSlotHeight).toDouble();
        final fontSize = (slotW * 0.55).clamp(16.0, 28.0).toDouble();
        return SizedBox(
          width: availableW,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(length, (i) {
              final ch = i < value.length ? value[i] : '';
              final filled = ch.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: slotW,
                  height: slotH,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppPalette.panel,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: filled ? AppPalette.primary : AppPalette.strokeSoft,
                      width: 1.3,
                    ),
                    boxShadow: [
                      if (filled)
                        BoxShadow(
                          color: AppPalette.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                    ],
                  ),
                  child: Text(
                    ch,
                    style: TextStyle(
                      color: AppPalette.text,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
