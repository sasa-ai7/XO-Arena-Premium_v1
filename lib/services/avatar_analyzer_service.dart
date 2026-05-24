import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_avatar.dart';

class AvatarDimension {
  final double centerDxRatio;
  final double centerDyRatio;
  final double radiusRatio;

  const AvatarDimension({
    required this.centerDxRatio,
    required this.centerDyRatio,
    required this.radiusRatio,
  });

  Map<String, dynamic> toJson() => {
        'x': centerDxRatio,
        'y': centerDyRatio,
        'r': radiusRatio,
      };

  factory AvatarDimension.fromJson(Map<String, dynamic> json) => AvatarDimension(
        centerDxRatio: (json['x'] as num).toDouble(),
        centerDyRatio: (json['y'] as num).toDouble(),
        radiusRatio: (json['r'] as num).toDouble(),
      );
}

/// Hand-tuned dimension overrides for animated GIF avatars whose transparent
/// hole is hard to detect automatically (antialiased edges, multi-frame codecs).
///
/// Values re-tuned 2026-05 so the inner profile photo sits centered and large
/// enough to read clearly inside each GIF's transparent hole — matching the
/// visual weight of the static PNG avatars. If you re-tune these, also bump
/// [_cacheKeyPrefix] so devices on the old cache pick up the new values.
///
/// 2026-05-21: Avatar__7 (Inferno) and Avatar__8 (Celestial) were removed
/// from the catalog — only Avatar__10 (Apex) remains as an animated avatar.
/// See [kRemovedAvatarIds] in lib/models/game_avatar.dart for the fallback
/// contract.
const Map<String, AvatarDimension> _gifDimensionOverrides = {
  'assets/avatar/Avatar__10.gif': AvatarDimension(
    centerDxRatio: 0.50,
    centerDyRatio: 0.50,
    radiusRatio: 0.34,
  ),
};

class AvatarAnalyzerService {
  static final Map<String, AvatarDimension> _memoryCache = {};
  // Bump suffix when [_gifDimensionOverrides] or fallback math changes so
  // existing installs ignore their stale cached dimensions and pick up the
  // new values on next launch.
  // v5 (2026-05-21): Avatar__7 and Avatar__8 removed from the catalog;
  // their stale SharedPreferences entries are now harmless but a prefix
  // bump keeps the cache schema versioned.
  static const String _cacheKeyPrefix = 'avatar_dim_v5_';
  static SharedPreferences? _prefs;
  static Future<void>? _initFuture;

  static Future<void> init() async {
    _initFuture ??= () async {
      _prefs = await SharedPreferences.getInstance();
    }();
    await _initFuture;
  }

  static Future<AvatarDimension> analyze(
    String assetPath, {
    double defaultProfileSizeRatio = 0.80,
    double defaultVerticalOffsetRatio = 0.04,
  }) async {
    if (_memoryCache.containsKey(assetPath)) {
      return _memoryCache[assetPath]!;
    }

    final override = _gifDimensionOverrides[assetPath];
    if (override != null) {
      _memoryCache[assetPath] = override;
      if (kDebugMode) {
        debugPrint('[AVATAR_ANALYSIS] using hardcoded override for $assetPath');
      }
      return override;
    }

    _prefs ??= await SharedPreferences.getInstance();

    final cacheKey = '$_cacheKeyPrefix$assetPath';
    final cachedStr = _prefs!.getString(cacheKey);
    if (cachedStr != null) {
      try {
        final dim = AvatarDimension.fromJson(json.decode(cachedStr));
        _memoryCache[assetPath] = dim;
        if (kDebugMode) {
          debugPrint('[AVATAR_ANALYSIS] cache hit asset=$assetPath');
        }
        return dim;
      } catch (e) {
        // ignore and re-analyze
      }
    }
    if (kDebugMode) {
      debugPrint('[AVATAR_ANALYSIS] lazy analyze asset=$assetPath');
    }

    // Default fallback values based on original manual ratios
    final fallback = AvatarDimension(
      centerDxRatio: 0.5,
      centerDyRatio: 0.5 - defaultVerticalOffsetRatio,
      radiusRatio: defaultProfileSizeRatio / 2,
    );

    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Decode image
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 256,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      final ByteData? rgbaData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgbaData == null) return fallback;

      final int width = image.width;
      final int height = image.height;
      final Uint8List rgbaPixels = rgbaData.buffer.asUint8List();

      // Find the center transparent hole to avoid outer transparent edges.
      // Start near the center and flood fill.
      int startX = width ~/ 2;
      int startY = height ~/ 2;
      
      bool isTransparent(int x, int y) {
        if (x < 0 || x >= width || y < 0 || y >= height) return false;
        final index = (y * width + x) * 4;
        return rgbaPixels[index + 3] < 50; // Alpha < 50 (mostly transparent)
      }

      // If exact center isn't transparent, spiral out to find nearest transparent pixel
      if (!isTransparent(startX, startY)) {
        bool found = false;
        int radius = 1;
        while (!found && radius < width / 3) {
          for (int dx = -radius; dx <= radius; dx++) {
            for (int dy = -radius; dy <= radius; dy++) {
              if (dx.abs() == radius || dy.abs() == radius) {
                if (isTransparent(startX + dx, startY + dy)) {
                  startX += dx;
                  startY += dy;
                  found = true;
                  break;
                }
              }
            }
            if (found) break;
          }
          radius++;
        }
        if (!found) {
          if (kDebugMode) print('No transparent hole found for $assetPath, using fallback.');
          return fallback;
        }
      }

      // Flood fill to find bounding box of the inner hole
      final Set<int> visited = {};
      final List<Point<int>> queue = [Point(startX, startY)];
      visited.add(startY * width + startX);

      int minX = startX;
      int maxX = startX;
      int minY = startY;
      int maxY = startY;

      while (queue.isNotEmpty) {
        final p = queue.removeLast();
        final x = p.x;
        final y = p.y;
        
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;

        // check neighbors
        for (final offset in const [
          Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1)
        ]) {
          final nx = x + offset.x;
          final ny = y + offset.y;
          final idx = ny * width + nx;
          
          if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
            if (!visited.contains(idx) && isTransparent(nx, ny)) {
              // Bound it within 90% of image size to avoid leaking to outer transparent regions
              // if there's a gap.
              bool withinLimits = nx > width * 0.05 && nx < width * 0.95 &&
                                  ny > height * 0.05 && ny < height * 0.95;
              if (withinLimits) {
                visited.add(idx);
                queue.add(Point(nx, ny));
              }
            }
          }
        }
      }

      double cx = (minX + maxX) / 2;
      double cy = (minY + maxY) / 2;
      double r = min((maxX - minX) / 2, (maxY - minY) / 2);

      // Increase radius slightly as the transparent hole might have anti-aliasing edges
      r = r * 1.05;

      final dim = AvatarDimension(
        centerDxRatio: cx / width,
        centerDyRatio: cy / height,
        radiusRatio: r / width,
      );

      _memoryCache[assetPath] = dim;
      await _prefs!.setString(cacheKey, json.encode(dim.toJson()));

      if (kDebugMode) {
        debugPrint('[AVATAR_ANALYSIS] analyzed asset=$assetPath '
            'center=(${dim.centerDxRatio.toStringAsFixed(3)}, ${dim.centerDyRatio.toStringAsFixed(3)}) '
            'r=${dim.radiusRatio.toStringAsFixed(3)}');
      }
      return dim;

    } catch (e) {
      if (kDebugMode) print('Failed to analyze avatar $assetPath: $e');
      return fallback;
    }
  }

  static Future<void> preAnalyzeAll() async {
    await init();
    // Clear stale cached dimensions for overridden GIF avatars so the
    // hand-tuned values take precedence on next analysis pass.
    for (final path in _gifDimensionOverrides.keys) {
      final key = '$_cacheKeyPrefix$path';
      _prefs?.remove(key);
      _memoryCache.remove(path);
    }
    for (final avatar in kGameAvatars) {
      await analyze(avatar.assetPath);
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
  }
}
