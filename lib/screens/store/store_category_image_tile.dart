import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// A Store top-category tile that shows a finished square category image
/// (`assets/e1..e4.webp`). Those images already include their own neon
/// rounded border and label text, so this widget deliberately adds NO
/// Flutter border, frame, or external glow around the art — it only clips to
/// a rounded rectangle and, when [selected], overlays a subtle green/cyan
/// highlight so the active category reads clearly without crowding the design.
class StoreCategoryImageTile extends StatelessWidget {
  const StoreCategoryImageTile({
    super.key,
    required this.assetPath,
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    required this.label,
  });

  final String assetPath;
  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;
  final String label;

  @override
  Widget build(BuildContext context) {
    const double radius = 22;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          scale: selected ? 1.03 : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Category exports include their own complete rounded card.
                      // Contain with breathing room keeps every edge and label in
                      // the artwork visible; no scaling or cover-crop is applied.
                      Padding(
                        padding: const EdgeInsets.all(3),
                        child: Image.asset(
                          assetPath,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: AppPalette.panelDeep,
                            child: Icon(Icons.image_not_supported_outlined,
                                color: AppPalette.textSubtle, size: 22),
                          ),
                        ),
                      ),
                      // Selected highlight: a soft green/cyan inner glow that does
                      // NOT cover the art. Unselected tiles get a gentle dim so the
                      // active one pops.
                      IgnorePointer(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius),
                            gradient: selected
                                ? LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppPalette.success.withOpacity(0.34),
                                      AppPalette.primary.withOpacity(0.10),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  )
                                : null,
                            color: selected
                                ? null
                                : Colors.black.withOpacity(0.34),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: safeOrbitron(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                  color: selected ? AppPalette.success : AppPalette.textMuted,
                ),
                child:
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
