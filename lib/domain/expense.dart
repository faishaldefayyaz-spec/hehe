/// Model transaksi pengeluaran — **SPEC §6**.
///
/// [amount] selalu integer (paritas Kotlin `Long`) — tidak pernah double.
/// [expenseFormat] ISO `yyyy-MM-dd` (SPEC §7).
class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.note,
    required this.expenseDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int amount;
  final int categoryId;
  final String note;
  final String expenseDate;
  final int createdAt;
  final int updatedAt;

  Expense copyWith({
    int? id,
    int? amount,
    int? categoryId,
    String? note,
    String? expenseDate,
    int? createdAt,
    int? updatedAt,
  }) =>
      Expense(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        note: note ?? this.note,
        expenseDate: expenseDate ?? this.expenseDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Hasil join transaksi + kategori (siap tampil), paritas
/// `ExpenseWithCategory` Android.
class ExpenseWithCategory {
  const ExpenseWithCategory({
    required this.expense,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
  });

  final Expense expense;
  final String categoryName;
  final String categoryIcon;
  final int categoryColor;
}

/// Hasil agregasi per kategori pada rentang tanggal — paritas
/// `CategoryTotal` Android (SPEC §10).
class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.total,
    required this.count,
  });

  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final int categoryColor;
  final int total;
  final int count;
}
