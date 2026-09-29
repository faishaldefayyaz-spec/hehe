import '../../core/color_utils.dart';

/// Skema database DompetKu — **persis SPEC-DOMPETKU-1.0 §15** (versi 1).
///
/// Sumber kebenaran: `SPEC-DOMPETKU-1.0.md`. Jangan mengubah skema ini
/// tanpa keputusan versi database baru + migrasi.
class DbSchema {
  DbSchema._();

  static const int databaseVersion = 1;
  static const String databaseName = 'dompetku.db';

  // ---------------------------------------------------------------- tabel

  static const String createCategories = '''
CREATE TABLE IF NOT EXISTS categories (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    icon       TEXT NOT NULL DEFAULT '💰',
    color      INTEGER NOT NULL,
    is_default INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
)
''';

  static const String createExpenses = '''
CREATE TABLE IF NOT EXISTS expenses (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    amount       INTEGER NOT NULL,
    category_id  INTEGER NOT NULL
                 REFERENCES categories(id) ON DELETE RESTRICT,
    note         TEXT NOT NULL DEFAULT '',
    expense_date TEXT NOT NULL,
    created_at   INTEGER NOT NULL,
    updated_at   INTEGER NOT NULL
)
''';

  static const String createBudgets = '''
CREATE TABLE IF NOT EXISTS budgets (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    month      INTEGER NOT NULL,
    year       INTEGER NOT NULL,
    amount     INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
)
''';

  // --------------------------------------------------------------- index

  static const String indexExpenseDate =
      'CREATE INDEX IF NOT EXISTS idx_expense_date ON expenses (expense_date)';
  static const String indexExpenseCategory =
      'CREATE INDEX IF NOT EXISTS idx_expense_category ON expenses (category_id)';
  static const String uniqueIndexBudgetMonthYear =
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_budget_month_year ON budgets (month, year)';

  static const List<String> allStatements = [
    createCategories,
    createExpenses,
    createBudgets,
    indexExpenseDate,
    indexExpenseCategory,
    uniqueIndexBudgetMonthYear,
  ];

  // ------------------------------------------------------------ seed data

  /// Kategori default 12 buah — **SPEC §5**: nama, emoji, dan warna HEX
  /// harus identik dengan Android 1.0 (warna disimpan signed32, lihat
  /// [argbToSigned32]).
  static const List<SeedCategory> defaultCategories = [
    SeedCategory('Makanan', '🍜', 0xFFEA580C),
    SeedCategory('Minuman', '☕', 0xFFCA8A04),
    SeedCategory('Transportasi', '⛽', 0xFF2563EB),
    SeedCategory('Belanja', '🛒', 0xFF7C3AED),
    SeedCategory('Rumah', '🏠', 0xFF16A34A),
    SeedCategory('Tagihan', '💡', 0xFF0891B2),
    SeedCategory('Kesehatan', '💊', 0xFFDC2626),
    SeedCategory('Hiburan', '🎮', 0xFFDB2777),
    SeedCategory('Pekerjaan', '💼', 0xFF4F46E5),
    SeedCategory('Hadiah', '🎁', 0xFFC026D3),
    SeedCategory('Langganan', '📱', 0xFF0D9488),
    SeedCategory('Lainnya', '💰', 0xFF64748B),
  ];

  /// Emoji default untuk kategori buatan user (CategoryViewModel Android).
  static const String defaultCustomIcon = '💰';
}

/// Satu baris kategori seed (warna masih berupa hex ARGB, diubah ke signed
/// saat disimpan).
class SeedCategory {
  const SeedCategory(this.name, this.icon, this.argbColor);

  final String name;
  final String icon;
  final int argbColor;

  int get signedColor => argbToSigned32(argbColor);
}
