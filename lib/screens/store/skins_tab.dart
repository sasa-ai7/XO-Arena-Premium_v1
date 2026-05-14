import 'package:flutter/material.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../models/xo_skin.dart';
import '../../services/local_store.dart';
import '../../widgets/app_ui.dart';

class XOSubTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const XOSubTabBar({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.panelDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.homeStroke.withOpacity(0.18)),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _xoTab(context, 0, 'X', AppPalette.homeCyan),
            _xoTab(context, 1, 'O', AppPalette.accentPurple),
          ],
        ),
      ),
    );
  }

  Widget _xoTab(BuildContext ctx, int idx, String label, Color accent) {
    final sel = selectedIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: sel
                ? LinearGradient(
                    colors: [accent.withOpacity(0.25), accent.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: sel
                ? Border.all(color: accent.withOpacity(0.45), width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: safeOrbitron(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: sel ? accent : Colors.white38,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Individual Skin Card ─────────────────────────────────────────────────────

class SkinCard extends StatelessWidget {
  final XOSkin skin;
  final bool isOwned;
  final bool isSelected;
  final Color accent;
  final VoidCallback? onBuy;
  final VoidCallback? onSelect;
  final Color xColor;
  final Color oColor;

  const SkinCard({
    required this.skin,
    required this.isOwned,
    required this.isSelected,
    required this.accent,
    this.onBuy,
    this.onSelect,
    this.xColor = const Color(0xFFFF3B30),
    this.oColor = const Color(0xFF0A84FF),
  });

  static const _gold = Color(0xFFFFD700);
  static const _goldDeep = Color(0xFFB8860B);
  static const _goldBorder = Color(0xFFDAA520);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isLeg = skin.isLegendary;
    final isDef = skin.isDefault;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: isOwned
            ? (isSelected ? null : onSelect)
            : onBuy,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isSelected
                ? LinearGradient(
                    colors: [accent.withOpacity(0.22), AppPalette.panelDeep],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : isLeg
                    ? const LinearGradient(
                        colors: [Color(0xFF1A1200), Color(0xFF0A0800)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          AppPalette.panelElevated,
                          AppPalette.panelDeep,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
            border: Border.all(
              color: isSelected
                  ? accent.withOpacity(0.80)
                  : isLeg
                      ? _goldBorder.withOpacity(0.60)
                      : AppPalette.homeStroke.withOpacity(0.18),
              width: isSelected || isLeg ? 1.5 : 1,
            ),
            boxShadow: isSelected || isLeg
                ? [
                    BoxShadow(
                      color: isSelected
                          ? accent.withOpacity(0.22)
                          : _gold.withOpacity(0.14),
                      blurRadius: 16,
                      spreadRadius: -2,
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Legendary shimmer badge
              if (isLeg)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Text(
                    'LEGENDARY',
                    style: safeOrbitron(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: _gold,
                    ),
                  ),
                )
              else
                const SizedBox(height: 8),
              // Skin image preview
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: isDef
                      ? DefaultPreview(isX: skin.type == 'x', xColor: xColor, oColor: oColor)
                      : Image.asset(
                          skin.assetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image_not_supported,
                                color: Colors.white24, size: 32),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              // Status badge
              if (isSelected)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent, width: 0.7),
                  ),
                  child: Text(
                    l10n.selectedBadge,
                    style: safeOrbitron(fontSize: 7, color: accent, fontWeight: FontWeight.w900),
                  ),
                )
              else if (isOwned)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.success.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppPalette.success, width: 0.7),
                  ),
                  child: Text(
                    l10n.ownedBadge,
                    style: safeOrbitron(
                        fontSize: 7, color: AppPalette.success, fontWeight: FontWeight.w900),
                  ),
                )
              else if (isDef)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.success.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppPalette.success, width: 0.7),
                  ),
                  child: Text(
                    l10n.freeBadge,
                    style: safeOrbitron(
                        fontSize: 7, color: AppPalette.success, fontWeight: FontWeight.w900),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/coin/COIN.png',
                        height: 11, fit: BoxFit.contain),
                    const SizedBox(width: 3),
                    Text(
                      '${skin.price}',
                      style: safeOrbitron(
                        fontSize: 9,
                        color: isLeg ? _gold : const Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 6),
              // Action button
              if (!isSelected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: isOwned ? onSelect : (isDef ? onSelect : onBuy),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOwned || isDef
                            ? accent.withOpacity(0.15)
                            : isLeg
                                ? _goldDeep
                                : accent.withOpacity(0.80),
                        foregroundColor: isOwned || isDef ? accent : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: isOwned || isDef
                                  ? accent.withOpacity(0.50)
                                  : Colors.transparent),
                        ),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                      ),
                      child: Text(
                        isOwned || isDef ? 'SELECT' : 'BUY',
                        style: safeOrbitron(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// Small X or O preview using the current color (for the Default card)
class DefaultPreview extends StatelessWidget {
  final bool isX;
  final Color xColor;
  final Color oColor;

  const DefaultPreview({required this.isX, required this.xColor, required this.oColor});

  @override
  Widget build(BuildContext context) {
    const xFixed = Color(0xFFFF3B30);
    const oFixed = Color(0xFF0A84FF);
    final color = isX ? xFixed : oFixed;
    return LayoutBuilder(builder: (ctx, c) {
      final sz = c.maxWidth * 0.80;
      return Center(
        child: SizedBox(
          width: sz,
          height: sz,
          child: isX
              ? CustomPaint(
                  painter: GlowXPainter(color: color),
                )
              : CustomPaint(
                  painter: GlowOPainter(color: color),
                ),
        ),
      );
    });
  }
}

// ── Color Picker Bottom Sheet ────────────────────────────────────────────────


class GlowXPainter extends CustomPainter {
  final Color color;

  const GlowXPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final main = Paint()
      ..shader = LinearGradient(
              colors: [color, Color.lerp(color, Colors.white, 0.18)!])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final p = size.width * 0.18;
    canvas.drawLine(
        Offset(p, p), Offset(size.width - p, size.height - p), glow);
    canvas.drawLine(
        Offset(size.width - p, p), Offset(p, size.height - p), glow);
    canvas.drawLine(
        Offset(p, p), Offset(size.width - p, size.height - p), main);
    canvas.drawLine(
        Offset(size.width - p, p), Offset(p, size.height - p), main);
  }

  @override
  bool shouldRepaint(covariant GlowXPainter oldDelegate) =>
      oldDelegate.color != color;
}

class GlowOPainter extends CustomPainter {
  final Color color;

  const GlowOPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
    final main = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.33, glow);
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.33, main);
  }

  @override
  bool shouldRepaint(covariant GlowOPainter oldDelegate) =>
      oldDelegate.color != color;
}

