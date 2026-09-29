import 'package:flutter/material.dart';

import 'package:dompetku_port/core/color_utils.dart';
import 'package:dompetku_port/core/money.dart';
import 'package:dompetku_port/domain/budget.dart';
import 'package:dompetku_port/features/common/widgets.dart';
import 'package:dompetku_port/features/report/report_controller.dart';

/// Tab "Laporan" — paritas `ReportFragment` (SPEC §10–§11).
class ReportScreen extends StatelessWidget {
  const ReportScreen({
    super.key,
    required this.controller,
    required this.onOpenAdd,
  });

  final ReportController controller;
  final VoidCallback onOpenAdd;

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
        animation: controller,
        builder: (context, _) {
          final s = controller.state;
          if (s.isLoading) return const Center(child: CircularProgressIndicator());
          if (s.errorMessage != null) {
            return EmptyState(title: s.errorMessage!, desc: '');
          }
          if (!s.hasAnyData) {
            return const EmptyState(
              title: 'Belum ada data.',
              desc: 'Catat pengeluaran untuk melihat laporan.',
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SegmentedButton<ReportPeriod>(
                    segments: const [
                      ButtonSegment(value: ReportPeriod.today, label: Text('Hari ini')),
                      ButtonSegment(value: ReportPeriod.week, label: Text('Minggu ini')),
                      ButtonSegment(value: ReportPeriod.month, label: Text('Bulan ini')),
                    ],
                    selected: {s.period},
                    onSelectionChanged: (sel) => controller.setPeriod(sel.first),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Paritas `report_total_label` (TextSectionTitle).
                        Text('Total pengeluaran'.toUpperCase(),
                            style: sectionTitleStyle(context)),
                        const SizedBox(height: 4),
                        // Paritas `TextAmountLarge` (40sp bold).
                        Text(
                          Money.format(s.total),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontSize: 40, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                _section(context, '7 hari terakhir'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Semantics(
                      label: 'Grafik pengeluaran 7 hari terakhir',
                      child: _BarChart(bars: s.bars),
                    ),
                  ),
                ),
                _section(context, 'Berdasarkan kategori'),
                if (s.breakdown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Belum ada data.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  )
                else
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final c in s.breakdown)
                          ListTile(
                            leading: CategoryIconView(
                                icon: c.categoryIcon,
                                colorValue: signed32ToArgb(c.categoryColor)),
                            title: Text(c.categoryName),
                            subtitle: Text('${c.count} transaksi'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(Money.format(c.total),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700)),
                                Text(
                                  s.total > 0
                                      ? '${(c.total * 100) ~/ s.total}%'
                                      : '0%',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                _section(context, 'Budget bulan ini'),
                _BudgetCard(
                  budget: s.budget,
                  onSave: controller.saveBudget,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String text) => SectionLabel(text);
}

/// Grafik 7 batang (paritas `BarChartView`): tinggi sebanding nominal;
/// hari tanpa data = batang 0 (garis dasar).
class _BarChart extends StatelessWidget {
  const _BarChart({required this.bars});

  final List<DayBar> bars;

  @override
  Widget build(BuildContext context) {
    final max = bars.fold<int>(1, (m, b) => b.amount > m ? b.amount : m);
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bar in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          height: bar.amount == 0 ? 0 : (bar.amount * 110) / max,
                          decoration: BoxDecoration(
                            color: bar.amount == 0
                                ? Colors.transparent
                                : color.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(bar.label, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kartu budget — paritas kartu budget `ReportFragment` (SPEC §11).
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.onSave});

  final BudgetUiState budget;
  final Future<bool> Function(String) onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: budget.hasBudget
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SummaryRow(label: 'Terpakai', value: Money.format(budget.used)),
                  SummaryRow(
                      label: 'Sisa',
                      value: Money.format(
                          budget.remaining < 0 ? 0 : budget.remaining)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (budget.percent.clamp(0, 100)) / 100,
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: budget.isOverBudget
                          ? scheme.error
                          : budget.showWarning
                              ? const Color(0xFFB45309)
                              : scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${budget.percent}% dari budget',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (budget.isOverBudget)
                    Text('Anda telah melebihi budget bulan ini.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.error))
                  else if (budget.showWarning)
                    Text(
                      'Anda telah menggunakan ${budget.percent}% budget bulan ini.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: const Color(0xFFB45309)),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => showBudgetDialog(context, onSave: onSave),
                      child: const Text('Ubah'),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Belum ada budget bulan ini.',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => showBudgetDialog(context, onSave: onSave),
                      child: const Text('Atur budget'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
