import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'forms.dart';
import 'pages/budget_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/plans_page.dart';
import 'pages/report_page.dart';
import 'pages/transactions_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  static const _titles = [
    'خرج خانه',
    'تراکنش‌ها',
    'بودجه',
    'برنامه‌ریزی',
    'گزارش',
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          if (_tab >= 1 && _tab <= 3)
            IconButton(
              tooltip: app.gridView ? 'نمایش کارتی' : 'نمایش شبکه‌ای',
              icon: Icon(
                app.gridView ? Icons.view_agenda_outlined : Icons.grid_view,
              ),
              onPressed: () => app.setGridView(!app.gridView),
            ),
          IconButton(
            tooltip: 'تنظیمات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => openSettings(context),
          ),
        ],
        bottom: (_tab == 3 || (_tab == 4 && app.reportYearly))
            ? null
            : const MonthSwitcher(),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          DashboardPage(),
          TransactionsPage(),
          BudgetPage(),
          PlansPage(),
          ReportPage(),
        ],
      ),
      floatingActionButton: (_tab == 0 || _tab == 1)
          ? FloatingActionButton.extended(
              onPressed: () => openTransactionForm(context),
              icon: const Icon(Icons.add),
              label: const Text('ثبت تراکنش'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'تراکنش‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'بودجه',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'برنامه',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'گزارش',
          ),
        ],
      ),
    );
  }
}
