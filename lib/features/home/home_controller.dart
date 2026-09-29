import 'package:flutter/foundation.dart';

import 'package:dompetku_port/core/app_date.dart';
import 'package:dompetku_port/data/expense_repository.dart';
import 'package:dompetku_port/domain/expense.dart';

/// State tab Beranda — paritas `HomeUiState` Android (SPEC §8).
class HomeUiState {
  const HomeUiState({
    this.todayTotal = 0,
    this.todayDateLabel = '',
    this.todayItems = const [],
    this.weekTotal = 0,
    this.monthTotal = 0,
    this.averagePerDay = 0,
    this.topCategory,
    this.isLoading = true,
    this.errorMessage,
  });

  final int todayTotal;
  final String todayDateLabel;
  final List<ExpenseWithCategory> todayItems;
  final int weekTotal;
  final int monthTotal;
  final int averagePerDay;
  final CategoryTotal? topCategory;
  final bool isLoading;
  final String? errorMessage;

  HomeUiState copyWith({
    int? todayTotal,
    String? todayDateLabel,
    List<ExpenseWithCategory>? todayItems,
    int? weekTotal,
    int? monthTotal,
    int? averagePerDay,
    CategoryTotal? topCategory,
    bool? isLoading,
    String? errorMessage,
  }) =>
      HomeUiState(
        todayTotal: todayTotal ?? this.todayTotal,
        todayDateLabel: todayDateLabel ?? this.todayDateLabel,
        todayItems: todayItems ?? this.todayItems,
        weekTotal: weekTotal ?? this.weekTotal,
        monthTotal: monthTotal ?? this.monthTotal,
        averagePerDay: averagePerDay ?? this.averagePerDay,
        topCategory: topCategory ?? this.topCategory,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

/// Logika layar "Hari Ini" — port `HomeViewModel` Android tanpa UI.
class HomeController extends ChangeNotifier {
  HomeController(this._expenses);

  final ExpenseRepository _expenses;

  HomeUiState state = const HomeUiState();

  /// Hitung ulang semua ringkasan (SPEC §8).
  Future<void> refresh() async {
    try {
      final today = AppDate.todayIso();
      final weekStart = AppDate.startOfWeek(today);
      final monthStart = AppDate.startOfMonth(today);

      final todayItems = await _expenses.getRange(
          fromIso: today, toIso: today, newestFirst: true);
      final todayTotal = todayItems.fold<int>(0, (a, i) => a + i.expense.amount);
      final weekTotal = await _expenses.sumRange(weekStart, today);
      final monthTotal = await _expenses.sumRange(monthStart, today);

      // Rata-rata: hariKeN = max(dayOfMonth, 1) — pembagian integer (§8).
      final dayOfMonth = AppDate.dayOfMonth(today);
      final average = monthTotal ~/ (dayOfMonth < 1 ? 1 : dayOfMonth);

      final breakdown = await _expenses.sumByCategory(monthStart, today);

      state = HomeUiState(
        todayTotal: todayTotal,
        todayDateLabel: AppDate.toDisplay(today),
        todayItems: todayItems,
        weekTotal: weekTotal,
        monthTotal: monthTotal,
        averagePerDay: average,
        topCategory: breakdown.isEmpty ? null : breakdown.first,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal membaca data pengeluaran.',
      );
    }
    notifyListeners();
  }

  /// Hapus transaksi; @return true bila berhasil (lalu refresh).
  Future<bool> delete(int expenseId) async {
    bool ok;
    try {
      ok = await _expenses.delete(expenseId);
    } catch (_) {
      ok = false;
    }
    if (ok) await refresh();
    return ok;
  }
}
