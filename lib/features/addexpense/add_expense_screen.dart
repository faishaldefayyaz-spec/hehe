import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dompetku_port/app_data.dart';
import 'package:dompetku_port/core/app_date.dart';
import 'package:dompetku_port/core/money.dart';
import 'package:dompetku_port/core/quick_input_parser.dart';
import 'package:dompetku_port/domain/category.dart';
import 'package:dompetku_port/domain/expense_form.dart';
import 'package:dompetku_port/features/common/widgets.dart';

/// Layar Tambah / Edit Pengeluaran — paritas `AddExpenseActivity` (SPEC §6).
///
/// Fitur: quick input (debounce 200 ms ala Android), nominal ter-digit otomatis
/// dikelompokkan, pilihan kategori, tanggal lewat date picker, dan konfirmasi
/// buang draft sebelum keluar.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, this.expenseId});

  /// `null` = tambah baru; selain itu = mode edit.
  final int? expenseId;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _quick = TextEditingController();

  final _form = GlobalKey<FormState>();
  List<Category> _categories = const [];
  int? _categoryId;
  String _dateIso = '';
  String? _amountError;
  String? _categoryError;
  bool _saving = false;

  // Snapshot nilai awal untuk deteksi "belum disimpan".
  String _initAmount = '';
  String _initNote = '';
  final String _initQuick = '';
  int? _initCategoryId;
  String _initDateIso = '';

  bool get _isEdit => widget.expenseId != null && widget.expenseId! > 0;

  bool get _dirty =>
      _amount.text != _initAmount ||
      _note.text != _initNote ||
      _quick.text != _initQuick ||
      _categoryId != _initCategoryId ||
      _dateIso != _initDateIso;

  @override
  void initState() {
    super.initState();
    _dateIso = AppDate.todayIso();
    _initDateIso = _dateIso;
  }

  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_booted) {
      _booted = true;
      _bootstrap(AppScope.of(context));
    }
  }

  Future<void> _bootstrap(AppData data) async {
    final categories = await data.categories.getAll();
    var amount = '';
    var note = '';
    var categoryId = 0;
    var dateIso = AppDate.todayIso();

    if (_isEdit) {
      final existing = await data.expenses.getById(widget.expenseId!);
      if (existing != null) {
        amount = Money.format(existing.expense.amount);
        note = existing.expense.note;
        categoryId = existing.expense.categoryId;
        dateIso = existing.expense.expenseDate;
      }
    }

    if (!mounted) return;
    setState(() {
      _categories = categories;
      _amount.text = amount;
      _note.text = note;
      _categoryId = categoryId > 0 ? categoryId : null;
      _dateIso = dateIso;
      _initAmount = _amount.text;
      _initNote = _note.text;
      _initCategoryId = _categoryId;
      _initDateIso = _dateIso;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _quick.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ aksi

  void _onQuickChanged(String text) {
    final result = QuickInputParser.parse(
      text,
      categoryNames: [for (final c in _categories) c.name],
    );
    setState(() {
      if (result.hasAmount) {
        _amount.text = Money.format(result.amount!);
      }
      if (result.hasCategory) {
        final match = _categories.firstWhere(
          (c) => c.name.toLowerCase() == result.categoryName!.toLowerCase(),
          orElse: () => _categories.first,
        );
        _categoryId = match.id;
      }
      if (result.note.isNotEmpty && _note.text.trim().isEmpty) {
        _note.text = result.note;
      }
      _amountError = null;
      _categoryError = null;
    });
  }

  /// Nominal: buang non-digit, kelompokkan ribuan (paritas Android).
  void _onAmountChanged(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    final grouped = digits.isEmpty ? '' : Money.groupDigits(digits);
    _amount.value = TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
    setState(() => _amountError = null);
  }

  Future<void> _pickDate() async {
    final initial = AppDate.parseIso(_dateIso) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateIso = AppDate.isoOf(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await _formSave();
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case SaveFormInvalid(:final amountError, :final categoryError):
        setState(() {
          _amountError = amountError;
          _categoryError = categoryError;
        });
      case SaveSuccess(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        Navigator.of(context).pop();
      case SaveFailure(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<ExpenseSaveResult> _formSave() async {
    final form = _form.currentState;
    form?.validate(); // no-op; validasi utama di ExpenseForm (§6)
    final data = AppScope.of(context);
    return ExpenseForm(data.expenses).save(
      editId: widget.expenseId,
      amountText: _amount.text,
      categoryId: _categoryId,
      note: _note.text,
      dateIso: _dateIso,
    );
  }

  Future<void> _confirmDiscard() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await confirmDialog(
      context,
      title: 'Data belum disimpan',
      message: 'Ada data yang belum disimpan. Buang perubahan?',
      positive: 'Buang',
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmDiscard,
            tooltip: 'Tutup',
          ),
          title: Text(_isEdit ? 'Edit Pengeluaran' : 'Tambah Pengeluaran'),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ------------------------------------------------ input cepat
              TextField(
                controller: _quick,
                decoration: const InputDecoration(
                  labelText: 'Input cepat (opsional)',
                  hintText: 'makan ayam 30000',
                  helperText: 'Ketik kategori dan nominal, contoh: makan ayam 30000',
                ),
                textInputAction: TextInputAction.next,
                onChanged: _onQuickChanged,
              ),
              const SizedBox(height: 16),

              // ---------------------------------------------------- nominal
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
                decoration: InputDecoration(
                  labelText: 'Nominal',
                  prefixText: 'Rp ',
                  // Paritas `prefixTextAppearance` caption (12sp, variant).
                  prefixStyle: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  errorText: _amountError,
                  helperText: 'Tidak boleh lebih dari Rp1.000.000.000.000',
                ),
                // Paritas `TextInputEditText`: nominal 30sp medium;
                // prefix `Rp` memakai `prefixTextAppearance` caption (12sp).
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: _onAmountChanged,
              ),
              const SizedBox(height: 16),

              // -------------------------------------------------- kategori
              // Paritas `TextSectionTitle`: label HURUF BESAR 13sp bold.
              Text('Kategori'.toUpperCase(), style: sectionTitleStyle(context)),
              const SizedBox(height: 8),
              // Paritas `HorizontalScrollView` + `ChipGroup`: satu baris,
              // digeser mendatar (tidak wrap).
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    for (final c in _categories)
                      ChoiceChip(
                        label: Text('${c.icon} ${c.name}'),
                        selected: _categoryId == c.id,
                        onSelected: (_) => setState(() {
                          _categoryId = c.id;
                          _categoryError = null;
                        }),
                      ),
                  ],
                ),
              ),
              if (_categoryError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _categoryError!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),

              // -------------------------------------------------- catatan
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Makan ayam',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // --------------------------------------------------- tanggal
              // Paritas `btn_date` (MaterialButton OutlinedButton): ikon
              // kalender di kiri, teks tanggal di tengah, tinggi min 52dp.
              OutlinedButton(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppDate.toDisplay(_dateIso),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100), // ruang untuk tombol SIMPAN
            ],
          ),
        ),
        // Paritas bar SIMPAN: latar `surface`, padding 16/12.
        bottomNavigationBar: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                // Paritas `btn_save`: tinggi 56dp, teks bold 16sp, radius 14.
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('SIMPAN'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
