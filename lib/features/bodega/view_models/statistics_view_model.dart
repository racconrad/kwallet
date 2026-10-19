import '../../../core/contracts/app_repositories.dart';
import '../../../core/mvvm/view_model.dart';
import '../models/spending_summary.dart';

class StatisticsViewModel extends ViewModel {
  final FinanceRepository repository;
  StatisticsViewModel(this.repository) {
    observe(repository.changes, load);
  }
  bool monthly = false;
  bool loading = true;
  DateTime date = DateTime.now();
  List<DailySpend> series = const [];
  List<CategoryBreakdown> categories = const [];
  double previousTotal = 0;
  double get total => series.fold(0, (sum, day) => sum + day.amount);
  double get average => total / elapsedDays;
  int get elapsedDays {
    final today = DateTime.now();
    final last = DateTime(today.year, today.month, today.day);
    final days = series.where((d) => !d.date.isAfter(last)).length;
    return days == 0 ? 1 : days;
  }

  double? get change =>
      previousTotal > 0 ? (total - previousTotal) / previousTotal * 100 : null;
  DateTime get start => monthly
      ? DateTime(date.year, date.month)
      : DateTime(date.year, date.month, date.day - date.weekday + 1);
  DateTime get end => monthly
      ? DateTime(start.year, start.month + 1)
      : DateTime(start.year, start.month, start.day + 7);
  DateTime _offset(int direction) => monthly
      ? DateTime(date.year, date.month + direction)
      : DateTime(date.year, date.month, date.day + direction * 7);
  void selectPeriod(bool value) {
    if (monthly == value) return;
    monthly = value;
    load();
  }

  void move(int direction) {
    date = _offset(direction);
    load();
  }

  Future<void> load() async {
    final request = beginRequest();
    loading = true;
    error = null;
    changed();
    final from = start,
        until = end,
        isMonth = monthly,
        selected = date,
        previousDate = _offset(-1);
    try {
      final rows = await repository.getSpendingSeries(
        monthly: isMonth,
        date: selected,
      );
      final previous = await repository.getSpendingSeries(
        monthly: isMonth,
        date: previousDate,
      );
      final breakdown = await repository.getExpenseBreakdown(
        start: from,
        end: until,
      );
      if (!isCurrent(request)) return;
      series = List.unmodifiable(rows);
      categories = List.unmodifiable(breakdown);
      previousTotal = previous.fold<double>(0, (sum, day) => sum + day.amount);
    } catch (e) {
      if (isCurrent(request)) {
        error = e is StateError
            ? e.message.toString()
            : 'No se pudieron cargar los gastos. Reintenta.';
      }
    } finally {
      if (isCurrent(request)) {
        loading = false;
        changed();
      }
    }
  }
}
