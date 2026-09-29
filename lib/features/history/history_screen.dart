import 'package:flutter/material.dart';

import 'package:dompetku_port/core/app_date.dart';
import 'package:dompetku_port/core/money.dart';
import 'package:dompetku_port/data/category_repository.dart';
import 'package:dompetku_port/domain/category.dart';
import 'package:dompetku_port/domain/expense.dart';
import 'package:dompetku_port/features/common/widgets.dart';
import 'package:dompetku_port/features/history/history_controller.dart';

/// Tab "Riwayat" — paritas `HistoryFragment` (SPEC §9).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.controller,
    required this.categories,
    required this.onOpenEdit,
  });

  final HistoryController controller;
  final CategoryRepository categories;
  final ValueChanged<int> onOpenEdit;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _search = TextEditingController();
  List<Category> _allCategories = const [];

  @override
  void initState() {
    super.initState();
    widget.categories.getAll().then((list) {
      if (mounted) setState(() => _allCategories = list);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Paritas `MainActivity`: toolbar "DompetKu" (TextSectionTitle).
        title: Text(
          'DompetKu'.toUpperCase(), // textAllCaps (TextSectionTitle)
          style: sectionTitleStyle(context)
              .copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final s = widget.controller.state;
          // Kelompokkan per tanggal (paritas `HistoryAdapter.submit`):
          // item urut `expense_date DESC` → header + baris per tanggal.
          final order = <String>[];
          final byDate = <String, List<ExpenseWithCategory>>{};
          for (final it in s.items) {
            final d = it.expense.expenseDate;
            byDate.putIfAbsent(d, () {
              order.add(d);
              return <ExpenseWithCategory>[];
            }).add(it);
          }
          final flat = <({bool isHeader, String date, ExpenseWithCategory? item})>[];
          for (final d in order) {
            flat.add((isHeader: true, date: d, item: null));
            for (final it in byDate[d]!) {
              flat.add((isHeader: false, date: d, item: it));
            }
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Cari transaksi…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: widget.controller.setQueryDebounced, // debounce 250 ms (§9)
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    _filterChip('Semua', DateFilter.all, s),
                    _filterChip('Hari ini', DateFilter.today, s),
                    _filterChip('7 hari', DateFilter.last7Days, s),
                    _filterChip('Bulan ini', DateFilter.thisMonth, s),
                    _customChip(s),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _pickCategory,
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: Text(s.categoryName),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.controller.toggleSort,
                      child: Text(
                        s.sortOrder == SortOrder.newest ? 'Terbaru' : 'Terlama',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${s.totalCount} transaksi · ${Money.format(s.totalAmount)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: s.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : s.items.isEmpty
                        ? const EmptyState(
                            title: 'Tidak ada transaksi.',
                            desc: 'Ubah filter atau catat pengeluaran baru.',
                          )
                        : ListView.builder(
                            itemCount: flat.length,
                            itemBuilder: (context, i) {
                              final row = flat[i];
                              if (row.isHeader) {
                                // Paritas `HistoryAdapter`: header per tanggal
                                // = tanggal + total nominal hari itu.
                                final total = byDate[row.date]!
                                    .fold<int>(0, (sum, e) => sum + e.expense.amount);
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          AppDate.toDisplay(row.date).toUpperCase(),
                                          style: sectionTitleStyle(context),
                                        ),
                                      ),
                                      Text(
                                        Money.format(total),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final item = row.item!;
                              return ExpenseTile(
                                item: item,
                                onTap: () => widget.onOpenEdit(item.expense.id),
                                onLongPress: () =>
                                    _confirmDelete(item.expense.id),
                                onDelete: () => _confirmDelete(item.expense.id),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, DateFilter filter, HistoryUiState s) {
    final selected = s.dateFilter == filter;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => widget.controller.setDateFilter(filter),
      ),
    );
  }

  Widget _customChip(HistoryUiState s) {
    final isCustom = s.dateFilter == DateFilter.custom;
    final label = isCustom &&
            s.customFromIso != null &&
            s.customToIso != null
        ? '${AppDate.toDisplay(s.customFromIso!)} – ${AppDate.toDisplay(s.customToIso!)}'
        : 'Pilih tanggal';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: isCustom,
        onSelected: (_) => _pickCustomRange(),
      ),
    );
  }

  // ------------------------------------------------------------ filter kategori

  Future<void> _pickCategory() async {
    final s = widget.controller.state;
    final result = await showDialog<_CatPick?>(
      context: context,
      builder: (ctx) => RadioGroup<int>(
        groupValue: s.categoryId ?? 0,
        onChanged: (v) => Navigator.of(
          ctx,
          rootNavigator: true,
        ).pop(v == null || v == 0 ? const _CatPick(null) : _CatPick(v)),
        child: SimpleDialog(
          title: const Text('Filter kategori'),
          children: [
            const RadioListTile<int>(
              value: 0,
              title: Text('Semua kategori'),
            ),
            ..._allCategories.map(
              (c) => RadioListTile<int>(
                value: c.id,
                title: Text('${c.icon} ${c.name}'),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return; // ditutup tanpa pilihan = batal
    if (result.id == null) {
      await widget.controller.setCategory(null, 'Semua kategori');
    } else {
      final name =
          _allCategories.firstWhere((c) => c.id == result.id).name;
      await widget.controller.setCategory(result.id, name);
    }
  }

  // ------------------------------------------------------------ rentang kustom

  Future<void> _pickCustomRange() async {
    final s = widget.controller.state;
    final now = DateTime.now();
    var from = DateTime.tryParse(s.customFromIso ?? '') ??
        DateTime(now.year, now.month, now.day - 6);
    var to = DateTime.tryParse(s.customToIso ?? '') ??
        DateTime(now.year, now.month, now.day);
    var confirmed = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Pilih tanggal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Dari: ${AppDate.toDisplay(AppDate.isoOf(from.year, from.month, from.day))}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: from,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setDialogState(() => from = picked);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Sampai: ${AppDate.toDisplay(AppDate.isoOf(to.year, to.month, to.day))}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: to,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setDialogState(() => to = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                confirmed = true;
                Navigator.of(ctx).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );

    if (confirmed) {
      await widget.controller.setCustomRange(
        AppDate.isoOf(from.year, from.month, from.day),
        AppDate.isoOf(to.year, to.month, to.day),
      );
    } else {
      // Paritas Android: batal dialog rentang -> kembali ke "Semua".
      await widget.controller.setDateFilter(DateFilter.all);
    }
  }

  // ------------------------------------------------------------------ hapus

  Future<void> _confirmDelete(int id) async {
    final item = widget.controller.state.items.firstWhere((i) => i.expense.id == id);
    final label = item.expense.note.trim().isEmpty
        ? item.categoryName
        : item.expense.note.trim();
    final ok = await confirmDialog(
      context,
      title: 'Hapus transaksi ini?',
      message: '"$label" senilai ${Money.format(item.expense.amount)} akan dihapus permanen.',
      positive: 'Hapus',
    );
    if (!ok || !mounted) return;
    final deleted = await widget.controller.delete(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(deleted ? 'Transaksi dihapus' : 'Gagal menghapus transaksi.')),
    );
  }
}

/// Hasil dialog filter kategori; `id == null` = "Semua kategori".
class _CatPick {
  const _CatPick(this.id);

  final int? id;
}
