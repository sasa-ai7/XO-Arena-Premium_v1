import os
import re

# 1. Update main.dart
main_path = 'lib/main.dart'
with open(main_path, 'r', encoding='utf-8') as f:
    main_code = f.read()

# Remove sound calls
main_code = re.sub(r'^\s*unawaited\(SoundService\(\)\.playPurchaseSound\(\)\);\r?\n', '', main_code, flags=re.MULTILINE)
main_code = re.sub(r'^\s*unawaited\(SoundService\(\)\.playAvatarSound\(\)\);\r?\n', '', main_code, flags=re.MULTILINE)
main_code = re.sub(r'^\s*SoundService\(\)\.playPurchaseSound\(\);\r?\n', '', main_code, flags=re.MULTILINE)

# Update Endgame Logic for Free AI Mode
old_logic = '''    } else {
      final winSubtitle = winner == playerChar
          ? (coinsToAdd > 0 ? "Victory!\\n+$coinsToAdd coins added!" : "Victory!")
          : "Good try. Play again!";
      _showEndDialog(
        title: "${winner} WINS",
        subtitle: winSubtitle,
        icon: Icons.emoji_events_outlined,
        coinsAdded: winner == playerChar ? coinsToAdd : 0,
      );
    }'''

new_logic = '''    } else {
      final isWin = winner == playerChar;
      final winSubtitle = isWin
          ? (coinsToAdd > 0 ? "Victory!\\n+$coinsToAdd coins added!" : "Victory!")
          : "Good try. Play again!";
      _showEndDialog(
        title: "${winner} WINS",
        subtitle: winSubtitle,
        icon: isWin ? Icons.emoji_events_outlined : Icons.sentiment_dissatisfied_outlined,
        coinsAdded: isWin ? coinsToAdd : 0,
      );
    }'''
main_code = main_code.replace(old_logic, new_logic)

# Update EndDialog image
old_image = "              Image.asset('assets/game/skull.png', width: 44, height: 44),\n              const SizedBox(height: 10),\n            Text("
new_image = "              icon == Icons.sentiment_dissatisfied_outlined || icon == Icons.sentiment_very_dissatisfied\n                  ? Image.asset('assets/game/skull.png', width: 44, height: 44)\n                  : Icon(icon, size: 44, color: icon == Icons.handshake ? Colors.blueGrey : const Color(0xFFFFD700)),\n              const SizedBox(height: 10),\n            Text("
main_code = main_code.replace(old_image, new_image)

with open(main_path, 'w', encoding='utf-8') as f:
    f.write(main_code)


# 2. Update sound_service.dart
sound_path = 'lib/services/sound_service.dart'
with open(sound_path, 'r', encoding='utf-8') as f:
    sound_code = f.read()

if "import 'package:flutter/widgets.dart';" not in sound_code:
    sound_code = sound_code.replace("import 'package:shared_preferences/shared_preferences.dart';", "import 'package:flutter/widgets.dart';\nimport 'package:shared_preferences/shared_preferences.dart';")

sound_code = sound_code.replace('class SoundService {', 'class SoundService with WidgetsBindingObserver {')
sound_code = sound_code.replace('Future<void> init() async {', 'Future<void> init() async {\n    WidgetsBinding.instance.addObserver(this);')
sound_code = sound_code.replace('void dispose() {', 'void dispose() {\n    WidgetsBinding.instance.removeObserver(this);')

lifecycle = '''
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _musicPlayer1.pause();
      _musicPlayer2.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_isMusicEnabled) {
        _musicPlayer1.resume();
        _musicPlayer2.resume();
      }
    }
  }

'''
sound_code = sound_code.replace('  Future<void> playTap() async {', lifecycle + '  Future<void> playTap() async {')

sound_code = re.sub(r'  Future<void> playPurchaseSound\(\) async \{[^}]+\n      sfx\.dispose\(\);\n    \}\);\n  \}\n', '', sound_code)
sound_code = re.sub(r'  Future<void> playAvatarSound\(\) async \{[^}]+\n      sfx\.dispose\(\);\n    \}\);\n  \}\n', '', sound_code)

with open(sound_path, 'w', encoding='utf-8') as f:
    f.write(sound_code)

print("Done fixing sounds and dialogs!")
