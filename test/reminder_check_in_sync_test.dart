import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/core/database/database_service.dart';
import 'package:knotes/core/services/credential_store.dart';
import 'package:knotes/core/services/reminder_check_in_sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseService service;
  setUp(() async {
    service = DatabaseService.atPath(
      inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
      credentials: MemoryCredentialStore(),
    );
    await service.database;
  });
  tearDown(() => service.closeAndReset());

  test(
    'Failed notification check-in stays queued and succeeds on retry',
    () async {
      await service.saveHabit('read', 'Read');
      final db = await service.database;
      await db.execute(
        "CREATE TRIGGER reject_checkin BEFORE INSERT ON habit_logs "
        "BEGIN SELECT RAISE(ABORT, 'Temporary write failure'); END",
      );
      final day = DateTime.now();
      final pending = <(String, DateTime)>[('read', day)];
      final sync = ReminderCheckInSync(
        service,
        readPending: () async => [...pending],
        acknowledge: (id, date) async => pending.remove((id, date)),
      );
      await sync.sync();
      expect(pending, hasLength(1));
      expect((await service.getHabits()).single.logFor(day), isNull);

      await db.execute('DROP TRIGGER reject_checkin');
      await sync.sync();
      expect(pending, isEmpty);
      expect((await service.getHabits()).single.logFor(day)?.completed, isTrue);
      expect(await service.getExperience(), 20);
    },
  );

  test(
    'Acknowledgement failure retries without awarding duplicate XP',
    () async {
      await service.saveHabit('read', 'Read');
      final day = DateTime.now();
      final pending = <(String, DateTime)>[('read', day)];
      var failAck = true;
      final sync = ReminderCheckInSync(
        service,
        readPending: () async => [...pending],
        acknowledge: (id, date) async {
          if (failAck) throw StateError('Bridge unavailable');
          pending.remove((id, date));
        },
      );
      await sync.sync();
      expect(pending, hasLength(1));
      expect((await service.getHabits()).single.logFor(day)?.completed, isTrue);
      expect(await service.getExperience(), 20);
      failAck = false;
      await sync.sync();
      expect(pending, isEmpty);
      expect(await service.getExperience(), 20);
    },
  );

  test(
    'Deleted habits are acknowledged without blocking existing ones',
    () async {
      await service.saveHabit('read', 'Read');
      final day = DateTime.now();
      final pending = <(String, DateTime)>[('deleted', day), ('read', day)];
      final sync = ReminderCheckInSync(
        service,
        readPending: () async => [...pending],
        acknowledge: (id, date) async => pending.remove((id, date)),
      );
      await sync.sync();
      expect(pending, isEmpty);
      expect((await service.getHabits()).single.logFor(day)?.completed, isTrue);
    },
  );

  test(
    'An acknowledgement retry preserves saved check-in annotations',
    () async {
      await service.saveHabit('read', 'Read');
      final day = DateTime.now();
      var failAck = true;
      final sync = ReminderCheckInSync(
        service,
        readPending: () async => [('read', day)],
        acknowledge: (_, _) async {
          if (failAck) throw StateError('Bridge unavailable');
        },
      );
      await sync.sync();
      await service.logHabitDays(
        ['read'],
        [day],
        completed: true,
        mood: 'tired',
        reason: 'Finished after a long day',
      );
      failAck = false;
      await sync.sync();
      final log = (await service.getHabits()).single.logFor(day)!;
      expect(log.mood, 'tired');
      expect(log.reason, 'Finished after a long day');
      expect(await service.getExperience(), 20);
    },
  );

  test('Concurrent refreshes share one notification drain', () async {
    await service.saveHabit('read', 'Read');
    final day = DateTime.now();
    final gate = Completer<List<(String, DateTime)>>();
    var reads = 0;
    var acknowledgements = 0;
    final sync = ReminderCheckInSync(
      service,
      readPending: () {
        reads++;
        return gate.future;
      },
      acknowledge: (_, _) async => acknowledgements++,
    );
    final first = sync.sync();
    final second = sync.sync();
    gate.complete([('read', day)]);
    await Future.wait([first, second]);
    expect(reads, 1);
    expect(acknowledgements, 1);
    expect(await service.getExperience(), 20);
  });
}
