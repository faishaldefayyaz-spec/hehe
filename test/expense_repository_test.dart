import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dompetku_port/data/db/app_database.dart';
import 'package:dompetku_port/data/expense_repository.dart';
import 'package:dompetku_port/domain/expense.dart';
import 'package:dompetku_port/domain/expense_form.dart';

/// PHASE 5 — CRUD transaksi + validasi urutan pesan (SPEC §6).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late ExpenseRepository repo;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = ExpenseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Sisipkan transaksi langsung (tanpa form) untuk keperluan query.
  Future<int> seed({
    required int amount,
    int categoryId = 1,
    String note = '',
    required String date,
    int createdAt = 1000,
    int updatedAt = 1000,
  }) =>
      repo.add(Expense(
        id: 0,
        amount: amount,
        categoryId: categoryId,
        note: note,
        expenseDate: date,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ));

  group('CRUD dasar (ExpenseDao port)', () {
    test('add + getById: join kategori lengkap', () async {
      final id = await seed(amount: 30000, note: 'makan ayam', date: '2026-09-29');
      expect(id, greaterThan(0));

      final item = await repo.getById(id);
      expect(item, isNotNull);
      expect(item!.expense.amount, 30000);
      expect(item.expense.note, 'makan ayam');
      expect(item.expense.expenseDate, '2026-09-29');
      expect(item.expense.categoryId, 1);
      expect(item.categoryName, 'Makanan'); // seed §5
      expect(item.categoryIcon, '\u{1F35C}'); // 🍜
      expect(item.categoryColor, -1419252); // #EA580C signed32
    });

    test('update: ubah amount/note/tanggal, updatedAt ikut, createdAt tetap',
        () async {
      final id = await seed(amount: 10000, note: 'lama', date: '2026-09-01');
      final before = (await repo.getById(id))!;
      final ok = await repo.update(before.expense.copyWith(
        amount: 99999,
        note: 'baru',
        expenseDate: '2026-09-29',
        updatedAt: 77777,
      ));
      expect(ok, isTrue);

      final after = (await repo.getById(id))!;
      expect(after.expense.amount, 99999);
      expect(after.expense.note, 'baru');
      expect(after.expense.expenseDate, '2026-09-29');
      expect(after.expense.updatedAt, 77777);
      expect(after.expense.createdAt, before.expense.createdAt); // tidak berubah
    });

    test('delete: hilang setelah dihapus', () async {
      final id = await seed(amount: 5000, date: '2026-09-29');
      expect(await repo.delete(id), isTrue);
      expect(await repo.getById(id), isNull);
      expect(await repo.delete(id), isFalse); // sudah tidak ada
    });

    test('FK RESTRICT: category_id tak dikenal ditolak SQLite', () async {
      expect(
        () => seed(amount: 1000, categoryId: 9999, date: '2026-09-29'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('getRange (SPEC §9)', () {
    setUp(() async {
      await seed(amount: 1000, note: 'sarapan', date: '2026-09-01', createdAt: 1);
      await seed(amount: 2000, categoryId: 3, note: 'bensin motor', date: '2026-09-15', createdAt: 2);
      await seed(amount: 3000, note: 'makan siang', date: '2026-09-29', createdAt: 3);
    });

    test('rentang inklusif + urutan terbaru dulu (default)', () async {
      final items = await repo.getRange(fromIso: '2026-09-01', toIso: '2026-09-29');
      expect(items.length, 3);
      expect(items.first.expense.amount, 3000); // 29 Sep
      expect(items.last.expense.amount, 1000); // 01 Sep
    });

    test('newestFirst=false → terlama dulu', () async {
      final items = await repo.getRange(
          fromIso: '0001-01-01', toIso: '9999-12-31', newestFirst: false);
      expect(items.first.expense.amount, 1000);
      expect(items.last.expense.amount, 3000);
    });

    test('query cocok ke catatan dan nama kategori (LIKE, case-insensitive)',
        () async {
      final byNote = await repo.getRange(
          fromIso: '0001-01-01', toIso: '9999-12-31', query: 'MOTOR');
      expect(byNote.length, 1);
      expect(byNote.single.expense.note, 'bensin motor');

      final byCategory = await repo.getRange(
          fromIso: '0001-01-01', toIso: '9999-12-31', query: 'transportasi');
      expect(byCategory.length, 1);
      expect(byCategory.single.expense.categoryId, 3);
    });

    test('filter categoryId persis', () async {
      final items = await repo.getRange(
          fromIso: '0001-01-01', toIso: '9999-12-31', categoryId: 1);
      expect(items.length, 2); // sarapan + makan siang
      expect(items.every((i) => i.expense.categoryId == 1), isTrue);
    });

    test('rentang tidak cocok → kosong', () async {
      final items =
          await repo.getRange(fromIso: '2027-01-01', toIso: '2027-12-31');
      expect(items, isEmpty);
    });
  });

  group('agregasi (SPEC §8/§10)', () {
    setUp(() async {
      await seed(amount: 10000, note: 'a', date: '2026-09-29', createdAt: 1);
      await seed(amount: 20000, note: 'b', date: '2026-09-29', createdAt: 2);
      await seed(amount: 5000, categoryId: 3, note: 'c', date: '2026-09-28', createdAt: 3);
      await seed(amount: 70000, categoryId: 4, note: 'd', date: '2026-08-15', createdAt: 4);
    });

    test('sumRange inklusif dua sisi', () async {
      expect(await repo.sumRange('2026-09-01', '2026-09-29'), 35000);
      expect(await repo.sumRange('2026-09-29', '2026-09-29'), 30000);
      expect(await repo.sumRange('2026-10-01', '2026-10-31'), 0); // tanpa data
    });

    test('sumByCategory urut total desc + COUNT benar', () async {
      final b = await repo.sumByCategory('2026-09-01', '2026-09-30');
      expect(b.length, 2);
      expect(b.first.categoryName, 'Makanan'); // 30.000
      expect(b.first.total, 30000);
      expect(b.first.count, 2);
      expect(b[1].categoryName, 'Transportasi'); // 5.000
      expect(b[1].total, 5000);
      expect(b[1].count, 1);
    });

    test('sumPerDay hanya berisi hari yang punya data', () async {
      final daily = await repo.sumPerDay('2026-09-28', '2026-09-29');
      expect(daily, {'2026-09-29': 30000, '2026-09-28': 5000});
      expect(daily.containsKey('2026-09-27'), isFalse);
    });

    test('countAll', () async {
      expect(await repo.countAll(), 4);
    });
  });

  group('validasi SIMPAN — urutan & pesan persis (SPEC §6)', () {
    test('1) nominal kosong/bukan angka', () {
      final v = ExpenseForm.validate(
          amountText: '', categoryId: 1, dateIso: '2026-09-29');
      expect(v.amountError, 'Masukkan nominal terlebih dahulu.');
      expect(ExpenseForm.validate(
              amountText: 'abc', categoryId: 1, dateIso: '2026-09-29')
          .amountError,
          'Masukkan nominal terlebih dahulu.');
      expect(
          ExpenseForm.validate(
                  amountText: '  ', categoryId: 1, dateIso: '2026-09-29')
              .amountError,
          'Masukkan nominal terlebih dahulu.');
    });

    test('2) nominal 0 / negatif', () {
      expect(
          ExpenseForm.validate(
                  amountText: '0', categoryId: 1, dateIso: '2026-09-29')
              .amountError,
          'Nominal tidak boleh 0.');
    });

    test('3) nominal > 1 triliun', () {
      expect(
          ExpenseForm.validate(
                  amountText: '1000000000001',
                  categoryId: 1,
                  dateIso: '2026-09-29')
              .amountError,
          'Nominal terlalu besar.');
      // tepat 1 triliun SAH
      expect(
          ExpenseForm.validate(
                  amountText: '1000000000000',
                  categoryId: 1,
                  dateIso: '2026-09-29')
              .isValid,
          isTrue);
    });

    test('4) kategori null / <= 0', () {
      expect(
          ExpenseForm.validate(
                  amountText: '25000', categoryId: null, dateIso: '2026-09-29')
              .categoryError,
          'Pilih kategori terlebih dahulu.');
      expect(
          ExpenseForm.validate(
                  amountText: '25000', categoryId: 0, dateIso: '2026-09-29')
              .categoryError,
          'Pilih kategori terlebih dahulu.');
    });

    test('5) tanggal kosong', () {
      final v = ExpenseForm.validate(
          amountText: '25000', categoryId: 1, dateIso: '   ');
      expect(v.amountError, 'Pilih tanggal terlebih dahulu.');
    });

    test('urutan: error pertama yang menang (bukan yang ke-4/5)', () {
      // kosong + kategori null → tetap pesan nominal dulu
      final v =
          ExpenseForm.validate(amountText: '', categoryId: null, dateIso: '');
      expect(v.amountError, 'Masukkan nominal terlebih dahulu.');
      expect(v.categoryError, isNull);

      // 0 + kategori null → "tidak boleh 0" dulu
      final v2 =
          ExpenseForm.validate(amountText: '0', categoryId: null, dateIso: '');
      expect(v2.amountError, 'Nominal tidak boleh 0.');
      expect(v2.categoryError, isNull);

      // nominal valid + kategori null → pesan kategori (tanggal belum dicek)
      final v3 = ExpenseForm.validate(
          amountText: '25000', categoryId: null, dateIso: '');
      expect(v3.amountError, isNull);
      expect(v3.categoryError, 'Pilih kategori terlebih dahulu.');
    });

    test('semua valid → isValid', () {
      expect(
          ExpenseForm.validate(
                  amountText: '25.000', categoryId: 1, dateIso: '2026-09-29')
              .isValid,
          isTrue);
    });
  });

  group('save() end-to-end (SPEC §6)', () {
    late ExpenseForm form;

    setUp(() => form = ExpenseForm(repo));

    test('tambah sukses → "Tersimpan" + row tersimpan + note di-trim', () async {
      final r = await form.save(
          amountText: '25.000',
          categoryId: 1,
          note: '  makan ayam  ',
          dateIso: '2026-09-29');
      expect(r, isA<SaveSuccess>());
      expect((r as SaveSuccess).message, 'Tersimpan');

      final items =
          await repo.getRange(fromIso: '2026-09-29', toIso: '2026-09-29');
      expect(items, hasLength(1));
      expect(items.single.expense.amount, 25000);
      expect(items.single.expense.note, 'makan ayam'); // trim
      expect(items.single.expense.createdAt, greaterThan(0));
      expect(items.single.expense.updatedAt, items.single.expense.createdAt);
    });

    test('validasi gagal → SaveFormInvalid dengan field yang benar', () async {
      final r = await form.save(
          amountText: '', categoryId: 1, note: '', dateIso: '2026-09-29');
      expect(r, isA<SaveFormInvalid>());
      final invalid = r as SaveFormInvalid;
      expect(invalid.amountError, 'Masukkan nominal terlebih dahulu.');
      expect(invalid.categoryError, isNull);
      expect(await repo.countAll(), 0); // tidak ada yang tersimpan
    });

    test('edit sukses → "Transaksi diperbarui"; createdAt tetap, updatedAt naik',
        () async {
      final id = await seed(amount: 10000, note: 'lama', date: '2026-09-01');
      final before = (await repo.getById(id))!;

      final r = await form.save(
          editId: id,
          amountText: '55000',
          categoryId: 3,
          note: 'baru',
          dateIso: '2026-09-29');
      expect(r, isA<SaveSuccess>());
      expect((r as SaveSuccess).message, 'Transaksi diperbarui');

      final after = (await repo.getById(id))!;
      expect(after.expense.amount, 55000);
      expect(after.expense.categoryId, 3);
      expect(after.expense.expenseDate, '2026-09-29');
      expect(after.expense.createdAt, before.expense.createdAt); // tetap
      expect(after.expense.updatedAt, greaterThan(before.expense.updatedAt));
    });

    test('edit id hilang → "Transaksi tidak ditemukan."', () async {
      final r = await form.save(
          editId: 99999,
          amountText: '55000',
          categoryId: 1,
          note: '',
          dateIso: '2026-09-29');
      expect(r, isA<SaveFailure>());
      expect((r as SaveFailure).message, 'Transaksi tidak ditemukan.');
    });
  });
}
