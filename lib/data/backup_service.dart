import 'dart:io';

/// Backup database — **salin mentah file `dompetku.db`** (SPEC §13).
///
/// Tidak ada format khusus; file backup identik byte-per-byte dengan
/// database produksi. Tidak ada fitur Restore di 1.0 (fakta desain).
class BackupService {
  BackupService._();

  /// Baca byte database mentah untuk dikirim ke pemilih berkas (SAF).
  /// @return `null` bila file tidak ada / gagal dibaca.
  static Future<List<int>?> readDatabaseBytes(String dbPath) async {
    try {
      final file = File(dbPath);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Salin langsung file database ke [destPath] (untuk path biasa).
  /// @return `null` = sukses; selain itu = `Gagal backup database.`
  static Future<String?> copyTo(String dbPath, String destPath) async {
    try {
      final src = File(dbPath);
      if (!await src.exists()) return 'Gagal backup database.';
      await src.copy(destPath);
      return null;
    } catch (_) {
      return 'Gagal backup database.';
    }
  }
}
