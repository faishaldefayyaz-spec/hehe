import 'package:flutter_test/flutter_test.dart';

import 'package:dompetku_port/core/csv_utils.dart';

/// PHASE 7a — Util CSV murni (SPEC §12): RFC 4180 + aturan impor.
void main() {
  group('escapeField (RFC 4180)', () {
    test('field polos tidak diubah', () {
      expect(CsvUtils.escapeField('Makanan'), 'Makanan');
      expect(CsvUtils.escapeField('30000'), '30000');
      expect(CsvUtils.escapeField(''), '');
      expect(CsvUtils.escapeField('titik.'), 'titik.');
    });

    test('koma / kutip / newline → dibungkus & kutip digandakan', () {
      expect(CsvUtils.escapeField('a,b'), '"a,b"');
      expect(CsvUtils.escapeField('kata "hebat"'), '"kata ""hebat"""');
      expect(CsvUtils.escapeField('baris\nbaru'), '"baris\nbaru"');
      expect(CsvUtils.escapeField('baris\rbaru'), '"baris\rbaru"');
    });

    test('line(): gabungkan field ter-escape', () {
      expect(CsvUtils.line(['a', 'b,c', '30000']), 'a,"b,c",30000');
    });
  });

  group('parseLine (parser kutip)', () {
    test('tanpa kutip', () {
      expect(CsvUtils.parseLine('a,b,c'), ['a', 'b', 'c']);
      expect(CsvUtils.parseLine('a,'), ['a', '']); // koma ekor
      expect(CsvUtils.parseLine(''), ['']); // baris kosong = 1 field kosong
    });

    test('kutip dengan koma di dalam', () {
      expect(CsvUtils.parseLine('"a,b",c'), ['a,b', 'c']);
      expect(CsvUtils.parseLine('x,"y,z",w'), ['x', 'y,z', 'w']);
    });

    test('kutip ganda menjadi satu kutip', () {
      expect(CsvUtils.parseLine('"kata ""hebat"""'), ['kata "hebat"']);
    });

    test('kutip tidak ditutup → null (baris rusak)', () {
      expect(CsvUtils.parseLine('"belum selesai'), isNull);
      expect(CsvUtils.parseLine('"a,b'), isNull);
    });
  });

  group('buildRows (format ekspor §12.1)', () {
    test('header + CRLF + baris + CRLF penutup', () {
      final csv = CsvUtils.buildRows([
        ['29/09/2026', '18:20', 'Makanan', 'Makan ayam', '30000'],
      ]);
      expect(
          csv,
          'Tanggal,Waktu,Kategori,Catatan,Nominal\r\n'
          '29/09/2026,18:20,Makanan,Makan ayam,30000\r\n');
    });

    test('tanpa baris data → hanya header + CRLF', () {
      expect(CsvUtils.buildRows([]), '${CsvUtils.header}\r\n');
    });

    test('beberapa baris, semua pakai CRLF (bukan LF)', () {
      final csv = CsvUtils.buildRows([
        ['01/01/2026', '07:00', 'Minuman', '', '5000'],
        ['02/01/2026', '08:00', 'Lainnya', 'note', '7000'],
      ]);
      final lines = csv.split('\r\n');
      expect(lines.first, CsvUtils.header);
      expect(lines[1], '01/01/2026,07:00,Minuman,,5000');
      expect(lines[2], '02/01/2026,08:00,Lainnya,note,7000');
      expect(lines.last, ''); // diakhiri CRLF
      expect(csv.contains('\n') && !csv.contains('\r\n'), isFalse);
    });
  });

  group('parseImport — header (§12.2)', () {
    test('null / kosong / whitespace → null', () {
      expect(CsvUtils.parseImport(null), isNull);
      expect(CsvUtils.parseImport(''), isNull);
      expect(CsvUtils.parseImport('   \n  '), isNull);
    });

    test('header tidak dikenal → null (bukan CSV DompetKu)', () {
      expect(CsvUtils.parseImport('foo,bar\n1,2'), isNull);
      expect(CsvUtils.parseImport('Tanggal,Kategori\n29/09/2026,Makanan'),
          isNull); // kolom nominal hilang
      expect(CsvUtils.parseImport('Waktu,Nominal\n18:20,30000'), isNull);
    });

    test('urutan kolom bebas + kapitalisasi bebas', () {
      final f = CsvUtils.parseImport(
          'NOMINAL,Catatan,Kategori,Waktu,Tanggal\n30000,halo,Makanan,18:20,29/09/2026');
      expect(f, isNotNull);
      expect(f!.rows.single.dateIso, '2026-09-29');
      expect(f.rows.single.amount, 30000);
      expect(f.rows.single.time, '18:20');
      expect(f.rows.single.categoryName, 'Makanan');
      expect(f.rows.single.note, 'halo');
      expect(f.invalidLines, 0);
    });

    test('kolom opsional hilang → default 00:00 / Lainnya / ""', () {
      final f = CsvUtils.parseImport('Tanggal,Nominal\n29/09/2026,30000');
      expect(f, isNotNull);
      expect(f!.rows.single.time, '00:00');
      expect(f.rows.single.categoryName, 'Lainnya');
      expect(f.rows.single.note, '');
    });

    test('kategori kosong → Lainnya', () {
      final f = CsvUtils.parseImport(
          'Tanggal,Kategori,Nominal\n29/09/2026,,30000');
      expect(f!.rows.single.categoryName, 'Lainnya');
    });
  });

  group('parseImport — baris data (§12.2–4)', () {
    test('baris valid: nominal bebas format, tanggal valid', () {
      final f = CsvUtils.parseImport(
          'Tanggal,Nominal\n29/09/2026,"25.000"\n01/01/2026,Rp1.000.000');
      expect(f!.rows.length, 2);
      expect(f.rows[0].amount, 25000);
      expect(f.rows[1].amount, 1000000);
      expect(f.invalidLines, 0);
    });

    test('baris invalid dihitung: tanggal rusak / nominal ≤ 0 / kolom kurang',
        () {
      final f = CsvUtils.parseImport(
          'Tanggal,Nominal\n'
          '29/09/2026,30000\n' // valid
          '33/13/2026,30000\n' // bulan > 12
          'bukan-tanggal,30000\n' // format salah
          '29/09/2026,0\n' // nominal 0
          '29/09/2026\n'); // kolom nominal hilang
      expect(f!.rows.length, 1);
      expect(f.invalidLines, 4);
    });

    test('waktu tak cocok pola H:MM → "00:00"; pola sah dipertahankan', () {
      final f = CsvUtils.parseImport(
          'Tanggal,Waktu,Nominal\n'
          '29/09/2026,9:05,1000\n'
          '29/09/2026,09:05,1000\n'
          '29/09/2026,abc,1000\n'
          '29/09/2026,,1000');
      expect(f!.rows[0].time, '9:05'); // H:MM sah
      expect(f.rows[1].time, '09:05');
      expect(f.rows[2].time, '00:00');
      expect(f.rows[3].time, '00:00');
      expect(f.invalidLines, 0);
    });

    test('baris rusak (kutip tak tertutup) → invalid, bukan gagal total', () {
      final f = CsvUtils.parseImport(
          'Tanggal,Nominal\n29/09/2026,30000\n"29/09/2026,30000');
      expect(f, isNotNull);
      expect(f!.rows.length, 1);
      expect(f.invalidLines, 1);
    });

    test('baris kosong dilewati tanpa dihitung invalid', () {
      final f = CsvUtils.parseImport(
          'Tanggal,Nominal\n\n29/09/2026,30000\n\n\n');
      expect(f!.rows.length, 1);
      expect(f.invalidLines, 0);
    });

    test('CRLF & LF dua-duanya ditangani', () {
      final f = CsvUtils.parseImport(
          'Tanggal,Nominal\r\n29/09/2026,30000\r\n30/09/2026,40000\n');
      expect(f!.rows.length, 2);
      expect(f.rows[1].dateIso, '2026-09-30');
    });
  });
}
