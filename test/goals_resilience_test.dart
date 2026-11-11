import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/core/database/database_backup.dart';
import 'package:knotes/core/database/database_service.dart';
import 'package:knotes/core/services/credential_store.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseService service;
  late Database db;
  setUp(() async {
    service = DatabaseService.atPath(
      inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
      credentials: MemoryCredentialStore(),
    );
    db = await service.database;
  });
  tearDown(() async => db.close());

  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day - 6);
  final end = DateTime(today.year, today.month, today.day + 1);
  Goal goal(String id, String kind, {String? habitId, int target = 3}) => Goal(
    id: id,
    title: id,
    kind: kind,
    habitId: habitId,
    target: target,
    startDay: start,
    endDay: end,
    createdAt: today,
  );

  test(
    'Goals count habit check-ins, finished tasks and manual marks',
    () async {
      await service.saveHabit('walk', 'Caminar', reminderTime: '07:30');
      await service.saveHabit('read', 'Leer');
      await service.logHabitDays(
        ['walk', 'read'],
        [today, today.subtract(const Duration(days: 1))],
        completed: true,
      );
      // Outside the window: must not count.
      await service.logHabitDays(
        ['walk'],
        [today.subtract(const Duration(days: 30))],
        completed: true,
      );
      await service.saveNote(
        PersonalNote(
          id: 'n',
          title: 'Lista',
          kind: 'list',
          items: const [
            NoteItem('a', id: 'a'),
            NoteItem('b', id: 'b'),
          ],
          updatedAt: today,
        ),
      );
      await service.setNoteItem('n', 0, true, expectedText: 'a');

      await service.saveGoal(goal('any', 'habits'));
      await service.saveGoal(goal('walk', 'habits', habitId: 'walk'));
      await service.saveGoal(goal('tasks', 'tasks'));
      await service.saveGoal(goal('free', 'manual', target: 2));
      await service.markGoal('free');
      await service.markGoal('free');

      final goals = {for (final g in await service.getGoals()) g.id: g};
      expect(goals['any']!.progress, 4);
      expect(goals['walk']!.progress, 2);
      expect(goals['tasks']!.progress, 1);
      expect(goals['free']!.reached, isTrue);
      await expectLater(service.markGoal('any'), throwsStateError);
      expect((await service.getHabits()).first.reminderTime, '07:30');
      await service.saveHabit(
        'read',
        'Leer',
        reminderTime: '21:00',
        reminderDays: '531',
      );
      final read = (await service.getHabits()).firstWhere(
        (h) => h.id == 'read',
      );
      expect(
        (read.reminderDays, read.remindsOn(3), read.remindsOn(2)),
        ('135', true, false),
      );
      await expectLater(
        service.saveHabit(
          'read',
          'Leer',
          reminderTime: '21:00',
          reminderDays: '',
        ),
        throwsArgumentError,
      );

      // Deleting a habit removes the goals tied to it.
      await service.deleteHabit('walk');
      expect(
        (await service.getGoals()).map((g) => g.id),
        isNot(contains('walk')),
      );
    },
  );

  test('One damaged row does not hide the rest of notes and habits', () async {
    await service.saveHabit('ok', 'Bien');
    await db.insert('personal_notes', {
      'id': 'broken',
      'title': 'Rota',
      'items': '{not json',
      'kind': 'weird',
      'updated_at': 'yesterday-ish',
    });
    await service.saveNote(
      PersonalNote(id: 'fine', title: 'Bien', updatedAt: today),
    );
    await db.insert('habit_logs', {
      'id': 'bad',
      'habit_id': 'ok',
      'day': 'not-a-day',
      'completed': 1,
    });
    final notes = await service.getNotes();
    expect(notes.map((n) => n.id), containsAll(['broken', 'fine']));
    final broken = notes.firstWhere((n) => n.id == 'broken');
    expect(broken.items, isEmpty);
    expect(broken.kind, 'note');
    expect((await service.getHabits()).single.logs, isEmpty);
  });

  test('Streaks use an indexed lookup and track the best run', () {
    final habit = Habit(
      id: 'h',
      title: 'h',
      logs: const [
        HabitLog(day: '2026-10-18', completed: true),
        HabitLog(day: '2026-10-17', completed: true),
        HabitLog(day: '2026-10-15', completed: true),
        HabitLog(day: '2026-10-14', completed: true),
        HabitLog(day: '2026-10-13', completed: true),
      ],
    );
    expect(habit.streak(DateTime(2026, 10, 18)), 2);
    expect(habit.streak(DateTime(2026, 10, 19)), 2);
    expect(habit.streak(DateTime(2026, 10, 20)), 0);
    expect(habit.bestStreak, 3);
  });

  test(
    'Daily snapshot writes once per day, keeps a week and restores newest',
    () async {
      final dir = await Directory.systemTemp.createTemp('knotes-daily-');
      addTearDown(() => dir.delete(recursive: true));
      final disk = DatabaseService.atPath(
        '${dir.path}/knotes.db',
        factory: databaseFactoryFfiNoIsolate,
        credentials: MemoryCredentialStore(),
      );
      final opened = await disk.database;
      addTearDown(opened.close);
      await disk.saveHabit('h', 'Primero');
      for (var i = 0; i < 9; i++) {
        expect(
          await disk.ensureDailySnapshot(
            now: DateTime.now().add(Duration(days: i + 1)),
          ),
          isTrue,
        );
        // Distinct timestamps in the file names.
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(await disk.ensureDailySnapshot(now: DateTime.now()), isFalse);
      final daily = (await disk.getRecoveryCopies()).where((c) => c.automatic);
      expect(daily, hasLength(7));

      // An older "before-v" copy must not win over the newest one.
      await DatabaseBackup.writeRecovery(
        opened.path,
        await disk.exportFullDataAsJson(),
        'before-v1',
      );
      await disk.saveHabit('h2', 'Después');
      await disk.ensureDailySnapshot(
        now: DateTime.now().add(const Duration(days: 30)),
      );
      expect(await disk.restoreLatestRecoveryCopy(), isTrue);
      expect(
        (await disk.getHabits()).map((h) => h.id),
        containsAll(['h', 'h2']),
      );
    },
  );

  test('Backups carry goals and v8 backups still import', () async {
    await service.saveHabit('h', 'Caminar');
    await service.saveGoal(goal('g', 'habits', habitId: 'h'));
    final json = await service.exportFullDataAsJson();
    await service.importFullDataFromJson(json);
    expect((await service.getGoals()).single.habitId, 'h');

    // A v8 export has no goals table at all.
    await db.execute('DROP TABLE goals');
    final v8 = await db.transaction((txn) => DatabaseBackup.encode(txn, 8));
    expect(DatabaseBackup.decode(v8)['goals'], isEmpty);
  });

  test('Quick capture turns dash lines into tasks and keeps the rest', () {
    var n = 0;
    final note = parseQuickNote(
      '  Compras\n- pan\nrecordar el cupón\n[ ] leche\n',
      id: 'q',
      newItemId: () => 'i${n++}',
    )!;
    expect(note.title, 'Compras');
    expect(note.kind, 'list');
    expect(note.items.map((i) => (i.id, i.text)), [
      ('i0', 'pan'),
      ('i1', 'leche'),
    ]);
    expect(note.body, 'recordar el cupón');
    expect(parseQuickNote(' \n ', id: 'x', newItemId: () => ''), isNull);
    expect(
      parseQuickNote('Solo idea', id: 'y', newItemId: () => '')!.kind,
      'note',
    );
  });
}
