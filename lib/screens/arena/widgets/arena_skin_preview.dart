import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Premium glassy preview of a player's equipped X or O cosmetic skin.
///
/// Used in both the Arena lobby (below each player's profile photo) and the
/// in-game player card (in the "YOUR MARK" / "OPPONENT MARK" slot). Falls
/// back to a glowing letter when no custom skin is equipped or when the
/// asset is missing — so a missing/renamed asset on the opponent's side
/// never crashes the screen.
class ArenaSkinPreview extends StatelessWidget {
  /// 'X' or 'O' — empty string renders a neutral "?" placeholder (used for
  /// the empty guest seat in the lobby).
  final String symbol;
  final String? xSkin;
  final String? oSkin;
  final double size;

  const ArenaSkinPreview({
    super.key,
    required this.symbol,
    this.xSkin,
    this.oSkin,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    if (symbol.isEmpty) {
      return _PlaceholderSlot(size: size);
    }
    final isX = symbol.toUpperCase() == 'X';
    final skin = isX ? xSkin : oSkin;
    final hasCustomSkin =
        skin != null && skin.isNotEmpty && skin != 'default';
    final tint = isX ? AppPalette.danger : AppPalette.primary;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.31),
        gradient: LinearGradient(
          colors: [
            tint.withValues(alpha: 0.18),
            AppPalette.panelDeep.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: tint.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.28),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.contain,
        child: hasCustomSkin
            ? Image.asset(
                'assets/${isX ? 'x' : 'o'}/$skin.webp',
                width: size * 0.72,
                height: size * 0.72,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _FallbackMark(symbol: symbol, color: tint, size: size),
              )
            : _FallbackMark(symbol: symbol, color: tint, size: size),
      ),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  final String symbol;
  final Color color;
  final double size;

  const _FallbackMark({
    required this.symbol,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Text(
        symbol.toUpperCase(),
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          fontFamily: 'Orbitron',
          color: color,
          shadows: [
            Shadow(color: color, blurRadius: 18),
            Shadow(color: color.withValues(alpha: 0.5), blurRadius: 32),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderSlot extends StatelessWidget {
  final double size;

  const _PlaceholderSlot({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.31),
        color: AppPalette.panelDeep.withValues(alpha: 0.6),
        border: Border.all(
          color: AppPalette.strokeSoft,
          width: 1,
        ),
      ),
      child: Text(
        '?',
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w900,
          color: AppPalette.textSubtle,
        ),
      ),
    );
  }
}
