import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// Pembuka database DompetKu — perilaku identik dengan
/// `DompetKuDbHelper` Android 1.0:
///
///  * `PRAGMA foreign_keys = ON` (FK aktif, termasuk `ON DELETE RESTRICT`)
///  * `onCreate`: buat tabel + index + **seed 12 kategori default**
///  * **Tidak ada data transaksi dummy** (instalasi baru = 0 expense)
///  * versi skema 1 (belum ada migrasi)
class AppDatabase {
  const AppDatabase._();

  /// Nama & versi identik dengan Android (SPEC §15).
  static const String name = DbSchema.databaseName;
  static const int version = DbSchema.databaseVersion;

  /// Buka database.
  ///
  /// [path] = path file DB **lengkap**; jika null memakai
  /// `getDatabasesPath()` + [name] (perilaku aplikasi).
  /// Untuk test, gunakan [inMemoryDatabasePath].
  static Future<Database> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), name);
    return openDatabase(
      dbPath,
      version: version,
      onConfigure: (db) async {
        // FK aktif — sama dengan DompetKuDbHelper.onConfigure().
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, ver) async {
        await _createSchema(db);
        await _seedDefaultCategories(db);
      },
    );
  }

  static Future<void> _createSchema(Database db) async {
    for (final sql in DbSchema.allStatements) {
      await db.execute(sql);
    }
  }

  /// Seed 12 kategori default dalam SATU transaksi — tanpa data dummy lain.
  static Future<void> _seedDefaultCategories(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (final c in DbSchema.defaultCategories) {
        await txn.insert('categories', {
          'name': c.name,
          'icon': c.icon,
          'color': c.signedColor,
          'is_default': 1,
          'created_at': now,
        });
      }
    });
  }
}
