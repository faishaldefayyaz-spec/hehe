import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:dompetku_port/core/app_date.dart';
import 'package:dompetku_port/data/expense_repository.dart';
import 'package:dompetku_port/domain/expense.dart';

/// Filter tanggal riwayat — paritas enum `DateFilter` Android (SPEC §9).
enum DateFilter { all, today, last7Days, thisMonth, custom }

enum SortOrder { newest, oldest }

/// State tab Riwayat — paritas `HistoryUiState` Android.
class HistoryUiState {
  const HistoryUiState({
    this.query = '',
    this.dateFilter = DateFilter.all,
    this.customFromIso,
    this.customToIso,
    this.categoryId,
    this.categoryName = 'Semua kategori',
    this.sortOrder = SortOrder.newest,
    this.items = const [],
    this.totalCount = 0,
    this.totalAmount = 0,
    this.isLoading = true,
    this.errorMessage,
  });

  final String query;
  final DateFilter dateFilter;
  final String? customFromIso;
  final String? customToIso;
  final int? categoryId;
  final String categoryName;
  final SortOrder sortOrder;
  final List<ExpenseWithCategory> items;
  final int totalCount;
  final int totalAmount;
  final bool isLoading;
  final String? errorMessage;

  /// Penanda "tidak disentuh" agar `categoryId`/rentang kustom bisa
  /// di-set ke `null` (reset ke "Semua") — `?? this.x` biasa tak bisa.
  static const Object _unset = Object();

  HistoryUiState copyWith({
    String? query,
    DateFilter? dateFilter,
    Object? customFromIso = _unset,
    Object? customToIso = _unset,
    Object? categoryId = _unset,
    String? categoryName,
    SortOrder? sortOrder,
    List<ExpenseWithCategory>? items,
    int? totalCount,
    int? totalAmount,
    bool? isLoading,
    String? errorMessage,
  }) =>
      HistoryUiState(
        query: query ?? this.query,
        dateFilter: dateFilter ?? this.dateFilter,
        customFromIso:
            identical(customFromIso, _unset) ? this.customFromIso : customFromIso as String?,
        customToIso:
            identical(customToIso, _unset) ? this.customToIso : customToIso as String?,
        categoryId: identical(categoryId, _unset) ? this.categoryId : categoryId as int?,
        categoryName: categoryName ?? this.categoryName,
        sortOrder: sortOrder ?? this.sortOrder,
        items: items ?? this.items,
        totalCount: totalCount ?? this.totalCount,
        totalAmount: totalAmount ?? this.totalAmount,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

/// Logika tab Riwayat — port `HistoryViewModel` Android tanpa UI.
/// Pencarian teks memakai debounce 250 ms (SPEC §9).
class HistoryController extends ChangeNotifier {
  HistoryController(this._expenses);

  final ExpenseRepository _expenses;

  HistoryUiState state = const HistoryUiState();

  /// Pencarian dengan **debounce 250 ms** (SPEC §9) — dipakai UI.
  Timer? _debounce;

  void setQueryDebounced(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), load);
  }

  /// Mutator sinkron tanpa debounce (dipakai test & pemanggil eksplisit).
  Future<void> setQuery(String query) {
    state = state.copyWith(query: query);
    return load();
  }

  Future<void> setDateFilter(DateFilter filter) {
    state = state.copyWith(dateFilter: filter);
    return load();
  }

  Future<void> setCustomRange(String? fromIso, String? toIso) {
    state = state.copyWith(
      dateFilter: DateFilter.custom,
      customFromIso: fromIso,
      customToIso: toIso,
    );
    return load();
  }

  Future<void> setCategory(int? categoryId, String categoryName) {
    state = state.copyWith(categoryId: categoryId, categoryName: categoryName);
    return load();
  }

  Future<void> toggleSort() {
    state = state.copyWith(
      sortOrder: state.sortOrder == SortOrder.newest
          ? SortOrder.oldest
          : SortOrder.newest,
    );
    return load();
  }

  Future<void> load() async {
    final s = state;
    try {
      final (from, to) = _resolveRange(s);
      final items = await _expenses.getRange(
        fromIso: from,
        toIso: to,
        query: s.query.trim().isEmpty ? null : s.query,
        categoryId: s.categoryId,
        newestFirst: s.sortOrder == SortOrder.newest,
      );
      state = s.copyWith(
        items: items,
        totalCount: items.length,
        totalAmount: items.fold<int>(0, (a, i) => a + i.expense.amount),
        isLoading: false,
        errorMessage: null,
      );
    } catch (_) {
      state = s.copyWith(
        isLoading: false,
        errorMessage: 'Gagal membaca riwayat transaksi.',
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<bool> delete(int expenseId) async {
    bool ok;
    try {
      ok = await _expenses.delete(expenseId);
    } catch (_) {
      ok = false;
    }
    if (ok) await load();
    return ok;
  }

  /// Rentang filter — persis `resolveRange` Android:
  /// `Semua` = 0001-01-01 s/d 9999-12-31; kustom ditukar bila from > to.
  (String, String) _resolveRange(HistoryUiState s) {
    final today = AppDate.todayIso();
    return switch (s.dateFilter) {
      DateFilter.all => ('0001-01-01', '9999-12-31'),
      DateFilter.today => (today, today),
      DateFilter.last7Days => (AppDate.daysBefore(today, 6), today),
      DateFilter.thisMonth => (AppDate.startOfMonth(today), today),
      DateFilter.custom => () {
          final from = s.customFromIso ?? AppDate.startOfMonth(today);
          final to = s.customToIso ?? today;
          return from.compareTo(to) <= 0 ? (from, to) : (to, from);
        }(),
    };
  }
}
