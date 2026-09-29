import 'package:flutter_test/flutter_test.dart';

import 'package:dompetku_port/core/money.dart';

/// PHASE 3a — Aturan uang DompetKu (SPEC §3).
///
/// Kasus wajib: 0, 1, 999, 25.000, 1.000.000, 1.000.000.000.000, > MAX.
void main() {
  group('Money.format — Rp + pemisah titik (SPEC §3)', () {
    test('format dasar', () {
      expect(Money.format(0), 'Rp0');
      expect(Money.format(1), 'Rp1');
      expect(Money.format(999), 'Rp999');
      expect(Money.format(25000), 'Rp25.000');
      expect(Money.format(1000000), 'Rp1.000.000');
      expect(Money.format(1250000), 'Rp1.250.000');
      expect(Money.format(10000000), 'Rp10.000.000');
    });

    test('format batas MAX (1 triliun)', () {
      expect(Money.format(Money.maxAmount), 'Rp1.000.000.000.000');
      expect(Money.maxAmount, 1000000000000);
    });
  });

  group('Money.groupDigits — field nominal', () {
    test('pengelompokan real-time', () {
      expect(Money.groupDigits(''), '');
      expect(Money.groupDigits('0'), '0');
      expect(Money.groupDigits('1'), '1');
      expect(Money.groupDigits('999'), '999');
      expect(Money.groupDigits('25000'), '25.000');
      expect(Money.groupDigits('1000000'), '1.000.000');
      expect(Money.groupDigits('1000000000000'), '1.000.000.000.000');
    });

    test('buang non-digit, buang nol di depan', () {
      expect(Money.groupDigits('Rp25.000'), '25.000');
      expect(Money.groupDigits('007'), '7');
      expect(Money.groupDigits('  1 2 '),
          '12'); // paritas Kotlin: semua digit menyatu
    });
  });

  group('Money.parse — teks -> integer', () {
    test('parse format bebas', () {
      expect(Money.parse('25000'), 25000);
      expect(Money.parse('25.000'), 25000);
      expect(Money.parse('25,000'), 25000);
      expect(Money.parse('Rp25000'), 25000);
      expect(Money.parse(' 25.000 '), 25000);
      expect(Money.parse('0'), 0);
      expect(Money.parse('1000000000000'), 1000000000000);
    });

    test('tanpa digit -> null', () {
      expect(Money.parse(''), null);
      expect(Money.parse('   '), null);
      expect(Money.parse('abc'), null);
    });

    test('paritas CurrencyFormat: non-digit sepenuhnya dibuang', () {
      // Sengaja "25rb" -> 25 (CurrencyFormat memang buang semua non-digit;
      // penolakan "25rb" hanya berlaku di Quick Input — SPEC §4).
      expect(Money.parse('25rb'), 25);
    });
  });

  group('Money.isValidAmount — validasi nominal (SPEC §6)', () {
    test('0 dan negatif tidak valid', () {
      expect(Money.isValidAmount(0), false);
      expect(Money.isValidAmount(-1), false);
    });

    test('1 s/d MAX valid', () {
      expect(Money.isValidAmount(1), true);
      expect(Money.isValidAmount(999), true);
      expect(Money.isValidAmount(25000), true);
      expect(Money.isValidAmount(Money.maxAmount), true);
    });

    test('> MAX (1.000.000.000.001) tidak valid', () {
      expect(Money.isValidAmount(Money.maxAmount + 1), false);
      expect(Money.isValidAmount(9999999999999), false);
    });
  });

  group('tanpa floating point (integritas uang)', () {
    test('jumlah besar tetap exact setelah format+parse roundtrip', () {
      const values = [
        25000,
        1250000,
        999999999999,
        1000000000000,
      ];
      for (final v in values) {
        final text = Money.format(v);
        final back = Money.parse(text);
        expect(back, v, reason: 'roundtrip $text');
      }
    });

    test('pertambahan kumulatif tanpa galat pembulatan', () {
      var total = 0;
      for (var i = 0; i < 1000; i++) {
        total += 33333; // 999 x 33333 = 33299667 — tidak boleh melenceng
      }
      expect(total, 33333000);
      expect(Money.format(total), 'Rp33.333.000');
    });
  });

  group('determinisme', () {
    test('format tidak tergantung locale sistem', () {
      // Pemisah WAJIB titik (bukan koma) berapa pun locale mesin.
      expect(Money.format(1234567890), 'Rp1.234.567.890');
    });
  });
}
