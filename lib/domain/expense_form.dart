import 'package:dompetku_port/core/money.dart';
import 'package:dompetku_port/data/expense_repository.dart';
import 'package:dompetku_port/domain/expense.dart';

/// Hasil validasi form transaksi — dua bidang error terpisah seperti
/// `amountError`/`categoryError` pada `AddExpenseViewModel` Android.
class ExpenseValidation {
  const ExpenseValidation({this.amountError, this.categoryError});

  final String? amountError;
  final String? categoryError;

  bool get isValid => amountError == null && categoryError == null;
}

/// Hasil akhir SIMPAN — paritas `SaveState` Android
/// (`Success(message)` / `Error(message)` + error validasi terpisah).
sealed class ExpenseSaveResult {
  const ExpenseSaveResult();

  const factory ExpenseSaveResult.validation({
    String? amountError,
    String? categoryError,
  }) = SaveFormInvalid;

  const factory ExpenseSaveResult.saved(String message) = SaveSuccess;
  const factory ExpenseSaveResult.failed(String message) = SaveFailure;
}

class SaveFormInvalid extends ExpenseSaveResult {
  const SaveFormInvalid({this.amountError, this.categoryError});

  final String? amountError;
  final String? categoryError;
}

class SaveSuccess extends ExpenseSaveResult {
  const SaveSuccess(this.message);
  final String message;
}

class SaveFailure extends ExpenseSaveResult {
  const SaveFailure(this.message);
  final String message;
}

/// Logika form tambah/edit transaksi — port persis validasi &
/// penyimpanan `AddExpenseViewModel.save` Android (SPEC §6).
///
/// Urutan validasi (pesan harfiah):
///  1. nominal kosong/bukan angka → `Masukkan nominal terlebih dahulu.`
///  2. nominal ≤ 0               → `Nominal tidak boleh 0.`
///  3. nominal > 1 triliun       → `Nominal terlalu besar.`
///  4. kategori null/≤ 0         → `Pilih kategori terlebih dahulu.`
///  5. tanggal kosong            → `Pilih tanggal terlebih dahulu.`
class ExpenseForm {
  ExpenseForm(this._expenses);

  final ExpenseRepository _expenses;

  /// Validasi murni (tanpa I/O) — bisa diuji langsung.
  static ExpenseValidation validate({
    required String amountText,
    int? categoryId,
    required String dateIso,
  }) {
    final amount = Money.parse(amountText); // buang semua non-digit
    if (amount == null) {
      return const ExpenseValidation(
          amountError: 'Masukkan nominal terlebih dahulu.');
    }
    if (amount <= 0) {
      return const ExpenseValidation(amountError: 'Nominal tidak boleh 0.');
    }
    if (amount > Money.maxAmount) {
      return const ExpenseValidation(amountError: 'Nominal terlalu besar.');
    }
    if (categoryId == null || categoryId <= 0) {
      return const ExpenseValidation(
          categoryError: 'Pilih kategori terlebih dahulu.');
    }
    if (dateIso.trim().isEmpty) {
      return const ExpenseValidation(
          amountError: 'Pilih tanggal terlebih dahulu.');
    }
    return const ExpenseValidation();
  }

  /// Validasi lalu simpan (tambah bila [editId] null/≤ 0, selain itu edit).
  Future<ExpenseSaveResult> save({
    int? editId,
    required String amountText,
    int? categoryId,
    required String note,
    required String dateIso,
  }) async {
    final v = validate(amountText: amountText, categoryId: categoryId, dateIso: dateIso);
    if (!v.isValid) {
      return ExpenseSaveResult.validation(
        amountError: v.amountError,
        categoryError: v.categoryError,
      );
    }

    final amount = Money.parse(amountText)!;
    final trimmedNote = note.trim();
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      if (editId != null && editId > 0) {
        final existing = await _expenses.getById(editId);
        if (existing == null) {
          return const SaveFailure('Transaksi tidak ditemukan.');
        }
        final updated = existing.expense.copyWith(
          amount: amount,
          categoryId: categoryId,
          note: trimmedNote,
          expenseDate: dateIso,
          updatedAt: now, // edit hanya mengubah updatedAt (SPEC §6)
        );
        final ok = await _expenses.update(updated);
        return ok
            ? const SaveSuccess('Transaksi diperbarui')
            : const SaveFailure('Gagal menyimpan transaksi.');
      }

      final id = await _expenses.add(Expense(
        id: 0,
        amount: amount,
        categoryId: categoryId!,
        note: trimmedNote,
        expenseDate: dateIso,
        createdAt: now,
        updatedAt: now,
      ));
      return id > 0
          ? const SaveSuccess('Tersimpan')
          : const SaveFailure('Gagal menyimpan transaksi.');
    } catch (_) {
      return const SaveFailure('Gagal menyimpan transaksi.');
    }
  }
}
