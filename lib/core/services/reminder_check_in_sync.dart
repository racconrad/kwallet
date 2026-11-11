import 'package:flutter/foundation.dart';

import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/services/notification_service.dart';

class ReminderCheckInSync {
  final JournalRepository repository;
  final Future<List<(String, DateTime)>> Function() readPending;
  final Future<void> Function(String, DateTime) acknowledge;
  Future<void>? _running;

  ReminderCheckInSync(
    this.repository, {
    this.readPending = NotificationService.pendingDoneFromNotifications,
    this.acknowledge = NotificationService.acknowledgeDoneFromNotification,
  });

  Future<void> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<void> _sync() async {
    final pending = await readPending();
    if (pending.isEmpty) return;
    final habits = {
      for (final habit in await repository.getHabits()) habit.id: habit,
    };
    for (final (id, day) in pending) {
      try {
        final habit = habits[id];
        if (habit != null && habit.logFor(day)?.completed != true) {
          await repository.logHabitDays(
            [id],
            [day],
            completed: true,
            mood: 'happy',
          );
        }
        // Missing habits cannot be applied; all other events require a commit.
        await acknowledge(id, day);
      } catch (error) {
        debugPrint('Reminder check-in retained for retry: $error');
      }
    }
  }
}
