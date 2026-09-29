import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:dompetku_port/app_data.dart';
import 'package:dompetku_port/core/app_date.dart';
import 'package:dompetku_port/core/money.dart';
import 'package:dompetku_port/data/backup_service.dart';
import 'package:dompetku_port/data/csv_service.dart';
import 'package:dompetku_port/data/db/app_database.dart';

/// Preferensi tema — **persis** `Settings` Android: file
/// `dompetku_settings`, kunci `night_mode` (int: -1 ikuti sistem,
/// 1 terang, 2 gelap). Tidak ada data sensitif (SPEC §14).
class ThemePrefs {
  ThemePrefs(this._prefs);

  static const String prefsName = 'dompetku_settings';
  static const String keyNightMode = 'night_mode';

  // Nilai AppCompatDelegate (paritas Android).
  static const int followSystem = -1;
  static const int light = 1;
  static const int dark = 2;

  final SharedPreferences _prefs;

  int get nightMode => _prefs.getInt(keyNightMode) ?? followSystem;

  ThemeMode get themeMode => switch (nightMode) {
        light => ThemeMode.light,
        dark => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String label(int mode) => switch (mode) {
        light => 'Terang',
        dark => 'Gelap',
        _ => 'Ikuti sistem',
      };

  Future<void> setNightMode(int mode) async {
    await _prefs.setInt(keyNightMode, mode);
  }
}

/// Pengaturan layar: tema, budget bulanan, export/import CSV, backup DB.
/// Semua lokal; tidak ada byte yang dikirim ke jaringan (SPEC §12–14).
class SettingsController extends ChangeNotifier {
  SettingsController(this._data, this.theme);

  final AppData _data;
  final ThemePrefs theme;

  int budgetAmount = 0;
  String budgetLabel = 'Belum diatur';
  bool busy = false;

  Future<void> refreshBudget() async {
    try {
      final today = AppDate.todayIso();
      final b = await _data.budgets.get(AppDate.monthOf(today), AppDate.yearOf(today));
      budgetAmount = (b == null || b.amount <= 0) ? 0 : b.amount;
      budgetLabel =
          budgetAmount > 0 ? Money.format(budgetAmount) : 'Belum diatur';
    } catch (_) {
      budgetLabel = 'Belum diatur';
    }
    notifyListeners();
  }

  /// Simpan budget bulan berjalan — digit saja, > 0; lain ditolak (§11).
  /// @return true bila berhasil.
  Future<bool> saveBudget(String amountText) async {
    final amount = Money.parse(amountText);
    if (amount == null || amount <= 0) return false;
    bool ok;
    try {
      final today = AppDate.todayIso();
      ok = await _data.budgets.set(
          AppDate.monthOf(today), AppDate.yearOf(today), amount);
    } catch (_) {
      ok = false;
    }
    if (ok) await refreshBudget();
    return ok;
  }

  // --------------------------------------------------- export / import / backup

  /// Export CSV (§12.1). @return pesan toast, atau `null` bila dibatalkan
  /// pengguna.
  Future<String?> exportCsv() async {
    _setBusy(true);
    try {
      final csvText = await _data.csv.buildExport();
      final name = 'dompetku_${DateTime.now().millisecondsSinceEpoch}.csv';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan CSV',
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(csvText)),
      );
      _setBusy(false);
      if (path == null) return 'Gagal menulis file CSV.'; // paritas Android
      return 'CSV tersimpan: ${_baseName(path)}';
    } catch (_) {
      _setBusy(false);
      return 'Gagal menulis file CSV.';
    }
  }

  /// Impor CSV (§12.2–6). @return pesan toast, atau `null` bila batal.
  Future<String?> importCsv() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return null; // batal: diam
      _setBusy(true);
      final bytes = picked.files.single.bytes;
      final text =
          bytes != null ? utf8.decode(bytes, allowMalformed: true) : null;
      final result = await _data.csv.import(text ?? '');
      await refreshBudget();
      _setBusy(false);
      return switch (result) {
        ImportFailed(:final message) => message,
        ImportDone(:final inserted, :final skipped) =>
          '$inserted transaksi diimpor, $skipped duplikat dilewati.',
      };
    } catch (_) {
      _setBusy(false);
      return 'File tidak valid atau tidak ada data yang bisa diimpor.';
    }
  }

  /// Backup mentah `dompetku.db` (§13). @return pesan toast, atau `null`
  /// bila dibatalkan.
  Future<String?> backupDatabase() async {
    _setBusy(true);
    try {
      final dbPath = p.join(await getDatabasesPath(), AppDatabase.name);
      final bytes = await BackupService.readDatabaseBytes(dbPath);
      if (bytes == null) {
        _setBusy(false);
        return 'Gagal backup database.';
      }
      final name = 'dompetku_backup_${DateTime.now().millisecondsSinceEpoch}.db';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan backup',
        fileName: name,
        bytes: Uint8List.fromList(bytes),
      );
      _setBusy(false);
      if (path == null) return 'Gagal backup database.'; // paritas Android
      return 'Backup tersimpan: ${_baseName(path)}';
    } catch (_) {
      _setBusy(false);
      return 'Gagal backup database.';
    }
  }

  void _setBusy(bool value) {
    busy = value;
    notifyListeners();
  }

  static String _baseName(String path) => path.split(RegExp(r'[/\\]')).last;
}
