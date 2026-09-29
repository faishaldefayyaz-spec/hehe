/// Konversi warna ARGB <-> INTEGER32-bit signed.
///
/// Android menyimpan warna sebagai `int`32-bit signed (hasil
/// `ContextCompat.getColor`), mis. `0xFFEA580C` menjadi `-1419252`.
/// Database DompetKu 1.0 berisi warna dalam format signed ini, sehingga
/// port Flutter HARUS memakai representasi yang sama agar data
/// (termasuk file backup) identik bit-per-bit antar platform.
library;

/// Konversi warna ARGB hex (mis. `0xFFEA580C`) menjadi INTEGER32-bit signed
/// persis seperti nilai yang disimpan Android ke SQLite.
int argbToSigned32(int argb) {
  final unsigned = argb & 0xFFFFFFFF;
  return unsigned >= 0x80000000 ? unsigned - 0x100000000 : unsigned;
}

/// Konversi nilai INTEGER dari database kembali ke bentuk ARGB unsigned
/// (untuk dipakai `Color(...)` di UI).
int signed32ToArgb(int dbValue) => dbValue & 0xFFFFFFFF;
