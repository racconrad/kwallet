import 'dart:async';

import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/mvvm/view_model.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/category_model.dart';
import 'package:knotes/features/bodega/models/monthly_movement_summary.dart';
import 'package:knotes/features/bodega/models/transaction_filter.dart';
import 'package:knotes/features/bodega/models/transaction_record.dart';

class MovementsViewModel extends ViewModel {
  final FinanceRepository repository;
  List<Account> accounts = const [];
  Map<String, CategoryModel> categories = const {};
  List<TransactionRecord> records = const [];
  List<MonthlyMovementSummary> months = const [];
  String? account;
  bool archived = false;
  String? type;
  String search = '';
  DateTime? start;
  DateTime? end;
  bool loading = true;
  bool more = true;
  int count = 0;
  double income = 0;
  double expense = 0;
  Timer? _debounce;
  MovementsViewModel(this.repository) {
    observe(repository.changes, load);
  }
  TransactionFilter get filter => TransactionFilter(
    accountId: account,
    archived: archived,
    type: type,
    search: search,
    start: start,
    end: end,
  );
  Future<void> load({bool next = false}) async {
    if (next && (loading || !more)) return;
    final request = beginRequest();
    if (!next) records = const [];
    loading = true;
    changed();
    try {
      if (!next) {
        final nextAccounts = await repository.getAccounts(
          includeArchived: true,
          includeDeleted: true,
        );
        if (!isCurrent(request)) return;
        accounts = List.unmodifiable(nextAccounts);
        if (!accounts.any((a) => a.id == account)) account = null;
      }
      final query = filter;
      final rows = await repository.getTransactionPage(
        query,
        before: next ? records.lastOrNull : null,
      );
      if (!next) {
        final nextCategories = await repository.getCategories();
        final totals = await repository.getTransactionTotals(query);
        final nextMonths = await repository.getMonthlyHistory(query);
        if (!isCurrent(request)) return;
        categories = Map.unmodifiable({
          for (final c in nextCategories) c.id: c,
        });
        count = totals.count;
        income = totals.income;
        expense = totals.expense;
        months = List.unmodifiable(nextMonths);
      }
      if (!isCurrent(request)) return;
      records = List.unmodifiable([if (next) ...records, ...rows]);
      more = rows.length == 40;
      loading = false;
      error = null;
      changed();
    } catch (_) {
      if (isCurrent(request)) {
        loading = false;
        fail('No se pudo cargar el historial. Reintenta.');
      }
    }
  }

  void searchFor(String text) {
    search = text;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), load);
  }

  void selectAccount(String? value) {
    account = value;
    load();
  }

  void selectType(String? value) {
    type = value;
    load();
  }

  void showArchived(bool value) {
    archived = value;
    load();
  }

  void selectDate(DateTime date, {required bool from}) {
    if (from) {
      start = date;
      if (end != null && date.isAfter(end!)) end = date;
    } else {
      end = date;
      if (start != null && date.isBefore(start!)) start = date;
    }
    load();
  }

  void clearDates() {
    start = null;
    end = null;
    load();
  }

  Future<bool> voidMovement(TransactionRecord record) {
    if (archived || !records.any((tx) => tx.id == record.id)) {
      return Future.value(false);
    }
    return perform(() async {
      await repository.deleteTransaction(record);
      await load();
    }, failure: 'No se pudo anular el movimiento. Reintenta.');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
