import 'package:flutter/material.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/neon_colors.dart';
import '../../models/xo_skin.dart';
import 'skins_tab.dart';

class _ColorPickerSheet extends StatefulWidget {
  final bool isX;
  final Set<int> ownedColors;
  final int selectedIndex;
  final Future<void> Function(int) onBuy;
  final int coins;

  const _ColorPickerSheet({
    required this.isX,
    required this.ownedColors,
    required this.selectedIndex,
    required this.onBuy,
    required this.coins,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  bool _buying = false;

  List<Color> get _colors =>
      widget.isX ? NeonColors.xColors : NeonColors.oColors;

  Color get _accent =>
      widget.isX ? AppPalette.homeCyan : AppPalette.accentPurple;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.panelDeep,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _accent.withOpacity(0.20), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.isX ? l10n.xColorsSection : l10n.oColorsSection,
            style: safeOrbitron(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: _accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.eachColorCosts,
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: _colors.length,
            itemBuilder: (ctx, i) {
              final color = _colors[i];
              final owned = widget.ownedColors.contains(i);
              final selected = widget.selectedIndex == i;
              return GestureDetector(
                onTap: _buying
                    ? null
                    : () async {
                        if (owned) {
                          // Just select it
                          Navigator.pop(context);
                          await widget.onBuy(i);
                        } else {
                          final price = 1000;
                          if (widget.coins < price) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.notEnoughCoinsColor(price),
                                    style: safeOrbitron(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                  ),
                                  backgroundColor: AppPalette.warning,
                                ),
                              );
                            }
                            return;
                          }
                          setState(() => _buying = true);
                          await widget.onBuy(i);
                          if (mounted) setState(() => _buying = false);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: color.withOpacity(owned ? 0.22 : 0.10),
                    border: Border.all(
                      color: selected
                          ? color
                          : owned
                              ? color.withOpacity(0.50)
                              : Colors.white12,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.30),
                              blurRadius: 10,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: widget.isX
                            ? CustomPaint(painter: GlowXPainter(color: color))
                            : CustomPaint(painter: GlowOPainter(color: color)),
                      ),
                      const SizedBox(height: 4),
                      if (selected)
                        Text('✓',
                            style: TextStyle(
                                fontSize: 9,
                                color: color,
                                fontWeight: FontWeight.w900))
                      else if (owned)
                        Text(l10n.ownedBadge,
                            style: safeOrbitron(
                                fontSize: 6,
                                color: AppPalette.success,
                                fontWeight: FontWeight.w700))
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monetization_on_rounded,
                                size: 8, color: Color(0xFFFFD700)),
                            const SizedBox(width: 1),
                            Text('1K',
                                style: safeOrbitron(
                                    fontSize: 7,
                                    color: const Color(0xFFFFD700),
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Redesigned ColorsTab ────────────────────────────────────────────────────

class ColorsTab extends StatefulWidget {
  final List<int> ownedX;
  final List<int> ownedO;
  final int selectedXIndex;
  final int selectedOIndex;
  final Future<void> Function(int) onBuyX;
  final Future<void> Function(int) onBuyO;
  final bool busy;

  // Skin props
  final List<String> ownedXSkins;
  final List<String> ownedOSkins;
  final String selectedXSkin;
  final String selectedOSkin;
  final Future<void> Function(String, int) onBuyXSkin;
  final Future<void> Function(String, int) onBuyOSkin;
  final Future<void> Function(String) onSelectXSkin;
  final Future<void> Function(String) onSelectOSkin;
  final int coins;

  const ColorsTab({
    super.key,
    required this.ownedX,
    required this.ownedO,
    required this.selectedXIndex,
    required this.selectedOIndex,
    required this.onBuyX,
    required this.onBuyO,
    required this.busy,
    required this.ownedXSkins,
    required this.ownedOSkins,
    required this.selectedXSkin,
    required this.selectedOSkin,
    required this.onBuyXSkin,
    required this.onBuyOSkin,
    required this.onSelectXSkin,
    required this.onSelectOSkin,
    required this.coins,
  });

  @override
  State<ColorsTab> createState() => _ColorsTabState();
}

class _ColorsTabState extends State<ColorsTab> {
  int _subTab = 0; // 0 = X, 1 = O

  Color get _xColor => NeonColors
      .xColors[widget.selectedXIndex.clamp(0, NeonColors.xColors.length - 1)];
  Color get _oColor => NeonColors
      .oColors[widget.selectedOIndex.clamp(0, NeonColors.oColors.length - 1)];

  // Retained for the optional color-palette mode.
  // ignore: unused_element
  void _openColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ColorPickerSheet(
        isX: _subTab == 0,
        ownedColors:
            _subTab == 0 ? widget.ownedX.toSet() : widget.ownedO.toSet(),
        selectedIndex:
            _subTab == 0 ? widget.selectedXIndex : widget.selectedOIndex,
        onBuy: _subTab == 0 ? widget.onBuyX : widget.onBuyO,
        coins: widget.coins,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isX = _subTab == 0;
    final accent = isX ? AppPalette.homeCyan : AppPalette.accentPurple;
    final skins = isX ? xSkinCatalog : oSkinCatalog;
    final ownedSkins =
        isX ? widget.ownedXSkins.toSet() : widget.ownedOSkins.toSet();
    final selectedSkin = isX ? widget.selectedXSkin : widget.selectedOSkin;
    final totalSkins = skins.length - 1; // exclude default
    final ownedCount = ownedSkins.where((id) => id != 'default').length;

    return Column(
      children: [
        XOSubTabBar(
          selectedIndex: _subTab,
          onChanged: (i) => setState(() => _subTab = i),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                        boxShadow: [
                          BoxShadow(
                              color: accent.withOpacity(0.30), blurRadius: 10)
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isX ? 'X SKINS' : 'O SKINS',
                      style: safeOrbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: accent.withOpacity(0.22)),
                      ),
                      child: Text(
                        '$ownedCount/$totalSkins',
                        style: safeOrbitron(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withOpacity(0.32),
                              Colors.transparent
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Skin grid (3 columns)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: skins.length,
                  itemBuilder: (ctx, i) {
                    final skin = skins[i];
                    final owned =
                        ownedSkins.contains(skin.id) || skin.isDefault;
                    final selected = selectedSkin == skin.id;
                    return SkinCard(
                      skin: skin,
                      isOwned: owned,
                      isSelected: selected,
                      accent: accent,
                      xColor: _xColor,
                      oColor: _oColor,
                      onBuy: widget.busy
                          ? null
                          : () => isX
                              ? widget.onBuyXSkin(skin.id, skin.price)
                              : widget.onBuyOSkin(skin.id, skin.price),
                      onSelect: widget.busy
                          ? null
                          : () => isX
                              ? widget.onSelectXSkin(skin.id)
                              : widget.onSelectOSkin(skin.id),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Retained for the optional color-palette mode.
// ignore: unused_element
class _ColorTile extends StatelessWidget {
  final int index;
  final bool isX;
  final Color color;
  final bool isOwned;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ColorTile({
    required this.index,
    required this.isX,
    required this.color,
    required this.isOwned,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(
                  AppPalette.panelElevated, color, isOwned ? 0.12 : 0.04)!,
              AppPalette.panelDeep,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.80)
                : (isOwned
                    ? color.withValues(alpha: 0.42)
                    : AppPalette.homeStroke.withOpacity(0.16)),
            width: isOwned || isSelected ? 1.5 : 1,
          ),
          boxShadow: isOwned || isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: isSelected ? 0.26 : 0.18),
                    blurRadius: 16,
                    spreadRadius: -2,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            SizedBox(
              width: 44,
              height: 44,
              child: isX
                  ? CustomPaint(painter: GlowXPainter(color: color))
                  : CustomPaint(painter: GlowOPainter(color: color)),
            ),
            const SizedBox(height: 8),
            if (isOwned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isSelected ? color : AppPalette.success)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: (isSelected ? color : AppPalette.success),
                      width: 0.5),
                ),
                child: Text(isSelected ? l10n.selectedBadge : l10n.ownedBadge,
                    style: safeOrbitron(
                        fontSize: 8,
                        color: isSelected ? color : AppPalette.success,
                        fontWeight: FontWeight.w700)),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/coin/COIN.webp',
                    height: 14,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${priceForColorIndex(index)}',
                    style: safeOrbitron(
                        fontSize: 10,
                        color: const Color(0xFFFFD700),
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
