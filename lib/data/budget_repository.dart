import 'package:sqflite/sqflite.dart';

import '../domain/budget.dart';

/// Repository budget bulanan — port `BudgetDao` + `BudgetRepository` Android.
/// Satu baris per `(month, year)` (UNIQUE index, SPEC §15).
class BudgetRepository {
  BudgetRepository(this._db);

  final Database _db;

  Future<Budget?> get(int month, int year) async {
    final rows = await _db.query(
      'budgets',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Budget(
      id: r['id'] as int,
      month: r['month'] as int,
      year: r['year'] as int,
      amount: r['amount'] as int,
      createdAt: r['created_at'] as int,
      updatedAt: r['updated_at'] as int,
    );
  }

  /// Insert atau update — @return true jika sukses (paritas `upsert`).
  Future<bool> set(int month, int year, int amount) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await get(month, year);
    if (existing == null) {
      final id = await _db.insert('budgets', {
        'month': month,
        'year': year,
        'amount': amount,
        'created_at': now,
        'updated_at': now,
      });
      return id > 0;
    }
    final n = await _db.update(
      'budgets',
      {'amount': amount, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [existing.id],
    );
    return n > 0;
  }
}
