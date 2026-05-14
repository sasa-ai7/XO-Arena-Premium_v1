import 'package:flutter/material.dart';

class AppPalette {
  static const Color bgTop = Color(0xFF040A14);
  static const Color bgBottom = Color(0xFF091426);
  static const Color bgDepth = Color(0xFF020712);

  static const Color surface = Color(0xFF0D1627);
  static const Color surface2 = Color(0xFF101A2C);
  static const Color panel = Color(0xFF0B1322);
  static const Color panelSoft = Color(0xFF111D31);
  static const Color panelDeep = Color(0xFF08101C);
  static const Color panelElevated = Color(0xFF15243A);
  static const Color glassHighlight = Color(0x1AD4F4FF);

  static const Color stroke = Color(0x615FD7FF);
  static const Color strokeStrong = Color(0x8858D8FF);
  static const Color strokeSoft = Color(0x3368C7EA);

  static const Color text = Color(0xFFF5FAFF);
  static const Color textMuted = Color(0xFFB7C6D8);
  static const Color textSubtle = Color(0xFF7E8FA5);

  static const Color primary = Color(0xFF58D8FF);
  static const Color primary2 = Color(0xFF2EA8FF);
  static const Color accentBlue = Color(0xFF1D6BFF);
  static const Color accentPurple = Color(0xFFB25CFF);
  static const Color gold = Color(0xFFF4C14D);
  static const Color goldDeep = Color(0xFFD89B1D);
  static const Color goldHighlight = Color(0xFFFFD96A);

  static const Color danger = Color(0xFFFF5E6A);
  static const Color success = Color(0xFF34D17B);
  static const Color warning = goldHighlight;
  static const Color rarityCommon = Color(0xFF6887A2);
  static const Color rarityRare = primary;
  static const Color rarityEpic = accentPurple;
  static const Color rarityLegendary = gold;
  static const Color rarityAnimated = Color(0xFFFFB35C);

  static const Color homeBgBase = bgTop;
  static const Color homeBgSecondary = bgBottom;
  static const Color homeSurface = surface2;
  static const Color homeSurface2 = panel;
  static const Color homePanel = Color(0xF20D1627);
  static const Color homePanelStrong = Color(0xF50B1322);
  static const Color homePanelDeep = Color(0xFA08101C);
  static const Color homeStroke = stroke;
  static const Color homeStrokeStrong = Color(0x9958D8FF);
  static const Color homeCyan = primary;
  static const Color homeSky = primary2;
  static const Color homeBlue = accentBlue;
  static const Color homePurple = accentPurple;
  static const Color homePink = Color(0xFFD87CFF);
  static const Color homeGold = gold;
  static const Color homeTitle = text;
  static const Color homeBody = textMuted;
  static const Color homeMuted = textSubtle;

  static const double radius = 20.0;
  static const double radiusSmall = 14.0;
}

TextStyle safeOrbitron({
  required double fontSize,
  required FontWeight fontWeight,
  double letterSpacing = 0.0,
  required Color color,
  List<Shadow>? shadows,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Orbitron',
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    color: color,
    shadows: shadows,
    height: height,
  );
}

TextStyle safeInter({
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
  double? letterSpacing,
  double? height,
}) {
  // Uses the locally bundled Inter family (registered in pubspec.yaml).
  // The previous implementation fetched Rajdhani over the network via
  // google_fonts, which spammed errors and crashed offline mode.
  return TextStyle(
    fontFamily: 'Inter',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

TextStyle _safeOrbitron({
  required double fontSize,
  required FontWeight fontWeight,
  double letterSpacing = 0.0,
  required Color color,
  List<Shadow>? shadows,
  double? height,
}) => safeOrbitron(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      shadows: shadows,
      height: height,
    );

TextStyle _safeInter({
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
  double? letterSpacing,
  double? height,
}) => safeInter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

TextStyle titleFont(BuildContext context) => _safeOrbitron(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: 2.1,
      color: AppPalette.text,
      height: 1.02,
      shadows: [
        Shadow(
          color: AppPalette.primary.withValues(alpha: 0.28),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        Shadow(
          color: AppPalette.accentBlue.withValues(alpha: 0.14),
          blurRadius: 36,
          offset: const Offset(0, 12),
        ),
      ],
    );

TextStyle sectionFont(BuildContext context) => _safeOrbitron(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.6,
      color: AppPalette.primary,
      height: 1.15,
    );

TextStyle bodyFont(BuildContext context) => _safeInter(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppPalette.textMuted,
      height: 1.32,
    );

TextStyle buttonFont(BuildContext context) => _safeOrbitron(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      letterSpacing: 2.0,
      color: AppPalette.text,
      height: 1.1,
    );

TextStyle homeOrbitron({
  required double fontSize,
  required FontWeight fontWeight,
  double letterSpacing = 0.0,
  Color color = AppPalette.homeTitle,
  List<Shadow>? shadows,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Orbitron',
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    color: color,
    shadows: shadows,
    height: height,
  );
}

TextStyle homeInter({
  required double fontSize,
  required FontWeight fontWeight,
  Color color = AppPalette.homeBody,
  double? letterSpacing,
  double? height,
}) {
  // Locally bundled Inter (see pubspec.yaml). Was GoogleFonts.rajdhani
  // before, which caused offline crashes and zone errors.
  return TextStyle(
    fontFamily: 'Inter',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

TextStyle homeTitleFont(
  BuildContext context, {
  double fontSize = 22,
  Color color = AppPalette.homeTitle,
}) =>
    homeOrbitron(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.8,
      color: color,
      height: 1.02,
      shadows: [
        Shadow(
          color: AppPalette.homeCyan.withValues(alpha: 0.30),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        Shadow(
          color: AppPalette.homeBlue.withValues(alpha: 0.14),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
    );

TextStyle homeLabelFont(
  BuildContext context, {
  double fontSize = 10,
  Color color = AppPalette.homeCyan,
}) =>
    homeOrbitron(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.4,
      color: color,
      height: 1.2,
    );

TextStyle homeBodyFont(
  BuildContext context, {
  double fontSize = 13,
  Color color = AppPalette.homeBody,
  FontWeight fontWeight = FontWeight.w500,
}) =>
    homeInter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );

TextStyle brandFont(
  BuildContext context, {
  double fontSize = 32,
  Color color = AppPalette.text,
}) =>
    homeOrbitron(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 4.2,
      color: color,
      height: 0.98,
      shadows: [
        Shadow(
          color: AppPalette.homeCyan.withValues(alpha: 0.34),
          blurRadius: 28,
          offset: const Offset(0, 8),
        ),
        Shadow(
          color: AppPalette.homeBlue.withValues(alpha: 0.14),
          blurRadius: 40,
          offset: const Offset(0, 14),
        ),
      ],
    );

TextStyle statNumberFont(
  BuildContext context, {
  double fontSize = 28,
  Color color = AppPalette.text,
}) =>
    homeOrbitron(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.0,
      color: color,
      height: 1.0,
    );
