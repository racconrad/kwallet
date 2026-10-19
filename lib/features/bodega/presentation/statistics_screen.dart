import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/mvvm/view_model_state.dart';
import '../../../core/theme/category_visuals.dart';
import '../../../core/theme/kwall_theme.dart';
import '../../../core/widgets/finance_widgets.dart';
import '../view_models/statistics_view_model.dart';

class StatisticsScreen extends StatefulWidget {
  final String currency;
  const StatisticsScreen({super.key, required this.currency});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState
    extends ViewModelState<StatisticsScreen, StatisticsViewModel> {
  @override
  StatisticsViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.statistics();
  String money(double value) =>
      KwallTheme.formatCurrency(value, widget.currency);
  @override
  Widget build(BuildContext context) {
    final end = model.end.subtract(const Duration(days: 1));
    final label = model.monthly
        ? DateFormat('MMMM yyyy', 'es').format(model.start)
        : '${DateFormat('d MMM', 'es').format(model.start)} – ${DateFormat('d MMM yyyy', 'es').format(end)}';
    final maximum = model.series.fold<double>(
      0,
      (value, day) => math.max(value, day.amount),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas de gastos')),
      body: ContentWidth(
        child: RefreshIndicator(
          onRefresh: model.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Semanal')),
                  ButtonSegment(value: true, label: Text('Mensual')),
                ],
                showSelectedIcon: false,
                selected: {model.monthly},
                onSelectionChanged: (value) => model.selectPeriod(value.single),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Periodo anterior',
                    onPressed: () => model.move(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: KwallTheme.fontTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Periodo siguiente',
                    onPressed: model.end.isAfter(DateTime.now())
                        ? null
                        : () => model.move(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (model.loading)
                const Center(child: CircularProgressIndicator())
              else if (model.error != null) ...[
                Text(model.error!),
                TextButton.icon(
                  onPressed: model.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ] else ...[
                Text(
                  'Total gastado',
                  style: TextStyle(color: KwallTheme.textSecondary),
                ),
                Text(
                  money(model.total),
                  style: KwallTheme.fontDisplay.copyWith(fontSize: 32),
                ),
                const SizedBox(height: 8),
                Text('Promedio diario: ${money(model.average)}'),
                const SizedBox(height: 4),
                Text(
                  model.change == null
                      ? 'Periodo anterior: ${money(model.previousTotal)}'
                      : '${model.change!.abs().toStringAsFixed(1)} % ${model.change! >= 0 ? 'más' : 'menos'} que ${model.monthly ? 'el mes' : 'la semana'} anterior (${money(model.previousTotal)})',
                  style: TextStyle(color: KwallTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comparación de periodos completos. El actual puede estar en curso.',
                  style: TextStyle(
                    fontSize: 12,
                    color: KwallTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                if (model.total == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No hay gastos registrados en este periodo.'),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth / model.series.length;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          height: 190,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final day in model.series)
                                Tooltip(
                                  triggerMode: TooltipTriggerMode.tap,
                                  message:
                                      '${DateFormat('d MMM', 'es').format(day.date)}: ${money(day.amount)}',
                                  child: Semantics(
                                    label:
                                        '${day.dayLabel}: ${money(day.amount)}',
                                    child: SizedBox(
                                      width: width,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            width: math.max(
                                              3,
                                              math.min(
                                                24,
                                                width - (model.monthly ? 3 : 8),
                                              ),
                                            ),
                                            height: day.amount == 0
                                                ? 2
                                                : math.max(
                                                    4,
                                                    148 * day.amount / maximum,
                                                  ),
                                            decoration: BoxDecoration(
                                              color: day.amount == 0
                                                  ? KwallTheme.border
                                                  : KwallTheme.accent,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            height: 18,
                                            child: OverflowBox(
                                              minWidth: 36,
                                              maxWidth: 36,
                                              minHeight: 18,
                                              maxHeight: 18,
                                              child: Text(
                                                !model.monthly ||
                                                        day.date.day == 1 ||
                                                        day.date.day % 5 == 0 &&
                                                            day.date.day <
                                                                model
                                                                        .series
                                                                        .length -
                                                                    1 ||
                                                        day == model.series.last
                                                    ? day.dayLabel
                                                    : '',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                softWrap: false,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 28),
                Text(
                  'Por categoría',
                  style: KwallTheme.fontTitle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 12),
                for (final item in model.categories) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.category.iconData,
                      color: KwallTheme.displayColor(item.category.colorValue),
                    ),
                    title: Text(item.category.name),
                    subtitle: Text('${item.percentage.toStringAsFixed(1)} %'),
                    trailing: Text(
                      money(item.amount),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  LinearProgressIndicator(
                    value: item.percentage / 100,
                    color: KwallTheme.displayColor(item.category.colorValue),
                    backgroundColor: KwallTheme.surfaceContainer,
                    minHeight: 4,
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 20),
                Text(
                  'Las transferencias, los aportes a ahorro y los ajustes de saldo no cuentan como gastos.',
                  style: TextStyle(
                    fontSize: 12,
                    color: KwallTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
