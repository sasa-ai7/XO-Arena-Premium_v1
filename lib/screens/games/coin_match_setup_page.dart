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
import 'coin_match_game_page.dart';

class CoinMatchSetupPage extends StatefulWidget {
  const CoinMatchSetupPage({super.key});

  @override
  State<CoinMatchSetupPage> createState() => _CoinMatchSetupPageState();
}

class _CoinMatchSetupPageState extends State<CoinMatchSetupPage> {
  static const int _kMaxEntry = 10000;

  PlayerSymbol _symbol = PlayerSymbol.x;
  int _boardSize = 3;
  int _coins = 0;
  int? _selectedEntryFee;
  final TextEditingController _customEntryFeeController =
      TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCoins();
    // Keep balance display in sync as coins change during the session.
    LocalStore.coinsNotifier.addListener(_loadCoins);
  }

  @override
  void dispose() {
    LocalStore.coinsNotifier.removeListener(_loadCoins);
    _customEntryFeeController.dispose();
    super.dispose();
  }

  void _loadCoins() {
    // Use the already-synced notifier value — correct for both online and offline modes.
    if (mounted) setState(() => _coins = LocalStore.coinsNotifier.value);
  }

  int? get _entryFee {
    if (_selectedEntryFee != null) return _selectedEntryFee;
    if (_customEntryFeeController.text.isNotEmpty) {
      final amount = int.tryParse(_customEntryFeeController.text);
      if (amount != null && amount > 0) return amount;
    }
    return null;
  }

  Future<void> _start() async {
    if (_busy) return;
    final fee = _entryFee;
    final l10n = AppL10n.of(context);
    if (fee == null || fee <= 0) {
      if (kDebugMode) debugPrint('[COIN_MATCH] invalid stake rejected: fee=$fee, balance=$_coins');
      showTopNotification(context, l10n.enterValidAmount, color: AppPalette.danger);
      return;
    }
    if (fee > _kMaxEntry) {
      if (kDebugMode) debugPrint('[COIN_MATCH] invalid stake rejected: fee=$fee exceeds max=$_kMaxEntry');
      showTopNotification(context, l10n.entryAmountTooHigh, color: AppPalette.danger);
      return;
    }
    if (fee > _coins) {
      if (kDebugMode) debugPrint('[COIN_MATCH] invalid stake rejected: fee=$fee > balance=$_coins');
      showTopNotification(context, l10n.notEnoughCoins, color: AppPalette.danger);
      return;
    }
    if (kDebugMode) debugPrint('[COIN_MATCH] stake accepted: $fee');

    setState(() => _busy = true);
    if (!mounted) return;

    final boardConfig = standardBoardConfig(_boardSize);

    await Navigator.of(context).push(
      xoFadeRoute(CoinMatchGamePage(
        playerSymbol: _symbol,
        entryFee: fee,
        boardSize: boardConfig.boardSize,
        winCondition: boardConfig.winLength,
      )),
    );

    if (mounted) {
      setState(() => _busy = false);
    }
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
                        onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Text(l10n.playCoinAi,
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
                          eyebrow: l10n.coinArena,
                          title: l10n.highStakesMatch,
                          subtitle: l10n.highStakesSubtitle,
                          chips: [
                            ModeInfoChip(
                              icon: Icons.sports_esports_rounded,
                              label: l10n.symbolLabel(_symbol == PlayerSymbol.x ? 'X' : 'O'),
                              color: AppPalette.primary,
                            ),
                            ModeInfoChip(
                              icon: Icons.payments_outlined,
                              label: _entryFee == null
                                  ? l10n.selectEntry
                                  : l10n.entryCoinsLabel(_entryFee!),
                              color: AppPalette.goldHighlight,
                            ),
                            ModeInfoChip(
                              icon: Icons.grid_view_rounded,
                              label: 'BOARD ${boardConfig.label}',
                              color: AppPalette.homeSky,
                            ),
                          ],
                          trailing: SizedBox(
                            width: 168,
                            child: PremiumBalanceBar(
                              coins: _coins,
                              compact: true,
                              label: l10n.availableLabel,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppGlassCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              const SizedBox(height: 8),
                              Text(
                                l10n.boardSizeDesc,
                                style: bodyFont(context).copyWith(
                                  color: AppPalette.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              BoardSizeSegment(
                                value: _boardSize,
                                onChanged: _busy
                                    ? null
                                    : (size) =>
                                        setState(() => _boardSize = size),
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
                        const SizedBox(height: 16),
                        AppGlassCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.coinAmountLabel, style: sectionFont(context)),
                              const SizedBox(height: 8),
                              Text(
                                l10n.coinAmountDesc,
                                style: bodyFont(context).copyWith(
                                  color: AppPalette.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [50, 100, 200, 500].map((amount) {
                                  final selected = _selectedEntryFee == amount;
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedEntryFee = amount;
                                        _customEntryFeeController.clear();
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        color: selected
                                            ? AppPalette.primary
                                                .withOpacity(0.28)
                                            : Colors.white.withOpacity(0.06),
                                        border: Border.all(
                                          color: selected
                                              ? AppPalette.primary
                                                  .withOpacity(0.70)
                                              : AppPalette.stroke,
                                        ),
                                      ),
                                      child: Text(
                                        "$amount",
                                        style: safeOrbitron(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: selected
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    l10n.orCustomAmount,
                                    style: sectionFont(context)
                                        .copyWith(fontSize: 12),
                                  ),
                                  const Spacer(),
                                  if (_entryFee != null)
                                    TinyBadge(
                                      text: '${_entryFee!} COINS',
                                      color: AppPalette.goldHighlight,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _customEntryFeeController,
                                keyboardType: TextInputType.number,
                                style: safeOrbitron(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n.enterAmountHint,
                                  hintStyle: bodyFont(context),
                                  filled: true,
                                  fillColor: AppPalette.panelDeep
                                      .withValues(alpha: 0.92),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: AppPalette.strokeSoft),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: AppPalette.strokeSoft),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: AppPalette.goldHighlight,
                                        width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                                onChanged: (_) {
                                  setState(() {
                                    _selectedEntryFee = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppPillButton(
                          label: l10n.enterMatch,
                          onPressed:
                              _busy || _entryFee == null || _entryFee! > _coins || _entryFee! > _kMaxEntry
                                  ? null
                                  : _start,
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

