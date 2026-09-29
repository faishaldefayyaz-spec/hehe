import 'package:sqflite/sqflite.dart';

import '../domain/expense.dart';

/// Repository transaksi — port persis `ExpenseDao` Android.
///
/// Semua query tanggal memakai string ISO `yyyy-MM-dd` sehingga perbandingan
/// leksikografis = kronologis dan index `expense_date` terpakai (SPEC §7).
class ExpenseRepository {
  ExpenseRepository(this._db);

  final Database _db;

  /// Join transaksi + kategori (alias kolom sama dengan Android).
  static const String _selectJoin = '''
SELECT e.id AS e_id,
       e.amount AS e_amount,
       e.category_id AS e_category_id,
       e.note AS e_note,
       e.expense_date AS e_date,
       e.created_at AS e_created_at,
       e.updated_at AS e_updated_at,
       COALESCE(c.name, 'Lainnya') AS c_name,
       COALESCE(c.icon, '\u{1F4B0}') AS c_icon,
       COALESCE(c.color, 0) AS c_color
FROM expenses e
LEFT JOIN categories c ON c.id = e.category_id''';

  /// @return id baru, atau -1 bila gagal (paritas SQLite `insert`).
  Future<int> add(Expense expense) => _db.insert('expenses', {
        'amount': expense.amount,
        'category_id': expense.categoryId,
        'note': expense.note,
        'expense_date': expense.expenseDate,
        'created_at': expense.createdAt,
        'updated_at': expense.updatedAt,
      });

  Future<bool> update(Expense expense) async {
    final n = await _db.update(
      'expenses',
      {
        'amount': expense.amount,
        'category_id': expense.categoryId,
        'note': expense.note,
        'expense_date': expense.expenseDate,
        'created_at': expense.createdAt,
        'updated_at': expense.updatedAt,
      },
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    return n > 0;
  }

  Future<bool> delete(int id) async {
    final n = await _db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    return n > 0;
  }

  Future<ExpenseWithCategory?> getById(int id) async {
    final rows = await _db.rawQuery('$_selectJoin WHERE e.id = ?', [id]);
    return rows.isEmpty ? null : _fromJoin(rows.first);
  }

  /// Ambil transaksi pada rentang [fromIso] s/d [toIso] (inklusif).
  ///
  /// [query] dicocokkan ke catatan ATAU nama kategori (`LIKE %q%`,
  /// case-insensitive). [categoryId] null = semua. [newestFirst] mengatur
  /// urutan `e_date DESC/ASC, e_id DESC/ASC` (SPEC §9).
  Future<List<ExpenseWithCategory>> getRange({
    required String fromIso,
    required String toIso,
    String? query,
    int? categoryId,
    bool newestFirst = true,
  }) async {
    final where = StringBuffer('e.expense_date >= ? AND e.expense_date <= ?');
    final args = <Object?>[fromIso, toIso];

    if (query != null && query.trim().isNotEmpty) {
      where.write(
          ' AND (e.note LIKE ? OR c.name LIKE ?)');
      final like = '%${query.trim()}%';
      args.add(like);
      args.add(like);
    }
    if (categoryId != null) {
      where.write(' AND e.category_id = ?');
      args.add(categoryId);
    }

    final order =
        newestFirst ? 'e_date DESC, e_id DESC' : 'e_date ASC, e_id ASC';
    final rows =
        await _db.rawQuery('$_selectJoin WHERE $where ORDER BY $order', args);
    return rows.map(_fromJoin).toList();
  }

  /// Total pengeluaran pada rentang tanggal (selalu ≥ 0).
  Future<int> sumRange(String fromIso, String toIso) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM expenses '
      'WHERE expense_date >= ? AND expense_date <= ?',
      [fromIso, toIso],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  /// Breakdown per kategori pada rentang tanggal — urut total **desc**
  /// (SPEC §10). Kategori hilang tampil `Lainnya`.
  Future<List<CategoryTotal>> sumByCategory(String fromIso, String toIso) async {
    const sql = '''
SELECT COALESCE(c.id, 0) AS c_id,
       COALESCE(c.name, 'Lainnya') AS c_name,
       COALESCE(c.icon, '\u{1F4B0}') AS c_icon,
       COALESCE(c.color, 0) AS c_color,
       SUM(e.amount) AS total,
       COUNT(e.id) AS cnt
FROM expenses e
LEFT JOIN categories c ON c.id = e.category_id
WHERE e.expense_date >= ? AND e.expense_date <= ?
GROUP BY e.category_id
ORDER BY total DESC''';
    final rows = await _db.rawQuery(sql, [fromIso, toIso]);
    return rows
        .map((r) => CategoryTotal(
              categoryId: (r['c_id'] as int?) ?? 0,
              categoryName: r['c_name'] as String,
              categoryIcon: r['c_icon'] as String,
              categoryColor: (r['c_color'] as int?) ?? 0,
              total: (r['total'] as int?) ?? 0,
              count: (r['cnt'] as int?) ?? 0,
            ))
        .toList();
  }

  /// Total harian untuk grafik 7 hari (SPEC §10) — hari tanpa data tidak
  /// muncul di map (caller mengisi 0).
  Future<Map<String, int>> sumPerDay(String fromIso, String toIso) async {
    final rows = await _db.rawQuery(
      'SELECT expense_date AS d, COALESCE(SUM(amount), 0) AS s '
      'FROM expenses WHERE expense_date >= ? AND expense_date <= ? '
      'GROUP BY expense_date',
      [fromIso, toIso],
    );
    return {
      for (final r in rows) r['d'] as String: (r['s'] as int?) ?? 0,
    };
  }

  Future<int> countAll() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM expenses');
    return (rows.first['c'] as int?) ?? 0;
  }

  ExpenseWithCategory _fromJoin(Map<String, Object?> row) => ExpenseWithCategory(
        expense: Expense(
          id: row['e_id'] as int,
          amount: row['e_amount'] as int,
          categoryId: row['e_category_id'] as int,
          note: row['e_note'] as String,
          expenseDate: row['e_date'] as String,
          createdAt: row['e_created_at'] as int,
          updatedAt: row['e_updated_at'] as int,
        ),
        categoryName: row['c_name'] as String,
        categoryIcon: row['c_icon'] as String,
        categoryColor: row['c_color'] as int,
      );
}
