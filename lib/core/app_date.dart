/// Utilitas tanggal/waktu DompetKu — **SPEC §7**.
///
/// Port persis `DateUtils` Android/Kotlin:
///  * internal ISO `yyyy-MM-dd` (perbandingan string = kronologis);
///  * timezone perangkat; tampilan locale Indonesia
///    (`"29 September 2026"`, `"18:35"`);
///  * minggu mulai **Senin**; parser meniru sifat *lenient* SimpleDateFormat
///    (tanggal meluber seperti `31/02` dinormalisasi ala Java).
class AppDate {
  AppDate._();

  static const List<String> _monthsId = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  /// Nama hari pendek (index = `DateTime.weekday`, Senin = 1).
  static const List<String> _shortDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  static int now() => DateTime.now().millisecondsSinceEpoch;

  /// ISO hari ini, contoh `"2026-09-29"`.
  static String todayIso() => toIso(now());

  static String toIso(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return _fmt(d);
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// `"29 September 2026"` — bila ISO tak terbaca, kembalikan input
  /// (paritas Android: fallback `iso`).
  static String toDisplay(String iso) {
    final d = parseIso(iso);
    if (d == null) return iso;
    return '${d.day} ${_monthsId[d.month - 1]} ${d.year}';
  }

  /// `"18:35"` dari epoch milli (timezone perangkat).
  static String toTime(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// `dd/MM/yyyy` untuk CSV — bila gagal, kembalikan ISO mentah.
  static String toCsvDate(String iso) {
    final d = parseIso(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String toCsvTime(int millis) => toTime(millis);

  /// Parse ISO (meniru lenient `SimpleDateFormat`): komponen tak valid
  /// (mis. hari 31 untuk bulan 2) **dinormalisasi** seperti Java.
  static DateTime? parseIso(String iso) {
    if (iso.trim().isEmpty) return null;
    try {
      return DateTime.parse(iso.trim());
    } catch (_) {
      // Lenient roll-over: "2026-02-31" -> 3 Maret 2026 (paritas Java).
      final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(iso.trim());
      if (m == null) return null;
      final y = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final da = int.tryParse(m.group(3)!);
      if (y == null || mo == null || da == null) return null;
      try {
        return DateTime(y, mo, da); // Dart me-normalisasi overflow
      } catch (_) {
        return null;
      }
    }
  }

  /// Parse `"29/09/2026"` -> ISO, atau `null`. Validasi: tahun 1970–2200,
  /// bulan 1–12, hari 1–31 (persis SPEC §12.2).
  static String? parseCsvDate(String text) {
    final parts = text.trim().split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (year < 1970 || year > 2200 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  /// Parse `"18:20"` -> epoch milli hari [dayIso] itu (detik/mili nol).
  /// Hari tidak terbaca -> `0` (paritas Android).
  static int parseCsvTime(String dayIso, String timeText) {
    final date = parseIso(dayIso);
    if (date == null) return 0;
    final parts = timeText.trim().split(':');
    final hour = (parts.isNotEmpty ? int.tryParse(parts[0].trim()) : null) ?? 0;
    final minute = (parts.length > 1 ? int.tryParse(parts[1].trim()) : null) ?? 0;
    return DateTime(
      date.year,
      date.month,
      date.day,
      hour.clamp(0, 23),
      minute.clamp(0, 59),
    ).millisecondsSinceEpoch;
  }

  static DateTime _dayOf(String iso) =>
      parseIso(iso) ?? DateTime.fromMillisecondsSinceEpoch(now());

  /// Awal minggu (**Senin**) dari [iso].
  static String startOfWeek(String iso) {
    final d = _dayOf(iso);
    return _fmt(DateTime(d.year, d.month, d.day - (d.weekday - 1)));
  }

  static String endOfWeek(String iso) {
    final d = _dayOf(iso);
    return _fmt(DateTime(d.year, d.month, d.day - (d.weekday - 1) + 6));
  }

  static String startOfMonth(String iso) {
    final d = _dayOf(iso);
    return _fmt(DateTime(d.year, d.month, 1));
  }

  static String endOfMonth(String iso) {
    final d = _dayOf(iso);
    // DateTime(y, m+1, 0) = hari terakhir bulan m (normalisasi Dart).
    return _fmt(DateTime(d.year, d.month + 1, 0));
  }

  /// `[daysBack]` hari ke belakang (0 = iso itu sendiri).
  static String daysBefore(String iso, int daysBack) {
    final d = _dayOf(iso);
    return _fmt(DateTime(d.year, d.month, d.day - daysBack));
  }

  static int monthOf(String iso) => _dayOf(iso).month;

  static int yearOf(String iso) => _dayOf(iso).year;

  static int dayOfMonth(String iso) => _dayOf(iso).day;

  /// ISO dari komponen (penengah jam 12 agar aman lintas timezone/DST).
  static String isoOf(int year, int month, int day) =>
      _fmt(DateTime(year, month, day, 12));

  /// Epoch milli tengah malam hari ini (timezone perangkat).
  static int todayMillisAtStartOfDay() {
    final n = DateTime.fromMillisecondsSinceEpoch(now());
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
  }

  /// Nama hari pendek label chart: `"Sen"`..`"Min"`.
  static String shortDayName(String iso) {
    final d = parseIso(iso);
    if (d == null) return '';
    return _shortDays[d.weekday - 1];
  }

  /// Tanggal pendek label sumbu X, contoh `"29"`.
  static String dayNumber(String iso) {
    final i = iso.lastIndexOf('-');
    return i >= 0 ? iso.substring(i + 1) : iso;
  }
}
