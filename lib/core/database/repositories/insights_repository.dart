import '../currency_snapshot.dart';
import '../../../features/bodega/models/spending_summary.dart';
import '../../../features/bodega/models/category_model.dart';
import '../database_context.dart';

mixin InsightsRepository on DatabaseContext {
  Future<List<DailySpend>> getSpendingSeries({
    required bool monthly,
    DateTime? date,
  }) async {
    final db = await database;
    final selected = date ?? DateTime.now();
    final day = DateTime(selected.year, selected.month, selected.day);
    final start = monthly
        ? DateTime(day.year, day.month)
        : DateTime(day.year, day.month, day.day - day.weekday + 1);
    final end = monthly
        ? DateTime(start.year, start.month + 1)
        : DateTime(start.year, start.month, start.day + 7);
    final rows = await db.rawQuery(
      "SELECT substr(date,1,10) AS day, COALESCE(currency,(SELECT currency FROM accounts WHERE accounts.id = transactions.account_id),'\$') AS unit, SUM(amount) AS total FROM transactions WHERE type = 'expense' AND date >= ? AND date < ? GROUP BY day,unit",
      [start.toIso8601String(), end.toIso8601String()],
    );
    final snapshot = await CurrencySnapshot.read(db);
    final amounts = <String, double>{};
    for (final row in rows) {
      final key = row['day'] as String;
      amounts[key] =
          (amounts[key] ?? 0) +
          snapshot.convert(
            (row['total'] as num).toDouble(),
            row['unit'] as String,
          );
    }
    const weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return [
      for (
        var d = start;
        d.isBefore(end);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        DailySpend(
          date: d,
          dayLabel: monthly ? '${d.day}' : weekdays[d.weekday - 1],
          amount: amounts[d.toIso8601String().substring(0, 10)] ?? 0,
        ),
    ];
  }

  Future<List<DailySpend>> getDailySpendingLast7Days() async {
    final db = await database;
    final now = DateTime.now();
    final List<DailySpend> result = [];

    const weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final start = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        0,
        0,
        0,
      ).toIso8601String();
      final total = await CurrencySnapshot.sum(
        db,
        "type = 'expense' AND date >= ? AND date < ?",
        [
          start,
          DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day + 1,
          ).toIso8601String(),
        ],
      );
      final dayLabel = weekdays[targetDate.weekday - 1];

      result.add(
        DailySpend(
          date: targetDate,
          dayLabel: i == 0 ? 'Hoy' : dayLabel,
          amount: total,
        ),
      );
    }

    return result;
  }

  Future<List<CategoryBreakdown>> getCategorySpendingBreakdown(
    int month,
    int year,
  ) async {
    return getExpenseBreakdown(
      start: DateTime(year, month),
      end: DateTime(year, month + 1),
    );
  }

  Future<List<CategoryBreakdown>> getExpenseBreakdown({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    final snapshot = await CurrencySnapshot.read(db);
    final rows = await db.rawQuery(
      "SELECT category_id, COALESCE(currency,(SELECT currency FROM accounts WHERE accounts.id = transactions.account_id),'\$') AS unit, SUM(amount) AS total FROM transactions WHERE type = 'expense' AND date >= ? AND date < ? GROUP BY category_id,unit",
      [start.toIso8601String(), end.toIso8601String()],
    );
    final totals = <String, double>{};
    for (final row in rows) {
      final id = row['category_id'] as String;
      totals[id] =
          (totals[id] ?? 0) +
          snapshot.convert(
            (row['total'] as num).toDouble(),
            row['unit'] as String,
          );
    }
    final grandTotal = totals.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    if (grandTotal <= 0) return [];
    final categories = (await db.query('categories'))
        .map(CategoryModel.fromMap);
    final catMap = {for (var c in categories) c.id: c};

    final List<CategoryBreakdown> breakdown = [];
    for (final r in totals.entries) {
      final catId = r.key;
      final total = r.value;
      final cat =
          catMap[catId] ??
          CategoryModel(
            id: catId,
            name: 'Varios',
            type: 'expense',
            iconKey: 'tag',
            colorValue: 0xFF625B52,
          );

      breakdown.add(
        CategoryBreakdown(
          category: cat,
          amount: total,
          percentage: (total / grandTotal) * 100,
        ),
      );
    }
    breakdown.sort((a, b) => b.amount.compareTo(a.amount));
    return breakdown;
  }
}
