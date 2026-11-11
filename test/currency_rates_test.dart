import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:knotes/core/database/database_backup.dart';
import 'package:knotes/core/database/database_schema.dart';
import 'package:knotes/core/database/repositories/currency_rates_repository.dart';
import 'package:knotes/core/services/notification_service.dart';
import 'package:knotes/features/bodega/models/planned_expense.dart';
import 'package:knotes/features/journal/models/journal_models.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
    }
  });

  group('CurrencyRatesRepository Conversion Logic', () {
    const dominant = 'C\$';
    final rates = <String, double>{'USD': 36.80, 'EUR': 40.00};

    test('Same currency returns exact amount', () {
      final res = CurrencyRatesRepository.convert(
        100.0,
        from: 'USD',
        to: 'USD',
        rates: rates,
        dominantCurrency: dominant,
      );
      expect(res, 100.0);
    });

    test('Converts from alternative currency to dominant currency', () {
      final res = CurrencyRatesRepository.convert(
        100.0,
        from: 'USD',
        to: dominant,
        rates: rates,
        dominantCurrency: dominant,
      );
      expect(res, closeTo(3680.0, 0.001));
    });

    test('Converts from dominant currency to alternative currency', () {
      final res = CurrencyRatesRepository.convert(
        3680.0,
        from: dominant,
        to: 'USD',
        rates: rates,
        dominantCurrency: dominant,
      );
      expect(res, closeTo(100.0, 0.001));
    });

    test(
      'Converts between two alternative currencies through dominant currency',
      () {
        // 100 EUR = 4000 C$ = 4000 / 36.80 USD = 108.6956 USD
        final res = CurrencyRatesRepository.convert(
          100.0,
          from: 'EUR',
          to: 'USD',
          rates: rates,
          dominantCurrency: dominant,
        );
        expect(res, closeTo(108.6956, 0.01));
      },
    );
  });

  group('CurrencyRatesRepository Database and Traceability', () {
    late Database db;
    late CurrencyRatesRepository repo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseSchema.create(db, DatabaseBackup.version);
      repo = CurrencyRatesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('setRate inserts and records initial history entry', () async {
      await repo.setRate(currency: 'USD', rate: 36.80, notes: 'Initial rate');
      final rates = await repo.getRates();
      expect(rates['USD'], 36.80);

      final history = await repo.getHistory(currency: 'USD');
      expect(history.length, 1);
      expect(history.first['previous_rate'], isNull);
      expect(history.first['new_rate'], 36.80);
      expect(history.first['notes'], 'Initial rate');
    });

    test('setRate records update traceability with previous rate', () async {
      await repo.setRate(currency: 'USD', rate: 36.50, notes: 'Day 1');
      await repo.setRate(currency: 'USD', rate: 36.80, notes: 'Day 2 update');

      final rates = await repo.getRates();
      expect(rates['USD'], 36.80);

      final history = await repo.getHistory(currency: 'USD');
      expect(history.length, 2);
      expect(history.first['previous_rate'], 36.50);
      expect(history.first['new_rate'], 36.80);
      expect(history.first['notes'], 'Day 2 update');
    });

    test('removeRate deletes rate from current rates', () async {
      await repo.setRate(currency: 'EUR', rate: 40.0);
      expect((await repo.getRates()).containsKey('EUR'), isTrue);

      await repo.removeRate('EUR');
      expect((await repo.getRates()).containsKey('EUR'), isFalse);
    });
  });

  group('NotificationService Permissions & Settings Checks', () {
    test(
      'showNotification returns false when notifications_enabled is false',
      () async {
        final res = await NotificationService.showNotification(
          id: 1,
          title: 'Test',
          body: 'Body',
          type: 'habits',
          settings: {'notifications_enabled': 'false'},
        );
        expect(res, isFalse);
      },
    );

    test('showNotification returns false when category is disabled', () async {
      final resHabits = await NotificationService.showNotification(
        id: 1,
        title: 'Test',
        body: 'Body',
        type: 'habits',
        settings: {'notifications_enabled': 'true', 'notify_habits': 'false'},
      );
      expect(resHabits, isFalse);

      final resFinances = await NotificationService.showNotification(
        id: 2,
        title: 'Test',
        body: 'Body',
        type: 'finances',
        settings: {'notifications_enabled': 'true', 'notify_finances': 'false'},
      );
      expect(resFinances, isFalse);

      final resPet = await NotificationService.showPetVisualNotification(
        petName: 'Mishi',
        visualIcon: '[♥]',
        settings: {'notifications_enabled': 'true', 'notify_pet': 'false'},
      );
      expect(resPet, isFalse);

      final resDayStart = await NotificationService.showDayStartNotification(
        petName: 'Mishi',
        settings: {
          'notifications_enabled': 'true',
          'notify_day_start': 'false',
        },
      );
      expect(resDayStart, isFalse);

      final resDayEnd = await NotificationService.showDayEndNotification(
        petName: 'Mishi',
        settings: {'notifications_enabled': 'true', 'notify_day_end': 'false'},
      );
      expect(resDayEnd, isFalse);
    });

    test(
      'buildReminders schedules custom day, habit, goal and payment reminders',
      () {
        final today = DateTime(2026, 10, 18, 9);
        final settings = {
          'notifications_enabled': 'true',
          'pet_name': 'Mishi',
          'day_start_message': 'Hola desde {pet}',
          'notify_day_end': 'false',
          'plan_reminder_days': '3',
        };
        final habits = [
          Habit(
            id: 'walk',
            title: 'Caminar',
            reminderTime: '07:30',
            reminderDays: '135',
            logs: const [
              HabitLog(day: '2026-10-18', completed: true),
              HabitLog(day: '2026-10-17', completed: true),
            ],
          ),
          Habit(id: 'read', title: 'Leer'),
        ];
        Goal goal(String id, int progress) => Goal(
          id: id,
          title: id,
          kind: 'tasks',
          target: 10,
          progress: progress,
          startDay: DateTime(2026, 10, 12),
          endDay: DateTime(2026, 10, 20),
          reminderTime: '19:00',
          createdAt: today,
        );
        PlannedExpense plan(String id, DateTime due) => PlannedExpense(
          id: id,
          title: id,
          amount: 12,
          dueDate: due,
          categoryId: 'c',
          createdAt: today,
        );
        final list = NotificationService.buildReminders(
          settings: settings,
          habits: habits,
          goals: [goal('behind', 3), goal('on-pace', 8)],
          plans: [
            plan('luz', DateTime(2026, 10, 25)),
            plan('agua', DateTime(2026, 10, 19)),
            plan('vieja', DateTime(2026, 10, 1)),
          ],
          now: today,
        );
        expect(list.map((r) => r.time), [
          '08:00',
          '07:30',
          '19:00',
          '19:00',
          '08:00',
          '08:00',
        ]);
        expect(list.first.body, 'Hola desde Mishi');
        final walk = list[1];
        expect(
          (walk.skipToday, walk.days, walk.habitId),
          (true, '135', 'walk'),
        );
        expect(walk.body, contains('Racha de 2 días'));
        // 7 of 9 days elapsed: 8 is on pace (no reminder today), 3 is behind.
        expect(
          list[2].body,
          '3 de 10 · te faltan 5 para ir al día · quedan 3 días',
        );
        expect((list[2].skipToday, list[3].skipToday), (false, true));
        expect(list[4].date, '2026-10-22');
        expect(list[4].body, startsWith('En 3 días vence'));
        // Due tomorrow with a 3-day lead: ring today instead of in the past.
        expect(
          (list[5].date, list[5].body.split(' ·').first),
          ('2026-10-18', 'Mañana vence'),
        );
        expect(
          NotificationService.buildReminders(
            settings: {...settings, 'notifications_enabled': 'false'},
            habits: habits,
            goals: const [],
            now: today,
          ),
          isEmpty,
        );
      },
    );
  });
}
