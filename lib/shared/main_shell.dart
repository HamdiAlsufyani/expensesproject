import 'package:flutter/material.dart';

import '../core/models.dart';
import '../features/backup/presentation/backup_page.dart';
import '../features/customers/presentation/party_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/expenses/presentation/expenses_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/transactions/presentation/transactions_page.dart';
import '../l10n/app_localizations.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      _Destination(
        l10n.home,
        Icons.dashboard_outlined,
        Icons.dashboard,
        const DashboardPage(),
      ),
      _Destination(
        l10n.customers,
        Icons.people_outline,
        Icons.people,
        const PartyPage(type: PartyType.customer),
      ),
      _Destination(
        l10n.suppliers,
        Icons.local_shipping_outlined,
        Icons.local_shipping,
        const PartyPage(type: PartyType.supplier),
      ),
      _Destination(
        l10n.expenses,
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        const ExpensesPage(),
      ),
      _Destination(
        l10n.transactions,
        Icons.swap_horiz_outlined,
        Icons.swap_horiz,
        const TransactionsPage(),
      ),
      _Destination(
        l10n.reports,
        Icons.bar_chart_outlined,
        Icons.bar_chart,
        const ReportsPage(),
      ),
      _Destination(
        l10n.backup,
        Icons.cloud_sync_outlined,
        Icons.cloud_sync,
        const BackupPage(),
      ),
      _Destination(
        l10n.settings,
        Icons.settings_outlined,
        Icons.settings,
        const SettingsPage(),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 840;
        if (desktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.appTitle,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  destinations: [
                    for (final item in destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [for (final item in destinations) item.page],
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: [for (final item in destinations) item.page],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index > 4 ? 0 : _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: [
              for (final item in destinations.take(5))
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon, this.page);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}
