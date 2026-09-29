import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dompetku_port/core/color_utils.dart';
import 'package:dompetku_port/core/money.dart';
import 'package:dompetku_port/domain/expense.dart';

/// Gaya `TextSectionTitle` Android (`themes.xml`): 13sp bold, huruf besar
/// (`textAllCaps`), `letterSpacing` 0.06em, warna `on_surface_variant`.
TextStyle sectionTitleStyle(BuildContext context) {
  final base = Theme.of(context).textTheme.labelMedium ?? const TextStyle();
  return base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 13 * 0.06,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

/// Label judul section — selalu HURUF BESAR (paritas `android:textAllCaps`).
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 8),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Text(text.toUpperCase(), style: sectionTitleStyle(context)),
      );
}

/// Ikon kategori: emoji di atas kotak berwarna (paritas `item_expense`).
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.icon, required this.color, this.size = 40});

  final String icon;
  final int color; // signed32 dari DB
  final double size;

  @override
  Widget build(BuildContext context) =>
      CategoryIconView(icon: icon, colorValue: signed32ToArgb(color), size: size);
}

class CategoryIconView extends StatelessWidget {
  const CategoryIconView(
      {super.key, required this.icon, required this.colorValue, this.size = 40});

  final String icon;
  final int colorValue; // ARGB unsigned
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color(colorValue),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(icon, style: TextStyle(fontSize: size * 0.5)),
      );
}

/// Baris transaksi — judul = catatan (fallback nama kategori), subjudul =
/// `kategori • HH:mm`, nominal `Rp…` (persis `ExpenseAdapter` Android).
///
/// [onDelete] diisi (mis. tab Riwayat) → muncul tombol ikon edit & hapus
/// 42dp (paritas `item_history.xml`).
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.onDelete,
  });

  final ExpenseWithCategory item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final note = item.expense.note.trim();
    final title = note.isEmpty ? item.categoryName : note;
    final time = _hhmm(item.expense.createdAt);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CategoryIcon(icon: item.categoryIcon, color: item.categoryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${item.categoryName} · $time',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 13, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(Money.format(item.expense.amount),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
            if (onDelete != null) ...[
              IconButton(
                constraints: const BoxConstraints.tightFor(width: 42, height: 42),
                onPressed: onTap,
                tooltip: 'Edit',
                icon: Icon(Icons.edit_outlined,
                    size: 22, color: scheme.onSurfaceVariant),
              ),
              IconButton(
                constraints: const BoxConstraints.tightFor(width: 42, height: 42),
                onPressed: onDelete,
                tooltip: 'Hapus',
                icon: Icon(Icons.delete_outline, size: 22, color: scheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _hhmm(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Kartu ringkasan (label kiri, nilai kanan) untuk layar Beranda/Laporan.
class SummaryRow extends StatelessWidget {
  const SummaryRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // Label = `TextCaption` (13sp, on_surface_variant).
            Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant))),
            // Nilai = `TextAmount` (17sp bold, on_surface).
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// Empty state umum: judul + deskripsi (+ aksi opsional).
class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.title, required this.desc, this.actionLabel, this.onAction});

  final String title;
  final String desc;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Paritas `ic_shield_empty` (56dp, tint outline).
            Icon(Icons.shield_outlined, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            // Judul = `TextBody` (15sp).
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 15)),
            const SizedBox(height: 8),
            // Deskripsi = `TextCaption` (13sp).
            Text(desc,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13, color: scheme.onSurfaceVariant)),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                // minHeight 48dp (paritas MaterialButton); ikon sengaja
                // tidak dipasang karena teks `action_add_first` sudah
                // diawali "＋" (mencegah "＋ ＋" seperti di Android 1.0).
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog konfirmasi dua tombol (Batal / aksi) — dipakai hapus & buang draft.
///
/// Adaptif (PHASE 8): iOS/macOS memakai `CupertinoAlertDialog`,
/// platform lain `AlertDialog`. Teks & hasil identik.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String negative = 'Batal',
  required String positive,
}) async {
  final cupertino = useCupertinoDialogs(context);
  final result = await showDialog<bool>(
    context: context,
    builder: cupertino
        ? (ctx) => CupertinoAlertDialog(
              title: Text(title),
              content: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(message),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(negative),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(positive),
                ),
              ],
            )
        : (ctx) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(negative)),
                FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(positive)),
              ],
            ),
  );
  return result ?? false;
}

/// iOS/macOS → dialog gaya Cupertino; sisanya Material.
bool useCupertinoDialogs(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// Dialog "Budget Bulanan" (paritas `SettingsFragment.showBudgetDialog`):
/// kolom `Contoh: 5000000` (diisi nominal saat ini bila ada), tombol `SIMPAN`.
///
/// Paritas Android: tombol SELALU menutup dialog, lalu toast
/// `Tersimpan` (sukses) atau `Masukkan nominal terlebih dahulu.` (gagal).
Future<void> showBudgetDialog(
  BuildContext context, {
  String initialText = '',
  required Future<bool> Function(String) onSave,
}) async {
  final input = TextEditingController(text: initialText);
  final cupertino = useCupertinoDialogs(context);

  final ok = await showDialog<bool>(
    context: context,
    builder: cupertino
        ? (ctx) => CupertinoAlertDialog(
              title: const Text('Budget Bulanan'),
              content: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CupertinoTextField(
                  controller: input,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  placeholder: 'Contoh: 5000000',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('Rp '),
                  ),
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Batal'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    final result = await onSave(input.text);
                    if (ctx.mounted) Navigator.of(ctx).pop(result);
                  },
                  child: const Text('SIMPAN'),
                ),
              ],
            )
        : (ctx) => AlertDialog(
              title: const Text('Budget Bulanan'),
              content: TextField(
                controller: input,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Contoh: 5000000',
                  prefixText: 'Rp ',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    final result = await onSave(input.text);
                    if (ctx.mounted) Navigator.of(ctx).pop(result);
                  },
                  child: const Text('SIMPAN'),
                ),
              ],
            ),
  );

  if (ok == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? 'Tersimpan' : 'Masukkan nominal terlebih dahulu.'),
    ),
  );
}
