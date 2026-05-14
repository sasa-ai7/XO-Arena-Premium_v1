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

class CoinsHistoryPage extends StatefulWidget {
  const CoinsHistoryPage({super.key});

  @override
  State<CoinsHistoryPage> createState() => _CoinsHistoryPageState();
}

class _CoinsHistoryPageState extends State<CoinsHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _loadError;

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

  String _formatDateTime(DateTime dt) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
    final timeFormat = DateFormat('HH:mm:ss', 'pt_BR');
    return '${dateFormat.format(dt)} ${timeFormat.format(dt)}';
  }

  String _defaultDescription(String type) {
    switch (type) {
      case 'win':
        return 'Game Win';
      case 'recharge':
        return 'Coin Purchase';
      case 'loss':
        return 'Game Entry';
      default:
        return 'Transaction';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCredit(Map<String, dynamic> entry) {
      final type = entry['type'] as String? ?? 'loss';
      final source = entry['source'] as String? ?? '';
      return type == 'win' || type == 'recharge' || type == 'credit' ||
          source.endsWith('_win') || source == 'iap_purchase';
    }

    final totalCredits = _history
        .where(isCredit)
        .fold<int>(0, (sum, entry) => sum + (entry['coins'] as int).abs());
    final totalDebits = _history
        .where((entry) => !isCredit(entry))
        .fold<int>(0, (sum, entry) => sum + (entry['coins'] as int).abs());

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
                      onTap: () => navigateToHomeHub(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "COIN HISTORY",
                        style: titleFont(context).copyWith(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: ModeHeroCard(
                  eyebrow: 'ARENA LEDGER',
                  title: 'TRANSACTION FLOW',
                  subtitle:
                      'Review purchases, entry fees, and reward payouts with live balance transitions.',
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
                          value: '+$totalCredits',
                          accent: AppPalette.success,
                        ),
                        const SizedBox(height: 10),
                        SummaryMetricTile(
                          icon: Icons.arrow_downward_rounded,
                          label: 'DEBITS',
                          value: '-$totalDebits',
                          accent: AppPalette.danger,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(
                        child: AppGlassCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                  color: AppPalette.primary),
                              const SizedBox(height: 16),
                              Text(
                                'Loading history feed...',
                                style: bodyFont(context),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _loadError != null
                        ? Center(
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
                                      "Could not load transaction history.",
                                      style: bodyFont(context),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _loadError!,
                                      style: bodyFont(context).copyWith(
                                          color: AppPalette.textMuted),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    AppPillButton(
                                      label: 'Retry',
                                      onPressed: _loadHistory,
                                      icon: Icons.refresh,
                                      fill: AppPalette.primary
                                          .withValues(alpha: 0.7),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : _history.isEmpty
                            ? Center(
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
                                        "No transactions yet",
                                        style: titleFont(context)
                                            .copyWith(fontSize: 18),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Coin purchases, match fees, and rewards will appear here once activity starts.",
                                        textAlign: TextAlign.center,
                                        style: bodyFont(context),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 0, 14, 16),
                                child: Column(
                                  children: _history.map((entry) {
                                    final type =
                                        entry['type'] as String? ?? 'loss';
                                    final coins = (entry['coins'] as int).abs();
                                    final dateTime =
                                        entry['dateTime'] as DateTime;
                                    final balanceBefore =
                                        entry['balanceBefore'] as int?;
                                    final balanceAfter =
                                        entry['balanceAfter'] as int?;
                                    final description =
                                        entry['description'] as String?;
                                    final source =
                                        entry['source'] as String?;

                                    final isPositive = isCredit(entry);
                                    const greenColor = Color(0xFF4ADE80);
                                    const redColor = Color(0xFFF87171);
                                    final accentColor =
                                        isPositive ? greenColor : redColor;

                                    // Derive description label from type if not provided
                                    final label = description ??
                                        _defaultDescription(type);

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: AppGlassCard(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        borderColor:
                                            accentColor.withValues(alpha: 0.26),
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
                                                    accentColor.withValues(
                                                        alpha: 0.18),
                                                    AppPalette.panelDeep
                                                        .withValues(
                                                            alpha: 0.98),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: accentColor.withValues(
                                                      alpha: 0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Image.asset(
                                                    'assets/coin/COIN.png',
                                                    width: 26,
                                                    height: 26,
                                                  ),
                                                  Positioned(
                                                    right: 5,
                                                    bottom: 5,
                                                    child: Icon(
                                                      isPositive
                                                          ? Icons.arrow_upward
                                                          : Icons
                                                              .arrow_downward,
                                                      color: accentColor,
                                                      size: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          label,
                                                          style: safeOrbitron(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors.white,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      TinyBadge(
                                                        text: isPositive
                                                            ? 'CREDIT'
                                                            : 'DEBIT',
                                                        color: accentColor,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        '${isPositive ? '+' : '-'}$coins',
                                                        style: safeOrbitron(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: accentColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _formatDateTime(dateTime),
                                                    style: bodyFont(context)
                                                        .copyWith(
                                                      fontSize: 12,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                  if (balanceBefore != null &&
                                                      balanceAfter != null) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Balance: $balanceBefore \u2192 $balanceAfter',
                                                      style: safeInter(
                                                        fontSize: 11,
                                                        color: AppPalette
                                                            .textSubtle,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                  if (source != null) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      source,
                                                      style: safeInter(
                                                        fontSize: 10,
                                                        color: AppPalette
                                                            .textSubtle,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
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


