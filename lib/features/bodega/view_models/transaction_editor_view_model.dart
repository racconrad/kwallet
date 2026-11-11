import 'dart:collection';

import 'package:uuid/uuid.dart';

import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/models/amount.dart';
import 'package:knotes/core/mvvm/view_model.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/category_model.dart';
import 'package:knotes/features/bodega/models/transaction_record.dart';

typedef MovementInput = ({
  String amount,
  String note,
  DateTime date,
  String account,
  String? destination,
  String? category,
});

class TransactionEditorViewModel extends ViewModel {
  final FinanceRepository repository;
  final List<Account> accounts;
  String type;
  List<CategoryModel> categories = const [];
  String? category;
  final List<TransactionRecord> _queue = [];
  UnmodifiableListView<TransactionRecord> get queue =>
      UnmodifiableListView(_queue);
  double get queueTotal => _queue.fold(0, (sum, tx) => sum + tx.amount);
  TransactionEditorViewModel(
    this.repository, {
    required List<Account> accounts,
    required this.type,
  }) : accounts = List.unmodifiable(accounts);
  String initialAccount(String? requested) =>
      accounts.any((a) => a.id == requested) ? requested! : accounts.first.id;
  Future<void> loadCategories() async {
    final request = beginRequest();
    try {
      final rows = await repository.getCategories(
        type: type == 'income' ? 'income' : 'expense',
      );
      if (!isCurrent(request)) return;
      categories = List.unmodifiable(rows);
      if (!rows.any((c) => c.id == category)) category = rows.firstOrNull?.id;
      changed();
    } catch (_) {
      if (isCurrent(request)) fail('No se pudieron cargar las categorías.');
    }
  }

  void selectType(String value) {
    if (_queue.isNotEmpty || busy) return;
    type = value;
    category = null;
    categories = const [];
    error = null;
    changed();
    loadCategories();
  }

  void selectCategory(String? value) {
    category = value;
    changed();
  }

  bool validate(MovementInput input) {
    final amount = parseAmount(input.amount);
    if (amount == null || amount <= 0) {
      return fail('Ingresa un monto mayor a 0.');
    }
    if (type == 'transfer' &&
        (input.destination == null || input.account == input.destination)) {
      return fail('Selecciona una cuenta de destino distinta.');
    }
    if (type != 'transfer' && input.category == null) {
      return fail('Añade y selecciona una categoría.');
    }
    return true;
  }

  TransactionRecord _draft(MovementInput input, [DateTime? date]) =>
      TransactionRecord(
        id: const Uuid().v4(),
        accountId: input.account,
        currency: accounts.firstWhere((a) => a.id == input.account).currency,
        toAccountId: type == 'transfer' ? input.destination : null,
        categoryId: input.category ?? 'transfer',
        amount: parseAmount(input.amount)!,
        type: type,
        note: input.note.trim(),
        date: date ?? input.date,
        createdAt: DateTime.now(),
      );
  bool enqueue(MovementInput input) {
    if (busy || !validate(input)) return false;
    _queue.add(_draft(input));
    error = null;
    changed();
    return true;
  }

  bool repeat(MovementInput input, DateTime start, DateTime end) {
    if (busy || !validate(input)) return false;
    final count =
        DateTime.utc(
          end.year,
          end.month,
          end.day,
        ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
        1;
    if (count < 1 || count > 366) {
      return fail('Selecciona como máximo 366 días por lote.');
    }
    for (var i = 0; i < count; i++) {
      _queue.add(
        _draft(input, DateTime(start.year, start.month, start.day + i)),
      );
    }
    error = null;
    changed();
    return true;
  }

  void removeQueued(int index) {
    if (!busy) {
      _queue.removeAt(index);
      changed();
    }
  }

  Future<bool> save(MovementInput input) {
    final transactions = [..._queue];
    if (input.amount.trim().isNotEmpty || transactions.isEmpty) {
      if (!validate(input)) return Future.value(false);
      transactions.add(_draft(input));
    }
    return perform(
      () => repository.addTransactions(transactions),
      failure: 'No se guardó el lote. Revisa las cuentas e inténtalo otra vez.',
    );
  }
}
