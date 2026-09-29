import 'package:dompetku_port/core/app_date.dart';
import 'package:dompetku_port/core/money.dart';

/// Utilitas CSV murni (tanpa dependensi platform) untuk export & import —
/// port persis `CsvUtils` Android (SPEC §12).
///
/// Format ekspor:
/// ```text
/// Tanggal,Waktu,Kategori,Catatan,Nominal
/// 29/09/2026,18:20,Makanan,Makan ayam,30000
/// ```
class CsvUtils {
  CsvUtils._();

  static const String header = 'Tanggal,Waktu,Kategori,Catatan,Nominal';
  static const String _crlf = '\r\n';

  /// Escape satu field sesuai RFC 4180 (quote bila mengandung
  /// koma/kutip/newline; kutip digandakan).
  static String escapeField(String value) {
    final needsQuote = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuote) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  static String line(List<String> fields) => fields.map(escapeField).join(',');

  /// Parse satu baris CSV (mendukung field bersisip kutip ganda & koma
  /// di dalam kutipan). @return list field, atau `null` bila tak valid
  /// (kutipan tidak ditutup).
  static List<String>? parseLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;
    var i = 0;
    final len = line.length;
    while (i < len) {
      final ch = line[i];
      if (inQuotes) {
        if (ch == '"' && i + 1 < len && line[i + 1] == '"') {
          sb.write('"');
          i += 2;
          continue;
        }
        if (ch == '"') {
          inQuotes = false;
          i++;
          continue;
        }
        sb.write(ch);
        i++;
        continue;
      }
      if (ch == '"' && sb.isEmpty) {
        inQuotes = true;
        i++;
        continue;
      }
      if (ch == ',') {
        result.add(sb.toString());
        sb.clear();
        i++;
        continue;
      }
      sb.write(ch);
      i++;
    }
    if (inQuotes) return null; // kutipan tidak ditutup
    result.add(sb.toString());
    return result;
  }

  /// Isi file ekspor: header + baris data (CRLF), diakhiri CRLF.
  static String buildRows(List<List<String>> rows) {
    final sb = StringBuffer(header);
    for (final row in rows) {
      sb.write(_crlf);
      sb.write(line(row));
    }
    sb.write(_crlf);
    return sb.toString();
  }

  static final RegExp _timePattern = RegExp(r'^\d{1,2}:\d{2}$');

  /// Parse isi file CSV impor.
  ///
  /// Header wajib punya kolom `tanggal` + `nominal` (case-insensitive,
  /// urutan bebas); `waktu`/`kategori`/`catatan` opsional. Baris invalid
  /// dihitung (SPEC §12.2–3).
  ///
  /// @return `null` bila header tidak dikenal / file kosong (bukan CSV
  /// DompetKu).
  static CsvImportFile? parseImport(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final lines = text
        .split('\n')
        .map((l) => l.trimRight().endsWith('\r')
            ? l.substring(0, l.length - 1)
            : l)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final headerFields = parseLine(lines.first);
    if (headerFields == null) return null;
    final normalized = headerFields.map((h) => h.trim().toLowerCase()).toList();
    final idxTanggal = normalized.indexOf('tanggal');
    final idxWaktu = normalized.indexOf('waktu');
    final idxKategori = normalized.indexOf('kategori');
    final idxCatatan = normalized.indexOf('catatan');
    final idxNominal = normalized.indexOf('nominal');
    if (idxTanggal < 0 || idxNominal < 0) return null;

    final rows = <CsvImportRow>[];
    var invalid = 0;

    for (var i = 1; i < lines.length; i++) {
      final cols = parseLine(lines[i]);
      if (cols == null) {
        invalid++;
        continue;
      }
      final dateIso = idxTanggal < cols.length
          ? AppDate.parseCsvDate(cols[idxTanggal])
          : null;
      final amount = idxNominal < cols.length ? Money.parse(cols[idxNominal]) : null;
      if (dateIso == null || amount == null || amount <= 0) {
        invalid++;
        continue;
      }
      final timeRaw = idxWaktu >= 0 && idxWaktu < cols.length
          ? cols[idxWaktu].trim()
          : '';
      final time = _timePattern.hasMatch(timeRaw) ? timeRaw : '00:00';
      final categoryName = (idxKategori >= 0 && idxKategori < cols.length
              ? cols[idxKategori].trim()
              : '')
          .isEmpty
          ? 'Lainnya'
          : cols[idxKategori].trim();
      final note = idxCatatan >= 0 && idxCatatan < cols.length
          ? cols[idxCatatan].trim()
          : '';

      rows.add(CsvImportRow(
        dateIso: dateIso,
        time: time,
        categoryName: categoryName,
        note: note,
        amount: amount,
      ));
    }

    return CsvImportFile(rows: rows, invalidLines: invalid);
  }
}

/// Satu baris hasil pembacaan file CSV impor.
class CsvImportRow {
  const CsvImportRow({
    required this.dateIso,
    required this.time,
    required this.categoryName,
    required this.note,
    required this.amount,
  });

  /// `yyyy-MM-dd`.
  final String dateIso;

  /// `HH:mm`.
  final String time;
  final String categoryName;
  final String note;
  final int amount;
}

/// Hasil pembacaan file CSV impor (baris valid + jumlah baris invalid).
class CsvImportFile {
  const CsvImportFile({required this.rows, required this.invalidLines});

  final List<CsvImportRow> rows;
  final int invalidLines;
}
