import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import '../services/app_mode_service.dart';
import '../widgets/app_ui.dart';

/// Read-only screen showing all safe user account data from Firestore.
/// Passwords are NEVER read, stored, or displayed.
class AccountDetailsScreen extends StatelessWidget {
  const AccountDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppPalette.bgTop,
        appBar: _buildAppBar(context),
        body: Center(
          child: Text(
            AppL10n.of(context).notSignedIn,
            style: const TextStyle(color: AppPalette.textMuted),
          ),
        ),
      );
    }

    final uid = user.uid;

    return Scaffold(
      backgroundColor: AppPalette.bgTop,
      appBar: _buildAppBar(context),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            // Guard: never start Firestore listener while offline.
            stream: AppModeService.isOfflineLike
                ? null
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppPalette.primary),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    AppL10n.of(context).errorLoadingAccount,
                    style: bodyFont(context)
                        .copyWith(color: AppPalette.danger),
                  ),
                );
              }

              final data = snapshot.data?.data() ?? {};
              final profile =
                  (data['Profile'] as Map<String, dynamic>?) ?? {};
              final wallet =
                  (data['Wallet'] as Map<String, dynamic>?) ?? {};
              final stats =
                  (data['Stats'] as Map<String, dynamic>?) ?? {};
              final inventory =
                  (data['Inventory'] as Map<String, dynamic>?) ?? {};

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── IDENTITY ────────────────────────────────────────
                    Builder(builder: (ctx) {
                      final l10n = AppL10n.of(ctx);
                      return _SectionCard(
                        title: l10n.identity,
                        icon: Icons.person_outline,
                        children: [
                          _InfoRow(
                            label: l10n.emailLabel,
                            value: _str(profile['email']) ?? user.email ?? '—',
                          ),
                          _InfoRow(
                            label: l10n.displayNameLabel,
                            value: _str(profile['displayName']) ??
                                _str(profile['name']) ??
                                user.displayName ??
                                '—',
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),

                    // ── WALLET ───────────────────────────────────────────
                    Builder(builder: (ctx) {
                      final l10n = AppL10n.of(ctx);
                      return _SectionCard(
                        title: l10n.walletSection,
                        icon: Icons.account_balance_wallet_outlined,
                        children: [
                          _InfoRow(
                            label: l10n.coinsLabel,
                            value: _fmtCoins(wallet['coins']),
                            valueColor: AppPalette.gold,
                          ),
                          _InfoRow(
                            label: l10n.lifetimeEarned,
                            value: _fmtCoins(wallet['lifetimeEarned']),
                          ),
                          _InfoRow(
                            label: l10n.lifetimeSpent,
                            value: _fmtCoins(wallet['lifetimeSpent']),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),

                    // ── STATS ────────────────────────────────────────────
                    Builder(builder: (ctx) {
                      final l10n = AppL10n.of(ctx);
                      return _SectionCard(
                        title: l10n.statsSection,
                        icon: Icons.bar_chart_outlined,
                        children: [
                          _InfoRow(
                              label: l10n.gamesPlayedLabel,
                              value: _num(stats['gamesPlayed'])),
                          _InfoRow(
                              label: l10n.winsLabel,
                              value: _num(stats['wins']),
                              valueColor: AppPalette.success),
                          _InfoRow(
                              label: l10n.lossesLabel,
                              value: _num(stats['losses']),
                              valueColor: AppPalette.danger),
                          _InfoRow(
                              label: l10n.drawsLabel,
                              value: _num(stats['draws']),
                              valueColor: AppPalette.textMuted),
                          _InfoRow(
                            label: l10n.winRateLabel,
                            value: _winRate(stats),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),

                    // ── INVENTORY ────────────────────────────────────────
                    Builder(builder: (ctx) {
                      final l10n = AppL10n.of(ctx);
                      return _SectionCard(
                        title: l10n.inventorySection,
                        icon: Icons.inventory_2_outlined,
                        children: [
                          _InfoRow(
                            label: l10n.equippedAvatarLabel,
                            value: _str(inventory['equippedAvatar']) ?? '—',
                          ),
                          _InfoRow(
                            label: l10n.equippedXSkinLabel,
                            value: _str(inventory['equippedXSkin']) ?? '—',
                          ),
                          _InfoRow(
                            label: l10n.equippedOSkinLabel,
                            value: _str(inventory['equippedOSkin']) ?? '—',
                          ),
                          const SizedBox(height: 4),
                          _ListRow(
                            label: l10n.ownedAvatarsLabel,
                            items: _strList(inventory['avatars']),
                          ),
                          _ListRow(
                            label: l10n.ownedXSkinsLabel,
                            items: _strList(inventory['xSkins']),
                          ),
                          _ListRow(
                            label: l10n.ownedOSkinsLabel,
                            items: _strList(inventory['oSkins']),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),

                    // ── RECENT TRANSACTIONS ──────────────────────────────
                    _TransactionsSection(uid: uid),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppPalette.bgTop,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: AppPalette.primary, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        AppL10n.of(context).accountDetailsTitle,
        style: safeOrbitron(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppPalette.primary,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String? _str(dynamic v) =>
      v != null ? v.toString() : null;

  static String _num(dynamic v) =>
      (v as num?)?.toInt().toString() ?? '0';

  static String _fmtCoins(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return NumberFormat('#,###').format(n);
  }

  static String _winRate(Map<String, dynamic> stats) {
    final games = (stats['gamesPlayed'] as num?)?.toInt() ?? 0;
    final wins = (stats['wins'] as num?)?.toInt() ?? 0;
    if (games == 0) return '—';
    final rate = (wins / games * 100).toStringAsFixed(1);
    return '$rate%';
  }

  static List<String> _strList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  static String _formatTimestamp(dynamic v) {
    if (v == null) return '—';
    DateTime? dt;
    if (v is Timestamp) {
      dt = v.toDate();
    } else if (v is DateTime) {
      dt = v;
    }
    if (dt == null) return '—';
    return DateFormat('MMM d, yyyy  h:mm a').format(dt.toLocal());
  }

}

// ── _SectionCard ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppPalette.strokeSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppPalette.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: safeOrbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.goldHighlight,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(
              color: AppPalette.strokeSoft, height: 1, thickness: 1),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

// ── _InfoRow ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: safeInter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppPalette.textSubtle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: safeInter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor ?? AppPalette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ListRow ─────────────────────────────────────────────────────────────────

class _ListRow extends StatelessWidget {
  final String label;
  final List<String> items;

  const _ListRow({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: safeInter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppPalette.textSubtle,
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Text(
                    AppL10n.of(context).noneLabel,
                    style: safeInter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppPalette.textSubtle,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppL10n.of(context).itemsOwned(items.length),
                        style: safeInter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: items
                            .map(
                              (id) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppPalette.surface2,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppPalette.strokeSoft),
                                ),
                                child: Text(
                                  id,
                                  style: safeInter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppPalette.textMuted,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── _TransactionsSection ─────────────────────────────────────────────────────

class _TransactionsSection extends StatelessWidget {
  final String uid;

  const _TransactionsSection({required this.uid});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'RECENT TRANSACTIONS',
      icon: Icons.receipt_long_outlined,
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          // Guard: never start Firestore listener while offline.
          stream: AppModeService.isOfflineLike
              ? null
              : FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('transactions')
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppPalette.primary),
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Text(
                'Unable to load transactions.',
                style: bodyFont(context)
                    .copyWith(color: AppPalette.textSubtle, fontSize: 12),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Text(
                'No transactions yet.',
                style: safeInter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppPalette.textSubtle,
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final d = doc.data();
                final type = d['type'] as String? ?? '—';
                final amount = (d['amount'] as num?)?.toInt() ?? 0;
                final balBefore =
                    (d['balanceBefore'] as num?)?.toInt();
                final balAfter =
                    (d['balanceAfter'] as num?)?.toInt();
                final createdAt = d['createdAt'];
                final itemName = d['itemName'] as String?;

                final isPositive = amount >= 0;
                final amountStr = isPositive
                    ? '+${NumberFormat('#,###').format(amount)}'
                    : NumberFormat('#,###').format(amount);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppPalette.strokeSoft),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _typeLabel(type, AppL10n.of(context)),
                              style: safeInter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.text,
                              ),
                            ),
                            if (itemName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                itemName,
                                style: safeInter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppPalette.textSubtle,
                                ),
                              ),
                            ],
                            if (balBefore != null &&
                                balAfter != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${NumberFormat('#,###').format(balBefore)} → ${NumberFormat('#,###').format(balAfter)} coins',
                                style: safeInter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: AppPalette.textSubtle,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              AccountDetailsScreen._formatTimestamp(
                                  createdAt),
                              style: safeInter(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: AppPalette.textSubtle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        amountStr,
                        style: safeInter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isPositive
                              ? AppPalette.success
                              : AppPalette.danger,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  static String _typeLabel(String type, AppL10n l10n) {
    switch (type) {
      case 'match_reward':
        return l10n.matchRewardLabel;
      case 'iap_purchase':
        return l10n.coinPurchaseIap;
      case 'avatar_purchase':
        return l10n.avatarPurchaseLabel;
      case 'x_skin_purchase':
        return l10n.xSkinPurchaseLabel;
      case 'o_skin_purchase':
        return l10n.oSkinPurchaseLabel;
      case 'admin_adjustment':
        return l10n.adminAdjustmentLabel;
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }
}
