import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dompetku_port/core/color_utils.dart';
import 'package:dompetku_port/data/db/app_database.dart';
import 'package:dompetku_port/data/db/schema.dart';

/// PHASE 2 — Port skema SQLite DompetKu (SPEC §15).
///
/// Menguji: CREATE, seed kategori (§5), INSERT, UPDATE, DELETE, QUERY,
/// FOREIGN KEY, ON DELETE RESTRICT, UNIQUE index, INDEX query plan,
/// dan paritas warna signed32 dengan Android.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<Map<String, Object?>>> query(String sql,
          [List<Object?>? args]) =>
      db.rawQuery(sql, args);

  group('CREATE (SPEC §15)', () {
    test('tabel categories, expenses, budgets terbuat', () async {
      final rows = await query(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
      final tables = rows.map((r) => r['name']).toList();
      expect(tables, containsAll(['budgets', 'categories', 'expenses']));
    });

    test('index & unique index terbuat', () async {
      final rows = await query(
          "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name");
      final indexes = rows.map((r) => r['name']).toList();
      expect(indexes, contains('idx_expense_date'));
      expect(indexes, contains('idx_expense_category'));
      expect(indexes, contains('idx_budget_month_year'));
    });

    test('database version = 1', () async {
      expect(await db.getVersion(), DbSchema.databaseVersion);
    });
  });

  group('SEED 12 kategori (SPEC §5)', () {
    test('persis 12 kategori, urut default-asc id', () async {
      final rows = await query(
          'SELECT name FROM categories ORDER BY is_default DESC, id ASC');
      expect(rows.length, 12);
      expect(
        rows.map((r) => r['name']).toList(),
        DbSchema.defaultCategories.map((c) => c.name).toList(),
      );
    });

    test('emoji & is_default persis', () async {
      final rows = await query('SELECT name, icon, is_default FROM categories');
      for (final r in rows) {
        expect(r['is_default'], 1, reason: '${r['name']} harus default');
      }
      final makanan =
          rows.firstWhere((r) => r['name'] == 'Makanan');
      expect(makanan['icon'], '\u{1F35C}'); // 🍜
      final lainnya = rows.firstWhere((r) => r['name'] == 'Lainnya');
      expect(lainnya['icon'], '\u{1F4B0}'); // 💰
    });

    test('warna tersimpan signed32 (negatif) — paritas Android', () async {
      final rows = await query('SELECT name, color FROM categories');
      for (final r in rows) {
        final color = r['color'] as int;
        expect(color, lessThan(0),
            reason: "${r['name']}: alpha FF harus menghasilkan int negatif");
      }
      // Contoh persis: #EA580C di Android = -1419252
      final makanan = rows.firstWhere((r) => r['name'] == 'Makanan');
      expect(makanan['color'], -1419252);
    });

    test('TIDAK ada data transaksi dummy', () async {
      final rows = await query('SELECT COUNT(*) AS c FROM expenses');
      expect(rows.first['c'], 0);
    });
  });

  group('Konversi warna (paritas warna)', () {
    test('argbToSigned32 konsisten dengan Android', () {
      expect(argbToSigned32(0xFFEA580C), -1419252);
      expect(argbToSigned32(0xFF64748B), -10193781); // cat_lainnya
      expect(argbToSigned32(0x7F000000), 0x7F000000); // alpha < 0x80: positif
    });

    test('roundtrip signed32 <-> argb untuk semua warna seed', () {
      for (final c in DbSchema.defaultCategories) {
        expect(signed32ToArgb(argbToSigned32(c.argbColor)), c.argbColor);
        // Semua warna kategori ber-alpha FF -> signed selalu negatif.
        expect(c.signedColor, lessThan(0));
      }
    });
  });

  group('INSERT / QUERY', () {
    test('transaksi masuk dan terbaca kembali dengan join kategori', () async {
      final id = await db.insert('expenses', {
        'amount': 30000,
        'category_id': 1, // Makanan
        'note': 'makan ayam',
        'expense_date': '2026-09-29',
        'created_at': 1759166400000,
        'updated_at': 1759166400000,
      });
      expect(id, 1);

      final rows = await query('''
        SELECT e.amount, e.note, e.expense_date, c.name AS cat
        FROM expenses e
        LEFT JOIN categories c ON c.id = e.category_id
        WHERE e.id = ?
      ''', [id]);
      expect(rows, hasLength(1));
      expect(rows.first['amount'], 30000);
      expect(rows.first['note'], 'makan ayam');
      expect(rows.first['expense_date'], '2026-09-29');
      expect(rows.first['cat'], 'Makanan');
    });

    test('note default kosong', () async {
      await db.insert('expenses', {
        'amount': 5000,
        'category_id': 1,
        'expense_date': '2026-09-29',
        'created_at': 1,
        'updated_at': 1,
      });
      final rows = await query('SELECT note FROM expenses');
      expect(rows.first['note'], '');
    });

    test('amount 1 triliun (MAX) tersimpan exact tanpa kehilangan presisi',
        () async {
      const max = 1000000000000; // SPEC §3 MAX_AMOUNT
      await db.insert('expenses', {
        'amount': max,
        'category_id': 1,
        'note': '',
        'expense_date': '2026-09-29',
        'created_at': 1,
        'updated_at': 1,
      });
      final rows = await query('SELECT amount FROM expenses');
      expect(rows.first['amount'], max);
    });
  });

  group('UPDATE / DELETE', () {
    test('update mengubah data lama', () async {
      final id = await db.insert('expenses', {
        'amount': 10000,
        'category_id': 1,
        'note': 'lama',
        'expense_date': '2026-09-29',
        'created_at': 1,
        'updated_at': 1,
      });
      final n = await db.update(
        'expenses',
        {'amount': 55000, 'note': 'baru', 'updated_at': 2},
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(n, 1);
      final rows = await query('SELECT amount, note FROM expenses WHERE id = ?',
          [id]);
      expect(rows.first['amount'], 55000);
      expect(rows.first['note'], 'baru');
    });

    test('delete menghapus satu baris saja', () async {
      Future<int> add(int amount) => db.insert('expenses', {
            'amount': amount,
            'category_id': 1,
            'note': '',
            'expense_date': '2026-09-29',
            'created_at': 1,
            'updated_at': 1,
          });

      final a = await add(1000);
      await add(2000);
      final n = await db.delete('expenses', where: 'id = ?', whereArgs: [a]);
      expect(n, 1);
      final rows = await query('SELECT COUNT(*) AS c FROM expenses');
      expect(rows.first['c'], 1);
    });
  });

  group('FOREIGN KEY + ON DELETE RESTRICT (SPEC §15)', () {
    test('expense dengan category_id tak dikenal DITOLAK', () async {
      expect(
        () => db.insert('expenses', {
          'amount': 1000,
          'category_id': 99999,
          'note': '',
          'expense_date': '2026-09-29',
          'created_at': 1,
          'updated_at': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('kategori TERPAKAI tidak bisa dihapus; data lama utuh', () async {
      await db.insert('expenses', {
        'amount': 30000,
        'category_id': 1, // Makanan
        'note': '',
        'expense_date': '2026-09-29',
        'created_at': 1,
        'updated_at': 1,
      });
      // Hapus kategori 1 harus gagal (RESTRICT).
      expect(
        () => db.delete('categories', where: 'id = ?', whereArgs: [1]),
        throwsA(isA<DatabaseException>()),
      );
      // Transaksi & kategori tetap ada.
      final cats = await query('SELECT COUNT(*) AS c FROM categories');
      expect(cats.first['c'], 12);
      final exps = await query('SELECT COUNT(*) AS c FROM expenses');
      expect(exps.first['c'], 1);
    });

    test('kategori TANPA transaksi bisa dihapus', () async {
      final id = await db.insert('categories', {
        'name': 'Kategori Uji',
        'icon': '\u{1F4B0}',
        'color': -10047545,
        'is_default': 0,
        'created_at': 1,
      });
      final n =
          await db.delete('categories', where: 'id = ?', whereArgs: [id]);
      expect(n, 1);
    });
  });

  group('UNIQUE index budget (SPEC §15)', () {
    test('month+year unik — duplikat DITOLAK, bulan beda BOLEH', () async {
      Future<void> putBudget(int month, int year) => db.insert('budgets', {
            'month': month,
            'year': year,
            'amount': 2000000,
            'created_at': 1,
            'updated_at': 1,
          });

      await putBudget(9, 2026);
      expect(() => putBudget(9, 2026), throwsA(isA<DatabaseException>()));
      await putBudget(10, 2026); // bulan beda — boleh
      final rows = await query('SELECT COUNT(*) AS c FROM budgets');
      expect(rows.first['c'], 2);
    });
  });

  group('INDEX dipakai query (performa)', () {
    test('filter tanggal memakai idx_expense_date', () async {
      final plan = await query(
        'EXPLAIN QUERY PLAN SELECT * FROM expenses '
        "WHERE expense_date >= '2026-09-01' AND expense_date <= '2026-09-30'",
      );
      final details = plan.map((r) => r['detail']).join(' | ');
      expect(details, contains('idx_expense_date'));
    });

    test('filter kategori memakai idx_expense_category', () async {
      final plan = await query(
        'EXPLAIN QUERY PLAN SELECT * FROM expenses WHERE category_id = 1',
      );
      final details = plan.map((r) => r['detail']).join(' | ');
      expect(details, contains('idx_expense_category'));
    });
  });

  group('ketahanan query lintas format', () {
    test('ISO tanggal bisa diurutkan leksikografis = kronologis', () async {
      for (final iso in ['2026-01-31', '2026-12-01', '2025-06-15']) {
        await db.insert('expenses', {
          'amount': 1000,
          'category_id': 1,
          'note': '',
          'expense_date': iso,
          'created_at': 1,
          'updated_at': 1,
        });
      }
      final rows = await query(
          'SELECT expense_date FROM expenses ORDER BY expense_date ASC');
      expect(rows.map((r) => r['expense_date']).toList(),
          ['2025-06-15', '2026-01-31', '2026-12-01']);
    });
  });

  group('helper path default', () {
    test('nama database persis dompetku.db (SPEC §15)', () {
      expect(AppDatabase.name, 'dompetku.db');
      expect(p.basename('dompetku.db'), 'dompetku.db');
    });
  });
}
