import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:knotes/features/bodega/models/planned_expense.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/core/theme/knotes_theme.dart';

/// One alarm: daily at [time] (optionally only on ISO [days]), or once on
/// [date]. Habit reminders carry [habitId] so the notification can mark it done.
class Reminder {
  final int id;
  final String time;
  final String title;
  final String body;
  final String channelId;
  final String? route;
  final bool skipToday;
  final String? days;
  final String? date;
  final String? habitId;
  const Reminder({
    required this.id,
    required this.time,
    required this.title,
    required this.body,
    this.channelId = 'knotes_habits',
    this.route,
    this.skipToday = false,
    this.days,
    this.date,
    this.habitId,
  });

  Map<String, Object> toJson() => {
    'id': id,
    'time': time,
    'title': title,
    'body': body,
    'channelId': channelId,
    'route': ?route,
    'skipToday': skipToday,
    'days': ?days,
    'date': ?date,
    'habitId': ?habitId,
  };
}

class NotificationService {
  static const MethodChannel _channel = MethodChannel(
    'com.knotes.app/notifications',
  );

  static bool _isAllowed(String type, Map<String, String>? settings) {
    if (settings == null) return false;
    if (settings['notifications_enabled'] != 'true') return false;

    return switch (type) {
      'habits' => settings['notify_habits'] != 'false',
      'finances' => settings['notify_finances'] != 'false',
      'pet' => settings['notify_pet'] != 'false',
      'day_start' => settings['notify_day_start'] != 'false',
      'day_end' => settings['notify_day_end'] != 'false',
      _ => true,
    };
  }

  static const defaultDayStartMessage =
      'Empieza tu día con tus hábitos y un vistazo a tu dinero.';
  static const defaultDayEndMessage =
      'Registra tus movimientos de hoy y cierra con tranquilidad.';
  static const defaultHabitMessage = '{pet} te recuerda: {habit}';

  // Stable per item so rescheduling replaces instead of duplicating alarms.
  static int _stableId(String prefix, String key) =>
      5000 +
      (('$prefix:$key').codeUnits.fold(
            17,
            (h, c) => (h * 31 + c) & 0x3fffffff,
          ) %
          900000);

  static String _fill(String template, Map<String, String> values) => values
      .entries
      .fold(template, (text, e) => text.replaceAll('{${e.key}}', e.value));

  /// Everything that should ring, given current data. Empty when the user
  /// has notifications off, which cancels all alarms.
  static List<Reminder> buildReminders({
    required Map<String, String> settings,
    required List<Habit> habits,
    required List<Goal> goals,
    List<PlannedExpense> plans = const [],
    Map<String, String> accountCurrencies = const {},
    DateTime? now,
  }) {
    if (settings['notifications_enabled'] != 'true') return const [];
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final pet = (settings['pet_name'] ?? '').trim().isEmpty
        ? 'Tu compañero'
        : settings['pet_name']!.trim();
    String text(String key, String fallback) =>
        (settings[key] ?? '').trim().isEmpty ? fallback : settings[key]!.trim();
    final startTime = settings['day_start_time'] ?? '08:00';
    final reminders = <Reminder>[];
    if (_isAllowed('day_start', settings)) {
      reminders.add(
        Reminder(
          id: 3001,
          time: startTime,
          title: '¡Buen día! $pet te espera',
          body: _fill(text('day_start_message', defaultDayStartMessage), {
            'pet': pet,
          }),
        ),
      );
    }
    if (_isAllowed('day_end', settings)) {
      reminders.add(
        Reminder(
          id: 3002,
          time: settings['day_end_time'] ?? '21:00',
          title: 'Cierre del día',
          body: _fill(text('day_end_message', defaultDayEndMessage), {
            'pet': pet,
          }),
        ),
      );
    }
    if (_isAllowed('habits', settings)) {
      for (final habit in habits.where((h) => h.reminderTime != null)) {
        final streak = habit.streak(today);
        reminders.add(
          Reminder(
            id: _stableId('habit', habit.id),
            time: habit.reminderTime!,
            title: habit.title,
            body:
                _fill(text('habit_reminder_message', defaultHabitMessage), {
                  'pet': pet,
                  'habit': habit.title,
                }) +
                (streak > 1 ? ' · Racha de $streak días' : ''),
            route: 'habits',
            skipToday: habit.logFor(today)?.completed == true,
            days: habit.reminderDays,
            habitId: habit.id,
          ),
        );
      }
      for (final goal in goals.where(
        (g) => g.reminderTime != null && !g.reached && !g.isExpired(today),
      )) {
        final total = goal.endDay.difference(goal.startDay).inDays + 1;
        final elapsed = (today.difference(goal.startDay).inDays + 1).clamp(
          0,
          total,
        );
        // On pace means no nagging today; the reminder speaks up only when behind.
        final expected = (goal.target * elapsed / total).ceil();
        final behind = expected - goal.progress;
        final left = goal.daysLeft(today);
        reminders.add(
          Reminder(
            id: _stableId('goal', goal.id),
            time: goal.reminderTime!,
            title: 'Meta: ${goal.title}',
            body:
                '${goal.progress} de ${goal.target}'
                '${behind > 0 ? ' · te faltan $behind para ir al día' : ''}'
                ' · ${left <= 1 ? 'último día' : 'quedan $left días'}',
            route: 'habits',
            skipToday: behind <= 0,
          ),
        );
      }
    }
    if (_isAllowed('finances', settings)) {
      final lead = int.tryParse(settings['plan_reminder_days'] ?? '') ?? 1;
      final currency = settings['currency'] ?? '\$';
      // shortcut: first 20 upcoming dates only, to stay far below Android's alarm cap.
      for (final plan in plans.where((p) => !p.isCompleted).take(20)) {
        final due = DateTime(
          plan.dueDate.year,
          plan.dueDate.month,
          plan.dueDate.day,
        );
        if (due.isBefore(today)) continue;
        var ring = due.subtract(Duration(days: lead));
        if (ring.isBefore(today)) ring = today;
        final days = due.difference(ring).inDays;
        final when = days == 0
            ? 'Hoy'
            : days == 1
            ? 'Mañana'
            : 'En $days días';
        reminders.add(
          Reminder(
            id: _stableId('plan', '${plan.id}:${dayKey(due)}'),
            time: startTime,
            date: dayKey(ring),
            title: plan.amount == 0 ? plan.title : 'Pago: ${plan.title}',
            body: plan.amount == 0
                ? '$when es la fecha.'
                : '$when vence · ${KnotesTheme.formatCurrency(plan.amount, accountCurrencies[plan.accountId] ?? currency)}',
            channelId: 'knotes_finances',
            route: 'agenda',
          ),
        );
      }
    }
    return reminders;
  }

  static String? _lastScheduled;

  static Future<void> syncReminders({
    required Map<String, String> settings,
    required List<Habit> habits,
    required List<Goal> goals,
    List<PlannedExpense> plans = const [],
    Map<String, String> accountCurrencies = const {},
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final payload = jsonEncode([
      for (final r in buildReminders(
        settings: settings,
        habits: habits,
        goals: goals,
        plans: plans,
        accountCurrencies: accountCurrencies,
      ))
        r.toJson(),
    ]);
    if (payload == _lastScheduled) return;
    try {
      await _channel.invokeMethod<bool>('scheduleReminders', payload);
      _lastScheduled = payload;
    } catch (e) {
      debugPrint('Reminder scheduling failed: $e');
    }
  }

  /// Reading never removes check-ins: persistence must precede acknowledgement.
  static Future<List<(String, DateTime)>> pendingDoneFromNotifications() async {
    if (kIsWeb || !Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<Object?>>(
        'pendingReminderDone',
      );
      return [
        for (final entry in raw ?? const [])
          if (entry is String && entry.contains('|'))
            if (DateTime.tryParse(entry.split('|').last) case final day?)
              (entry.split('|').first, day),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> acknowledgeDoneFromNotification(
    String habitId,
    DateTime day,
  ) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _channel.invokeMethod<void>('acknowledgeReminderDone', {
      'entries': ['$habitId|${dayKey(day)}'],
    });
  }

  static Future<bool> areNotificationsEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return ok ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return ok ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> openUrl(String url) async {
    if (kIsWeb || !Platform.isAndroid) {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        try {
          if (Platform.isLinux) {
            await Process.run('xdg-open', [url]);
            return true;
          } else if (Platform.isMacOS) {
            await Process.run('open', [url]);
            return true;
          } else if (Platform.isWindows) {
            await Process.run('cmd', ['/c', 'start', '', url]);
            return true;
          }
        } catch (_) {}
      }
      return false;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static String _resolveChannel(String type) => switch (type) {
    'finances' => 'knotes_finances',
    'pet' => 'knotes_pet',
    'day_start' || 'day_end' => 'knotes_habits',
    _ => 'knotes_habits',
  };

  static Future<bool> showNotification({
    required int id,
    required String title,
    required String body,
    String type = 'habits',
    Map<String, String>? settings,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    if (!_isAllowed(type, settings)) return false;

    try {
      final ok = await _channel.invokeMethod<bool>('showNotification', {
        'id': id,
        'title': title,
        'body': body,
        'channelId': _resolveChannel(type),
      });
      return ok ?? true;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('Error triggering system notification: $e');
      return false;
    }
  }

  static Future<bool> showPetVisualNotification({
    required String petName,
    required String visualIcon,
    Map<String, String>? settings,
  }) {
    return showNotification(
      id: 2001,
      title: petName,
      body: visualIcon,
      type: 'pet',
      settings: settings,
    );
  }

  static Future<bool> showDayStartNotification({
    required String petName,
    Map<String, String>? settings,
  }) {
    final pet = petName.trim().isEmpty ? 'Tu compañero' : petName.trim();
    return showNotification(
      id: 3001,
      title: '¡Buen día! $pet te espera',
      body: _fill(
        (settings?['day_start_message'] ?? '').trim().isEmpty
            ? defaultDayStartMessage
            : settings!['day_start_message']!.trim(),
        {'pet': pet},
      ),
      type: 'day_start',
      settings: settings,
    );
  }

  static Future<bool> showDayEndNotification({
    required String petName,
    Map<String, String>? settings,
  }) {
    final pet = petName.trim().isEmpty ? 'Tu compañero' : petName.trim();
    return showNotification(
      id: 3002,
      title: 'Cierre del día',
      body: _fill(
        (settings?['day_end_message'] ?? '').trim().isEmpty
            ? defaultDayEndMessage
            : settings!['day_end_message']!.trim(),
        {'pet': pet},
      ),
      type: 'day_end',
      settings: settings,
    );
  }
}
