import '../../features/bodega/models/spending_summary.dart';

import 'package:flutter/foundation.dart';

import '../../features/bodega/models/account.dart';
import '../../features/bodega/models/budget_model.dart';
import '../../features/bodega/models/category_model.dart';
import '../../features/bodega/models/finance_overview.dart';
import '../../features/bodega/models/planned_expense.dart';
import '../../features/bodega/models/quick_expense.dart';
import '../../features/bodega/models/transaction_filter.dart';
import '../../features/bodega/models/monthly_movement_summary.dart';
import '../../features/bodega/models/transaction_record.dart';
import '../../features/journal/models/journal_models.dart';
import '../../features/bodega/models/front_pending_item.dart';
import '../models/recovery_copy.dart';

abstract interface class Repository {
  Listenable get changes;
}

abstract interface class FinanceRepository implements Repository {
  Future<List<Account>> getAccounts({
    bool includeArchived = false,
    bool includeDeleted = false,
  });
  Future<void> createAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> setAccountArchived(String id, bool archived);
  Future<void> deleteAccount(String id);
  Future<void> adjustAccountBalance(
    String id,
    double balance, {
    required double expectedBalance,
    required String reason,
  });
  Future<List<DailySpend>> getSpendingSeries({
    required bool monthly,
    DateTime? date,
  });
  Future<List<CategoryBreakdown>> getExpenseBreakdown({
    required DateTime start,
    required DateTime end,
  });
  Future<List<CategoryModel>> getCategories({String? type});
  Future<void> createCategory(CategoryModel category);
  Future<void> deleteCategory(String id);
  Future<List<TransactionRecord>> getTransactions({
    String? accountId,
    int limit = 100,
  });
  Future<List<TransactionRecord>> getTransactionPage(
    TransactionFilter filter, {
    TransactionRecord? before,
    int limit = 40,
  });
  Future<({int count, double income, double expense})> getTransactionTotals(
    TransactionFilter filter,
  );
  Future<List<MonthlyMovementSummary>> getMonthlyHistory(
    TransactionFilter filter,
  );
  Future<void> addTransactions(List<TransactionRecord> transactions);
  Future<void> deleteTransaction(TransactionRecord record);
  Future<BudgetModel> getCurrentBudget();
  Future<Map<BudgetPeriod, double>> getBudgetAllocations(DateTime date);
  Future<Map<BudgetPeriod, double>> getPeriodSpending(DateTime date);
  Future<void> allocateBudget(
    BudgetPeriod period,
    DateTime date,
    double? amount, {
    String? mode,
    double? share,
  });
  Future<List<PlannedExpense>> getPlannedExpenses({
    bool includeCompleted = true,
  });
  Future<void> addPlannedExpense(PlannedExpense expense);
  Future<void> updatePlannedExpense(PlannedExpense expense);
  Future<void> deletePlannedExpense(String id);
  Future<void> payPlannedExpense(
    String id,
    String accountId, {
    required DateTime expectedDueDate,
  });
  Future<List<Map<String, dynamic>>> getAccountCurrencyHistory(
    String accountId,
  );
  Future<void> recordCurrencyChange({
    required String accountId,
    required String baseCurrency,
    required String currency,
    required double rate,
    double? previousRate,
    required String changeType,
    String notes = '',
  });
  Future<List<Map<String, dynamic>>> getBudgetAllocationHistory({
    String? periodKey,
    BudgetPeriod? period,
  });
  Future<List<Map<String, dynamic>>> getPlannedExpensePayments({
    String? plannedExpenseId,
  });
  Future<List<QuickExpense>> getQuickExpenses();
  Future<void> saveQuickExpense(QuickExpense expense);
  Future<void> deleteQuickExpense(String id);
}

abstract interface class JournalRepository implements Repository {
  Future<List<PersonalNote>> getNotes();
  Future<void> saveNote(PersonalNote note);
  Future<void> setNoteItem(
    String id,
    int index,
    bool done, {
    required String expectedText,
  });
  Future<void> deleteNote(String id);
  Future<List<Habit>> getHabits();
  Future<void> saveHabit(
    String id,
    String title, {
    String iconKey,
    int colorValue,
    String timeBlock,
  });
  Future<void> deleteHabit(String id);
  Future<void> logHabitDays(
    Iterable<String> habitIds,
    Iterable<DateTime> days, {
    required bool completed,
    String mood = 'neutral',
    String reason = '',
  });
  Future<int> getExperience();
  Future<bool> awardAffection(int points);
  Future<void> syncFrontPendingItems(List<FrontPendingItem> items);
  Future<List<FrontPendingItem>> getFrontPendingItems({
    bool onlyPending = true,
  });
  Future<void> markFrontPendingItemDone(String id, bool done);
}

abstract interface class SettingsRepository implements Repository {
  Future<String?> getGitHubToken();
  Future<void> saveGitHubToken(String? token);
  Future<Map<String, String>> getSettings();
  Future<void> saveSettings(Map<String, String> values);
  Future<String> exportFullDataAsJson();
  Future<Map<String, int>> inspectBackup(String content);
  Future<void> importFullDataFromJson(String content);
  Future<List<RecoveryCopy>> getRecoveryCopies();
  Future<String> readRecoveryCopy(String id);
  Future<Map<String, double>> getCurrencyRates();
  Future<void> setCurrencyRate({
    required String currency,
    required double rate,
    String notes = '',
  });
  Future<void> removeCurrencyRate(String currency);
  Future<List<Map<String, dynamic>>> getCurrencyRateHistory({String? currency});
  Future<Map<String, String>> getUserCurrencies();
  Future<void> saveUserCurrency(String code, [String name = '']);
  Future<void> deleteUserCurrency(String code);
  Future<bool> hasRecoveryCopies();
  Future<bool> restoreLatestRecoveryCopy();
  Future<void> repairOrResetDatabase();
  Future<String> checkDatabaseIntegrity();
}
