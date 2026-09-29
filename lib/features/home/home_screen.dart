import 'package:flutter/material.dart';

import 'package:dompetku_port/core/money.dart';
import 'package:dompetku_port/features/common/widgets.dart';
import 'package:dompetku_port/features/home/home_controller.dart';

/// Tab "Hari Ini" — paritas `HomeFragment` (SPEC §8).
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onOpenAdd,
    required this.onOpenEdit,
  });

  final HomeController controller;
  final VoidCallback onOpenAdd;
  final ValueChanged<int> onOpenEdit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Paritas `MainActivity`: toolbar selalu menampilkan "DompetKu"
        // dengan `titleTextAppearance = TextSectionTitle` (13sp bold caps).
        title: Text(
          'DompetKu'.toUpperCase(), // textAllCaps (TextSectionTitle)
          style: sectionTitleStyle(context)
              .copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final s = controller.state;
          if (s.isLoading) return const Center(child: CircularProgressIndicator());
          if (s.errorMessage != null) {
            return EmptyState(title: s.errorMessage!, desc: '');
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _TotalCard(label: 'Pengeluaran Hari Ini', date: s.todayDateLabel, amount: s.todayTotal),
                const SectionLabel('Ringkasan'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        SummaryRow(label: 'Minggu ini', value: Money.format(s.weekTotal)),
                        SummaryRow(label: 'Bulan ini', value: Money.format(s.monthTotal)),
                        SummaryRow(label: 'Rata-rata per hari', value: Money.format(s.averagePerDay)),
                        SummaryRow(
                          label: 'Kategori terbesar bulan ini',
                          value: s.topCategory?.categoryName ?? '—',
                        ),
                      ],
                    ),
                  ),
                ),
                const SectionLabel('Transaksi hari ini'),
                if (s.todayItems.isEmpty)
                  EmptyState(
                    title: 'Belum ada pengeluaran hari ini.',
                    desc: 'Catat pengeluaran pertama Anda.',
                    actionLabel: '＋ Catat Pengeluaran',
                    onAction: onOpenAdd,
                  )
                else
                  ...s.todayItems.map(
                    (item) => ExpenseTile(
                      item: item,
                      onTap: () => onOpenEdit(item.expense.id),
                      onLongPress: () => _confirmDelete(context, item.expense.id),
                    ),
                  ),
                const SizedBox(height: 80), // ruang untuk FAB
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, int id) async {
    final s = controller.state;
    final item = s.todayItems.firstWhere((i) => i.expense.id == id);
    final label = item.expense.note.trim().isEmpty
        ? item.categoryName
        : item.expense.note.trim();
    final ok = await confirmDialog(
      context,
      title: 'Hapus transaksi ini?',
      message: '"$label" senilai ${Money.format(item.expense.amount)} akan dihapus permanen.',
      positive: 'Hapus',
    );
    if (!ok || !context.mounted) return;
    final deleted = await controller.delete(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(deleted ? 'Transaksi dihapus' : 'Gagal menghapus transaksi.')),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.label, required this.date, required this.amount});

  final String label;
  final String date;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label = `TextSectionTitle` (13sp bold caps).
            Text(label.toUpperCase(), style: sectionTitleStyle(context)),
            const SizedBox(height: 4),
            // Nominal = `TextAmountLarge` (40sp bold).
            Text(
              Money.format(amount),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 40, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            // Tanggal = `TextCaption` (13sp).
            Text(date,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 13, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
