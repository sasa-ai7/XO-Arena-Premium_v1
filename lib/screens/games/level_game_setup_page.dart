import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../services/local_store.dart';
import '../../utils/board_utils.dart';
import '../../widgets/app_ui.dart';
import 'game_widgets.dart';
import '../../screens/home/home_widgets.dart';
import '../../utils/navigation_utils.dart';
import 'level_game_page.dart';

class LevelGameSetupPage extends StatefulWidget {
  const LevelGameSetupPage({super.key});

  @override
  State<LevelGameSetupPage> createState() => _LevelGameSetupPageState();
}

class _LevelGameSetupPageState extends State<LevelGameSetupPage> {
  int _currentLevel = 1;
  bool _loading = true;
  PlayerSymbol _symbol = PlayerSymbol.x;
  final DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadLevel);
  }

  Future<void> _loadLevel() async {
    try {
      final level = await LocalStore.getLevelGameCurrentLevel().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint(
                '[LevelGameSetupPage] _loadLevel timeout - using default level 1');
          }
          return 1; // Fallback to level 1 if timeout
        },
      );
      if (mounted) {
        setState(() {
          _currentLevel = level;
          _loading = false;
        });
        if (kDebugMode) {
          final ms = DateTime.now().difference(_openedAt).inMilliseconds;
          debugPrint('[PERF] level_open_ms=$ms');
        }
      }
    } catch (e) {
      // If any error occurs, fallback to level 1 and hide loading
      if (kDebugMode) {
        debugPrint('[LevelGameSetupPage] _loadLevel error: $e');
      }
      if (mounted) {
        setState(() {
          _currentLevel = 1;
          _loading = false;
        });
      }
    }
  }

  Future<void> _start() async {
    await Navigator.of(context).push(
      xoFadeRoute(LevelGamePage(
          initialLevel: _currentLevel, playerSymbol: _symbol)),
    );
    await _loadLevel();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (_loading) {
      return Scaffold(
        body: SafeArea(
          child: AppBackground(
            child: const Center(
              child: CircularProgressIndicator(color: AppPalette.primary),
            ),
          ),
        ),
      );
    }

    final progress = _currentLevel / 20;
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
                        onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Text(l10n.levelGame,
                        style: titleFont(context).copyWith(fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        ModeHeroCard(
                          eyebrow: l10n.campaignMode,
                          title: l10n.levelRun,
                          subtitle: l10n.levelRunSubtitle,
                          chips: [
                            ModeInfoChip(
                              icon: Icons.flag_rounded,
                              label: 'LEVEL $_currentLevel / 20',
                              color: AppPalette.goldHighlight,
                            ),
                            ModeInfoChip(
                              icon: Icons.grid_view_rounded,
                              label: _currentLevel <= 8
                                  ? l10n.gridBoard3x3
                                  : _currentLevel <= 15
                                      ? l10n.gridBoard4x4
                                      : l10n.gridBoard5x5,
                              color: AppPalette.primary,
                            ),
                          ],
                          trailing: SizedBox(
                            width: 148,
                            child: SummaryMetricTile(
                              icon: Icons.auto_graph_rounded,
                              label: l10n.progressLabel,
                              value: '${(progress * 100).toInt()}%',
                              accent: AppPalette.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppGlassCard(
                          padding: const EdgeInsets.all(22),
                          borderColor:
                              AppPalette.primary.withValues(alpha: 0.24),
                          child: Column(
                            children: [
                              Text(l10n.currentLevelLabel,
                                  style: sectionFont(context)),
                              const SizedBox(height: 16),
                              Text(
                                "$_currentLevel / 20",
                                style: safeOrbitron(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: AppPalette.goldHighlight,
                                ),
                              ),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: AppPalette.panelDeep
                                    .withValues(alpha: 0.90),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppPalette.primary),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${(progress * 100).toInt()}% Complete",
                                style: bodyFont(context)
                                    .copyWith(color: AppPalette.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppGlassCard(
                          padding: const EdgeInsets.all(22),
                          borderColor: AppPalette.gold.withValues(alpha: 0.26),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.rewardsLabel, style: sectionFont(context)),
                              const SizedBox(height: 12),
                              _RewardInfo(level: 10, coins: 100),
                              const SizedBox(height: 8),
                              _RewardInfo(level: 20, coins: 500),
                              const SizedBox(height: 12),
                              Text(
                                l10n.eachLevelCoins,
                                style: bodyFont(context)
                                    .copyWith(color: AppPalette.goldHighlight),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppGlassCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              Text(l10n.chooseSymbol,
                                  style: sectionFont(context)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: SymbolOption(
                                      symbol: PlayerSymbol.x,
                                      selected: _symbol == PlayerSymbol.x,
                                      onTap: () => setState(
                                          () => _symbol = PlayerSymbol.x),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SymbolOption(
                                      symbol: PlayerSymbol.o,
                                      selected: _symbol == PlayerSymbol.o,
                                      onTap: () => setState(
                                          () => _symbol = PlayerSymbol.o),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppPillButton(
                          label: "ENTER LEVEL $_currentLevel",
                          onPressed: _start,
                          icon: Icons.play_arrow,
                        ),
                      ],
                    ),
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

class _RewardInfo extends StatelessWidget {
  final int level;
  final int coins;

  const _RewardInfo({required this.level, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.panelSoft.withValues(alpha: 0.96),
            AppPalette.panelDeep.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppPalette.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppPalette.goldHighlight,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Level $level milestone",
              style: bodyFont(context),
            ),
          ),
          Image.asset(
            'assets/coin/COIN.webp',
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 8),
          Text(
            "+$coins",
            style: safeOrbitron(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppPalette.goldHighlight,
            ),
          ),
        ],
      ),
    );
  }
}

/// ==========================
///   LEVEL GAME PAGE
/// ==========================
