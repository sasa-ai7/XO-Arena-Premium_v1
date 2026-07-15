import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_l10n.dart';
import '../../../core/app_theme.dart';

/// Premium bet selector for the Create Room page.
///
/// Layout:
///   • Dark glass panel with a gold border and gold glow.
///   • Header row: coin icon + "Play with Coins" + on/off toggle.
///   • When enabled:
///       – Big amount row: [ - ]  [ amount field ]  [ + ]
///       – Wrap of 6 preset chips (50/100/500/1K/5K/10K).
///       – Prize Pool line.
///   • Disabled presets (preset > balance) render with a dim red overlay
///     and surface a "Not enough coins" toast on tap.
///   • Custom amounts are clamped to [kArenaMinBet, kArenaMaxBet] and to
///     the user's coin balance.
class ArenaBetSelector extends StatefulWidget {
  final bool enabled;
  final int amount;
  final int balance;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onAmountChanged;
  final VoidCallback onInsufficientForToggle;
  final VoidCallback onTapDisabledPreset;

  const ArenaBetSelector({
    super.key,
    required this.enabled,
    required this.amount,
    required this.balance,
    required this.onToggle,
    required this.onAmountChanged,
    required this.onInsufficientForToggle,
    required this.onTapDisabledPreset,
  });

  static const List<int> presets = <int>[50, 100, 500, 1000, 5000, 10000];

  @override
  State<ArenaBetSelector> createState() => _ArenaBetSelectorState();
}

/// Min/max constants exported for reuse in the Create Room validation.
const int kArenaMinBet = 50;
const int kArenaMaxBet = 10000;

class _ArenaBetSelectorState extends State<ArenaBetSelector> {
  bool _editing = false;
  late final TextEditingController _ctl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.amount.toString());
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) {
        _commitEdit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ArenaBetSelector old) {
    super.didUpdateWidget(old);
    if (!_editing && widget.amount != int.tryParse(_ctl.text)) {
      _ctl.text = widget.amount.toString();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _editing = true;
      _ctl.text = widget.amount.toString();
      _ctl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctl.text.length,
      );
    });
    _focus.requestFocus();
  }

  void _commitEdit() {
    final raw = _ctl.text.replaceAll(RegExp(r'\D'), '');
    final parsed = int.tryParse(raw) ?? widget.amount;
    int next = parsed;
    if (next < kArenaMinBet) next = kArenaMinBet;
    if (next > kArenaMaxBet) next = kArenaMaxBet;
    // Refuse amounts beyond the balance — but never clamp silently when the
    // user types over their balance; show a toast and revert.
    if (next > widget.balance) {
      widget.onTapDisabledPreset();
      next = widget.amount;
    }
    setState(() {
      _editing = false;
      _ctl.text = next.toString();
    });
    if (next != widget.amount) widget.onAmountChanged(next);
  }

  /// Snap up to the next preset (clamped to max + balance).
  void _increment() {
    final cur = widget.amount;
    int next = cur;
    for (final p in ArenaBetSelector.presets) {
      if (p > cur) {
        next = p;
        break;
      }
    }
    if (next == cur) next = kArenaMaxBet;
    if (next > widget.balance) {
      widget.onTapDisabledPreset();
      return;
    }
    if (next < kArenaMinBet) next = kArenaMinBet;
    if (next > kArenaMaxBet) next = kArenaMaxBet;
    widget.onAmountChanged(next);
  }

  /// Snap down to the previous preset (clamped to min).
  void _decrement() {
    final cur = widget.amount;
    int next = cur;
    for (final p in ArenaBetSelector.presets.reversed) {
      if (p < cur) {
        next = p;
        break;
      }
    }
    if (next == cur) next = kArenaMinBet;
    if (next < kArenaMinBet) next = kArenaMinBet;
    if (next > kArenaMaxBet) next = kArenaMaxBet;
    widget.onAmountChanged(next);
  }

  void _onPresetTap(int preset) {
    if (preset > widget.balance) {
      widget.onTapDisabledPreset();
      return;
    }
    widget.onAmountChanged(preset);
  }

  void _onToggle(bool v) {
    if (v && widget.balance < kArenaMinBet) {
      widget.onInsufficientForToggle();
      return;
    }
    widget.onToggle(v);
  }

  String _presetLabel(int v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.toInt() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    }
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final balanceTooLow = widget.balance < kArenaMinBet;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppPalette.panel.withValues(alpha: 0.96),
            AppPalette.panelDeep.withValues(alpha: 0.98),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppPalette.gold.withValues(alpha: 0.7),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.gold.withValues(alpha: 0.22),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            enabled: widget.enabled,
            balanceTooLow: balanceTooLow,
            onToggle: _onToggle,
            title: l10n.playWithCoins,
          ),
          if (balanceTooLow) ...[
            const SizedBox(height: 6),
            Text(
              l10n.notEnoughCoinsShort,
              style: const TextStyle(
                color: AppPalette.danger,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!widget.enabled) ...[
            const SizedBox(height: 10),
            _FriendlyModePanel(
              title: l10n.noEntryFee,
              subtitle: l10n.friendlyMatchMode,
            ),
          ],
          if (widget.enabled) ...[
            const SizedBox(height: 14),
            _AmountRow(
              amount: widget.amount,
              editing: _editing,
              controller: _ctl,
              focusNode: _focus,
              onTap: _startEdit,
              onSubmit: (_) => _commitEdit(),
              onMinus: _decrement,
              onPlus: _increment,
              coinsLabel: l10n.coinsWord,
            ),
            const SizedBox(height: 12),
            _PresetGrid(
              presets: ArenaBetSelector.presets,
              selected: widget.amount,
              balance: widget.balance,
              labelOf: _presetLabel,
              onTap: _onPresetTap,
            ),
            const SizedBox(height: 12),
            _PrizePoolRow(
              prizePool: widget.amount * 2,
              balance: widget.balance,
              insufficient: widget.balance < widget.amount,
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool enabled;
  final bool balanceTooLow;
  final ValueChanged<bool> onToggle;
  final String title;
  const _Header({
    required this.enabled,
    required this.balanceTooLow,
    required this.onToggle,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/coin/COIN.webp',
          width: 22,
          height: 22,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.monetization_on_rounded,
            color: AppPalette.gold,
            size: 22,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppPalette.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Switch(
          value: enabled,
          onChanged: balanceTooLow && !enabled ? null : onToggle,
          activeThumbColor: AppPalette.gold,
          activeTrackColor: AppPalette.gold.withValues(alpha: 0.45),
          inactiveTrackColor: AppPalette.panelDeep,
        ),
      ],
    );
  }
}

class _FriendlyModePanel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FriendlyModePanel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppPalette.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppPalette.success.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppPalette.success.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.handshake_rounded,
              color: AppPalette.success,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final int amount;
  final bool editing;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final ValueChanged<String> onSubmit;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final String coinsLabel;

  const _AmountRow({
    required this.amount,
    required this.editing,
    required this.controller,
    required this.focusNode,
    required this.onTap,
    required this.onSubmit,
    required this.onMinus,
    required this.onPlus,
    required this.coinsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(icon: Icons.remove_rounded, onTap: onMinus),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: editing ? null : onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.panelDeep,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppPalette.gold.withValues(alpha: 0.55),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.gold.withValues(alpha: 0.18),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: editing
                  ? TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      textAlign: TextAlign.center,
                      cursorColor: AppPalette.gold,
                      style: const TextStyle(
                        color: AppPalette.gold,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1.0,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onSubmitted: onSubmit,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$amount',
                          style: const TextStyle(
                            color: AppPalette.gold,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Orbitron',
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          coinsLabel,
                          style: TextStyle(
                            color: AppPalette.gold.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        _RoundIconButton(icon: Icons.add_rounded, onTap: onPlus),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.gold.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppPalette.gold.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          child: Icon(icon, color: AppPalette.gold, size: 20),
        ),
      ),
    );
  }
}

class _PresetGrid extends StatelessWidget {
  final List<int> presets;
  final int selected;
  final int balance;
  final String Function(int) labelOf;
  final ValueChanged<int> onTap;
  const _PresetGrid({
    required this.presets,
    required this.selected,
    required this.balance,
    required this.labelOf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in presets)
          _PresetChip(
            label: labelOf(preset),
            selected: preset == selected,
            disabled: preset > balance,
            onTap: () => onTap(preset),
          ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor;
    final Color textColor;
    final Color borderColor;
    final List<BoxShadow>? glow;
    if (disabled) {
      baseColor = AppPalette.panelDeep;
      textColor = AppPalette.danger.withValues(alpha: 0.70);
      borderColor = AppPalette.danger.withValues(alpha: 0.45);
      glow = null;
    } else if (selected) {
      baseColor = AppPalette.gold.withValues(alpha: 0.20);
      textColor = AppPalette.gold;
      borderColor = AppPalette.gold;
      glow = [
        BoxShadow(
          color: AppPalette.gold.withValues(alpha: 0.45),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ];
    } else {
      baseColor = AppPalette.panelDeep;
      textColor = AppPalette.text;
      borderColor = AppPalette.primary.withValues(alpha: 0.55);
      glow = null;
    }
    return SizedBox(
      width: 76,
      height: 36,
      child: Material(
        color: baseColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.6 : 1.0,
              ),
              boxShadow: glow,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrizePoolRow extends StatelessWidget {
  final int prizePool;
  final int balance;
  final bool insufficient;
  const _PrizePoolRow({
    required this.prizePool,
    required this.balance,
    required this.insufficient,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppPalette.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppPalette.gold.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: AppPalette.gold,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                '${l10n.prizePoolLabel}: $prizePool',
                style: const TextStyle(
                  color: AppPalette.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${l10n.yourCoins}: ',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: '$balance',
                  style: TextStyle(
                    color:
                        insufficient ? AppPalette.danger : AppPalette.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
