/// Aturan uang DompetKu — **SPEC-DOMPETKU-1.0 §3**.
///
/// Port dari `CurrencyFormat` (Android/Kotlin). Nilai selalu integer
/// (setara Kotlin `Long`) — tidak pernah double/float.
class Money {
  Money._();

  /// Batas wajar nominal: 1 triliun (SPEC §3 — `MAX_AMOUNT`).
  static const int maxAmount = 1000000000000;

  /// Format tampilan: `Rp25.000`, `Rp1.250.000`, `Rp10.000.000`.
  /// Pemisah ribuan selalu titik (locale Indonesia).
  static String format(int amount) => 'Rp${groupDigits(amount.toString())}';

  /// Kelompokkan digit dengan titik — `25000` -> `25.000`.
  /// Mengembalikan `''` bila tidak ada digit sama sekali.
  static String groupDigits(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return '';
    final value = int.tryParse(cleaned);
    // Paritas Kotlin: bila angka tidak muat (overflow), kembalikan mentah.
    if (value == null) return cleaned;
    return _group(value.toString());
  }

  /// Parse bebas (`"25.000"`, `"Rp25000"`, `" 25,000 "`) -> `25000`.
  /// `null` bila tidak ada digit atau meluber dari64-bit.
  static int? parse(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  /// Validasi nominal sesuai urutan save (SPEC §6): `0 < amount <= max`.
  static bool isValidAmount(int amount) => amount > 0 && amount <= maxAmount;

  static String _group(String digits) {
    final negative = digits.startsWith('-');
    final d = negative ? digits.substring(1) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && (d.length - i) % 3 == 0) buf.write('.');
      buf.write(d[i]);
    }
    return negative ? '-${buf.toString()}' : buf.toString();
  }
}
