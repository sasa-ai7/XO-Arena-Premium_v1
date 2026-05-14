import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../core/keys.dart';
import '../../services/app_mode_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_store.dart';
import '../../services/sound_service.dart';
import '../../utils/ai_engine.dart';
import '../../utils/board_utils.dart';
import '../../widgets/app_ui.dart';
import 'game_widgets.dart';
import '../../screens/home/home_widgets.dart';
import '../../screens/settings/settings_widgets.dart';
import '../../utils/navigation_utils.dart';
import 'game_page.dart';

class FriendSetupPage extends StatefulWidget {
  const FriendSetupPage({super.key});

  @override
  State<FriendSetupPage> createState() => _FriendSetupPageState();
}

class _FriendSetupPageState extends State<FriendSetupPage> {
  PlayerSymbol _symbol = PlayerSymbol.x;
  int _boardSize = 3;
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);

    if (!mounted) return;

    final boardConfig = standardBoardConfig(_boardSize);

    await Navigator.of(context).push(
      xoFadeRoute(GamePage(
        mode: GameMode.friend,
        difficulty: AIDifficulty.easy,
        playerSymbol: _symbol,
        boardSize: boardConfig.boardSize,
        winCondition: boardConfig.winLength,
      )),
    );

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final boardConfig = standardBoardConfig(_boardSize);

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.localSetup,
                        style: titleFont(context).copyWith(fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          ModeHeroCard(
                            eyebrow: l10n.localDuel,
                            title: l10n.headToHeadSetup,
                            subtitle: l10n.headToHeadSubtitle,
                            chips: [
                              ModeInfoChip(
                                icon: Icons.close_rounded,
                                label:
                                    'START ${_symbol == PlayerSymbol.x ? 'X' : 'O'}',
                                color: AppPalette.goldHighlight,
                              ),
                              ModeInfoChip(
                                icon: Icons.grid_view_rounded,
                                label: 'BOARD ${boardConfig.label}',
                                color: AppPalette.homeSky,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AppGlassCard(
                            padding: const EdgeInsets.all(20),
                            borderColor:
                                AppPalette.strokeStrong.withValues(alpha: 0.60),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(l10n.whoStarts,
                                    style: sectionFont(context)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SymbolTile(
                                        label: "X",
                                        selected: _symbol == PlayerSymbol.x,
                                        dimmed: _symbol == PlayerSymbol.o,
                                        onTap: _busy
                                            ? null
                                            : () => setState(
                                                  () =>
                                                      _symbol = PlayerSymbol.x,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SymbolTile(
                                        label: "O",
                                        selected: _symbol == PlayerSymbol.o,
                                        dimmed: _symbol == PlayerSymbol.x,
                                        onTap: _busy
                                            ? null
                                            : () => setState(
                                                  () =>
                                                      _symbol = PlayerSymbol.o,
                                                ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "The chosen symbol takes the opening move in local play.",
                                  textAlign: TextAlign.center,
                                  style:
                                      bodyFont(context).copyWith(fontSize: 12),
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Text(l10n.boardSizeLabel,
                                        style: sectionFont(context)),
                                    const Spacer(),
                                    TinyBadge(
                                      text: boardConfig.label,
                                      color: AppPalette.homeSky,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                BoardSizeSegment(
                                  value: _boardSize,
                                  onChanged: _busy
                                      ? null
                                      : (size) =>
                                          setState(() => _boardSize = size),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.boardSizeHint,
                                  textAlign: TextAlign.center,
                                  style:
                                      bodyFont(context).copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AppPillButton(
                    label: "START LOCAL MATCH",
                    loading: _busy,
                    onPressed: _busy ? null : _start,
                    icon: Icons.play_arrow_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

