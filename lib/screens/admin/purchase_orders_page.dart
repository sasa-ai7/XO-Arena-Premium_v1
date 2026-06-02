import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'admin_user_detail_page.dart';

const List<String> _kStatuses = <String>[
  'started',
  'pending',
  'purchased_client_reported',
  'coin_granted_client_fallback',
  'avatar_unlocked_client_fallback',
  'already_processed_client',
  'cancelled',
  'error',
  'restored_client_reported',
];

/// Top-level admin page rendering the global purchase_orders stream.
class PurchaseOrdersPage extends StatefulWidget {
  /// When provided, scopes the query to this user only (used by the
  /// per-user detail page).
  final String? uidFilter;
  const PurchaseOrdersPage({super.key, this.uidFilter});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  String _statusFilter = 'all';
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('purchase_orders');
    if (widget.uidFilter != null) {
      q = q.where('uid', isEqualTo: widget.uidFilter);
    }
    return q.orderBy('createdAt', descending: true).limit(200);
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    if (_statusFilter != 'all' && data['status'] != _statusFilter) {
      return false;
    }
    if (_search.isEmpty) return true;
    final s = _search.toLowerCase();
    final fields = <String?>[
      data['email'] as String?,
      data['uid'] as String?,
      data['productId'] as String?,
      data['orderId'] as String?,
      data['purchaseTokenHash'] as String?,
      data['displayName'] as String?,
    ];
    return fields.any((f) => f != null && f.toLowerCase().contains(s));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.uidFilter == null)
            Text(
              'Purchase Orders',
              style: safeOrbitron(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: AppPalette.text,
              ),
            ),
          if (widget.uidFilter == null) const SizedBox(height: 12),
          _FilterBar(
            selectedStatus: _statusFilter,
            onStatusChanged: (s) => setState(() => _statusFilter = s),
            searchController: _searchCtrl,
            onSearchChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load: ${snap.error}',
                      style: const TextStyle(color: AppPalette.danger),
                    ),
                  );
                }
                final docs = snap.data?.docs ?? const [];
                final filtered = docs
                    .where((d) => _matchesFilter(d.data()))
                    .toList(growable: false);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No purchase orders match.',
                      style: TextStyle(color: AppPalette.textMuted),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = filtered[i].data();
                    return _OrderRow(
                      orderId: filtered[i].id,
                      data: d,
                      onTapUser: widget.uidFilter == null
                          ? () {
                              final uid = d['uid'] as String?;
                              if (uid == null) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminUserDetailPage(uid: uid),
                                ),
                              );
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  const _FilterBar({
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = <String>['all', ..._kStatuses];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          style: const TextStyle(color: AppPalette.text),
          decoration: InputDecoration(
            hintText: 'Search by email, uid, productId, orderId, tokenHash…',
            hintStyle: const TextStyle(color: AppPalette.textSubtle),
            prefixIcon: const Icon(Icons.search, color: AppPalette.textMuted),
            filled: true,
            fillColor: AppPalette.panel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppPalette.stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppPalette.stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppPalette.primary),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: statuses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = statuses[i];
              final selected = s == selectedStatus;
              return ChoiceChip(
                label: Text(s),
                selected: selected,
                onSelected: (_) => onStatusChanged(s),
                backgroundColor: AppPalette.panel,
                selectedColor: AppPalette.primary.withOpacity(0.25),
                labelStyle: TextStyle(
                  color: selected ? AppPalette.primary : AppPalette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color:
                        selected ? AppPalette.primary : AppPalette.strokeSoft,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final VoidCallback? onTapUser;
  const _OrderRow({
    required this.orderId,
    required this.data,
    this.onTapUser,
  });

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] as String?) ?? 'unknown';
    final productId = (data['productId'] as String?) ?? '—';
    final email = (data['email'] as String?) ?? '—';
    final displayName = (data['displayName'] as String?) ?? email;
    final photoURL = data['photoURL'] as String?;
    final uid = (data['uid'] as String?) ?? '';
    final coins = data['coins'];
    final granted = data['grantedCoins'];
    final avatarId = data['avatarId'];
    final price = data['priceLabel'] as String?;
    final tokenHash = data['purchaseTokenHash'] as String?;
    final gOrderId = data['orderId'] as String?;
    final balanceBefore = data['balanceBefore'];
    final balanceAfter = data['balanceAfter'];
    final errorMessage = data['errorMessage'] as String?;
    final productType = (data['productType'] as String?) ?? '—';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.strokeSoft),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppPalette.panelElevated,
                backgroundImage:
                    photoURL != null ? NetworkImage(photoURL) : null,
                child: photoURL == null
                    ? const Icon(Icons.person,
                        color: AppPalette.textMuted, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onTapUser,
                  borderRadius: BorderRadius.circular(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: AppPalette.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        email,
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      SelectableText(
                        uid,
                        style: const TextStyle(
                          color: AppPalette.textSubtle,
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
              const _UnverifiedBadge(),
              const SizedBox(width: 8),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _KV('Product', '$productId ($productType)'),
              if (coins is num) _KV('Coins', coins.toString()),
              if (granted is num) _KV('Granted', granted.toString()),
              if (avatarId != null) _KV('Avatar', avatarId.toString()),
              if (price != null) _KV('Price', price),
              if (balanceBefore != null || balanceAfter != null)
                _KV('Balance',
                    '${balanceBefore ?? '?'} → ${balanceAfter ?? '?'}'),
              if (gOrderId != null) _KV('OrderId', gOrderId),
              if (tokenHash != null)
                _KV('TokenHash', tokenHash.substring(0, tokenHash.length.clamp(0, 12)) + '…'),
              if (createdAt != null) _KV('Created', _fmtTs(createdAt)),
              if (updatedAt != null) _KV('Updated', _fmtTs(updatedAt)),
              _KV('Doc', orderId),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppPalette.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.danger.withOpacity(0.4)),
              ),
              child: Text(
                errorMessage,
                style: const TextStyle(
                  color: AppPalette.danger,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtTs(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

class _KV extends StatelessWidget {
  final String k;
  final String v;
  const _KV(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11.5),
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(
                color: AppPalette.textSubtle,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: v,
              style: const TextStyle(color: AppPalette.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnverifiedBadge extends StatelessWidget {
  const _UnverifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppPalette.warning.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.warning.withOpacity(0.6)),
      ),
      child: Text(
        'UNVERIFIED',
        style: TextStyle(
          color: AppPalette.warning,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static Color _colorForStatus(String s) {
    switch (s) {
      case 'started':
      case 'pending':
        return AppPalette.primary;
      case 'purchased_client_reported':
      case 'restored_client_reported':
        return AppPalette.primary2;
      case 'coin_granted_client_fallback':
      case 'avatar_unlocked_client_fallback':
        return AppPalette.success;
      case 'already_processed_client':
        return AppPalette.warning;
      case 'cancelled':
        return AppPalette.textMuted;
      case 'error':
      case 'coin_grant_failed':
      case 'avatar_unlock_failed':
        return AppPalette.danger;
      default:
        return AppPalette.textMuted;
    }
  }
}
