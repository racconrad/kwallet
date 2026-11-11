import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/journal/view_models/journal_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/journal/presentation/goals_section.dart';
import 'package:knotes/features/journal/presentation/habit_check_in.dart';
import 'package:knotes/features/journal/presentation/journal_sheets.dart';

import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/core/widgets/pet_cameo_empty_state.dart';
import 'package:knotes/features/journal/presentation/widgets/habit_time_block_filter.dart';
import 'package:knotes/features/journal/presentation/widgets/quick_capture_field.dart';
import 'package:knotes/core/widgets/menu_label.dart';

export 'note_screen.dart' show NoteScreen, openNote;

class JournalScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback? onSettings;
  const JournalScreen({super.key, this.initialTab = 0, this.onSettings});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState
    extends ViewModelState<JournalScreen, JournalViewModel> {
  @override
  JournalViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.journalScreen();
  List<PersonalNote> get _notes => model.notes;
  List<Habit> get _habits => model.habits;
  Map<String, String> get _settings => model.settings;
  int get _xp => model.xp;
  late int _tab = widget.initialTab;
  String _activeTimeBlock = 'all';
  final _search = TextEditingController();
  String _noteFilter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PersonalNote> get _visibleNotes {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final note in _notes)
        if ((_noteFilter != 'lists' || note.items.isNotEmpty) &&
            (_noteFilter != 'pending' || note.items.any((i) => !i.done)) &&
            (query.isEmpty ||
                note.title.toLowerCase().contains(query) ||
                note.body.toLowerCase().contains(query) ||
                note.items.any((i) => i.text.toLowerCase().contains(query))))
          note,
    ];
  }

  DateTime? _selectedDay;
  DateTime get _day => _selectedDay ?? DateTime.now();
  void _selectDay(DateTime date) => setState(
    () =>
        _selectedDay = DateUtils.isSameDay(date, DateTime.now()) ? null : date,
  );
  bool get _loading => model.loading;
  String? get _error => model.error;
  Future<void> _load() => model.load();
  void _editNote([PersonalNote? note, bool edit = false]) =>
      openNote(context, note: note, edit: edit);
  Future<void> _habit([Habit? habit]) => editHabit(context, habit: habit);

  @override
  Widget build(BuildContext _) {
    Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi espacio'),
        actions: [
          if (widget.onSettings != null)
            IconButton(
              tooltip: 'Ajustes',
              icon: const Icon(Icons.tune_rounded),
              onPressed: widget.onSettings,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Notas'),
                        icon: Icon(Icons.sticky_note_2_outlined),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Hábitos'),
                        icon: Icon(Icons.local_fire_department_outlined),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (value) =>
                        setState(() => _tab = value.first),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    TextButton(onPressed: _load, child: Text(_error!)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tab == 0 ? 'Mis notas' : 'Mis hábitos',
                          style: KnotesTheme.fontTitle.copyWith(fontSize: 20),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: _tab == 0
                            ? 'Nueva nota o lista'
                            : 'Nuevo hábito',
                        onPressed: () {
                          if (_tab == 0) {
                            _editNote();
                          } else {
                            _habit();
                          }
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  if (_tab == 0) ...[
                    const SizedBox(height: 8),
                    const QuickCaptureField(),
                    if (_notes.length > 3) ...[
                      const SizedBox(height: 12),
                      SearchBar(
                        controller: _search,
                        hintText: 'Buscar en mis notas',
                        leading: const Icon(Icons.search_rounded),
                        elevation: const WidgetStatePropertyAll(0),
                        onChanged: (_) => setState(() {}),
                        trailing: [
                          if (_search.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Limpiar',
                              onPressed: () => setState(_search.clear),
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (key, label) in const [
                          ('all', 'Todas'),
                          ('lists', 'Listas'),
                          ('pending', 'Con pendientes'),
                        ])
                          ChoiceChip(
                            label: Text(label),
                            selected: _noteFilter == key,
                            onSelected: (_) =>
                                setState(() => _noteFilter = key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_notes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Text('Una idea, una lista, lo que necesites.'),
                      )
                    else if (_visibleNotes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Nada coincide con tu búsqueda.',
                          style: TextStyle(color: KnotesTheme.textSecondary),
                        ),
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final note in _visibleNotes)
                              SizedBox(
                                width: itemWidth,
                                child: _buildCompactNoteCard(note),
                              ),
                          ],
                        );
                      },
                    ),
                  ] else ...[
                    _dayPicker(),
                    const SizedBox(height: 16),
                    if (_habits.isEmpty)
                      const PetCameoEmptyState(
                        label: 'Tu primer hábito empieza aquí.',
                        iconBadge: Icons.auto_awesome_rounded,
                      ),
                    HabitDaySummary(
                      habits: _habits,
                      day: _day,
                      settings: _settings,
                      reward: _xp,
                    ),
                    if (_habits.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      HabitTimeBlockFilter(
                        activeBlock: _activeTimeBlock,
                        onChanged: (block) =>
                            setState(() => _activeTimeBlock = block),
                      ),
                    ],
                    const SizedBox(height: 12),
                    for (final habit in HabitTimeBlockFilter.filter(
                      _habits,
                      _activeTimeBlock,
                    ))
                      HabitCard(
                        key: ValueKey(habit.id),
                        habit: habit,
                        day: _day,
                        hideStreak: _settings['disable_streaks'] == 'true',
                        onEdit: () => _habit(habit),
                      ),
                    const SizedBox(height: 24),
                    GoalsSection(
                      goals: model.goals,
                      habits: _habits,
                      onMark: model.markGoal,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _dayPicker() => Column(
    children: [
      TextButton.icon(
        icon: const Icon(Icons.event_outlined),
        label: Text(DateFormat('EEE d MMM y', 'es').format(_day)),
        onPressed: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _day,
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );
          if (date != null && mounted) _selectDay(date);
        },
      ),
      Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (_) {
                  final day = DateTime(
                    _day.year,
                    _day.month,
                    _day.day - _day.weekday + 1 + i,
                  );
                  final future = DateUtils.dateOnly(day)
                      .isAfter(DateUtils.dateOnly(DateTime.now()));
                  final selected = dayKey(day) == dayKey(_day);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color: selected
                          ? KnotesTheme.accent
                          : KnotesTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          KnotesTheme.radiusSm,
                        ),
                        onTap: future ? null : () => _selectDay(day),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('EE', 'es').format(day),
                                style: TextStyle(
                                  color: selected
                                      ? KnotesTheme.onAccent
                                      : KnotesTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: selected
                                      ? KnotesTheme.onAccent
                                      : future
                                      ? KnotesTheme.textSecondary.withValues(
                                          alpha: .45,
                                        )
                                      : KnotesTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ],
  );

  Widget _buildCompactNoteCard(PersonalNote note) {
    final noteColor = note.colorValue != 0
        ? Color(note.colorValue)
        : KnotesTheme.accent;
    final bgTint = note.colorValue != 0
        ? noteColor.withValues(alpha: 0.08)
        : KnotesTheme.surface;
    final borderTint = note.colorValue != 0
        ? noteColor.withValues(alpha: 0.35)
        : KnotesTheme.border.withValues(alpha: 0.65);

    return Material(
      color: bgTint,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
        side: BorderSide(
          color: borderTint,
          width: note.colorValue != 0 ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
        onTap: () => _editNote(note),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: noteColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      getNoteIcon(note.iconKey),
                      color: noteColor,
                      size: 16,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 18,
                    tooltip: 'Acciones',
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _editNote(note, true);
                      } else {
                        final removed = await model.deleteNote(note);
                        if (!mounted) return;
                        if (!removed) {
                          showFailure(
                            context,
                            model.error ?? 'No se pudo eliminar la nota.',
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      menuItem('edit', Icons.edit_outlined, 'Editar'),
                      menuItem(
                        'delete',
                        Icons.delete_outline_rounded,
                        'Eliminar',
                        danger: true,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: KnotesTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
              if (note.items.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 13,
                      color: noteColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${note.items.where((i) => i.done).length}/${note.items.length} hechas',
                        style: TextStyle(
                          fontSize: 11,
                          color: KnotesTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Text(
                DateFormat('d MMM', 'es').format(note.updatedAt),
                style: TextStyle(
                  fontSize: 10,
                  color: KnotesTheme.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
