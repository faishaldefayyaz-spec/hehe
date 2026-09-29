import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

import 'package:dompetku_port/data/budget_repository.dart';
import 'package:dompetku_port/data/category_repository.dart';
import 'package:dompetku_port/data/csv_service.dart';
import 'package:dompetku_port/data/expense_repository.dart';

/// Paket dependensi sekali-buat di akar aplikasi (DI sederhana).
class AppData {
  AppData(this.db)
      : expenses = ExpenseRepository(db),
        categories = CategoryRepository(db),
        budgets = BudgetRepository(db) {
    csv = CsvService(expenses, categories);
  }

  final Database db;
  final ExpenseRepository expenses;
  final CategoryRepository categories;
  final BudgetRepository budgets;
  late final CsvService csv;
}

/// Akses `AppData` dari layar mana pun.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.data, required super.child});

  final AppData data;

  static AppData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.data;

  @override
  bool updateShouldNotify(AppScope oldWidget) => data != oldWidget.data;
}
