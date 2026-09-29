import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dompetku_port/core/app_date.dart';
import 'package:dompetku_port/data/budget_repository.dart';
import 'package:dompetku_port/data/db/app_database.dart';
import 'package:dompetku_port/data/expense_repository.dart';
import 'package:dompetku_port/domain/budget.dart';
import 'package:dompetku_port/domain/expense.dart';
import 'package:dompetku_port/features/history/history_controller.dart';
import 'package:dompetku_port/features/home/home_controller.dart';
import 'package:dompetku_port/features/report/report_controller.dart';

/// PHASE 6b — Logika 4 tab: Home (§8), Riwayat (§9), Laporan+Budget (§10–§11).
///
/// Semua ekspektasi tanggal dihitung dari `AppDate` sehingga test lulus
/// pada tanggal berapa pun dijalankan.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late ExpenseRepository expenses;
  late BudgetRepository budgets;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    expenses = ExpenseRepository(db);
    budgets = BudgetRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seed({
    required int amount,
    int categoryId = 1,
    String note = '',
    required String date,
    int createdAt = 1,
    int updatedAt = 1,
  }) =>
      expenses.add(Expense(
        id: 0,
        amount: amount,
        categoryId: categoryId,
        note: note,
        expenseDate: date,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ));

  // ---------------------------------------------------------------- Home
  group('HomeController (SPEC §8)', () {
    test('ringkasan: hari/minggu/bulan/rata-rata/top kategori', () async {
      final today = AppDate.todayIso();
      final monthStart = AppDate.startOfMonth(today);
      final weekStart = AppDate.startOfWeek(today);
      // Jika hari ini = tanggal 1, monthStart == today (seed satukan hari ini).
      final monthlyDate = monthStart == today ? today : monthStart;

      await seed(amount: 10000, note: 'sarapan', date: today, createdAt: 1);
      await seed(amount: 20000, note: 'makan siang', date: today, createdAt: 2);
      await seed(
          amount: 50000, categoryId: 3, note: 'bensin', date: monthlyDate, createdAt: 3);

      // (tanggal, nominal) semua seed — untuk ekspektasi rentang.
      final seeds = <(String, int)>[
        (today, 10000),
        (today, 20000),
        (monthlyDate, 50000),
      ];
      int sumIn(String from, String to) => seeds
          .where((s) => s.$1.compareTo(from) >= 0 && s.$1.compareTo(to) <= 0)
          .fold<int>(0, (a, s) => a + s.$2);

      final c = HomeController(expenses);
      await c.refresh();

      expect(c.state.isLoading, isFalse);
      expect(c.state.errorMessage, isNull);
      expect(c.state.todayDateLabel, AppDate.toDisplay(today));

      // Total hari ini = semua seed jatuh hari ini hanya bila tanggal 1.
      final expectedToday = sumIn(today, today);
      expect(c.state.todayTotal, expectedToday);
      expect(c.state.todayItems.length,
          seeds.where((s) => s.$1 == today).length);

      // Urutan daftar hari ini: terbaru dulu (date DESC, id DESC).
      for (var i = 1; i < c.state.todayItems.length; i++) {
        final p = c.state.todayItems[i - 1].expense;
        final q = c.state.todayItems[i].expense;
        final ordered = p.expenseDate.compareTo(q.expenseDate) > 0 ||
            (p.expenseDate == q.expenseDate && p.id > q.id);
        expect(ordered, isTrue, reason: 'urutan terbaru dulu');
      }

      expect(c.state.weekTotal, sumIn(weekStart, today));
      expect(c.state.monthTotal, sumIn(monthStart, today));

      // Rata-rata = monthTotal / max(dayOfMonth, 1) — integer.
      final dayN = AppDate.dayOfMonth(today);
      expect(c.state.averagePerDay, c.state.monthTotal ~/ (dayN < 1 ? 1 : dayN));

      // Top kategori bulan ini: Makanan 30k vs Transportasi 50k.
      expect(c.state.topCategory, isNotNull);
      expect(c.state.topCategory!.categoryName, 'Transportasi');
      expect(c.state.topCategory!.total, 50000);
      expect(c.state.topCategory!.count, 1);
    });

    test('DB tanpa transaksi → semua 0, topCategory null, tanpa error',
        () async {
      final c = HomeController(expenses);
      await c.refresh();
      expect(c.state.todayTotal, 0);
      expect(c.state.weekTotal, 0);
      expect(c.state.monthTotal, 0);
      expect(c.state.averagePerDay, 0);
      expect(c.state.topCategory, isNull);
      expect(c.state.todayItems, isEmpty);
      expect(c.state.errorMessage, isNull);
      expect(c.state.todayDateLabel, isNotEmpty); // label tanggal tetap ada
    });

    test('delete: hapus lalu refresh; id asal → true, id hilang → false',
        () async {
      final today = AppDate.todayIso();
      final id = await seed(amount: 5000, date: today, createdAt: 1);
      final c = HomeController(expenses);
      await c.refresh();
      expect(c.state.todayTotal, 5000);

      expect(await c.delete(id), isTrue);
      expect(c.state.todayTotal, 0);
      expect(await c.delete(99999), isFalse);
      expect(c.state.todayTotal, 0);
    });
  });

  // ------------------------------------------------------------- Riwayat
  group('HistoryController (SPEC §9)', () {
    late String today;
    late String d3;

    setUp(() async {
      today = AppDate.todayIso();
      d3 = AppDate.daysBefore(today, 3);
      await seed(
          amount: 10000,
          note: 'sarapan pagi',
          date: today,
          categoryId: 1,
          createdAt: 1);
      await seed(
          amount: 20000,
          note: 'bensin motor',
          date: d3,
          categoryId: 3,
          createdAt: 2);
      await seed(
          amount: 7000,
          note: 'kopi',
          date: '1999-06-15',
          categoryId: 2,
          createdAt: 3);
      await seed(
          amount: 3000,
          note: '',
          date: AppDate.startOfMonth(today),
          categoryId: 4,
          createdAt: 4);
    });

    test('default: Semua + terbaru dulu + header jumlah & total', () async {
      final c = HistoryController(expenses);
      await c.load();
      expect(c.state.dateFilter, DateFilter.all);
      expect(c.state.sortOrder, SortOrder.newest);
      expect(c.state.categoryName, 'Semua kategori');
      expect(c.state.totalCount, 4);
      expect(c.state.totalAmount, 40000);
      expect(c.state.items.last.expense.expenseDate, '1999-06-15');
      expect(c.state.errorMessage, isNull);
    });

    test('pencarian ke catatan DAN nama kategori (LIKE, case-insensitive)',
        () async {
      final c = HistoryController(expenses);
      await c.setQuery('bensin');
      expect(c.state.totalCount, 1);
      expect(c.state.items.single.expense.note, 'bensin motor');

      await c.setQuery('transportasi');
      expect(c.state.totalCount, 1);
      expect(c.state.items.single.expense.categoryId, 3);

      await c.setQuery('Kopi');
      expect(c.state.totalCount, 1); // catatan "kopi"

      await c.setQuery('');
      expect(c.state.totalCount, 4);
    });

    test('filter Hari ini', () async {
      final c = HistoryController(expenses);
      await c.setDateFilter(DateFilter.today);
      expect(c.state.totalCount,
          AppDate.startOfMonth(today) == today ? 3 : 1); // id1+id2+id4 bila tgl 1
      for (final i in c.state.items) {
        expect(i.expense.expenseDate, today);
      }
    });

    test('filter 7 hari terakhir = H-6 s/d hari ini (inklusif)', () async {
      final c = HistoryController(expenses);
      await c.setDateFilter(DateFilter.last7Days);
      final from = AppDate.daysBefore(today, 6);

      final dates = c.state.items.map((i) => i.expense.expenseDate).toSet();
      expect(dates.contains(today), isTrue);
      expect(dates.contains(d3), isTrue);
      expect(dates.contains('1999-06-15'), isFalse); // di luar rentang
      for (final i in c.state.items) {
        expect(i.expense.expenseDate.compareTo(from),
            greaterThanOrEqualTo(0));
        expect(i.expense.expenseDate.compareTo(today),
            lessThanOrEqualTo(0));
      }
    });

    test('filter Bulan ini = tgl 1 s/d hari ini', () async {
      final c = HistoryController(expenses);
      await c.setDateFilter(DateFilter.thisMonth);
      final from = AppDate.startOfMonth(today);
      final dates = c.state.items.map((i) => i.expense.expenseDate).toSet();
      expect(dates.contains('1999-06-15'), isFalse);
      expect(dates.contains(from), isTrue);
      expect(dates.contains(today), isTrue);
    });

    test('filter kustom: from–to inklusif + auto-tukar bila terbalik', () async {
      final c = HistoryController(expenses);
      await c.setCustomRange(d3, d3);
      expect(c.state.dateFilter, DateFilter.custom);
      // Rentang satu hari [d3]; seed awal bulan ikut bila kebetulan = d3.
      final monthStart = AppDate.startOfMonth(today);
      expect(
          c.state.totalCount, 1 + (monthStart == d3 ? 1 : 0));
      expect(
          c.state.items.any((i) => i.expense.amount == 20000), isTrue);

      // Terbalik (from > to) → ditukar otomatis (resolveRange Android)
      // → rentang [1999-06-15, d3]; seed awal bulan ikut bila di rentang.
      await c.setCustomRange(d3, '1999-06-15');
      final monthSeedIn = monthStart.compareTo('1999-06-15') >= 0 &&
          monthStart.compareTo(d3) <= 0;
      expect(c.state.totalCount, 2 + (monthSeedIn ? 1 : 0));
    });

    test('filter kategori persis + label nama', () async {
      final c = HistoryController(expenses);
      await c.setCategory(3, 'Transportasi');
      expect(c.state.categoryId, 3);
      expect(c.state.categoryName, 'Transportasi');
      expect(c.state.totalCount, 1);
      expect(c.state.items.single.expense.categoryId, 3);

      await c.setCategory(null, 'Semua kategori');
      expect(c.state.totalCount, 4);
    });

    test('toggleSort: terbaru ↔ terlama', () async {
      final c = HistoryController(expenses);
      await c.load();
      expect(c.state.sortOrder, SortOrder.newest);

      await c.toggleSort();
      expect(c.state.sortOrder, SortOrder.oldest);
      expect(c.state.items.first.expense.expenseDate, '1999-06-15');

      await c.toggleSort();
      expect(c.state.sortOrder, SortOrder.newest);
      expect(c.state.items.first.expense.expenseDate.compareTo(
              c.state.items.last.expense.expenseDate),
          greaterThanOrEqualTo(0));
    });

    test('gabungan: query + filter tanggal + kategori', () async {
      final c = HistoryController(expenses);
      await c.setQuery('motor');
      await c.setDateFilter(DateFilter.last7Days);
      await c.setCategory(3, 'Transportasi');
      expect(c.state.totalCount, 1);
      expect(c.state.totalAmount, 20000);

      await c.setCategory(1, 'Makanan');
      expect(c.state.totalCount, 0); // "motor" tak ada di Makanan
      expect(c.state.totalAmount, 0);
    });

    test('delete menghapus dari daftar (header ikut berubah)', () async {
      final c = HistoryController(expenses);
      await c.load();
      expect(c.state.totalCount, 4);
      final victim = c.state.items.first;
      expect(await c.delete(victim.expense.id), isTrue);
      expect(c.state.totalCount, 3);
      expect(c.state.totalAmount, 40000 - victim.expense.amount);
    });
  });

  // -------------------------------------------------------------- Laporan
  group('ReportController (SPEC §10–§11)', () {
    test('default periode = Bulan ini; total & breakdown benar', () async {
      final today = AppDate.todayIso();
      final monthStart = AppDate.startOfMonth(today);
      final secondDate = monthStart == today ? today : monthStart;

      await seed(amount: 10000, date: today, categoryId: 1, createdAt: 1);
      await seed(
          amount: 25000, date: secondDate, categoryId: 3, createdAt: 2);

      final c = ReportController(expenses, budgets);
      await c.refresh();

      expect(c.state.period, ReportPeriod.month);
      expect(c.state.isLoading, isFalse);
      expect(c.state.total, 35000);
      expect(c.state.breakdown.first.total, 25000); // urut desc
      expect(c.state.breakdown.first.categoryName, 'Transportasi');
      expect(c.state.hasAnyData, isTrue);
      expect(c.state.errorMessage, isNull);
    });

    test('grafik 7 hari: H-6..H0, label nomor tanggal, kosong = 0',
        () async {
      final today = AppDate.todayIso();
      final d2 = AppDate.daysBefore(today, 2);
      await seed(amount: 12000, date: d2, createdAt: 1);

      final c = ReportController(expenses, budgets);
      await c.refresh();

      expect(c.state.bars.length, 7);
      expect(c.state.bars.first.dateIso, AppDate.daysBefore(today, 6));
      expect(c.state.bars.last.dateIso, today);
      expect(c.state.bars.last.label, AppDate.dayNumber(today));

      for (final b in c.state.bars) {
        expect(b.amount, b.dateIso == d2 ? 12000 : 0,
            reason: 'bar ${b.dateIso}');
      }
    });

    test('grafik 7 hari independen dari periode terpilih', () async {
      final today = AppDate.todayIso();
      final d2 = AppDate.daysBefore(today, 2);
      await seed(amount: 9000, date: d2, createdAt: 1);

      final c = ReportController(expenses, budgets);
      await c.refresh();
      await c.setPeriod(ReportPeriod.today);

      expect(c.state.total, 0); // tidak ada transaksi tepat hari ini
      expect(c.state.bars.firstWhere((b) => b.dateIso == d2).amount, 9000);
      expect(c.state.hasAnyData, isTrue); // batang > 0 membuat hasAnyData
    });

    test('ganti periode: total mengikuti rentang tanggal', () async {
      final today = AppDate.todayIso();
      final weekStart = AppDate.startOfWeek(today);
      final monthStart = AppDate.startOfMonth(today);
      final d10 = AppDate.daysBefore(today, 10);

      await seed(amount: 1000, date: today, createdAt: 1);
      await seed(amount: 2000, date: weekStart, createdAt: 2);
      await seed(amount: 4000, date: d10, createdAt: 3);

      final seeds = <(String, int)>[
        (today, 1000),
        (weekStart, 2000),
        (d10, 4000),
      ];
      int sumIn(String from, String to) => seeds
          .where((s) => s.$1.compareTo(from) >= 0 && s.$1.compareTo(to) <= 0)
          .fold<int>(0, (a, s) => a + s.$2);

      final c = ReportController(expenses, budgets);
      await c.refresh();

      await c.setPeriod(ReportPeriod.today);
      expect(c.state.total, sumIn(today, today));

      await c.setPeriod(ReportPeriod.week);
      expect(c.state.total, sumIn(weekStart, today));

      await c.setPeriod(ReportPeriod.month);
      expect(c.state.total, sumIn(monthStart, today));
    });

    test('DB kosong: hasAnyData false, budget belum diatur', () async {
      final c = ReportController(expenses, budgets);
      await c.refresh();
      expect(c.state.hasAnyData, isFalse);
      expect(c.state.total, 0);
      expect(c.state.breakdown, isEmpty);
      expect(c.state.bars.every((b) => b.amount == 0), isTrue);
      expect(c.state.budget.hasBudget, isFalse);
      expect(c.state.budget.used, 0);
    });

    test('saveBudget valid → tersimpan & perhitungan §11 benar', () async {
      final today = AppDate.todayIso();
      await seed(amount: 80000, date: today, createdAt: 1);

      final c = ReportController(expenses, budgets);
      await c.refresh();
      expect(c.state.budget.hasBudget, isFalse);

      expect(await c.saveBudget('100000'), isTrue);
      expect(c.state.budget.hasBudget, isTrue);
      expect(c.state.budget.budget, 100000);
      expect(c.state.budget.used, 80000);
      expect(c.state.budget.remaining, 20000);
      expect(c.state.budget.percent, 80);
      expect(c.state.budget.showWarning, isTrue); // >= 80%
      expect(c.state.budget.isOverBudget, isFalse);

      final stored =
          await budgets.get(AppDate.monthOf(today), AppDate.yearOf(today));
      expect(stored, isNotNull);
      expect(stored!.amount, 100000);
    });

    test('saveBudget ditolak diam-diam: kosong / huruf / nol', () async {
      final c = ReportController(expenses, budgets);
      await c.refresh();
      expect(await c.saveBudget(''), isFalse);
      expect(await c.saveBudget('abc'), isFalse);
      expect(await c.saveBudget('0'), isFalse);
      expect(c.state.budget.hasBudget, isFalse);

      // Paritas Android: filter digit membuang tanda → "-5000" jadi 5000
      // dan TETAP lolos (sama persis dengan `filter{isDigit}` di Kotlin).
      expect(await c.saveBudget('-5000'), isTrue);
      expect(c.state.budget.budget, 5000);
    });

    test('over budget: remaining minus, persen > 100', () async {
      final today = AppDate.todayIso();
      await seed(amount: 150000, date: today, createdAt: 1);
      final c = ReportController(expenses, budgets);
      await c.refresh();
      await c.saveBudget('100000');
      expect(c.state.budget.isOverBudget, isTrue);
      expect(c.state.budget.remaining, -50000);
      expect(c.state.budget.percent, 150);
      expect(c.state.budget.showWarning, isTrue);
    });

    test('computeBudgetState: rumus integer persis §11', () {
      expect(computeBudgetState(used: 5000, budgetAmount: null).hasBudget,
          isFalse);
      expect(
          computeBudgetState(used: 5000, budgetAmount: 0).hasBudget, isFalse);
      expect(computeBudgetState(used: 5000, budgetAmount: 0).used, 5000);

      // Pembulatan ke bawah: 1/3 = 33%.
      final a = computeBudgetState(used: 1, budgetAmount: 3);
      expect(a.percent, 33);
      expect(a.showWarning, isFalse);

      // 80% → peringatan; 79% tidak.
      expect(computeBudgetState(used: 80, budgetAmount: 100).showWarning,
          isTrue);
      expect(computeBudgetState(used: 79, budgetAmount: 100).showWarning,
          isFalse);

      // Tepat 100% → persen 100, bukan over (strict >), sisa 0.
      final b = computeBudgetState(used: 100, budgetAmount: 100);
      expect(b.percent, 100);
      expect(b.isOverBudget, isFalse);
      expect(b.remaining, 0);
      expect(b.showWarning, isTrue);
    });
  });
}
