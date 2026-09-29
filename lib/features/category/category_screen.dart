import 'package:flutter/material.dart';

import 'package:dompetku_port/core/color_utils.dart';
import 'package:dompetku_port/data/category_repository.dart';
import 'package:dompetku_port/domain/category.dart';
import 'package:dompetku_port/features/common/widgets.dart';
/// Layar "Kelola Kategori" — paritas penuh `CategoryActivity` + `CategoryAdapter`
/// (SPEC §5): baris = ikon berwarna + nama + meta (`%d transaksi` /
/// `%d transaksi · Bawaan`), tombol Edit & Hapus per baris, dialog form
/// (nama/ikon/palet 10 warna), toast persis Android.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.repo});

  final CategoryRepository repo;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<Category> _items = const [];
  final Map<int, int> _usage = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await widget.repo.getAll();
    final usage = <int, int>{};
    for (final c in items) {
      usage[c.id] = await widget.repo.usageCount(c.id);
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _usage
        ..clear()
        ..addAll(usage);
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      body: _items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Harus ada minimal satu kategori.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                for (final c in _items) _row(c),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDialog(null),
        icon: const Icon(Icons.add),
        label: const Text('Tambah kategori'),
      ),
    );
  }

  Widget _row(Category c) {
    final used = _usage[c.id] ?? 0;
    final usedLabel = '$used transaksi';
    return ListTile(
      leading: CategoryIconView(
        icon: c.icon,
        colorValue: signed32ToArgb(c.color),
        size: 40,
      ),
      title: Text(c.name),
      subtitle: Text(c.isDefault ? '$usedLabel · Bawaan' : usedLabel),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => _editDialog(c),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus',
            onPressed: () => _confirmDelete(c),
          ),
        ],
      ),
      onTap: () => _editDialog(c),
    );
  }

  // ------------------------------------------------------------ dialog form

  Future<void> _editDialog(Category? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final icon = TextEditingController(text: existing?.icon ?? '');
    // Palet persis Android: 10 warna cat_*; kategori baru default = Makanan.
    var selectedColor =
        existing?.color ?? argbToSigned32(0xFFEA580C);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Tambah kategori' : 'Edit kategori'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama kategori'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: icon,
                  decoration: const InputDecoration(labelText: 'Ikon (emoji)'),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child:
                      // Paritas `TextSectionTitle` (dialog_category.xml).
                      Text('Warna'.toUpperCase(),
                          style: sectionTitleStyle(ctx)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final argb in _palette)
                      GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedColor = argbToSigned32(argb)),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(argb),
                            shape: BoxShape.circle,
                            border: selectedColor == argbToSigned32(argb)
                                ? Border.all(
                                    color: Theme.of(ctx).colorScheme.primary,
                                    width: 3,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );

    // Paritas Android: tombol SIMPAN selalu menutup dialog; hasil lewat toast.
    if (confirmed != true || !mounted) return;
    final err = await widget.repo.save(
      id: existing?.id,
      name: name.text,
      icon: icon.text.trim().isEmpty ? '💰' : icon.text,
      color: selectedColor,
    );
    _toast(err ?? 'Tersimpan');
    await _reload();
  }

  // ------------------------------------------------------------- konfirmasi

  Future<void> _confirmDelete(Category c) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus kategori ini?',
      message: 'Nama kategori: ${c.name}',
      positive: 'Hapus',
    );
    if (!ok || !mounted) return;

    final result = await widget.repo.delete(c.id);
    final message = switch (result) {
      DeleteLastCategory() => 'Harus ada minimal satu kategori.',
      DeleteInUse(:final count) =>
        'Kategori ini digunakan oleh $count transaksi dan tidak bisa dihapus.',
      DeleteDeleted() => 'Kategori dihapus',
      DeleteFailed() => 'Gagal menyimpan kategori.',
    };
    _toast(message);
    await _reload();
  }
}

/// Palet persis `CategoryActivity`: cat_makanan … cat_lainnya (10 warna).
const List<int> _palette = [
  0xFFEA580C, // Makanan
  0xFFCA8A04, // Minuman
  0xFF2563EB, // Transportasi
  0xFF7C3AED, // Belanja
  0xFF16A34A, // Rumah
  0xFF0891B2, // Tagihan
  0xFFDC2626, // Kesehatan
  0xFFDB2777, // Hiburan
  0xFF4F46E5, // Pekerjaan
  0xFF64748B, // Lainnya
];
