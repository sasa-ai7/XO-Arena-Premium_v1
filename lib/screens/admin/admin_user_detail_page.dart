import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'purchase_orders_page.dart';

/// Per-user detail page. Renders profile + Purchases / Wallet Ledger /
/// Owned Avatars / Audit Logs tabs scoped to the selected uid.
class AdminUserDetailPage extends StatefulWidget {
  final String uid;
  const AdminUserDetailPage({super.key, required this.uid});

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.homeBgBase,
      appBar: AppBar(
        backgroundColor: AppPalette.panelDeep,
        title: SelectableText(
          widget.uid,
          style: TextStyle(
            color: AppPalette.text,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
        iconTheme: const IconThemeData(color: AppPalette.text),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppPalette.primary,
          unselectedLabelColor: AppPalette.textMuted,
          indicatorColor: AppPalette.primary,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Purchases'),
            Tab(text: 'Wallet Ledger'),
            Tab(text: 'Owned Avatars'),
            Tab(text: 'Audit Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProfileTab(uid: widget.uid),
          PurchaseOrdersPage(uidFilter: widget.uid),
          _WalletLedgerTab(uid: widget.uid),
          _OwnedAvatarsTab(uid: widget.uid),
          _UserAuditLogsTab(uid: widget.uid),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String uid;
  const _ProfileTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data?.data();
        if (data == null) {
          return const Center(
            child: Text('User not found.',
                style: TextStyle(color: AppPalette.textMuted)),
          );
        }
        final profile = (data['Profile'] is Map)
            ? data['Profile'] as Map<String, dynamic>
            : <String, dynamic>{};
        final wallet = (data['Wallet'] is Map)
            ? data['Wallet'] as Map<String, dynamic>
            : <String, dynamic>{};
        final stats = (data['Stats'] is Map)
            ? data['Stats'] as Map<String, dynamic>
            : <String, dynamic>{};
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Section('Profile', profile),
            const SizedBox(height: 12),
            _Section('Wallet', wallet),
            const SizedBox(height: 12),
            _Section('Stats', stats),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  const _Section(this.title, this.data);

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.strokeSoft),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: safeOrbitron(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: AppPalette.primary,
              )),
          const SizedBox(height: 8),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 160,
                    child: Text(e.key,
                        style: const TextStyle(
                            color: AppPalette.textMuted, fontSize: 12.5)),
                  ),
                  Expanded(
                    child: SelectableText(
                      e.value.toString(),
                      style: const TextStyle(
                          color: AppPalette.text, fontSize: 12.5),
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

class _WalletLedgerTab extends StatelessWidget {
  final String uid;
  const _WalletLedgerTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('wallet_ledger')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('No ledger entries.',
                style: TextStyle(color: AppPalette.textMuted)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final delta = (d['coinsDelta'] ?? d['delta']);
            final type = d['type'] as String?;
            final balanceAfter = d['balanceAfter'] ?? d['after'];
            final source = d['source'] as String?;
            final ts = (d['createdAt'] as Timestamp?)?.toDate();
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.strokeSoft),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type ?? '—',
                            style: const TextStyle(
                                color: AppPalette.text,
                                fontWeight: FontWeight.w700)),
                        if (source != null)
                          Text(source,
                              style: const TextStyle(
                                  color: AppPalette.textMuted,
                                  fontSize: 11.5)),
                        SelectableText(docs[i].id,
                            style: const TextStyle(
                                color: AppPalette.textSubtle,
                                fontSize: 10.5,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${delta is num && delta > 0 ? '+' : ''}${delta ?? '?'}',
                        style: TextStyle(
                          color: (delta is num && delta < 0)
                              ? AppPalette.danger
                              : AppPalette.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (balanceAfter != null)
                        Text('= $balanceAfter',
                            style: const TextStyle(
                                color: AppPalette.textMuted, fontSize: 11)),
                      if (ts != null)
                        Text(_fmtTs(ts),
                            style: const TextStyle(
                                color: AppPalette.textSubtle, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _fmtTs(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

class _OwnedAvatarsTab extends StatelessWidget {
  final String uid;
  const _OwnedAvatarsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('ownedAvatars')
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No avatar entitlement docs yet. '
              '(Legacy ownership lives in Inventory.ownedAvatars on the user doc.)',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.textMuted),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.strokeSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('avatarId: ${d['avatarId'] ?? docs[i].id}',
                      style: const TextStyle(
                          color: AppPalette.text,
                          fontWeight: FontWeight.w700)),
                  Text('productId: ${d['productId'] ?? '—'}',
                      style:
                          const TextStyle(color: AppPalette.textMuted)),
                  if (d['orderId'] != null)
                    Text('orderId: ${d['orderId']}',
                        style:
                            const TextStyle(color: AppPalette.textMuted)),
                  if (d['purchaseTokenHash'] != null)
                    Text('tokenHash: ${d['purchaseTokenHash']}',
                        style: const TextStyle(
                            color: AppPalette.textSubtle,
                            fontSize: 11,
                            fontFamily: 'monospace')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _UserAuditLogsTab extends StatelessWidget {
  final String uid;
  const _UserAuditLogsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('audit_logs')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load audit logs (this query may need a '
                'composite index on uid+createdAt — Firestore will surface '
                'a link in the console).\n\n${snap.error}',
                style: const TextStyle(color: AppPalette.danger),
              ),
            ),
          );
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('No audit logs.',
                style: TextStyle(color: AppPalette.textMuted)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.strokeSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['eventName']?.toString() ?? '—',
                      style: const TextStyle(
                          color: AppPalette.text,
                          fontWeight: FontWeight.w700)),
                  SelectableText(
                    (d['metadata'] ?? '').toString(),
                    style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 11.5,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
