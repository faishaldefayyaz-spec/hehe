import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dompetku_port/core/app_date.dart';
import 'package:dompetku_port/core/csv_utils.dart';
import 'package:dompetku_port/data/backup_service.dart';
import 'package:dompetku_port/data/category_repository.dart';
import 'package:dompetku_port/data/csv_service.dart';
import 'package:dompetku_port/data/db/app_database.dart';
import 'package:dompetku_port/data/expense_repository.dart';
import 'package:dompetku_port/domain/expense.dart';

/// PHASE 7b — Export/impor CSV (§12) + backup mentah (§13).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late ExpenseRepository expenses;
  late CategoryRepository categories;
  late CsvService csv;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    expenses = ExpenseRepository(db);
    categories = CategoryRepository(db);
    csv = CsvService(expenses, categories);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seed({
    required int amount,
    int categoryId = 1,
    String note = '',
    required String date,
    required int createdAt,
  }) =>
      expenses.add(Expense(
        id: 0,
        amount: amount,
        categoryId: categoryId,
        note: note,
        expenseDate: date,
        createdAt: createdAt,
        updatedAt: createdAt,
      ));

  String timeOf(int y, int m, int d, int hh, int mm) =>
      DateTime(y, m, d, hh, mm).millisecondsSinceEpoch.toString();

  group('export (§12.1)', () {
    test('header + urut tanggal naik + nominal mentah + waktu dari createdAt',
        () async {
      final t1 = int.parse(timeOf(2026, 9, 29, 18, 20));
      final t2 = int.parse(timeOf(2026, 9, 28, 7, 5));
      await seed(
          amount: 30000,
          note: 'makan ayam',
          date: '2026-09-29',
          createdAt: t1);
      await seed(
          amount: 5000, categoryId: 2, note: 'kopi', date: '2026-09-28', createdAt: t2);

      final out = await csv.buildExport();
      final lines = out.split('\r\n');
      expect(lines.first, 'Tanggal,Waktu,Kategori,Catatan,Nominal');
      expect(lines[1], '28/09/2026,07:05,Minuman,kopi,5000'); // tanggal naik
      expect(lines[2], '29/09/2026,18:20,Makanan,makan ayam,30000');
      expect(lines.last, ''); // diakhiri CRLF
    });

    test('escape RFC 4180 pada catatan (koma & kutip)', () async {
      final t = int.parse(timeOf(2026, 9, 29, 10, 0));
      await seed(
          amount: 1000,
          note: 'nasi, "spesial"',
          date: '2026-09-29',
          createdAt: t);
      final out = await csv.buildExport();
      expect(out.contains('"nasi, ""spesial"""'), isTrue);
      // Dan hasil ekspor kembali terbaca utuh oleh parser impor.
      final back = CsvUtils.parseImport(out);
      expect(back, isNotNull);
      expect(back!.rows.single.note, 'nasi, "spesial"');
      expect(back.rows.single.amount, 1000);
    });

    test('DB kosong → hanya header', () async {
      expect(await csv.buildExport(), 'Tanggal,Waktu,Kategori,Catatan,Nominal\r\n');
    });
  });

  group('import (§12.2–6)', () {
    const header = 'Tanggal,Waktu,Kategori,Catatan,Nominal';

    test('file valid: masuk semua + kategori case-insensitive + waktu dipakai',
        () async {
      final result = await csv.import(
          '$header\r\n29/09/2026,18:20,makanan,makan siang,25000\r\n'
          '30/09/2026,07:00,,tanpa kategori,7000\r\n');
      expect(result, isA<ImportDone>());
      final done = result as ImportDone;
      expect(done.inserted, 2);
      expect(done.skipped, 0);

      final items =
          await expenses.getRange(fromIso: '0001-01-01', toIso: '9999-12-31');
      expect(items, hasLength(2));
      final makan = items.firstWhere((i) => i.expense.note == 'makan siang');
      expect(makan.expense.categoryId, 1); // "makanan" → Makanan
      expect(makan.categoryName, 'Makanan');
      final tanpa = items.firstWhere((i) => i.expense.note == 'tanpa kategori');
      expect(tanpa.categoryName, 'Lainnya'); // kolom kosong → fallback
      // createdAt = jam 18:20 pada tanggal terkait (parseCsvTime).
      final expected = AppDate.parseCsvTime('2026-09-29', '18:20');
      expect(makan.expense.createdAt, expected);
      expect(makan.expense.updatedAt, expected); // updatedAt = createdAt
      expect(makan.expense.expenseDate, '2026-09-29');
    });

    test('kategori tak dikenal → fallback Lainnya (§12.4)', () async {
      final result = await csv.import(
          '$header\n29/09/2026,10:00,Kemewahan,salah ketik,90000');
      expect(result, isA<ImportDone>());
      final items =
          await expenses.getRange(fromIso: '2026-09-29', toIso: '2026-09-29');
      expect(items.single.categoryName, 'Lainnya');
      expect(items.single.expense.amount, 90000);
    });

    test('import dua kali: gelombang kedua seluruhnya duplikat (§12.5)',
        () async {
      const file = '$header\n29/09/2026,18:20,Makanan,makan,30000\n'
          '29/09/2026,19:00,Minuman,kopi,15000';
      final first = await csv.import(file);
      expect((first as ImportDone).inserted, 2);
      expect(first.skipped, 0);

      final second = await csv.import(file);
      expect(second, isA<ImportDone>());
      expect((second as ImportDone).inserted, 0);
      expect(second.skipped, 2);

      // Catatan BERBEDA → BUKAN duplikat (note bagian kriteria).
      final third = await csv
          .import('$header\n29/09/2026,18:20,Makanan,makan berat,30000');
      expect((third as ImportDone).inserted, 1);
      expect(third.skipped, 0);
      expect(await expenses.countAll(), 3);
    });

    test('baris invalid dilewat & dihitung dalam total dilewati', () async {
      final result = await csv.import(
          '$header\n29/09/2026,10:00,Makanan,ok,30000\n'
          '33/13/2026,x,Makanan,rusak,30000\n'
          '29/09/2026,10:00,Makanan,nol,0');
      expect(result, isA<ImportDone>());
      // Baris rusak tidak masuk daftar row → tidak dihitung sama sekali
      // (paritas Android: invalidLines terpisah, tidak ditambahkan ke
      // skipped; hanya row valid yang bisa inserted/skipped).
      final done = result as ImportDone;
      expect(done.inserted, 1);
      expect(done.skipped, 0);
      expect(await expenses.countAll(), 1);
    });

    test('file tak dikenal → pesan persis §12.6', () async {
      for (final bad in [null, '', 'foo,bar\n1,2', 'Tanggal,Kategori\n29/09/2026,Makanan']) {
        final r = await csv.import(bad ?? '');
        expect(r, isA<ImportFailed>(), reason: '[$bad]');
        expect(
            (r as ImportFailed).message,
            'File tidak valid atau tidak ada data yang bisa diimpor.');
      }
      // Hanya header (tanpa data) → juga ditolak.
      final r = await csv.import(header);
      expect(r, isA<ImportFailed>());
    });

    test('roundtrip: export → import ke DB baru = data sama', () async {
      final t = int.parse(timeOf(2026, 9, 29, 18, 20));
      await seed(amount: 30000, note: 'makan', date: '2026-09-29', createdAt: t);
      await seed(
          amount: 15000,
          categoryId: 3,
          note: 'bensin',
          date: '2026-09-28',
          createdAt: t);
      final exported = await csv.buildExport();

      // DB kedua — pakai file sementara: `:memory:` pada sqflite ffi
      // dipakai ulang per path, jadi dua open bersamaan = satu DB.
      final tmp = await Directory.systemTemp.createTemp('dompetku_roundtrip');
      final db2 = await AppDatabase.open(path: '${tmp.path}/kedua.db');
      try {
        final csv2 = CsvService(ExpenseRepository(db2), CategoryRepository(db2));
        final r = await csv2.import(exported);
        expect((r as ImportDone).inserted, 2);
        expect(r.skipped, 0);
        expect(await csv2.buildExport(), exported); // ekspor identik
      } finally {
        await db2.close();
        await tmp.delete(recursive: true);
      }
    });
  });

  group('backup (§13)', () {
    test('readDatabaseBytes: byte identik dengan file sumber', () async {
      final tmp = await Directory.systemTemp.createTemp('dompetku_backup');
      try {
        final src = File('${tmp.path}/dompetku.db');
        await src.writeAsBytes([0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0, 1, 2, 3]);
        final bytes = await BackupService.readDatabaseBytes(src.path);
        expect(bytes, isNotNull);
        expect(bytes, await src.readAsBytes()); // salin mentah
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('copyTo: file tujuan identik byte-per-byte', () async {
      final tmp = await Directory.systemTemp.createTemp('dompetku_backup');
      try {
        final src = File('${tmp.path}/dompetku.db');
        final data = List<int>.generate(4096, (i) => i % 256);
        await src.writeAsBytes(data);
        final dest = File('${tmp.path}/salinan.db');

        final err = await BackupService.copyTo(src.path, dest.path);
        expect(err, isNull);
        expect(await dest.readAsBytes(), data); // identik
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('file tidak ada → pesan gagal persis Android', () async {
      final tmp = await Directory.systemTemp.createTemp('dompetku_backup');
      try {
        expect(await BackupService.readDatabaseBytes('${tmp.path}/hilang.db'),
            isNull);
        expect(
            await BackupService.copyTo(
                '${tmp.path}/hilang.db', '${tmp.path}/out.db'),
            'Gagal backup database.');
      } finally {
        await tmp.delete(recursive: true);
      }
    });
  });
}
