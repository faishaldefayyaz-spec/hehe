import 'package:flutter/material.dart';

import 'package:dompetku_port/app_data.dart';
import 'package:dompetku_port/features/addexpense/add_expense_screen.dart';
import 'package:dompetku_port/features/history/history_controller.dart';
import 'package:dompetku_port/features/history/history_screen.dart';
import 'package:dompetku_port/features/home/home_controller.dart';
import 'package:dompetku_port/features/home/home_screen.dart';
import 'package:dompetku_port/features/report/report_controller.dart';
import 'package:dompetku_port/features/report/report_screen.dart';
import 'package:dompetku_port/features/settings/settings_controller.dart';
import 'package:dompetku_port/features/settings/settings_screen.dart';

/// Kerangka utama — **4 tab + FAB "CATAT"** (SPEC §2).
///
/// Sama seperti Android: tab aktif di-refresh saat kembali ke tampilan
/// (paritas `VisibleRefresh`), dan setelah layar penuh ditutup semua
/// ringkasan ikut disegarkan.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.data, required this.settings});

  final AppData data;
  final SettingsController settings;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  late final AppData _data;
  late final HomeController _home;
  late final HistoryController _history;
  late final ReportController _report;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _home = HomeController(_data.expenses);
    _history = HistoryController(_data.expenses);
    _report = ReportController(_data.expenses, _data.budgets);
    _refreshVisible();
  }

  @override
  void dispose() {
    _home.dispose();
    _history.dispose();
    _report.dispose();
    super.dispose();
  }

  void _refreshVisible() {
    switch (_index) {
      case 0:
        _home.refresh();
      case 1:
        _history.load();
      case 2:
        _report.refresh();
      case 3:
        widget.settings.refreshBudget();
    }
  }

  void _refreshAll() {
    _home.refresh();
    _history.load();
    _report.refresh();
    widget.settings.refreshBudget();
  }

  void _openAddExpense([int? expenseId]) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => AddExpenseScreen(expenseId: expenseId),
        ))
        .then((_) => _refreshAll()); // paritas onResume setelah ditutup
  }

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _refreshVisible(); // paritas VisibleRefresh saat tab aktif
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            controller: _home,
            onOpenAdd: () => _openAddExpense(),
            onOpenEdit: (id) => _openAddExpense(id),
          ),
          HistoryScreen(
            controller: _history,
            categories: _data.categories,
            onOpenEdit: (id) => _openAddExpense(id),
          ),
          ReportScreen(controller: _report, onOpenAdd: () => _openAddExpense()),
          SettingsScreen(
            settings: widget.settings,
            onRefreshAll: _refreshAll,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Hari Ini'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Riwayat'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Laporan'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Pengaturan'),
        ],
      ),
      // Paritas `syncFab`: tombol CATAT hanya di tab Hari Ini & Riwayat.
      floatingActionButton: _index == 0 || _index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _openAddExpense(),
              icon: const Icon(Icons.add),
              label: const Text(
                'CATAT', // SPEC §2
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }
}
