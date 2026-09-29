/// Model kategori DompetKu — **SPEC §5**.
///
/// [color] disimpan sebagai INTEGER **signed32** (paritas Android, lihat
/// `core/color_utils.dart`).
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isDefault,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String icon;
  final int color;
  final bool isDefault;
  final int createdAt;

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    int? color,
    bool? isDefault,
    int? createdAt,
  }) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        isDefault: isDefault ?? this.isDefault,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// Hasil hapus kategori — perilaku identik
/// `CategoryRepository.DeleteResult` Android (4 kasus).
sealed class CategoryDeleteResult {
  const CategoryDeleteResult();

  const factory CategoryDeleteResult.deleted() = DeleteDeleted;
  const factory CategoryDeleteResult.lastCategory() = DeleteLastCategory;
  const factory CategoryDeleteResult.inUse(int count) = DeleteInUse;
  const factory CategoryDeleteResult.failed() = DeleteFailed;
}

class DeleteDeleted extends CategoryDeleteResult {
  const DeleteDeleted();
}

class DeleteLastCategory extends CategoryDeleteResult {
  const DeleteLastCategory();
}

class DeleteInUse extends CategoryDeleteResult {
  const DeleteInUse(this.count);
  final int count;
}

class DeleteFailed extends CategoryDeleteResult {
  const DeleteFailed();
}

/// Pesan error hapus — **persis** teks Android (strings.xml +
/// CategoryViewModel):
///
///  * Deleted     -> `null` (UI menampilkan "Kategori dihapus" terpisah)
///  * LastCategory-> `Harus ada minimal satu kategori.`
///  * InUse(n)    -> `Kategori ini digunakan oleh n transaksi dan tidak bisa dihapus.`
///  * Failed      -> `Gagal menghapus kategori.`
String? categoryDeleteMessage(CategoryDeleteResult result) => switch (result) {
      DeleteDeleted() => null,
      DeleteLastCategory() => 'Harus ada minimal satu kategori.',
      DeleteInUse(:final count) =>
        'Kategori ini digunakan oleh $count transaksi dan tidak bisa dihapus.',
      DeleteFailed() => 'Gagal menghapus kategori.',
    };
