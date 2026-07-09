import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'app_ui.dart';

/// Custom numeric keypad widget with glass styling
class NumericKeypad extends StatelessWidget {
  final Function(String) onNumberTap;
  final VoidCallback? onClear;
  final VoidCallback? onBackspace;

  const NumericKeypad({
    super.key,
    required this.onNumberTap,
    this.onClear,
    this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Number grid (1-9)
          Row(
            children: [
              Expanded(child: _KeypadButton(label: '1', onTap: () => onNumberTap('1'))),
              const SizedBox(width: 12),
              Expanded(child: _KeypadButton(label: '2', onTap: () => onNumberTap('2'))),
              const SizedBox(width: 12),
              Expanded(child: _KeypadButton(label: '3', onTap: () => onNumberTap('3'))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _KeypadButton(label: '4', onTap: () => onNumberTap('4'))),
              const SizedBox(width: 12),
              Expanded(child: _KeypadButton(label: '5', onTap: () => onNumberTap('5'))),
              const SizedBox(width: 12),
              Expanded(child: _KeypadButton(label: '6', onTap: () => onNumberTap('6'))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _KeypadButton(label: '7', onTap: () => onNumberTap('7'))),
              const SizedBox(width: 12),
              Expanded(child: _KeypadButton(label: '8', onTap: () => onNumberTap('8'))),
              const SizedBox(width: 12),
              Expanded(child: _KeypadButton(label: '9', onTap: () => onNumberTap('9'))),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom row: Clear, 0, Backspace
          Row(
            children: [
              Expanded(
                child: _KeypadButton(
                  label: 'Clear',
                  onTap: onClear ?? () {},
                  isAction: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _KeypadButton(label: '0', onTap: () => onNumberTap('0'))),
              const SizedBox(width: 12),
              Expanded(
                child: _KeypadButton(
                  label: '⌫',
                  onTap: onBackspace ?? () {},
                  isAction: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAction;

  const _KeypadButton({
    required this.label,
    required this.onTap,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppPalette.radiusSmall),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isAction ? 0.08 : 0.06),
          borderRadius: BorderRadius.circular(AppPalette.radiusSmall),
          border: Border.all(
            color: AppPalette.stroke,
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: safeOrbitron(
              fontSize: isAction ? 14 : 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
