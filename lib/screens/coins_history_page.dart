import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/coin_format.dart';
import '../services/local_store.dart';
import '../utils/navigation_utils.dart';
import '../widgets/app_ui.dart';
import 'home/home_widgets.dart';
import 'settings/settings_widgets.dart';

/// Categorical filter chips for the wallet activity feed.
enum _HistoryFilter { all, purchases, rewards, matches, bets, avatar }

extension _HistoryFilterDisplay on _HistoryFilter {
  String get label {
    switch (this) {
      case _HistoryFilter.all:
        return 'ALL';
      case _HistoryFilter.purchases:
        return 'PURCHASES';
      case _HistoryFilter.rewards:
        return 'REWARDS';
      case _HistoryFilter.matches:
        return 'MATCHES';
      case _HistoryFilter.bets:
        return 'BETS';
      case _HistoryFilter.avatar:
        return 'AVATAR';
    }
  }
}

class CoinsHistoryPage extends StatefulWidget {
  const CoinsHistoryPage({super.key});

  @override
  State<CoinsHistoryPage> createState() => _CoinsHistoryPageState();
}

class _CoinsHistoryPageState extends State<CoinsHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _loadError;
  _HistoryFilter _filter = _HistoryFilter.all;

  // Match user-facing strings on the rest of the shop: English, 24h time with
  // seconds, no locale override.
  static final _dateFormat = DateFormat('MMM d, y');
  static final _timeFormat = DateFormat('HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final history = await LocalStore.getTopupHistory();
      if (mounted) {
        setState(() {
          _history = history;
          _loading = false;
        });
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CoinsHistoryPage] _loadHistory error: $e');
        debugPrint('[CoinsHistoryPage] $st');
      }
      if (mounted) {
        setState(() {
          _loadError = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  // ── Classification ────────────────────────────────────────────────────

  _HistoryFilter _categoryOf(Map<String, dynamic> entry) {
    final type = (entry['type'] as String? ?? '').toLowerCase();
    final source = (entry['source'] as String? ?? '').toLowerCase();
    final description = (entry['description'] as String? ?? '').toLowerCase();

    if (type == 'avatar' ||
        source.contains('avatar') ||
        description.contains('avatar')) {
      return _HistoryFilter.avatar;
    }
    if (type == 'recharge' ||
        source == 'iap_purchase' ||
        source.contains('purchase')) {
      return _HistoryFilter.purchases;
    }
    if (source.contains('bet') ||
        description.contains('bet') ||
        description.contains('arena')) {
      return _HistoryFilter.bets;
    }
    if (source == 'level_win' ||
        source.contains('win') ||
        type == 'win' ||
        source.contains('referral') ||
        source.contains('invite') ||
        description.contains('reward') ||
        description.contains('referral')) {
      // Online room results often arrive as type=win with source=arena_* —
      // promote those to matches so the row lands under the right chip.
      if (source.contains('arena') ||
          source.contains('room') ||
          description.contains('room')) {
        return _HistoryFilter.matches;
      }
      return _HistoryFilter.rewards;
    }
    if (description.contains('continue')) {
      return _HistoryFilter.matches;
    }
    return _HistoryFilter.purchases;
  }

  bool _isCredit(Map<String, dynamic> entry) {
    final type = (entry['type'] as String? ?? 'loss').toLowerCase();
    final source = (entry['source'] as String? ?? '').toLowerCase();
    return type == 'win' ||
        type == 'recharge' ||
        type == 'credit' ||
        source.endsWith('_win') ||
        source.endsWith('_reward') ||
        source == 'iap_purchase';
  }

  String _formatDateTime(DateTime dt) =>
      '${_dateFormat.format(dt)} • ${_timeFormat.format(dt)}';

  String _titleFor(Map<String, dynamic> entry, _HistoryFilter category) {
    final desc = (entry['description'] as String?)?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    switch (category) {
      case _HistoryFilter.purchases:
        return 'Coin Purchase';
      case _HistoryFilter.rewards:
        return 'Reward';
      case _HistoryFilter.matches:
        return 'Match Reward';
      case _HistoryFilter.bets:
        return 'Bet';
      case _HistoryFilter.avatar:
        return 'Avatar Unlock';
      case _HistoryFilter.all:
        return 'Transaction';
    }
  }

  IconData _iconFor(_HistoryFilter category, bool credit) {
    switch (category) {
      case _HistoryFilter.purchases:
        return Icons.shopping_bag_rounded;
      case _HistoryFilter.rewards:
        return Icons.card_giftcard_rounded;
      case _HistoryFilter.matches:
        return Icons.emoji_events_rounded;
      case _HistoryFilter.bets:
        return Icons.casino_rounded;
      case _HistoryFilter.avatar:
        return Icons.workspace_premium_rounded;
      case _HistoryFilter.all:
        return credit ? Icons.arrow_upward : Icons.arrow_downward;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filteredHistory = _filter == _HistoryFilter.all
        ? _history
        : _history.where((e) => _categoryOf(e) == _filter).toList();
    final totalCredits = _history
        .where(_isCredit)
        .fold<int>(0, (sum, entry) => sum + (entry['coins'] as int).abs());
    final totalDebits = _history
        .where((e) => !_isCredit(e))
        .fold<int>(0, (sum, entry) => sum + (entry['coins'] as int).abs());

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          child: Column(
            children: [
              _buildHeader(),
              _buildHero(totalCredits, totalDebits),
              _buildFilterRow(),
              Expanded(
                child: _loading
                    ? _buildLoading()
                    : _loadError != null
                        ? _buildError()
                        : filteredHistory.isEmpty
                            ? _buildEmpty()
                            : RefreshIndicator(
                                color: AppPalette.primary,
                                backgroundColor: AppPalette.panelElevated,
                                onRefresh: _loadHistory,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                      14, 4, 14, 18),
                                  itemBuilder: (ctx, i) =>
                                      _buildRow(filteredHistory[i]),
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemCount: filteredHistory.length,
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back,
            onTap: () => navigateToHomeHub(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ACTIVITY HISTORY',
              style: titleFont(context).copyWith(fontSize: 18),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loading ? null : _loadHistory,
          ),
        ],
      ),
    );
  }

  Widget _buildHero(int totalCredits, int totalDebits) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: ModeHeroCard(
        eyebrow: 'ARENA LEDGER',
        title: 'TRANSACTION FLOW',
        subtitle:
            'Purchases, rewards, bets, and avatar unlocks — every coin movement.',
        chips: [
          ModeInfoChip(
            icon: Icons.receipt_long_rounded,
            label: '${_history.length} ENTRIES',
            color: AppPalette.primary,
          ),
        ],
        trailing: SizedBox(
          width: 176,
          child: Column(
            children: [
              SummaryMetricTile(
                icon: Icons.arrow_upward_rounded,
                label: 'CREDITS',
                value: '+${formatCoins(totalCredits, compact: true)}',
                accent: AppPalette.success,
              ),
              const SizedBox(height: 10),
              SummaryMetricTile(
                icon: Icons.arrow_downward_rounded,
                label: 'DEBITS',
                value: '-${formatCoins(totalDebits, compact: true)}',
                accent: AppPalette.danger,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _HistoryFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final f = _HistoryFilter.values[i];
          final selected = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppPalette.homeSky, AppPalette.homeBlue],
                      )
                    : null,
                color:
                    selected ? null : AppPalette.panelElevated.withOpacity(0.6),
                border: Border.all(
                  color: selected
                      ? AppPalette.homeStrokeStrong.withOpacity(0.7)
                      : AppPalette.homeStroke.withOpacity(0.45),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                f.label,
                style: safeOrbitron(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: selected ? Colors.white : AppPalette.textSubtle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: AppGlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppPalette.primary),
            const SizedBox(height: 16),
            Text('Loading history feed...', style: bodyFont(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AppGlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: AppPalette.danger,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load transaction history.',
                style: bodyFont(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _loadError!,
                style: bodyFont(context).copyWith(color: AppPalette.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AppPillButton(
                label: 'Retry',
                onPressed: _loadHistory,
                icon: Icons.refresh,
                fill: AppPalette.primary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: AppGlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.payments_outlined,
              size: 34,
              color: AppPalette.goldHighlight,
            ),
            const SizedBox(height: 12),
            Text(
              'No transactions yet',
              style: titleFont(context).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Coin purchases, match rewards, bets, and avatar unlocks will appear here.',
              textAlign: TextAlign.center,
              style: bodyFont(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> entry) {
    final category = _categoryOf(entry);
    final isPositive = _isCredit(entry);
    final coins = (entry['coins'] as int).abs();
    final dateTime = entry['dateTime'] as DateTime;
    final balanceBefore = entry['balanceBefore'] as int?;
    final balanceAfter = entry['balanceAfter'] as int?;
    final source = entry['source'] as String?;
    const greenColor = Color(0xFF4ADE80);
    const redColor = Color(0xFFF87171);
    final accentColor = isPositive ? greenColor : redColor;
    final label = _titleFor(entry, category);
    final icon = _iconFor(category, isPositive);

    return AppGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: accentColor.withValues(alpha: 0.26),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.18),
                  AppPalette.panelDeep.withValues(alpha: 0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: safeOrbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TinyBadge(
                      text: category == _HistoryFilter.all
                          ? (isPositive ? 'CREDIT' : 'DEBIT')
                          : category.label,
                      color: accentColor,
                    ),
                    const SizedBox(width: 10),
                    if (coins > 0)
                      Text(
                        '${isPositive ? '+' : '-'}${formatCoins(coins, compact: true)}',
                        style: safeOrbitron(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDateTime(dateTime),
                  style: bodyFont(context).copyWith(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                if (balanceBefore != null && balanceAfter != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Balance: ${formatCoins(balanceBefore, compact: true)} → ${formatCoins(balanceAfter, compact: true)}',
                    style: safeInter(
                      fontSize: 11,
                      color: AppPalette.textSubtle,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (source != null && source.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    source,
                    style: safeInter(
                      fontSize: 10,
                      color: AppPalette.textSubtle,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
