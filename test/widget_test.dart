import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dompetku_port/app_data.dart';
import 'package:dompetku_port/core/app_date.dart';
import 'package:dompetku_port/data/db/app_database.dart';
import 'package:dompetku_port/main.dart';

/// Smoke test UI — shell 4 tab, FAB "CATAT", dan alur simpan transaksi.
///
/// Catatan teknis: query SQLite FFI berjalan async nyata, jadi test ini
/// memakai `runAsync` (waktu nyata) + `pump` alih-alih `pumpAndSettle`
/// (yang hanya memutar fake-clock dan bisa habis sebelum query selesai).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await AppDatabase.open(path: inMemoryDatabasePath);
  });

  Future<void> settle(WidgetTester tester) async {
    // 8 x 100 ms fake-clock > durasi transisi route standar (300 ms),
    // dengan jeda waktu nyata tiap iterasi agar future SQLite FFI selesai.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(DompetKuApp(data: AppData(db), prefs: prefs));
    await settle(tester);
  }

  testWidgets('shell: 4 tab + FAB CATAT + empty states', (tester) async {
    await pumpApp(tester);

    // Tab terlihat.
    expect(find.text('Hari Ini'), findsWidgets);
    expect(find.text('Riwayat'), findsOneWidget);
    expect(find.text('Laporan'), findsOneWidget);
    expect(find.text('Pengaturan'), findsOneWidget);

    // Toolbar utama = "DOMPETKU" caps (paritas MainActivity + TextSectionTitle).
    expect(find.text('DOMPETKU'), findsOneWidget);

    // FAB CATAT (SPEC §2).
    expect(find.widgetWithText(FloatingActionButton, 'CATAT'), findsOneWidget);

    // Empty state Beranda (DB masih kosong).
    expect(find.text('Belum ada pengeluaran hari ini.'), findsOneWidget);
    expect(find.text('RINGKASAN'), findsOneWidget);

    // -> Riwayat (FAB tetap tampil; paritas syncFab: hanya home & riwayat).
    await tester.tap(find.text('Riwayat'));
    await settle(tester);
    expect(find.widgetWithText(FloatingActionButton, 'CATAT'), findsOneWidget);
    expect(find.text('Cari transaksi…'), findsOneWidget);
    expect(find.text('Tidak ada transaksi.'), findsOneWidget);

    // -> Laporan (FAB disembunyikan).
    await tester.tap(find.text('Laporan'));
    await settle(tester);
    expect(find.widgetWithText(FloatingActionButton, 'CATAT'), findsNothing);
    expect(find.text('Belum ada data.'), findsOneWidget);

    // -> Pengaturan (versi ada di bawah: scroll dulu; FAB tetap tersembunyi).
    await tester.tap(find.text('Pengaturan'));
    await settle(tester);
    expect(find.widgetWithText(FloatingActionButton, 'CATAT'), findsNothing);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Kelola Kategori'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await settle(tester);
    expect(find.text('Versi 1.0.0'), findsOneWidget);
  });

  testWidgets('FAB -> form -> simpan -> muncul di Beranda', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'CATAT'));
    await settle(tester);
    expect(find.text('Tambah Pengeluaran'), findsOneWidget);
    expect(find.text('Input cepat (opsional)'), findsOneWidget);

    // Isi nominal (dikelompokkan ribuan) + pilih kategori + SIMPAN.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '30000');
    await tester.pump();
    expect(find.text('30.000'), findsOneWidget); // dikelompokkan: Rp | 30.000

    await tester.tap(find.text('🍜 Makanan'));
    await tester.pump();
    await tester.tap(find.text('SIMPAN'));
    await settle(tester);

    // Diagnosis: pastikan tidak ada error validasi yang tertinggal.
    for (final err in const [
      'Masukkan nominal terlebih dahulu.',
      'Nominal tidak boleh 0.',
      'Nominal terlalu besar.',
      'Pilih kategori terlebih dahulu.',
      'Pilih tanggal terlebih dahulu.',
      'Gagal menyimpan transaksi.',
    ]) {
      expect(find.text(err), findsNothing, reason: 'masih tampil: "$err"');
    }

    // Kembali ke Beranda; transaksi tampil + toast persis Android.
    expect(find.text('Tambah Pengeluaran'), findsNothing);
    expect(find.text('Tersimpan'), findsOneWidget);
    expect(find.text('Rp30.000'), findsWidgets); // kartu total + baris transaksi
    expect(find.text('Belum ada pengeluaran hari ini.'), findsNothing);

    // Riwayat: header per tanggal + tombol edit/hapus
    // (paritas `HistoryAdapter` + `item_history.xml`).
    await tester.tap(find.text('Riwayat'));
    await settle(tester);
    expect(
      find.text(AppDate.toDisplay(AppDate.todayIso()).toUpperCase()),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
