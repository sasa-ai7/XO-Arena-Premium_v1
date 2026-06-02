import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'admin_user_detail_page.dart';

class AdminUsersListPage extends StatefulWidget {
  const AdminUsersListPage({super.key});

  @override
  State<AdminUsersListPage> createState() => _AdminUsersListPageState();
}

class _AdminUsersListPageState extends State<AdminUsersListPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Order by Profile.lastLoginAt desc — fall back to no ordering if the
    // field is missing on some docs (Firestore will simply omit them).
    final stream = FirebaseFirestore.instance
        .collection('users')
        .limit(200)
        .snapshots();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Users',
            style: safeOrbitron(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: AppPalette.text,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: AppPalette.text),
            decoration: InputDecoration(
              hintText: 'Search by email, uid, or name…',
              hintStyle: const TextStyle(color: AppPalette.textSubtle),
              prefixIcon:
                  const Icon(Icons.search, color: AppPalette.textMuted),
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
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
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
                final filtered = docs.where((d) {
                  if (_search.isEmpty) return true;
                  final s = _search.toLowerCase();
                  final data = d.data();
                  final profile = data['Profile'];
                  String? email;
                  String? name;
                  if (profile is Map) {
                    email = profile['email'] as String?;
                    name = profile['name'] as String?;
                  }
                  return d.id.toLowerCase().contains(s) ||
                      (email != null && email.toLowerCase().contains(s)) ||
                      (name != null && name.toLowerCase().contains(s));
                }).toList(growable: false);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No users match.',
                        style: TextStyle(color: AppPalette.textMuted)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = filtered[i].data();
                    final profile =
                        (d['Profile'] is Map) ? d['Profile'] as Map : {};
                    final wallet =
                        (d['Wallet'] is Map) ? d['Wallet'] as Map : {};
                    return _UserRow(
                      uid: filtered[i].id,
                      email: profile['email']?.toString() ?? '—',
                      name: profile['name']?.toString() ?? '—',
                      photoURL: profile['photoURL']?.toString(),
                      coins: (wallet['coins'] as num?)?.toInt() ?? 0,
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

class _UserRow extends StatelessWidget {
  final String uid;
  final String email;
  final String name;
  final String? photoURL;
  final int coins;
  const _UserRow({
    required this.uid,
    required this.email,
    required this.name,
    required this.photoURL,
    required this.coins,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminUserDetailPage(uid: uid),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppPalette.panelElevated,
                backgroundImage:
                    photoURL != null ? NetworkImage(photoURL!) : null,
                child: photoURL == null
                    ? const Icon(Icons.person,
                        color: AppPalette.textMuted, size: 18)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          color: AppPalette.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    Text(email,
                        style: const TextStyle(
                            color: AppPalette.textMuted, fontSize: 12)),
                    SelectableText(uid,
                        style: const TextStyle(
                            color: AppPalette.textSubtle,
                            fontSize: 10.5,
                            fontFamily: 'monospace')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.gold.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppPalette.gold.withOpacity(0.6)),
                ),
                child: Text(
                  '$coins coins',
                  style: TextStyle(
                    color: AppPalette.goldHighlight,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppPalette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
