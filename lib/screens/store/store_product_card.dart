import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/app_ui.dart';

/// Shared visual language for Store product cards (X/O skins, avatars, emojis)
/// so every section reads as one store. The Coins pack cards intentionally keep
/// their own design and do not use these helpers.
///
/// All product cards use [AppGlassCard] as the shell and [AppPillButton] as the
/// action button; these helpers centralize the radius, padding, border colors,
/// badges, and the GREEN purchase button so the sections stay in sync.
class StoreCardSpec {
  StoreCardSpec._();

  static const double radius = 18;
  static const EdgeInsets padding = EdgeInsets.all(9);
  static const double buttonHeight = 34;

  /// Coin-spend / purchase button is always green.
  static const Color buyFill = AppPalette.success;
  static Color get buyStroke => AppPalette.success.withOpacity(0.55);

  /// Equipped / selected (active) accents.
  static const Color activeGreen = Color(0xFF3DCC6E);

  /// Border color for a product card given its ownership state.
  static Color borderColor({
    required bool active,
    required bool owned,
    Color? activeColor,
  }) {
    if (active) return (activeColor ?? activeGreen).withOpacity(0.88);
    if (owned) return AppPalette.primary.withOpacity(0.40);
    return AppPalette.gold.withOpacity(0.34);
  }

  /// Background tint for a product card given its state.
  static Color? backgroundColor({required bool active, Color? activeColor}) {
    if (active) {
      return Color.lerp(
          AppPalette.panelElevated, activeColor ?? activeGreen, 0.22);
    }
    return AppPalette.panel;
  }
}

/// A small rounded status tag (FREE / OWNED / SELECTED / LEGENDARY …).
class StoreCardTag extends StatelessWidget {
  const StoreCardTag({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.75), width: 0.7),
      ),
      child: Text(
        label,
        style: safeOrbitron(
            fontSize: 8, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}

/// The unified product-card shell: glass card + preview area + action button,
/// with an optional top-left tag. Tapping the card triggers [onTap].
class StoreProductCard extends StatelessWidget {
  const StoreProductCard({
    super.key,
    required this.preview,
    required this.button,
    this.topTag,
    this.active = false,
    this.owned = false,
    this.activeColor,
    this.onTap,
  });

  final Widget preview;
  final Widget button;
  final Widget? topTag;
  final bool active;
  final bool owned;
  final Color? activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: AppGlassCard(
          padding: StoreCardSpec.padding,
          radius: StoreCardSpec.radius,
          borderColor: StoreCardSpec.borderColor(
              active: active, owned: owned, activeColor: activeColor),
          backgroundColor: StoreCardSpec.backgroundColor(
              active: active, activeColor: activeColor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (topTag != null)
                Align(alignment: Alignment.centerLeft, child: topTag!),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: preview,
                ),
              ),
              SizedBox(height: StoreCardSpec.buttonHeight, child: button),
            ],
          ),
        ),
      ),
    );
  }
}

/// The green coin-spend purchase button, consistent across all sections.
AppPillButton storeBuyButton({
  required String label,
  required VoidCallback? onPressed,
  Widget? leading,
}) {
  return AppPillButton(
    label: label,
    fill: StoreCardSpec.buyFill,
    stroke: StoreCardSpec.buyStroke,
    onPressed: onPressed,
    leading: leading,
    leadingSlotWidth: leading == null ? 0 : 14,
    fitLabel: true,
    labelFontSize: 10,
    labelLetterSpacing: 0.4,
  );
}
