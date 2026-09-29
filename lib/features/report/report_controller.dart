import 'package:flutter/foundation.dart';

import 'package:dompetku_port/core/app_date.dart';
import 'package:dompetku_port/core/money.dart';
import 'package:dompetku_port/data/budget_repository.dart';
import 'package:dompetku_port/data/expense_repository.dart';
import 'package:dompetku_port/domain/budget.dart';
import 'package:dompetku_port/domain/expense.dart';

enum ReportPeriod { today, week, month }

/// Satu batang grafik 7 hari (SPEC §10).
class DayBar {
  const DayBar({required this.dateIso, required this.label, required this.amount});

  final String dateIso;
  final String label; // nomor tanggal, mis. "29"
  final int amount;
}

/// State tab Laporan — paritas `ReportUiState` Android.
class ReportUiState {
  const ReportUiState({
    this.period = ReportPeriod.month,
    this.total = 0,
    this.breakdown = const [],
    this.bars = const [],
    this.hasAnyData = false,
    this.budget = const BudgetUiState(),
    this.isLoading = true,
    this.errorMessage,
  });

  final ReportPeriod period;
  final int total;
  final List<CategoryTotal> breakdown;
  final List<DayBar> bars;
  final bool hasAnyData;
  final BudgetUiState budget;
  final bool isLoading;
  final String? errorMessage;

  ReportUiState copyWith({
    ReportPeriod? period,
    int? total,
    List<CategoryTotal>? breakdown,
    List<DayBar>? bars,
    bool? hasAnyData,
    BudgetUiState? budget,
    bool? isLoading,
    String? errorMessage,
  }) =>
      ReportUiState(
        period: period ?? this.period,
        total: total ?? this.total,
        breakdown: breakdown ?? this.breakdown,
        bars: bars ?? this.bars,
        hasAnyData: hasAnyData ?? this.hasAnyData,
        budget: budget ?? this.budget,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

/// Logika tab Laporan — port `ReportViewModel` Android tanpa UI (SPEC §10–§11).
class ReportController extends ChangeNotifier {
  ReportController(this._expenses, this._budgets);

  final ExpenseRepository _expenses;
  final BudgetRepository _budgets;

  ReportUiState state = const ReportUiState();

  Future<void> setPeriod(ReportPeriod period) async {
    if (state.period == period) return;
    state = state.copyWith(period: period);
    await refresh();
  }

  Future<void> refresh() async {
    final period = state.period;
    try {
      final today = AppDate.todayIso();
      final (from, to) = switch (period) {
        ReportPeriod.today => (today, today),
        ReportPeriod.week => (AppDate.startOfWeek(today), today),
        ReportPeriod.month => (AppDate.startOfMonth(today), today),
      };

      final total = await _expenses.sumRange(from, to);
      final breakdown = await _expenses.sumByCategory(from, to);

      // Grafik 7 hari terakhir — selalu H-6..H0, independen periode (§10).
      final daily =
          await _expenses.sumPerDay(AppDate.daysBefore(today, 6), today);
      final bars = List.generate(7, (i) {
        final iso = AppDate.daysBefore(today, 6 - i);
        return DayBar(
          dateIso: iso,
          label: AppDate.dayNumber(iso),
          amount: daily[iso] ?? 0,
        );
      });

      final monthStart = AppDate.startOfMonth(today);
      final monthTotal = await _expenses.sumRange(monthStart, today);
      final budget = await _budgets.get(AppDate.monthOf(today), AppDate.yearOf(today));
      final budgetState = computeBudgetState(
        used: monthTotal,
        budgetAmount: (budget == null || budget.amount <= 0) ? null : budget.amount,
      );

      final monthBreakdown = await _expenses.sumByCategory(monthStart, today);

      state = state.copyWith(
        total: total,
        breakdown: breakdown,
        bars: bars,
        hasAnyData: monthBreakdown.isNotEmpty ||
            total > 0 ||
            bars.any((b) => b.amount > 0),
        budget: budgetState,
        isLoading: false,
        errorMessage: null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat laporan.',
      );
    }
    notifyListeners();
  }

  /// Simpan budget bulan berjalan — digit saja, harus > 0;
  /// selain itu ditolak diam-diam (`onDone(false)`, SPEC §11).
  Future<bool> saveBudget(String amountText) async {
    final amount = Money.parse(amountText);
    if (amount == null || amount <= 0) return false;
    bool ok;
    try {
      final today = AppDate.todayIso();
      ok = await _budgets.set(AppDate.monthOf(today), AppDate.yearOf(today), amount);
    } catch (_) {
      ok = false;
    }
    if (ok) await refresh();
    return ok;
  }
}
