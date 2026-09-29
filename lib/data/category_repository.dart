import 'package:sqflite/sqflite.dart';

import '../core/color_utils.dart';
import '../domain/category.dart';

/// Repository kategori — perilaku identik `CategoryDao` +
/// `CategoryRepository` + validasi `CategoryViewModel.save/delete` Android.
///
/// Catatan struktur: di Android validasi ada di ViewModel; di sini digabung
/// ke repository agar bisa diuji tanpa UI. **Perilaku & teks pesan identik.**
class CategoryRepository {
  CategoryRepository(this._db);

  final Database _db;

  // ------------------------------------------------------------- baca

  /// Urut: `is_default DESC, id ASC` (SPEC §5).
  Future<List<Category>> getAll() async {
    final rows = await _db.query(
      'categories',
      orderBy: 'is_default DESC, id ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Category?> getById(int id) async {
    final rows =
        await _db.query('categories', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Pencocokan nama **case-insensitive** (`LOWER(name) = LOWER(?)`).
  Future<Category?> getByName(String name) async {
    final rows = await _db.query(
      'categories',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM categories');
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Jumlah transaksi yang memakai kategori ini.
  Future<int> usageCount(int categoryId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM expenses WHERE category_id = ?',
      [categoryId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  // ------------------------------------------------------------ tulis

  /// @return id baru, atau `-1` jika gagal (paritas DAO Android).
  Future<int> create(String name, String icon, int color) async {
    final id = await _db.insert('categories', {
      'name': name,
      'icon': icon,
      'color': color,
      'is_default': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<bool> rename(Category category) async {
    final n = await _db.update(
      'categories',
      {
        'name': category.name,
        'icon': category.icon,
        'color': category.color,
        'is_default': category.isDefault ? 1 : 0,
        'created_at': category.createdAt,
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
    return n > 0;
  }

  /// Simpan (buat/edit) dengan validasi persis `CategoryViewModel.save`.
  ///
  /// @return `null` = sukses; selain itu = pesan error persis Android.
  Future<String?> save({
    int? id,
    required String name,
    String? icon,
    required int color,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Masukkan nama kategori.';

    final existing = await getByName(trimmed);
    if (existing != null && existing.id != id) {
      return 'Nama kategori sudah dipakai.';
    }

    if (id == null || id == 0) {
      final newId = await create(
        trimmed,
        (icon == null || icon.isEmpty) ? '💰' : icon, // default §5
        color,
      );
      return newId > 0 ? null : 'Gagal menyimpan kategori.';
    }

    final current = await getById(id);
    if (current == null) return 'Kategori tidak ditemukan.';
    final ok = await rename(current.copyWith(
      name: trimmed,
      icon: (icon == null || icon.isEmpty) ? current.icon : icon,
      color: color,
    ));
    return ok ? null : 'Gagal menyimpan kategori.';
  }

  /// Hapus dengan urutan cek persis `CategoryRepository.delete` Android:
  /// 1) kategori terakhir -> [DeleteLastCategory]
  /// 2) masih dipakai      -> [DeleteInUse] (ON DELETE RESTRICT juga aktif di DB)
  /// 3) selain itu          -> hapus.
  Future<CategoryDeleteResult> delete(int categoryId) async {
    if (await count() <= 1) return const DeleteLastCategory();
    if (await usageCount(categoryId) > 0) {
      return DeleteInUse(await usageCount(categoryId));
    }
    final n = await _db.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
    return n > 0 ? const DeleteDeleted() : const DeleteFailed();
  }

  Category _fromRow(Map<String, Object?> row) => Category(
        id: row['id'] as int,
        name: row['name'] as String,
        icon: row['icon'] as String,
        color: row['color'] as int,
        isDefault: (row['is_default'] as int) == 1,
        createdAt: row['created_at'] as int,
      );

  /// Konversi ARGB hex -> signed32 (paritas warna Android).
  static int colorFromArgb(int argb) => argbToSigned32(argb);
}
