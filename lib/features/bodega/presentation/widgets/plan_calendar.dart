import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/bodega/models/planned_expense.dart';

class PlanCalendar extends StatelessWidget {
  final DateTime month;
  final DateTimeRange range;
  final List<PlannedExpense> plans;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onSelect;
  const PlanCalendar({
    super.key,
    required this.month,
    required this.range,
    required this.plans,
    required this.onMonth,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final marks = <int, List<PlannedExpense>>{};
    for (final plan in plans) {
      for (final date in plan.datesBetween(
        first,
        DateTime(month.year, month.month, days),
      )) {
        (marks[date.day] ??= []).add(plan);
      }
    }
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return LedgerPanel(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
                icon: Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${months[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: KnotesTheme.fontTitle.copyWith(fontSize: 18),
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
                icon: Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final day in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(color: KnotesTheme.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48,
            ),
            itemCount: first.weekday - 1 + days,
            itemBuilder: (context, index) {
              final day = index - first.weekday + 2;
              if (day < 1) return SizedBox.shrink();
              final date = DateTime(month.year, month.month, day);
              final selected =
                  !date.isBefore(range.start) && !date.isAfter(range.end);
              final events = marks[day] ?? [];
              final today = DateUtils.isSameDay(date, DateTime.now());
              return Semantics(
                label:
                    '${DateFormat('dd/MM/yyyy').format(date)}, ${events.length} fechas',
                selected: selected,
                button: true,
                child: Tooltip(
                  message: events.map((p) => p.title).join(', '),
                  child: InkWell(
                    onTap: () => onSelect(date),
                    child: Container(
                      margin: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: selected ? KnotesTheme.accentLight : null,
                        borderRadius: BorderRadius.circular(
                          KnotesTheme.radiusSm,
                        ),
                        border: today
                            ? Border.all(color: KnotesTheme.accent, width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$day'),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (events.any((p) => p.amount > 0))
                                Container(
                                  width: 5,
                                  height: 5,
                                  color: KnotesTheme.accent,
                                ),
                              if (events.any((p) => p.amount == 0))
                                Icon(
                                  Icons.star_rounded,
                                  size: 9,
                                  color: KnotesTheme.incomeGreen,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 10),
          Text(
            'Cuadrado: pagos · Estrella: días especiales',
            style: TextStyle(color: KnotesTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
