import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xo_arena_neon_clash/models/game_avatar.dart';

/// Guards the asset optimization: bundled images were re-encoded to WebP and
/// (for skins/coins/avatars/portraits) renamed to `.webp`. This test proves the
/// engine still decodes them and that they were downsized to sane dimensions,
/// so `Image.asset(...)` keeps rendering skins/avatars/coins/backgrounds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> decode(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec =
        await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  test('re-encoded assets still decode and are downsized', () async {
    const cases = <String, int>{
      'assets/x/x1.webp': 640,
      'assets/o/o1.webp': 640,
      'assets/account/man.webp': 900,
      'assets/coin/COIN.webp': 320,
      'assets/XO-BACK.png': 1200,
    };
    for (final entry in cases.entries) {
      final img = await decode(entry.key);
      expect(img.width, greaterThan(0), reason: '${entry.key} decoded width');
      expect(img.width, lessThanOrEqualTo(entry.value),
          reason: '${entry.key} should be downsized');
      img.dispose();
    }
  });

  test('every catalog avatar frame decodes at a sane size', () async {
    for (final avatar in kGameAvatars) {
      final img = await decode(avatar.assetPath);
      expect(img.width, greaterThan(0),
          reason: '${avatar.assetPath} (id ${avatar.id}) decoded width');
      // New frame art tops out at ~1254px; guard against anything oversized
      // slipping back in.
      expect(img.width, lessThanOrEqualTo(1500),
          reason: '${avatar.assetPath} should be a reasonable frame size');
      img.dispose();
    }
  });

  test('invite artwork decodes at a wide uncropped composition', () async {
    final image = await decode('assets/online/hedy.webp');
    expect(image.width, greaterThan(0));
    expect(image.height, greaterThan(0));
    expect(image.width / image.height, greaterThan(1.6),
        reason: 'the card relies on the artwork-safe area at the right');
    image.dispose();
  });
}
