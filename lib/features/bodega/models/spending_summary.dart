import 'package:knotes/features/bodega/models/category_model.dart';

class DailySpend {
  final DateTime date;
  final String dayLabel;
  final double amount;

  DailySpend({
    required this.date,
    required this.dayLabel,
    required this.amount,
  });
}

class CategoryBreakdown {
  final CategoryModel category;
  final double amount;
  final double percentage;

  CategoryBreakdown({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}
