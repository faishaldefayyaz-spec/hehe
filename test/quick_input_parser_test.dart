import 'package:flutter_test/flutter_test.dart';

import 'package:dompetku_port/core/quick_input_parser.dart';

/// PHASE 4 — Regression test Quick Input Parser (SPEC §4).
///
/// Port harus menghasilkan perilaku **identik** dengan parser Android.
void main() {
  group('kasus contoh resmi (SPEC §4)', () {
    test('"makan ayam 30000" -> Makanan + 30000 + catatan "ayam"', () {
      final r = QuickInputParser.parse('makan ayam 30000');
      expect(r.amount, 30000);
      expect(r.categoryName, 'Makanan');
      expect(r.note, 'ayam');
      expect(r.matchedKeyword, 'makan');
      expect(r.hasAmount, isTrue);
      expect(r.hasCategory, isTrue);
    });

    test('"bensin 50000" -> Transportasi + 50000 + catatan kosong', () {
      final r = QuickInputParser.parse('bensin 50000');
      expect(r.amount, 50000);
      expect(r.categoryName, 'Transportasi');
      expect(r.note, '');
    });

    test('"kopi 15000" -> Minuman + 15000 + catatan kosong', () {
      final r = QuickInputParser.parse('kopi 15000');
      expect(r.amount, 15000);
      expect(r.categoryName, 'Minuman');
      expect(r.note, '');
    });

    test('"asdfgh 9000" -> kategori null + 9000 + catatan "asdfgh"', () {
      final r = QuickInputParser.parse('asdfgh 9000');
      expect(r.amount, 9000);
      expect(r.categoryName, isNull); // caller memakai chip pilihan manual
      expect(r.note, 'asdfgh');
      expect(r.hasCategory, isFalse);
    });
  });

  group('kasus uji nyata emulator (audit Android 1.0)', () {
    test('"makan ayam 12000" -> Makanan + 12000 + "ayam"', () {
      final r = QuickInputParser.parse('makan ayam 12000');
      expect(r.amount, 12000);
      expect(r.categoryName, 'Makanan');
      expect(r.note, 'ayam');
    });
  });

  group('aturan nominal (SPEC §4.1)', () {
    test('token angka pertama menang, sisanya jadi catatan', () {
      final r = QuickInputParser.parse('30000 makan');
      expect(r.amount, 30000);
      expect(r.categoryName, 'Makanan');
      expect(r.note, '');
    });

    test('pemisah titik & koma diterima', () {
      expect(QuickInputParser.parse('makan 25.000').amount, 25000);
      expect(QuickInputParser.parse('makan 25,000').amount, 25000);
      expect(QuickInputParser.parse('nasi goreng 25.000').amount, 25000);
    });

    test('awalan rp diterima (case-insensitive)', () {
      expect(QuickInputParser.parse('makan rp30000').amount, 30000);
      expect(QuickInputParser.parse('makan RP30000').amount, 30000);
      final r = QuickInputParser.parse('rp1.000.000 belanja');
      expect(r.amount, 1000000);
      expect(r.categoryName, 'Belanja');
    });

    test('"25rb" DITOLAK jadi nominal (ada huruf) — khusus parser ini', () {
      // Berbeda dari Money.parse: Quick Input menolak token campur huruf.
      final r = QuickInputParser.parse('makan 25rb');
      expect(r.amount, isNull);
      expect(r.categoryName, 'Makanan');
      expect(r.note, '25rb'); // token tetap menjadi catatan
    });

    test('nominal 0 terbaca tapi hasAmount = false', () {
      final r = QuickInputParser.parse('makan 0');
      expect(r.amount, 0);
      expect(r.hasAmount, isFalse); // amount > 0 requirement
    });

    test('tanpa angka sama sekali', () {
      final r = QuickInputParser.parse('makan ayam geprek');
      expect(r.amount, isNull);
      expect(r.hasAmount, isFalse);
      expect(r.categoryName, 'Makanan');
      expect(r.note, 'ayam geprek'); // semua token sisa jadi catatan
    });

    test('nominal besar tetap exact (int, tanpa float)', () {
      expect(QuickInputParser.parse('makan 1000000000000').amount, 1000000000000);
    });
  });

  group('aturan kategori (SPEC §4.2)', () {
    test('nama kategori user didahulukan atas alias', () {
      // User punya kategori bernama "Kopi" (bukan default) -> menang atas
      // alias 'kopi' -> Minuman.
      final r = QuickInputParser.parse('kopi 15000',
          categoryNames: ['Kopi', 'Makanan']);
      expect(r.categoryName, 'Kopi');
      expect(r.matchedKeyword, 'kopi');
    });

    test('pencocokan case-insensitive', () {
      expect(QuickInputParser.parse('MAKAN 30000').categoryName, 'Makanan');
      expect(QuickInputParser.parse('Kopi 15000').categoryName, 'Minuman');
      // Nama kategori multi-kata ("Kopi Senja") TIDAK pernah cocok karena
      // parser mencocokkan PER TOKEN — alias 'kopi' menang. (Paritas Android.)
      final r = QuickInputParser.parse('kopi susu 15000',
          categoryNames: ['KOPI SENJA']);
      expect(r.categoryName, 'Minuman');
      expect(r.note, 'susu');
    });

    test('token pertama yang cocok menang (urutan)', () {
      final r = QuickInputParser.parse('nasi kopi 20000');
      expect(r.categoryName, 'Makanan'); // "nasi" lebih dulu
      expect(r.note, 'kopi');
    });
  });

  group('tokenisasi & input kosong (SPEC §4)', () {
    test('input kosong / whitespace -> hasil null semua', () {
      for (final input in ['', '   ', '\t\n']) {
        final r = QuickInputParser.parse(input);
        expect(r.amount, isNull, reason: '[$input]');
        expect(r.categoryName, isNull, reason: '[$input]');
        expect(r.note, '', reason: '[$input]');
      }
    });

    test('spasi berlebihan tidak membuat token kosong', () {
      final r = QuickInputParser.parse('  makan   ayam   30000  ');
      expect(r.amount, 30000);
      expect(r.note, 'ayam');
    });
  });

  group('regression: SEMUA alias di tabel SPEC §4', () {
    const expected = <String, List<String>>{
      'Makanan': [
        'makan', 'makanan', 'sarapan', 'nasi', 'nasgor', 'gofood', 'grabfood'
      ],
      'Minuman': ['minum', 'minuman', 'kopi', 'teh', 'jus', 'es', 'drink'],
      'Transportasi': [
        'transportasi', 'transport', 'bensin', 'bbm', 'pertamax', 'ojek',
        'ojol', 'angkot', 'bus', 'kereta', 'taksi', 'taxi', 'parkir', 'tol',
        'gojek', 'grab'
      ],
      'Belanja': [
        'belanja', 'belanjaan', 'grocery', 'sayur', 'pasar', 'baju',
        'shopee', 'tokopedia'
      ],
      'Rumah': [
        'rumah', 'kos', 'kost', 'sewa', 'kontrakan', 'perabot', 'furnitur'
      ],
      'Tagihan': [
        'tagihan', 'listrik', 'pln', 'air', 'pdam', 'wifi', 'internet',
        'pulsa', 'gas', 'iuran'
      ],
      'Kesehatan': ['kesehatan', 'obat', 'dokter', 'vitamin', 'bpjs', 'klinik'],
      'Hiburan': [
        'hiburan', 'nonton', 'film', 'movie', 'game', 'bioskop', 'konser',
        'liburan'
      ],
      'Pekerjaan': ['pekerjaan', 'kerja', 'kantor', 'atk', 'operasional'],
      'Hadiah': [
        'hadiah', 'kado', 'sumbangan', 'infaq', 'sedekah', 'zakat'
      ],
      'Langganan': [
        'langganan', 'subscription', 'netflix', 'spotify', 'youtube', 'premi'
      ],
      'Lainnya': ['lainnya', 'lain', 'misc', 'aneka'],
    };

    test('tabel alias parser == tabel SPEC', () {
      // Jumlah total alias harus sama dengan SPEC (91 kata).
      final totalSpec = expected.values.fold<int>(0, (a, b) => a + b.length);
      expect(QuickInputParser.aliases.length, totalSpec);

      expected.forEach((kategori, kata) {
        for (final k in kata) {
          expect(QuickInputParser.aliases[k], kategori,
              reason: 'alias "$k" harus -> $kategori');
        }
      });
    });

    test('setiap alias menghasilkan kategori yang benar lewat parse()', () {
      expected.forEach((kategori, kata) {
        for (final k in kata) {
          final r = QuickInputParser.parse('$k 5000');
          expect(r.categoryName, kategori,
              reason: 'parse "$k 5000" harus -> $kategori');
          expect(r.amount, 5000);
        }
      });
    });
  });
}
