/// Quick Input Parser — **100% lokal, tanpa AI/API** (SPEC §4).
///
/// Port persis `QuickInputParser` Android/Kotlin. Contoh:
///   `"makan ayam 30000"` -> kategori Makanan, nominal 30000, catatan "ayam"
///   `"bensin 50000"`     -> kategori Transportasi, nominal 50000, catatan ""
///   `"asdfgh 9000"`      -> kategori null, nominal 9000, catatan "asdfgh"
///
/// Aturan (SPEC §4):
///  1. Nominal = token pertama yang seluruh isinya angka
///     (boleh pemisah `.` `,` atau awalan `rp`).
///  2. Kategori = token pertama yang cocok dengan nama kategori user
///     ATAU alias bawaan.
///  3. Sisa token menjadi catatan.
library;

class QuickInputResult {
  const QuickInputResult({
    required this.amount,
    required this.categoryName,
    required this.note,
    this.matchedKeyword,
  });

  /// `null` jika tidak ada nominal terbaca.
  final int? amount;

  /// `null` jika kategori tidak dikenali (caller memakai "Lainnya").
  final String? categoryName;

  final String note;

  /// Kata yang cocok dengan kategori (nama user atau alias).
  final String? matchedKeyword;

  /// Paritas Kotlin: amount != null && amount > 0.
  bool get hasAmount => amount != null && amount! > 0;

  bool get hasCategory => categoryName != null;
}

class QuickInputParser {
  QuickInputParser._();

  /// Alias kata -> nama kategori bawaan — **identik 100% dengan SPEC §4**.
  static const Map<String, String> aliases = {
    // Makanan
    'makan': 'Makanan',
    'makanan': 'Makanan',
    'sarapan': 'Makanan',
    'nasi': 'Makanan',
    'nasgor': 'Makanan',
    'gofood': 'Makanan',
    'grabfood': 'Makanan',
    // Minuman
    'minum': 'Minuman',
    'minuman': 'Minuman',
    'kopi': 'Minuman',
    'teh': 'Minuman',
    'jus': 'Minuman',
    'es': 'Minuman',
    'drink': 'Minuman',
    // Transportasi
    'transportasi': 'Transportasi',
    'transport': 'Transportasi',
    'bensin': 'Transportasi',
    'bbm': 'Transportasi',
    'pertamax': 'Transportasi',
    'ojek': 'Transportasi',
    'ojol': 'Transportasi',
    'angkot': 'Transportasi',
    'bus': 'Transportasi',
    'kereta': 'Transportasi',
    'taksi': 'Transportasi',
    'taxi': 'Transportasi',
    'parkir': 'Transportasi',
    'tol': 'Transportasi',
    'gojek': 'Transportasi',
    'grab': 'Transportasi',
    // Belanja
    'belanja': 'Belanja',
    'belanjaan': 'Belanja',
    'grocery': 'Belanja',
    'sayur': 'Belanja',
    'pasar': 'Belanja',
    'baju': 'Belanja',
    'shopee': 'Belanja',
    'tokopedia': 'Belanja',
    // Rumah
    'rumah': 'Rumah',
    'kos': 'Rumah',
    'kost': 'Rumah',
    'sewa': 'Rumah',
    'kontrakan': 'Rumah',
    'perabot': 'Rumah',
    'furnitur': 'Rumah',
    // Tagihan
    'tagihan': 'Tagihan',
    'listrik': 'Tagihan',
    'pln': 'Tagihan',
    'air': 'Tagihan',
    'pdam': 'Tagihan',
    'wifi': 'Tagihan',
    'internet': 'Tagihan',
    'pulsa': 'Tagihan',
    'gas': 'Tagihan',
    'iuran': 'Tagihan',
    // Kesehatan
    'kesehatan': 'Kesehatan',
    'obat': 'Kesehatan',
    'dokter': 'Kesehatan',
    'vitamin': 'Kesehatan',
    'bpjs': 'Kesehatan',
    'klinik': 'Kesehatan',
    // Hiburan
    'hiburan': 'Hiburan',
    'nonton': 'Hiburan',
    'film': 'Hiburan',
    'movie': 'Hiburan',
    'game': 'Hiburan',
    'bioskop': 'Hiburan',
    'konser': 'Hiburan',
    'liburan': 'Hiburan',
    // Pekerjaan
    'pekerjaan': 'Pekerjaan',
    'kerja': 'Pekerjaan',
    'kantor': 'Pekerjaan',
    'atk': 'Pekerjaan',
    'operasional': 'Pekerjaan',
    // Hadiah
    'hadiah': 'Hadiah',
    'kado': 'Hadiah',
    'sumbangan': 'Hadiah',
    'infaq': 'Hadiah',
    'sedekah': 'Hadiah',
    'zakat': 'Hadiah',
    // Langganan
    'langganan': 'Langganan',
    'subscription': 'Langganan',
    'netflix': 'Langganan',
    'spotify': 'Langganan',
    'youtube': 'Langganan',
    'premi': 'Langganan',
    // Lainnya
    'lainnya': 'Lainnya',
    'lain': 'Lainnya',
    'misc': 'Lainnya',
    'aneka': 'Lainnya',
  };

  /// Parse satu baris teks bebas.
  ///
  /// [categoryNames] = nama kategori milik user (dicek dulu, case-insensitive,
  /// sebelum alias bawaan).
  static QuickInputResult parse(String input,
      {List<String> categoryNames = const []}) {
    final tokens = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return const QuickInputResult(
          amount: null, categoryName: null, note: '');
    }

    // 1) Nominal: token pertama yang seluruh isinya angka.
    int? amount;
    var amountIndex = -1;
    for (var i = 0; i < tokens.length; i++) {
      final value = _amountFrom(tokens[i]);
      if (value != null) {
        amount = value;
        amountIndex = i;
        break;
      }
    }

    final remaining = <String>[
      for (var i = 0; i < tokens.length; i++)
        if (i != amountIndex) tokens[i],
    ];

    // 2) Kategori: nama kategori user dulu, baru alias bawaan.
    final nameLookup = <String, String>{
      for (final n in categoryNames) n.toLowerCase(): n,
    };

    String? matchedName;
    String? matchedKeyword;
    var matchedIndex = -1;
    for (var i = 0; i < remaining.length; i++) {
      final key = remaining[i].toLowerCase();
      final byName = nameLookup[key];
      if (byName != null) {
        matchedName = byName;
        matchedKeyword = remaining[i];
        matchedIndex = i;
        break;
      }
      final byAlias = aliases[key];
      if (byAlias != null) {
        matchedName = byAlias;
        matchedKeyword = remaining[i];
        matchedIndex = i;
        break;
      }
    }

    // 3) Catatan = sisa token (tanpa nominal & tanpa kata kategori).
    final noteTokens = <String>[
      for (var i = 0; i < remaining.length; i++)
        if (i != matchedIndex) remaining[i],
    ];

    return QuickInputResult(
      amount: amount,
      categoryName: matchedName,
      note: noteTokens.join(' ').trim(),
      matchedKeyword: matchedKeyword,
    );
  }

  /// Ekstrak nominal dari satu token.
  /// `"25000"` / `"25.000"` / `"25,000"` / `"rp25000"` -> angka. Selain itu null.
  static int? _amountFrom(String token) {
    var work = token.trim().toLowerCase();
    if (work.isEmpty) return null;
    if (work.startsWith('rp')) work = work.substring(2);
    final digits = work.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) return null;
    // Hanya boleh berisi digit, '.', ',', atau whitespace — huruf lain = tolak.
    final rest = work.replaceAll(RegExp(r'[0-9.,\s]'), '');
    if (rest.isNotEmpty) return null;
    return int.tryParse(digits);
  }
}
