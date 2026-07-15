import 'package:flutter/material.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/coin_format.dart';
import '../../models/xo_skin.dart';
import '../../widgets/app_ui.dart';
import 'store_product_card.dart';

class XOSubTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const XOSubTabBar({super.key, required this.selectedIndex, required this.onChanged});

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

  const SkinCard({super.key, 
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isLeg = skin.isLegendary;
    final isDef = skin.isDefault;
    // "Owned" for card purposes includes the free default.
    final owned = isOwned || isDef;

    // Preview: default cards paint the current color glyph; image skins show
    // their WebP art with a graceful fallback.
    final preview = isDef
        ? DefaultPreview(isX: skin.type == 'x', xColor: xColor, oColor: oColor)
        : Image.asset(
            skin.assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.image_not_supported,
                  color: Colors.white24, size: 32),
            ),
          );

    // Top-left status tag: LEGENDARY for premium skins, FREE for the default.
    Widget? topTag;
    if (isLeg) {
      topTag = const StoreCardTag(label: 'LEGENDARY', color: _gold);
    } else if (isDef && !isSelected) {
      topTag = StoreCardTag(label: l10n.freeBadge, color: AppPalette.success);
    }

    // Action button — green BUY when locked, accent SELECT when owned, and a
    // green disabled SELECTED pill when currently equipped.
    final Widget button;
    if (isSelected) {
      button = AppPillButton(
        label: l10n.selectedBadge,
        fill: StoreCardSpec.activeGreen,
        stroke: StoreCardSpec.activeGreen.withOpacity(0.55),
        onPressed: null,
        icon: Icons.check_rounded,
        labelFontSize: 10,
        labelLetterSpacing: 0.6,
      );
    } else if (owned) {
      button = AppPillButton(
        label: 'SELECT',
        fill: Colors.white.withOpacity(0.04),
        stroke: accent.withOpacity(0.50),
        iconColor: accent,
        icon: Icons.bolt_rounded,
        onPressed: onSelect,
        labelFontSize: 10,
        labelLetterSpacing: 0.6,
      );
    } else {
      button = storeBuyButton(
        label: l10n.buyWithPrice(formatCoins(skin.price)),
        onPressed: onBuy,
        leading: Image.asset('assets/coin/COIN.webp',
            height: 12, fit: BoxFit.contain),
      );
    }

    return StoreProductCard(
      onTap: owned ? (isSelected ? null : onSelect) : onBuy,
      active: isSelected,
      owned: owned,
      activeColor: accent,
      topTag: topTag,
      preview: preview,
      button: button,
    );
  }
}

// Small X or O preview using the current color (for the Default card)
class DefaultPreview extends StatelessWidget {
  final bool isX;
  final Color xColor;
  final Color oColor;

  const DefaultPreview({super.key, required this.isX, required this.xColor, required this.oColor});

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

