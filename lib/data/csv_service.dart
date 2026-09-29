import 'package:dompetku_port/core/app_date.dart';
import 'package:dompetku_port/core/csv_utils.dart';
import 'package:dompetku_port/data/category_repository.dart';
import 'package:dompetku_port/data/expense_repository.dart';
import 'package:dompetku_port/domain/category.dart';
import 'package:dompetku_port/domain/expense.dart';

/// Hasil impor CSV — paritas balikan `SettingsViewModel.importCsv` Android.
sealed class CsvImportResult {
  const CsvImportResult();
}

/// `File tidak valid atau tidak ada data yang bisa diimpor.` /
/// `Kategori tidak ditemukan.`
class ImportFailed extends CsvImportResult {
  const ImportFailed(this.message);
  final String message;
}

/// `"jumlahMasuk|jumlahDilewati"` → UI memformat
/// `%d transaksi diimpor, %d duplikat dilewati.`
class ImportDone extends CsvImportResult {
  const ImportDone(this.inserted, this.skipped);
  final int inserted;
  final int skipped;
}

/// Layanan export/import CSV — logika murni `SettingsViewModel`
/// (SPEC §12), tanpa platform I/O (pemilihan berkas ditangani UI).
class CsvService {
  CsvService(this._expenses, this._categories);

  final ExpenseRepository _expenses;
  final CategoryRepository _categories;

  /// Seluruh transaksi, urut tanggal **naik**, format §12.1.
  Future<String> buildExport() async {
    final items = await _expenses.getRange(
        fromIso: '0001-01-01', toIso: '9999-12-31', newestFirst: false);
    final rows = items
        .map((item) => [
              AppDate.toCsvDate(item.expense.expenseDate),
              AppDate.toCsvTime(item.expense.createdAt),
              item.categoryName,
              item.expense.note,
              item.expense.amount.toString(),
            ])
        .toList();
    return CsvUtils.buildRows(rows);
  }

  /// Impor isi file CSV (aturan §12.2–6):
  /// kategori tak dikenal → `Lainnya`; duplikat (amount + kategori +
  /// catatan + createdAt pada tanggal sama) → dilewati & dihitung.
  Future<CsvImportResult> import(String text) async {
    try {
      final parsed = CsvUtils.parseImport(text);
      if (parsed == null || parsed.rows.isEmpty) {
        return const ImportFailed(
            'File tidak valid atau tidak ada data yang bisa diimpor.');
      }

      final categories = await _categories.getAll();
      final byName = <String, Category>{
        for (final c in categories) c.name.toLowerCase(): c,
      };
      final fallback = byName['lainnya'] ??
          (categories.isEmpty ? null : categories.last);
      if (fallback == null) {
        return const ImportFailed('Kategori tidak ditemukan.');
      }

      var inserted = 0;
      var skipped = 0;
      for (final row in parsed.rows) {
        final category = byName[row.categoryName.toLowerCase()] ?? fallback;
        final createdAt = AppDate.parseCsvTime(row.dateIso, row.time);
        if (await _isDuplicate(row, category.id, createdAt)) {
          skipped++;
          continue;
        }
        final id = await _expenses.add(Expense(
          id: 0,
          amount: row.amount,
          categoryId: category.id,
          note: row.note,
          expenseDate: row.dateIso,
          createdAt: createdAt,
          updatedAt: createdAt,
        ));
        if (id > 0) {
          inserted++;
        } else {
          skipped++;
        }
      }
      return ImportDone(inserted, skipped);
    } catch (_) {
      return const ImportFailed(
          'File tidak valid atau tidak ada data yang bisa diimpor.');
    }
  }

  /// Duplikat = amount + categoryId + note + createdAt sama pada tanggal
  /// yang sama (persis kriteria Android).
  Future<bool> _isDuplicate(CsvImportRow row, int categoryId, int createdAt) async {
    final sameDay =
        await _expenses.getRange(fromIso: row.dateIso, toIso: row.dateIso);
    return sameDay.any((e) =>
        e.expense.amount == row.amount &&
        e.expense.categoryId == categoryId &&
        e.expense.note == row.note &&
        e.expense.createdAt == createdAt);
  }
}
