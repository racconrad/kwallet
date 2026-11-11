import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/journal/presentation/goals_section.dart';
import 'package:knotes/features/journal/presentation/habit_check_in.dart';
import 'package:knotes/features/journal/presentation/journal_sheets.dart';
import 'package:knotes/features/journal/presentation/note_preview.dart';
import 'package:knotes/features/journal/presentation/widgets/quick_capture_field.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';
import 'package:knotes/features/bodega/presentation/widgets/home_tasks_panel.dart';
import 'package:knotes/features/bodega/presentation/widgets/quick_expense_shortcuts.dart';
import 'package:knotes/features/bodega/presentation/widgets/upcoming_dates_panel.dart';

const homeAreas = ['money', 'habits', 'notes'];

/// The three areas of knotes, each with a live summary that doubles as a tab.
/// The chosen area is remembered between launches.
class HomeHub extends StatefulWidget {
  final HomeViewModel controller;
  final ValueChanged<String> onTransaction;
  final VoidCallback onAgenda;
  final VoidCallback? onOpenFinances;
  final ValueChanged<int> onJournal;
  const HomeHub({
    super.key,
    required this.controller,
    required this.onTransaction,
    required this.onAgenda,
    required this.onJournal,
    this.onOpenFinances,
  });
  @override
  State<HomeHub> createState() => _HomeHubState();
}

class _HomeHubState extends State<HomeHub> {
  late String _area =
      homeAreas.contains(widget.controller.settings['home_area'])
      ? widget.controller.settings['home_area']!
      : 'money';
  DateTime? _selectedDay;
  DateTime get _habitDay => _selectedDay ?? DateTime.now();
  HomeViewModel get _c => widget.controller;

  void _select(String area) {
    if (area == _area) return;
    HapticFeedback.selectionClick();
    setState(() => _area = area);
    _c.saveSetting('home_area', area);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _c.pendingTasks.length;
    final areas = [
      (
        'money',
        Icons.account_balance_wallet_outlined,
        'Dinero',
        KnotesTheme.formatCurrency(_c.available, _c.currency),
        'libre para usar',
      ),
      (
        'habits',
        Icons.local_fire_department_outlined,
        'Hábitos',
        _c.totalHabitsToday == 0
            ? '0'
            : '${_c.completedHabitsToday}/${_c.totalHabitsToday}',
        'hechos hoy',
      ),
      (
        'notes',
        Icons.sticky_note_2_outlined,
        'Notas',
        '$pending',
        pending == 1 ? 'tarea pendiente' : 'tareas pendientes',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (i, (key, icon, label, value, caption)) in areas.indexed)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                  child: _AreaTab(
                    icon: icon,
                    label: label,
                    value: value,
                    caption: caption,
                    selected: _area == key,
                    onTap: () => _select(key),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
          ),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .03),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey(_area),
            child: switch (_area) {
              'habits' => _habits(),
              'notes' => _notes(),
              _ => _money(),
            },
          ),
        ),
      ],
    );
  }

  Widget _heading(String text, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: KnotesTheme.fontTitle.copyWith(fontSize: 20),
          ),
        ),
        ?action,
      ],
    ),
  );

  Widget _money() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Tu dinero hoy'),
      Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => widget.onTransaction('expense'),
              icon: const Icon(Icons.north_east_rounded),
              label: const Text('Gasto'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => widget.onTransaction('income'),
              icon: const Icon(Icons.south_west_rounded),
              label: const Text('Ingreso'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      QuickExpenseShortcuts(controller: _c),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.event_repeat_rounded, color: KnotesTheme.accent),
        title: Text(
          '${KnotesTheme.formatCurrency(_c.weeklyCommitments, _c.currency)} previstos esta semana',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: widget.onAgenda,
      ),
      UpcomingDatesPanel(controller: _c, onOpenAgenda: widget.onAgenda),
      if (widget.onOpenFinances != null)
        TextButton.icon(
          onPressed: widget.onOpenFinances,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Cuentas y estadísticas'),
        ),
    ],
  );

  Widget _habits() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(
        'Tus hábitos',
        action: IconButton.filledTonal(
          tooltip: 'Nuevo hábito',
          onPressed: () => editHabit(context),
          icon: const Icon(Icons.add_rounded),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _habitDay,
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null && mounted) {
              setState(
                () => _selectedDay = DateUtils.isSameDay(date, DateTime.now())
                    ? null
                    : date,
              );
            }
          },
          icon: const Icon(Icons.today_outlined),
          label: Text(
            DateUtils.isSameDay(_habitDay, DateTime.now())
                ? 'Hoy'
                : DateFormat('d MMM y', 'es').format(_habitDay),
          ),
        ),
      ),
      if (_c.habits.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Tu primer hábito empieza aquí. Algo pequeño basta: beber agua, leer 5 minutos.',
            style: TextStyle(color: KnotesTheme.textSecondary),
          ),
        )
      else ...[
        HabitDaySummary(
          habits: _c.habits,
          day: _habitDay,
          settings: _c.settings,
          reward: _c.xp,
        ),
        const SizedBox(height: 12),
        for (final habit in _c.habits.take(4))
          HabitCard(
            key: ValueKey(habit.id),
            habit: habit,
            day: _habitDay,
            compact: true,
            hideStreak: _c.settings['disable_streaks'] == 'true',
          ),
      ],
      const SizedBox(height: 12),
      GoalsSection(
        goals: _c.goals,
        habits: _c.habits,
        onMark: _c.markGoal,
        limit: 2,
      ),
      TextButton.icon(
        onPressed: () => widget.onJournal(1),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Todos mis hábitos y metas'),
      ),
    ],
  );

  Widget _notes() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(
        'Tus notas',
        action: IconButton.filledTonal(
          tooltip: 'Nueva nota o lista',
          onPressed: () => openNote(context),
          icon: const Icon(Icons.add_rounded),
        ),
      ),
      const QuickCaptureField(),
      const SizedBox(height: 12),
      HomeTasksPanel(
        controller: _c,
        onNewTask: () => openNote(context, initialKind: 'list'),
        onOpenNotes: () => widget.onJournal(0),
      ),
      const SizedBox(height: 12),
      for (final note in _c.notes.where((n) => n.items.isEmpty).take(3))
        NotePreview(key: ValueKey(note.id), note: note),
      for (final note in _c.notes.where((n) => n.items.isNotEmpty).take(2))
        NotePreview(key: ValueKey('list-${note.id}'), note: note),
      if (_c.notes.isNotEmpty)
        TextButton.icon(
          onPressed: () => widget.onJournal(0),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Todas mis notas'),
        ),
    ],
  );
}

class _AreaTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final bool selected;
  final VoidCallback onTap;
  const _AreaTab({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: '$label: $value $caption',
    excludeSemantics: true,
    child: AnimatedContainer(
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
      ),
      decoration: BoxDecoration(
        color: selected ? KnotesTheme.accentLight : KnotesTheme.surface,
        borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
        border: Border.all(
          color: selected ? KnotesTheme.accent : KnotesTheme.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? KnotesTheme.accent
                      : KnotesTheme.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: KnotesTheme.fontTitle.copyWith(fontSize: 17),
                  ),
                ),
                Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: KnotesTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
