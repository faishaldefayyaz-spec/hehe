import 'package:flutter_test/flutter_test.dart';

import 'package:dompetku_port/core/app_date.dart';

/// PHASE 6a — Tanggal/waktu (SPEC §7) + aturan CSV date/time (§12).
void main() {
  group('format tampilan (locale id_ID)', () {
    test('toDisplay: "d MMMM yyyy" Indonesia', () {
      expect(AppDate.toDisplay('2026-09-29'), '29 September 2026');
      expect(AppDate.toDisplay('2026-01-05'), '5 Januari 2026');
      expect(AppDate.toDisplay('2024-12-31'), '31 Desember 2024');
    });

    test('toDisplay gagal -> kembalikan ISO mentah (paritas Android)', () {
      expect(AppDate.toDisplay('bogus'), 'bogus');
      expect(AppDate.toDisplay(''), '');
    });

    test('lenient roll-over ala SimpleDateFormat: 31 Feb -> 3 Maret', () {
      // Android: SimpleDateFormat lenient men rollover "2026-02-31".
      expect(AppDate.toDisplay('2026-02-31'), '3 Maret 2026');
    });

    test('toTime: HH:mm dipadatkan', () {
      expect(AppDate.toTime(DateTime(2026, 9, 29, 18, 35).millisecondsSinceEpoch),
          '18:35');
      expect(AppDate.toTime(DateTime(2026, 1, 2, 7, 5).millisecondsSinceEpoch),
          '07:05');
      expect(AppDate.toTime(DateTime(2026, 1, 2, 0, 0).millisecondsSinceEpoch),
          '00:00');
    });

    test('toIso dari DateTime lokal', () {
      expect(AppDate.toIso(DateTime(2026, 9, 29, 15, 45).millisecondsSinceEpoch),
          '2026-09-29');
    });
  });

  group('CSV date/time (SPEC §12)', () {
    test('toCsvDate dd/MM/yyyy', () {
      expect(AppDate.toCsvDate('2026-09-29'), '29/09/2026');
      expect(AppDate.toCsvDate('2026-01-05'), '05/01/2026');
      expect(AppDate.toCsvDate('bogus'), 'bogus');
    });

    test('parseCsvDate valid', () {
      expect(AppDate.parseCsvDate('29/09/2026'), '2026-09-29');
      expect(AppDate.parseCsvDate(' 1/2/2026 '), '2026-02-01');
      expect(AppDate.parseCsvDate('29/02/2020'), '2020-02-29');
      // Rentang lolos validasi (hari ≤ 31) — disimpan mentah, paritas Android.
      expect(AppDate.parseCsvDate('31/02/2026'), '2026-02-31');
    });

    test('parseCsvDate ditolak di luar validasi', () {
      expect(AppDate.parseCsvDate('x/y/z'), isNull);
      expect(AppDate.parseCsvDate('29-09-2026'), isNull); // pemisah salah
      expect(AppDate.parseCsvDate('29/13/2026'), isNull); // bulan > 12
      expect(AppDate.parseCsvDate('0/1/2026'), isNull); // hari < 1
      expect(AppDate.parseCsvDate('32/1/2026'), isNull); // hari > 31
      expect(AppDate.parseCsvDate('1/1/1969'), isNull); // tahun < 1970
      expect(AppDate.parseCsvDate('1/1/2201'), isNull); // tahun > 2200
      expect(AppDate.parseCsvDate(''), isNull);
    });

    test('parseCsvTime: hari valid + jam dinormalisasi', () {
      final base = DateTime(2026, 9, 29).millisecondsSinceEpoch;
      expect(AppDate.parseCsvTime('2026-09-29', '18:20'),
          DateTime(2026, 9, 29, 18, 20).millisecondsSinceEpoch);
      expect(AppDate.parseCsvTime('2026-09-29', ''), base); // -> 00:00
      expect(AppDate.parseCsvTime('2026-09-29', 'abc'), base);
      // jam/menit di luar 0..23/0..59 di-clamp (paritas coerceIn)
      expect(AppDate.parseCsvTime('2026-09-29', '99:99'),
          DateTime(2026, 9, 29, 23, 59).millisecondsSinceEpoch);
    });

    test('parseCsvTime: hari tak terbaca -> 0', () {
      expect(AppDate.parseCsvTime('bogus', '18:20'), 0);
      expect(AppDate.parseCsvTime('', '18:20'), 0);
    });
  });

  group('rentang kalender (minggu = Senin)', () {
    test('startOfWeek/endOfWeek', () {
      // 2026-09-29 = Selasa -> minggu 2026-09-28 (Sen) s/d 2026-10-04 (Min).
      expect(AppDate.startOfWeek('2026-09-29'), '2026-09-28');
      expect(AppDate.endOfWeek('2026-09-29'), '2026-10-04');
      // Sudah Senin -> tetap hari itu.
      expect(AppDate.startOfWeek('2026-09-28'), '2026-09-28');
      // Lintas tahun: 2026-01-01 = Kamis -> Senin 2025-12-29.
      expect(AppDate.startOfWeek('2026-01-01'), '2025-12-29');
      expect(AppDate.endOfWeek('2026-01-01'), '2026-01-04');
      // Minggu penuh 7 hari.
      final s = AppDate.startOfWeek('2026-09-29');
      final e = AppDate.endOfWeek('2026-09-29');
      expect(DateTime.parse(e).difference(DateTime.parse(s)).inDays, 6);
    });

    test('startOfMonth/endOfMonth (termasuk kabisat)', () {
      expect(AppDate.startOfMonth('2026-09-29'), '2026-09-01');
      expect(AppDate.endOfMonth('2026-09-29'), '2026-09-30');
      expect(AppDate.endOfMonth('2026-02-10'), '2026-02-28');
      expect(AppDate.endOfMonth('2024-02-10'), '2024-02-29');
      expect(AppDate.endOfMonth('2026-12-31'), '2026-12-31');
    });

    test('daysBefore lintas bulan/tahun', () {
      expect(AppDate.daysBefore('2026-03-01', 6), '2026-02-23');
      expect(AppDate.daysBefore('2026-01-02', 5), '2025-12-28');
      expect(AppDate.daysBefore('2026-09-29', 0), '2026-09-29');
      expect(AppDate.daysBefore('2026-09-29', 7), '2026-09-22');
    });

    test('monthOf/yearOf/dayOfMonth', () {
      expect(AppDate.monthOf('2026-09-29'), 9);
      expect(AppDate.yearOf('2026-09-29'), 2026);
      expect(AppDate.dayOfMonth('2026-09-29'), 29);
      expect(AppDate.monthOf('2026-12-31'), 12);
    });

    test('isoOf', () {
      expect(AppDate.isoOf(2026, 9, 29), '2026-09-29');
      expect(AppDate.isoOf(2026, 1, 5), '2026-01-05');
    });
  });

  group('label chart & hari ini', () {
    test('shortDayName Sen..Min', () {
      expect(AppDate.shortDayName('2026-09-28'), 'Sen'); // Senin
      expect(AppDate.shortDayName('2026-09-29'), 'Sel');
      expect(AppDate.shortDayName('2026-09-30'), 'Rab');
      expect(AppDate.shortDayName('2026-10-04'), 'Min'); // Minggu
      expect(AppDate.shortDayName('bogus'), '');
    });

    test('dayNumber = nomor tanggal', () {
      expect(AppDate.dayNumber('2026-09-29'), '29');
      expect(AppDate.dayNumber('2026-10-04'), '04');
    });

    test('hari ini konsisten dengan kalender', () {
      final today = AppDate.todayIso();
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(today), isTrue);
      expect(AppDate.parseIso(today), isNotNull);
      // today berada di minggu & bulan berjalan (semua diturunkan dari
      // variabel yang sama — bebas race lintas tengah malam).
      expect(today.compareTo(AppDate.startOfWeek(today)), greaterThanOrEqualTo(0));
      expect(today.compareTo(AppDate.endOfWeek(today)), lessThanOrEqualTo(0));
      expect(today.compareTo(AppDate.startOfMonth(today)), greaterThanOrEqualTo(0));
      expect(today.compareTo(AppDate.endOfMonth(today)), lessThanOrEqualTo(0));
      expect(AppDate.dayOfMonth(today), greaterThanOrEqualTo(1));
    });
  });
}
