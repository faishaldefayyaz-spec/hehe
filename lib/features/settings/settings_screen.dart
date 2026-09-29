import 'package:flutter/material.dart';

import 'package:dompetku_port/app_data.dart';
import 'package:dompetku_port/features/category/category_screen.dart';
import 'package:dompetku_port/features/common/widgets.dart';
import 'package:dompetku_port/features/settings/settings_controller.dart';

/// Tab "Pengaturan" — paritas penuh `SettingsFragment` + `fragment_settings.xml`
/// (SPEC §12–§14): section Tampilan / Backup & Data / Kategori / Tentang,
/// dialog tema single-choice, dialog budget, export/import/backup lewat
/// file picker sistem.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onRefreshAll,
  });

  final SettingsController settings;
  final VoidCallback onRefreshAll;

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
        animation: settings,
        builder: (context, _) => ListView(
          children: [
            _header(context, 'Tampilan'),
            ListTile(
              title: const Text('Tampilan'),
              subtitle: Text(
                ThemePrefs.label(settings.theme.nightMode),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () => _showThemeDialog(context),
            ),
            _header(context, 'Backup & Data'),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Export CSV'),
              enabled: !settings.busy,
              onTap: () => _run(context, settings.exportCsv),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Import CSV'),
              enabled: !settings.busy,
              onTap: () => _run(context, settings.importCsv,
                  silentCancel: true, readingToast: true),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Backup Database'),
              enabled: !settings.busy,
              onTap: () => _run(context, settings.backupDatabase),
            ),
            _header(context, 'Kategori'),
            ListTile(
              title: const Text('Kelola Kategori'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final data = AppScope.of(context);
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CategoryScreen(repo: data.categories),
                ));
                onRefreshAll();
              },
            ),
            ListTile(
              title: const Text('Budget Bulanan'),
              subtitle: Text(
                settings.budgetLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showBudgetDialog(
                context,
                initialText: settings.budgetAmount > 0
                    ? '${settings.budgetAmount}'
                    : '',
                onSave: settings.saveBudget,
              ),
            ),
            _header(context, 'Tentang'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Semua data disimpan lokal di perangkat ini. '
                'Tidak ada data yang dikirim ke server, tidak ada akun, tidak ada internet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Versi 1.0.0'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Dialog tema — paritas `showThemeDialog`: single choice, langsung simpan
  /// + tutup, negatif 'Batal'.
  Future<void> _showThemeDialog(BuildContext context) async {
    final modes = const [
      ThemePrefs.followSystem,
      ThemePrefs.light,
      ThemePrefs.dark,
    ];
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => RadioGroup<int>(
        groupValue: settings.theme.nightMode,
        onChanged: (v) => Navigator.of(ctx).pop(v),
        child: SimpleDialog(
          title: const Text('Tampilan'),
          children: [
            for (final mode in modes)
              RadioListTile<int>(
                value: mode,
                title: Text(ThemePrefs.label(mode)),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return; // batal: tidak diubah
    await settings.theme.setNightMode(selected);
  }

  Future<void> _run(
    BuildContext context,
    Future<String?> Function() action, {
    bool silentCancel = false,
    bool readingToast = false,
  }) async {
    if (readingToast) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mengimpor data…')));
    }
    final message = await action();
    if (!context.mounted) return;
    if (message == null) return; // batal: import diam, lainnya sudah toast
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    if (silentCancel) {
      onRefreshAll(); // impor menambah data -> segarkan tab lain
    }
  }

  // Paritas `TextSectionTitle`: 13sp bold, huruf besar, on_surface_variant.
  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text.toUpperCase(), style: sectionTitleStyle(context)),
      );
}
