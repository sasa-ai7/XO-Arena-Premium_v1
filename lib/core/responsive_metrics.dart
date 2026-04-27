import 'package:flutter/widgets.dart';

enum DeviceSizeClass { compact, regular, expanded }

class UiMetrics {
  final DeviceSizeClass sizeClass;
  final bool isLandscape;

  const UiMetrics._({
    required this.sizeClass,
    required this.isLandscape,
  });

  factory UiMetrics.of(BoxConstraints constraints, Orientation orientation) {
    final width = constraints.maxWidth;
    final sizeClass = width < 380
        ? DeviceSizeClass.compact
        : width < 700
            ? DeviceSizeClass.regular
            : DeviceSizeClass.expanded;
    return UiMetrics._(
      sizeClass: sizeClass,
      isLandscape: orientation == Orientation.landscape,
    );
  }

  factory UiMetrics.fromSize(Size size, Orientation orientation) {
    return UiMetrics.of(
      BoxConstraints.tightFor(width: size.width, height: size.height),
      orientation,
    );
  }

  double get cardRadius => switch (sizeClass) {
        DeviceSizeClass.compact => 20,
        DeviceSizeClass.regular => 24,
        DeviceSizeClass.expanded => 26,
      };

  double get cardGap => switch (sizeClass) {
        DeviceSizeClass.compact => 10,
        DeviceSizeClass.regular => 14,
        DeviceSizeClass.expanded => 16,
      };

  double get horizontalPadding => switch (sizeClass) {
        DeviceSizeClass.compact => 12,
        DeviceSizeClass.regular => 18,
        DeviceSizeClass.expanded => 22,
      };

  double get storeCardAspectRatio => switch (sizeClass) {
        DeviceSizeClass.compact => 0.76,
        DeviceSizeClass.regular => 0.79,
        DeviceSizeClass.expanded => 0.82,
      };

  double get coinsCardAspectRatio => switch (sizeClass) {
        DeviceSizeClass.compact => 0.72,
        DeviceSizeClass.regular => 0.76,
        DeviceSizeClass.expanded => 0.78,
      };

  int coinsColumns(double width) {
    if (width >= 980) return 4;
    if (width >= 700) return 3;
    return 2;
  }

  double get previewAreaRatio => 0.52;
  double get textAreaRatio => 0.21;
  double get actionAreaRatio => 0.17;

  double get buttonHeight => switch (sizeClass) {
        DeviceSizeClass.compact => 40,
        DeviceSizeClass.regular => 42,
        DeviceSizeClass.expanded => 44,
      };

  double get buttonFontSize => switch (sizeClass) {
        DeviceSizeClass.compact => 10.8,
        DeviceSizeClass.regular => 11.8,
        DeviceSizeClass.expanded => 12.6,
      };

  double get buttonLetterSpacing => switch (sizeClass) {
        DeviceSizeClass.compact => 1.2,
        DeviceSizeClass.regular => 1.5,
        DeviceSizeClass.expanded => 1.8,
      };

  double get homeGridAspectRatio => switch (sizeClass) {
        DeviceSizeClass.compact => isLandscape ? 1.15 : 1.02,
        DeviceSizeClass.regular => isLandscape ? 1.08 : 0.98,
        DeviceSizeClass.expanded => 0.98,
      };

  double get homeCardImageShare => switch (sizeClass) {
        DeviceSizeClass.compact => 0.62,
        DeviceSizeClass.regular => 0.60,
        DeviceSizeClass.expanded => 0.58,
      };

  double get tabBarHeight => switch (sizeClass) {
        DeviceSizeClass.compact => 52,
        DeviceSizeClass.regular => 54,
        DeviceSizeClass.expanded => 58,
      };

  double get tabLabelSize => switch (sizeClass) {
        DeviceSizeClass.compact => 8.5,
        DeviceSizeClass.regular => 9.5,
        DeviceSizeClass.expanded => 10.0,
      };
}
