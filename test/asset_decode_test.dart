import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the Stage 6 asset optimization: several bundled images were
/// re-encoded to WebP *content* while keeping their original `.png` filenames
/// (Flutter decodes by byte signature, not by extension). This test proves the
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
      'assets/x/x1.png': 640,
      'assets/o/o1.png': 640,
      'assets/avatar/Avatar__1.png': 640,
      'assets/account/man.png': 900,
      'assets/coin/COIN.png': 320,
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
}
