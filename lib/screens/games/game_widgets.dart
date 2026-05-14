import "dart:math";

import 'package:flutter/material.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../utils/board_utils.dart';
import '../../widgets/app_ui.dart';

class CardAura extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const CardAura({
    required this.color,
    required this.size,
    this.opacity = 0.16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(opacity * 0.35),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}


class SymbolTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  const SymbolTile({
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected && !dimmed;
    final glow = active
        ? AppPalette.primary.withValues(alpha: 0.30)
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppPalette.radiusSmall),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: dimmed ? 0.35 : 1.0,
        child: Container(
          height: 98,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppPalette.radiusSmall),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: active
                  ? [
                      AppPalette.primary.withValues(alpha: 0.18),
                      AppPalette.accentPurple.withValues(alpha: 0.16),
                    ]
                  : [
                      AppPalette.panelSoft.withValues(alpha: 0.94),
                      AppPalette.panelDeep.withValues(alpha: 0.98),
                    ],
            ),
            border: Border.all(
              color: active
                  ? AppPalette.gold.withValues(alpha: 0.48)
                  : AppPalette.strokeSoft,
              width: active ? 1.6 : 1.0,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: glow,
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 8)),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: safeOrbitron(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : Colors.white70,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                active
                    ? AppL10n.of(context).lockedIn
                    : AppL10n.of(context).tapToSelect,
                style: safeOrbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  color: active ? AppPalette.goldHighlight : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class DifficultySegment extends StatelessWidget {
  final AIDifficulty value;
  final ValueChanged<AIDifficulty>? onChanged;

  const DifficultySegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, AIDifficulty v) {
      final selected = value == v;
      return InkWell(
        onTap: onChanged == null ? null : () => onChanged!(v),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      AppPalette.primary.withValues(alpha: 0.28),
                      AppPalette.accentPurple.withValues(alpha: 0.18),
                    ]
                  : [
                      AppPalette.panelSoft.withValues(alpha: 0.94),
                      AppPalette.panelDeep.withValues(alpha: 0.98),
                    ],
            ),
            border: Border.all(
              color: selected
                  ? AppPalette.gold.withValues(alpha: 0.40)
                  : AppPalette.strokeSoft,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.16),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: safeOrbitron(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              color: selected ? Colors.white : AppPalette.textMuted,
            ),
          ),
        ),
      );
    }

    final l10n = AppL10n.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) {
          return Row(
            children: [
              Expanded(child: chip(l10n.easyDifficulty, AIDifficulty.easy)),
              const SizedBox(width: 10),
              Expanded(child: chip(l10n.mediumDifficulty, AIDifficulty.medium)),
              const SizedBox(width: 10),
              Expanded(child: chip(l10n.hardDifficulty, AIDifficulty.hard)),
            ],
          );
        }

        final chipWidth = constraints.maxWidth >= 320
            ? max(0.0, (constraints.maxWidth - 10) / 2)
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(width: chipWidth, child: chip(l10n.easyDifficulty, AIDifficulty.easy)),
            SizedBox(
              width: chipWidth,
              child: chip(l10n.mediumDifficulty, AIDifficulty.medium),
            ),
            SizedBox(width: chipWidth, child: chip(l10n.hardDifficulty, AIDifficulty.hard)),
          ],
        );
      },
    );
  }
}


class BoardSizeSegment extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;

  const BoardSizeSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(int size) {
      final selected = value == size;
      final boardConfig = standardBoardConfig(size);
      return InkWell(
        onTap: onChanged == null ? null : () => onChanged!(size),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      AppPalette.homeSky.withValues(alpha: 0.26),
                      AppPalette.homeBlue.withValues(alpha: 0.18),
                    ]
                  : [
                      AppPalette.panelSoft.withValues(alpha: 0.94),
                      AppPalette.panelDeep.withValues(alpha: 0.98),
                    ],
            ),
            border: Border.all(
              color: selected
                  ? AppPalette.homeSky.withValues(alpha: 0.62)
                  : AppPalette.strokeSoft,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppPalette.homeSky.withValues(alpha: 0.16),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                boardConfig.label,
                style: safeOrbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: selected ? Colors.white : AppPalette.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${boardConfig.winLength} IN ROW',
                style: safeOrbitron(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: selected
                      ? AppPalette.homeSky.withValues(alpha: 0.92)
                      : AppPalette.textSubtle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 360) {
          return Row(
            children: [
              Expanded(child: chip(3)),
              const SizedBox(width: 10),
              Expanded(child: chip(4)),
              const SizedBox(width: 10),
              Expanded(child: chip(5)),
            ],
          );
        }

        final chipWidth = max(0.0, (constraints.maxWidth - 10) / 2);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(width: chipWidth, child: chip(3)),
            SizedBox(width: chipWidth, child: chip(4)),
            SizedBox(width: chipWidth, child: chip(5)),
          ],
        );
      },
    );
  }
}

/// ==========================
///   COIN MATCH SETUP PAGE
/// ==========================

class SymbolOption extends StatelessWidget {
  final PlayerSymbol symbol;
  final bool selected;
  final VoidCallback onTap;

  const SymbolOption(
      {required this.symbol, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    AppPalette.primary.withValues(alpha: 0.22),
                    AppPalette.accentPurple.withValues(alpha: 0.16),
                  ]
                : [
                    AppPalette.panelSoft.withValues(alpha: 0.94),
                    AppPalette.panelDeep.withValues(alpha: 0.98),
                  ],
          ),
          border: Border.all(
            color: selected
                ? AppPalette.gold.withValues(alpha: 0.40)
                : AppPalette.strokeSoft,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.14),
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: symbol == PlayerSymbol.x
                    ? BoxShape.rectangle
                    : BoxShape.circle,
                borderRadius:
                    symbol == PlayerSymbol.x ? BorderRadius.circular(8) : null,
              ),
              child: symbol == PlayerSymbol.x
                  ? CustomPaint(
                      size: const Size(60, 60),
                      painter: XPainter(
                        color: selected
                            ? AppPalette.goldHighlight
                            : AppPalette.textMuted,
                        strokeWidth: 6,
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppPalette.goldHighlight
                              : AppPalette.textMuted,
                          width: 8,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              symbol == PlayerSymbol.x ? "X" : "O",
              style: safeOrbitron(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : AppPalette.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              selected ? AppL10n.of(context).readyLabel : AppL10n.of(context).tapToPick,
              style: safeOrbitron(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color:
                    selected ? AppPalette.goldHighlight : AppPalette.textSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==========================
///   GAME PAGE
///   - board centered
///   - coins at top right
///   - "NEXT" at top
///   - ignores taps while AI thinking/moving
/// ==========================

class XPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  XPainter({required this.color, this.strokeWidth = 8});

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.35)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = strokeWidth + 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final corePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.95),
          Color.lerp(color, Colors.white, 0.25)!,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final padding = size.width * 0.18;
    final startX = padding;
    final endX = size.width - padding;
    final startY = padding;
    final endY = size.height - padding;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), glowPaint);
    canvas.drawLine(Offset(endX, startY), Offset(startX, endY), glowPaint);
    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), corePaint);
    canvas.drawLine(Offset(endX, startY), Offset(startX, endY), corePaint);
  }

  @override
  bool shouldRepaint(covariant XPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
