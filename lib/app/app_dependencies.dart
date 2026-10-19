import '../features/bodega/view_models/statistics_view_model.dart';
import '../core/contracts/app_repositories.dart';
import '../core/database/database_service.dart';
import '../core/services/device_files.dart';
import '../features/bodega/models/account.dart';
import '../features/bodega/view_models/account_editor_view_model.dart';
import '../features/bodega/view_models/budget_editor_view_model.dart';
import '../features/bodega/view_models/categories_view_model.dart';
import '../features/bodega/view_models/home_view_model.dart';
import '../features/bodega/view_models/movements_view_model.dart';
import '../features/bodega/view_models/planning_view_model.dart';
import '../features/bodega/view_models/plan_editor_view_model.dart';
import '../features/bodega/view_models/transaction_editor_view_model.dart';
import '../features/journal/view_models/journal_actions_view_model.dart';
import '../features/journal/view_models/journal_view_model.dart';
import '../features/settings/view_models/settings_view_model.dart';
import '../features/welcome/view_models/launch_view_model.dart';
import 'app_view_model.dart';

class AppDependencies {
  final FinanceRepository finance;
  final JournalRepository journal;
  final SettingsRepository settings;
  final DeviceFiles files;
  const AppDependencies({
    required this.finance,
    required this.journal,
    required this.settings,
    required this.files,
  });
  factory AppDependencies.local() {
    final database = DatabaseService.instance;
    return AppDependencies(
      finance: database,
      journal: database,
      settings: database,
      files: NativeDeviceFiles(),
    );
  }
  AppViewModel app() => AppViewModel(settings)..load();
  HomeViewModel home() =>
      HomeViewModel(finance, journal, settings, files: files)..load();
  LaunchViewModel launch() => LaunchViewModel(settings, files: files)..load();
  JournalViewModel journalScreen() =>
      JournalViewModel(journal, settings)..load();
  JournalActionsViewModel journalActions() => JournalActionsViewModel(journal);
  SettingsViewModel settingsScreen() =>
      SettingsViewModel(settings, files)..load();
  PlanningViewModel planning() =>
      PlanningViewModel(finance, settings, journal)..load(restoreRange: true);
  StatisticsViewModel statistics() => StatisticsViewModel(finance)..load();
  MovementsViewModel movements() => MovementsViewModel(finance)..load();
  CategoriesViewModel categories(String type) =>
      CategoriesViewModel(finance, type)..load();
  AccountEditorViewModel accountEditor() =>
      AccountEditorViewModel(finance, settings)..loadCurrencies();
  BudgetEditorViewModel budgetEditor() => BudgetEditorViewModel(finance);
  PlanEditorViewModel planEditor() => PlanEditorViewModel(finance);
  TransactionEditorViewModel transactionEditor(
    List<Account> accounts,
    String type,
  ) =>
      TransactionEditorViewModel(finance, accounts: accounts, type: type)
        ..loadCategories();
}
