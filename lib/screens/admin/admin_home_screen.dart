import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'admin_guard.dart';
import 'admin_users_list_page.dart';
import 'purchase_orders_page.dart';

/// Top-level admin shell. Renders a left sidebar and swaps the body between
/// the available sections.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;

  static const _sections = <_SidebarItem>[
    _SidebarItem('Dashboard', Icons.dashboard_rounded),
    _SidebarItem('Purchase Orders', Icons.receipt_long_rounded),
    _SidebarItem('Users', Icons.people_alt_rounded),
  ];

  Widget _body() {
    switch (_index) {
      case 1:
        return const PurchaseOrdersPage();
      case 2:
        return const AdminUsersListPage();
      case 0:
      default:
        return const _DashboardLanding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: Scaffold(
        backgroundColor: AppPalette.homeBgBase,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(
                items: _sections,
                selectedIndex: _index,
                onSelect: (i) => setState(() => _index = i),
              ),
              const VerticalDivider(width: 1, color: AppPalette.stroke),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _UnverifiedBanner(),
                    Expanded(child: _body()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem {
  final String label;
  final IconData icon;
  const _SidebarItem(this.label, this.icon);
}

class _Sidebar extends StatelessWidget {
  final List<_SidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppPalette.panelDeep,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
            child: Text(
              'XO ARENA ADMIN',
              style: safeOrbitron(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppPalette.primary,
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _SidebarTile(
              item: items[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              'v1 · client-reported logs',
              style: TextStyle(
                color: AppPalette.textSubtle,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final _SidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.primary : AppPalette.textMuted;
    return Material(
      color: selected
          ? AppPalette.primary.withOpacity(0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: color),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnverifiedBanner extends StatelessWidget {
  const _UnverifiedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppPalette.warning.withOpacity(0.16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppPalette.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Client-reported / Unverified. These records are NOT backend '
              'verified. Treat as diagnostic, not as revenue truth.',
              style: TextStyle(
                color: AppPalette.warning,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLanding extends StatelessWidget {
  const _DashboardLanding();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: safeOrbitron(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: AppPalette.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Use the sidebar to inspect purchase orders and users. '
            'All purchase records here are client-reported telemetry only.',
            style: TextStyle(color: AppPalette.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
