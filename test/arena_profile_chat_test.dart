import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xo_arena_neon_clash/models/arena/arena_chat_signal.dart';
import 'package:xo_arena_neon_clash/models/game_avatar.dart';
import 'package:xo_arena_neon_clash/screens/arena/widgets/quick_emoji_bar.dart';
import 'package:xo_arena_neon_clash/services/referral/referral_service.dart';
import 'package:xo_arena_neon_clash/widgets/full_avatar_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  bool hasAsset(WidgetTester tester, String assetName) {
    return tester.widgetList<Image>(find.byType(Image)).any((image) {
      final provider = image.image;
      return provider is AssetImage && provider.assetName == assetName;
    });
  }

  testWidgets('equipped frame overlays the real profile image', (tester) async {
    final avatar = gameAvatarById(1);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ArenaProfileAvatar(
            size: 96,
            localProfileImageAsset: 'assets/account/man.png',
            equippedAvatarFrameAsset: avatar.assetPath,
            equippedAvatar: avatar,
            fallbackInitials: 'XO',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(hasAsset(tester, 'assets/account/man.png'), isTrue);
    expect(hasAsset(tester, avatar.assetPath), isTrue);
  });

  testWidgets('no equipped frame renders only the normal profile image',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ArenaProfileAvatar(
            size: 96,
            localProfileImageAsset: 'assets/account/man.png',
            fallbackInitials: 'XO',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(hasAsset(tester, 'assets/account/man.png'), isTrue);
    expect(hasAsset(tester, 'assets/avatar/Avatar__1.webp'), isFalse);
  });

  test('stored avatar values accept legacy numeric strings safely', () {
    expect(parseEquippedAvatarId('7'), 7);
    expect(parseEquippedAvatarId(10), 10);
    expect(parseEquippedAvatarId('8'), 8); // id 8 is a catalog avatar again
    expect(parseEquippedAvatarId('999'), 0); // unknown → no frame
    expect(parseEquippedAvatarId('not-an-avatar'), 0);
  });

  test('chat signals parse valid reactions and reject malformed payloads', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Reactions now carry an emoji catalog id (image emoji), not a Unicode char.
    final signal = ArenaChatSignal.tryParse(
      <String, Object>{
        'type': 'emoji',
        'senderUid': 'player-1',
        'senderName': 'PLAYER',
        'payload': 'arena1',
        'sentAtMs': now,
        'clientSentAtMs': now,
        'nonce': '1',
      },
      expectedUid: 'player-1',
    );

    expect(signal, isNotNull);
    expect(signal!.isEmoji, isTrue);
    expect(signal.isFresh(nowMs: now), isTrue);
    expect(
      ArenaChatSignal.tryParse(
        <String, Object>{
          'type': 'emoji',
          'senderUid': 'player-1',
          'senderName': 'PLAYER',
          'payload': '🚫',
          'sentAtMs': now,
          'clientSentAtMs': now,
          'nonce': '2',
        },
        expectedUid: 'player-1',
      ),
      isNull,
    );
  });

  testWidgets('quick emoji bar suppresses double taps for three seconds',
      (tester) async {
    var sends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickEmojiBar(
            emojis: const <String>['arena1'],
            showLabel: false,
            decorated: false,
            onSelected: (_) async => sends++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(sends, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(sends, 2);
  });

  test('referral reward remains one thousand coins', () {
    expect(ReferralService.kRewardPerFriend, 1000);
  });
}
