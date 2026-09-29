/// Model & perhitungan budget bulanan — **SPEC §11**.
class Budget {
  const Budget({
    required this.id,
    required this.month,
    required this.year,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int month; // 1..12
  final int year;
  final int amount;
  final int createdAt;
  final int updatedAt;
}

/// State tampilan budget — paritas `BudgetUiState` Android.
class BudgetUiState {
  const BudgetUiState({
    this.hasBudget = false,
    this.budget = 0,
    this.used = 0,
    this.remaining = 0,
    this.percent = 0,
    this.isOverBudget = false,
    this.showWarning = false,
  });

  final bool hasBudget;
  final int budget;
  final int used;
  final int remaining;
  final int percent;
  final bool isOverBudget;
  final bool showWarning;
}

/// Hitung state budget persis rumus SPEC §11:
///
/// ```text
/// percent      = (totalBulan * 100) / budget   // integer, ke bawah
/// remaining    = budget - totalBulan
/// isOverBudget = totalBulan > budget
/// showWarning  = percent >= 80
/// ```
///
/// Budget `null`/≤ 0 → `hasBudget=false` (tampil `Belum diatur`, tanpa
/// progress) — `used` tetap diisi untuk keperluan lain.
BudgetUiState computeBudgetState({required int used, int? budgetAmount}) {
  if (budgetAmount == null || budgetAmount <= 0) {
    return BudgetUiState(hasBudget: false, used: used);
  }
  final percent = (used * 100) ~/ budgetAmount;
  return BudgetUiState(
    hasBudget: true,
    budget: budgetAmount,
    used: used,
    remaining: budgetAmount - used,
    percent: percent,
    isOverBudget: used > budgetAmount,
    showWarning: percent >= 80,
  );
}
