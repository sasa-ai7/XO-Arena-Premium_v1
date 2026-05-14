import 'package:flutter/material.dart';

const String kAppName = "XO ARENA";
const int kThemePriceCoins = 100;
const int kWinRewardCoins = 15;

/// Neon color palettes for X and O pieces, plus string ↔ Color helpers.
class NeonColors {
  static final List<Color> xColors = [
    const Color(0xFFFF3B30),
    const Color(0xFFFF2D55),
    const Color(0xFFFF375F),
    const Color(0xFFFF6B6B),
    const Color(0xFFFF9500),
    const Color(0xFFFFD60A),
    const Color(0xFF32D74B),
    const Color(0xFF64D2FF),
    const Color(0xFF5E5CE6),
    const Color(0xFFBF5AF2),
    const Color(0xFFFF3AA6),
    const Color(0xFF00FFFF),
    const Color(0xFF30E0A1),
    const Color(0xFFFF0040),
    const Color(0xFFFF8C00),
    const Color(0xFFADFF2F),
    const Color(0xFF00FF7F),
    const Color(0xFF40E0D0),
    const Color(0xFF9370DB),
    const Color(0xFFFF1493),
  ];

  static final List<Color> oColors = [
    const Color(0xFF0A84FF),
    const Color(0xFF32D74B),
    const Color(0xFF64D2FF),
    const Color(0xFF5E5CE6),
    const Color(0xFFBF5AF2),
    const Color(0xFFFFD60A),
    const Color(0xFFFF375F),
    const Color(0xFF30E0A1),
    const Color(0xFFFF6B6B),
    const Color(0xFF00FFFF),
    const Color(0xFFADFF2F),
    const Color(0xFFFF00FF),
    const Color(0xFF00FF7F),
    const Color(0xFFFF8C00),
    const Color(0xFF9370DB),
    const Color(0xFF40E0D0),
    const Color(0xFFFF1493),
    const Color(0xFF7FFF00),
    const Color(0xFFDC143C),
    const Color(0xFF20B2AA),
  ];

  static String colorToString(Color color) =>
      color.value.toRadixString(16).padLeft(8, '0');

  static Color stringToColor(String hex) => Color(int.parse(hex, radix: 16));
}

/// First color costs 100 coins, +50 per index, capped at 1000.
int priceForColorIndex(int index) => (100 + index * 50).clamp(100, 1000);
