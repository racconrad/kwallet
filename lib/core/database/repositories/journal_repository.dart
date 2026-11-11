import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:knotes/features/bodega/models/planned_expense.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:knotes/features/bodega/models/finance_overview.dart';
import 'package:knotes/features/bodega/models/front_pending_item.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/core/database/reward_events.dart';
import 'package:knotes/core/database/database_context.dart';

mixin JournalRepository on DatabaseContext {
  Future<int> getExperience() async {
    final db = await database;
    return ((await db.rawQuery(
              'SELECT SUM(points) AS total FROM reward_events',
            )).first['total']
            as int?) ??
        0;
  }

  Future<bool> awardAffection(int points) async {
    if (points <= 0) return false;
    final db = await database;
    final now = DateTime.now();
    final dayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final key = 'affection_daily:$dayStr';
    final existing = await db.query(
      'reward_events',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return false;
    }
    await RewardEvents.award(db, key, points);
    notifyChanged();
    return true;
  }

  Future<List<PersonalNote>> getNotes() async {
    final db = await database;
    final notes = <PersonalNote>[];
    for (final row in await db.query(
      'personal_notes',
      orderBy: 'updated_at DESC',
    )) {
      try {
        notes.add(PersonalNote.fromMap(row));
      } catch (e) {
        // Keep the rest readable; the row stays in the DB and in backups.
        debugPrint('Skipped unreadable note ${row['id']}: $e');
      }
    }
    return notes;
  }

  Future<void> saveNote(PersonalNote note) async {
    if (note.title.trim().isEmpty) throw ArgumentError('Escribe un título');
    final db = await database;
    await db.transaction((txn) async {
      final previous = await txn.query(
        'personal_notes',
        where: 'id = ?',
        whereArgs: [note.id],
      );
      final unmatched = previous.isEmpty
          ? <NoteItem>[]
          : [...PersonalNote.fromMap(previous.single).items];
      final usedIds = <String>{};
      final items = note.items.map((item) {
        final match = unmatched
            .where(
              (old) =>
                  item.id != null ? old.id == item.id : old.text == item.text,
            )
            .firstOrNull;
        if (match != null) unmatched.remove(match);
        final id = item.id ?? match?.id ?? const Uuid().v4();
        if (!usedIds.add(id)) {
          throw ArgumentError('Elemento de lista duplicado');
        }
        return NoteItem(
          item.text,
          id: id,
          done: item.done,
          dueDate: item.dueDate,
        );
      }).toList();
      await txn.insert('personal_notes', {
        ...note.toMap(),
        'items': jsonEncode(items.map((i) => i.toMap()).toList()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _awardNoteItems(txn, note.id, items);
    });
    notifyChanged();
  }

  Future<void> setNoteItem(
    String noteId,
    int index,
    bool done, {
    required String expectedText,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'personal_notes',
        where: 'id = ?',
        whereArgs: [noteId],
      );
      if (rows.isEmpty) throw StateError('Esta lista ya no existe');
      final note = PersonalNote.fromMap(rows.single);
      if (index < 0 ||
          index >= note.items.length ||
          note.items[index].text != expectedText) {
        throw StateError('La lista cambió. Vuelve a abrirla');
      }
      final items = [...note.items];
      items[index] = NoteItem(
        items[index].text,
        id: items[index].id,
        done: done,
        dueDate: items[index].dueDate,
      );
      final updated = PersonalNote(
        id: note.id,
        title: note.title,
        body: note.body,
        kind: note.kind,
        items: items,
        iconKey: note.iconKey,
        colorValue: note.colorValue,
        updatedAt: DateTime.now(),
      );
      await txn.update(
        'personal_notes',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [noteId],
      );
      await _awardNoteItems(txn, noteId, items);
    });
    notifyChanged();
  }

  Future<void> _awardNoteItems(
    DatabaseExecutor db,
    String noteId,
    List<NoteItem> items,
  ) async {
    for (final item in items.where((item) => item.done)) {
      await RewardEvents.award(db, 'note_item:$noteId:${item.id}', 5);
    }
    if (items.isNotEmpty && items.every((item) => item.done)) {
      await RewardEvents.award(db, 'note:$noteId', 20);
    }
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete('personal_notes', where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }

  Future<List<Habit>> getHabits() async {
    final db = await database;
    final habits = await db.query('habits', orderBy: 'created_at ASC');
    // Only the columns the UI reads; one pass groups them per habit.
    final logs = await db.query(
      'habit_logs',
      columns: ['habit_id', 'day', 'completed', 'mood', 'reason'],
      orderBy: 'day DESC',
    );
    final byHabit = <String, List<HabitLog>>{};
    for (final log in logs) {
      final habitId = log['habit_id'];
      final day = log['day'];
      if (habitId is! String ||
          day is! String ||
          DateTime.tryParse(day) == null) {
        continue;
      }
      (byHabit[habitId] ??= []).add(HabitLog.fromMap(log));
    }
    return [
      for (final habit in habits)
        if (habit['id'] is String)
          Habit(
            id: habit['id'] as String,
            title: habit['title']?.toString() ?? '',
            iconKey: (habit['icon_key'] as String?) ?? 'spa_rounded',
            colorValue: (habit['color_value'] as int?) ?? 0xFF4CAF50,
            timeBlock: (habit['time_block'] as String?) ?? 'anytime',
            reminderTime: _validTime(habit['reminder_time']),
            reminderDays: _validDays(habit['reminder_days']),
            logs: byHabit[habit['id']] ?? const [],
          ),
    ];
  }

  static String? _validTime(Object? value) =>
      value is String && RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)
      ? value
      : null;

  static String? _validDays(Object? value) =>
      value is String && RegExp(r'^[1-7]{1,7}$').hasMatch(value)
      ? (value.split('').toSet().toList()..sort()).join()
      : null;

  Future<List<Goal>> getGoals() async {
    final db = await database;
    final goals = <Goal>[];
    for (final row in await db.query('goals', orderBy: 'end_day ASC')) {
      try {
        final goal = Goal.fromMap(row);
        goals.add(goal.copyWith(progress: await _goalProgress(db, goal)));
      } catch (e) {
        debugPrint('Skipped unreadable goal ${row['id']}: $e');
      }
    }
    return goals;
  }

  Future<int> _goalProgress(DatabaseExecutor db, Goal goal) async {
    final start = dayKey(goal.startDay);
    final end = dayKey(goal.endDay);
    final after = dayKey(goal.endDay.add(const Duration(days: 1)));
    final rows = switch (goal.kind) {
      'habits' => await db.rawQuery(
        'SELECT COUNT(*) AS n FROM habit_logs WHERE completed = 1 AND day >= ? AND day <= ?'
        '${goal.habitId == null ? '' : ' AND habit_id = ?'}',
        [start, end, ?goal.habitId],
      ),
      'tasks' => await db.rawQuery(
        "SELECT COUNT(*) AS n FROM reward_events WHERE id LIKE 'note_item:%' AND created_at >= ? AND created_at < ?",
        [start, after],
      ),
      _ => null,
    };
    return rows == null ? goal.progress : (rows.first['n'] as int? ?? 0);
  }

  Future<void> saveGoal(Goal goal) async {
    if (goal.title.trim().isEmpty) throw ArgumentError('Escribe una meta');
    if (goal.target <= 0) {
      throw ArgumentError('La meta debe ser mayor que cero');
    }
    if (goal.endDay.isBefore(goal.startDay)) {
      throw ArgumentError('La fecha final va después del inicio');
    }
    if (goal.reminderTime != null && _validTime(goal.reminderTime) == null) {
      throw ArgumentError('Hora de recordatorio inválida');
    }
    final db = await database;
    await db.insert(
      'goals',
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  /// Manual goals only: the other kinds are counted from real activity.
  Future<void> markGoal(String id, {int delta = 1}) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('goals', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw StateError('Esta meta ya no existe');
      final goal = Goal.fromMap(rows.single);
      if (goal.kind != 'manual') throw StateError('Esta meta se cuenta sola');
      final progress = (goal.progress + delta).clamp(0, 1 << 30);
      await txn.update(
        'goals',
        {'progress': progress},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (goal.progress < goal.target && progress >= goal.target) {
        await RewardEvents.award(txn, 'goal:$id', 30);
      }
    });
    notifyChanged();
  }

  Future<void> deleteGoal(String id) async {
    final db = await database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }

  Future<void> saveHabit(
    String id,
    String title, {
    String iconKey = 'spa_rounded',
    int colorValue = 0xFF4CAF50,
    String timeBlock = 'anytime',
    String? reminderTime,
    String? reminderDays,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Escribe un hábito');
    if (reminderDays != null && _validDays(reminderDays) == null) {
      throw ArgumentError('Elige al menos un día para el recordatorio');
    }
    if (reminderTime != null && _validTime(reminderTime) == null) {
      throw ArgumentError('Hora de recordatorio inválida');
    }
    final db = await database;
    final changed = await db.update(
      'habits',
      {
        'title': title.trim(),
        'icon_key': iconKey,
        'color_value': colorValue,
        'time_block': timeBlock,
        'reminder_time': reminderTime,
        'reminder_days': reminderDays == null ? null : _validDays(reminderDays),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed == 0) {
      await db.insert('habits', {
        'id': id,
        'title': title.trim(),
        'icon_key': iconKey,
        'color_value': colorValue,
        'time_block': timeBlock,
        'reminder_time': reminderTime,
        'reminder_days': reminderDays == null ? null : _validDays(reminderDays),
        'created_at': DateTime.now().toIso8601String(),
      });
      await RewardEvents.award(db, 'habit_created:$id', 10);
    }
    notifyChanged();
  }

  Future<void> deleteHabit(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('habit_logs', where: 'habit_id = ?', whereArgs: [id]);
      await txn.delete('habits', where: 'id = ?', whereArgs: [id]);
    });
    notifyChanged();
  }

  Future<void> logHabit(
    String habitId,
    DateTime date, {
    required bool completed,
    String mood = 'neutral',
    String reason = '',
  }) => logHabitDays(
    [habitId],
    [date],
    completed: completed,
    mood: mood,
    reason: reason,
  );

  Future<void> logHabitDays(
    Iterable<String> habitIds,
    Iterable<DateTime> dates, {
    required bool completed,
    String mood = 'neutral',
    String reason = '',
  }) async {
    if (!['happy', 'neutral', 'tired', 'sad', 'stressed'].contains(mood)) {
      throw ArgumentError('Ánimo inválido');
    }
    final today = dateOnly(DateTime.now());
    final ids = habitIds.toSet();
    final days = dates.map(dateOnly).toSet();
    if (ids.isEmpty || days.isEmpty) {
      throw ArgumentError('Elige al menos un hábito y un día');
    }
    if (days.any((day) => day.isAfter(today))) {
      throw ArgumentError('No se puede marcar un día futuro');
    }
    final db = await database;
    await db.transaction((txn) async {
      for (final id in ids) {
        if ((await txn.query(
          'habits',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
        )).isEmpty) {
          throw StateError('Este hábito ya no existe');
        }
        for (final date in days) {
          final day = dayKey(date);
          await txn.insert('habit_logs', {
            'id': '$id:$day',
            'habit_id': id,
            'day': day,
            'completed': completed ? 1 : 0,
            'mood': mood,
            'reason': reason.trim(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          if (completed) await RewardEvents.award(txn, 'habit:$id:$day', 10);
        }
      }
    });
    notifyChanged();
  }

  Future<void> syncFrontPendingItems(List<FrontPendingItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('front_pending_items');
      for (final item in items) {
        await txn.insert(
          'front_pending_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<FrontPendingItem>> getFrontPendingItems({
    bool onlyPending = true,
  }) async {
    // Derived from authoritative sources on every request; no stale persisted cache.
    final now = DateTime.now();
    final notes = await getNotes();
    final habits = await getHabits();
    final db = await database;
    final plans = (await db.query(
      'planned_expenses',
      where: 'is_completed = 0',
    )).map(PlannedExpense.fromMap).toList();

    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final pendingList = <FrontPendingItem>[];
    for (final note in notes) {
      if (note.items.isNotEmpty) {
        for (var i = 0; i < note.items.length; i++) {
          if (!note.items[i].done) {
            pendingList.add(
              FrontPendingItem(
                id: 'task_${note.id}_$i',
                category: 'task',
                title: note.items[i].text,
                subtitle: 'Lista: ${note.title}',
                sourceId: note.id,
                sourceIndex: i,
                isCompleted: false,
                createdAt: note.updatedAt,
                updatedAt: now,
              ),
            );
          }
        }
      }
    }

    for (final habit in habits) {
      final log = habit.logFor(now);
      if (log?.completed != true) {
        pendingList.add(
          FrontPendingItem(
            id: 'habit_${habit.id}_$todayStr',
            category: 'habit',
            title: habit.title,
            subtitle: 'Hábito diario',
            sourceId: habit.id,
            isCompleted: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    final todayStart = DateTime(now.year, now.month, now.day);
    final monthLimit = todayStart.add(const Duration(days: 30));
    for (final plan in plans) {
      if (!plan.dueDate.isBefore(todayStart) &&
          !plan.dueDate.isAfter(monthLimit)) {
        pendingList.add(
          FrontPendingItem(
            id: 'plan_${plan.id}',
            category: 'plan',
            title: plan.title,
            subtitle: plan.recurrenceLabel,
            dueDate: plan.dueDate,
            sourceId: plan.id,
            isCompleted: false,
            createdAt: plan.createdAt,
            updatedAt: now,
          ),
        );
      }
    }

    return pendingList;
  }

  Future<void> markFrontPendingItemDone(String id, bool done) async {
    final db = await database;
    await db.update(
      'front_pending_items',
      {
        'is_completed': done ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyChanged();
  }
}
