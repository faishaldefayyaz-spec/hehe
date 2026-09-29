import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dompetku_port/data/category_repository.dart';
import 'package:dompetku_port/data/db/app_database.dart';
import 'package:dompetku_port/domain/category.dart';

/// PHASE 3b — Kategori (SPEC §5): seed, urutan, nama unik,
/// delete-restrict, last-category, dan teks error persis Android.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late CategoryRepository repo;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = CategoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Sisipkan transaksi yang memakai [categoryId].
  Future<void> addExpense(int categoryId) => db.insert('expenses', {
        'amount': 30000,
        'category_id': categoryId,
        'note': 'makan ayam',
        'expense_date': '2026-09-29',
        'created_at': 1,
        'updated_at': 1,
      });

  group('seed & urutan (SPEC §5)', () {
    test('12 kategori default terurut is_default desc, id asc', () async {
      final all = await repo.getAll();
      expect(all.length, 12);
      expect(all.first.name, 'Makanan');
      expect(all.last.name, 'Lainnya');
      expect(all.every((c) => c.isDefault), isTrue);
    });

    test('getByName case-insensitive', () async {
      expect((await repo.getByName('makanan'))?.name, 'Makanan');
      expect((await repo.getByName('MAKANAN'))?.name, 'Makanan');
      expect(await repo.getByName('Tidak Ada'), isNull);
    });

    test('usageCount awal 0 semua', () async {
      expect(await repo.usageCount(1), 0);
    });
  });

  group('create & save (validasi persis Android)', () {
    test('nama kosong -> "Masukkan nama kategori."', () async {
      expect(
          await repo.save(name: '   ', color: -1), 'Masukkan nama kategori.');
    });

    test('nama duplikat (beda kapital) -> "Nama kategori sudah dipakai."',
        () async {
      expect(await repo.save(name: '  MAKANAN ', color: -1),
          'Nama kategori sudah dipakai.');
    });

    test('edit id tak dikenal -> "Kategori tidak ditemukan."', () async {
      expect(await repo.save(id: 9999, name: 'Baru', color: -1),
          'Kategori tidak ditemukan.');
    });

    test('create sukses: id > 0, bukan default, ikon default 💰', () async {
      expect(await repo.save(name: 'Kopi Pagi', icon: '', color: -10193781),
          isNull);
      final created = await repo.getByName('kopi pagi');
      expect(created, isNotNull);
      expect(created!.id, greaterThan(0));
      expect(created.isDefault, isFalse);
      expect(created.icon, '\u{1F4B0}'); // 💰
      expect(created.color, -10193781);
      expect(await repo.count(), 13);
    });

    test('edit sukses: rename + pertahankan createdAt & ikon bila kosong',
        () async {
      final makanan = (await repo.getByName('Makanan'))!;
      expect(
        await repo.save(
            id: makanan.id,
            name: 'Makanan Berat',
            icon: '',
            color: makanan.color),
        isNull,
      );
      final edited = await repo.getById(makanan.id);
      expect(edited!.name, 'Makanan Berat');
      expect(edited.icon, makanan.icon); // ikon lama dipertahankan
      expect(edited.createdAt, makanan.createdAt); // createdAt tidak berubah
      expect(await repo.getByName('Makanan'), isNull); // unik tetap terjaga
    });
  });

  group('delete (SPEC §5 + DeleteResult Android)', () {
    test('kategori TERPAKAI -> InUse(n) + pesan persis', () async {
      await addExpense(1);
      final result = await repo.delete(1);
      expect(result, isA<DeleteInUse>());
      expect((result as DeleteInUse).count, 1);
      expect(categoryDeleteMessage(result),
          'Kategori ini digunakan oleh 1 transaksi dan tidak bisa dihapus.');
      // kategori & transaksi tetap utuh (DB FK RESTRICT juga menjaga)
      expect(await repo.getByName('Makanan'), isNotNull);
      expect(await repo.usageCount(1), 1);
    });

    test('FK RESTRICT tetap aktif meski guard aplikasi ada', () async {
      await addExpense(1);
      expect(
        () => db.delete('categories', where: 'id = ?', whereArgs: [1]),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('kategori TANPA transaksi -> Deleted (pesan null)', () async {
      await repo.save(name: 'Sementara', color: -1);
      final kategori = (await repo.getByName('Sementara'))!;
      final r = await repo.delete(kategori.id);
      expect(r, isA<DeleteDeleted>());
      expect(categoryDeleteMessage(r), isNull);
      expect(await repo.getByName('Sementara'), isNull);
    });

    test('kategori TERAKHIR -> LastCategory + pesan persis', () async {
      // buang 11 kategori kosong sampai tersisa 1
      final all = await repo.getAll();
      for (final c in all.take(11)) {
        final r = await repo.delete(c.id);
        expect(r, isA<DeleteDeleted>(), reason: c.name);
      }
      expect(await repo.count(), 1);
      final last = (await repo.getAll()).single;
      final r = await repo.delete(last.id);
      expect(r, isA<DeleteLastCategory>());
      expect(categoryDeleteMessage(r), 'Harus ada minimal satu kategori.');
      expect(await repo.count(), 1); // masih ada
    });

    test('pesan Failed persis Android', () {
      expect(categoryDeleteMessage(const DeleteFailed()),
          'Gagal menghapus kategori.');
    });
  });
}
