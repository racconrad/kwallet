import 'package:flutter/material.dart';

import 'package:knotes/features/journal/models/journal_day.dart';

class HabitLog {
  final String day;
  final bool completed;
  final String mood;
  final String reason;
  const HabitLog({
    required this.day,
    required this.completed,
    this.mood = 'neutral',
    this.reason = '',
  });
  factory HabitLog.fromMap(Map<String, Object?> map) => HabitLog(
    day: map['day'] as String,
    completed: map['completed'] == 1,
    mood: (map['mood'] as String?) ?? 'neutral',
    reason: (map['reason'] as String?) ?? '',
  );
}

class HabitPalette {
  final String category;
  final List<(String, String)> icons;
  final List<(int, String)> colors;

  const HabitPalette({
    required this.category,
    required this.icons,
    required this.colors,
  });
}

const habitPalettes = [
  HabitPalette(
    category: 'Salud y Naturaleza',
    icons: [
      ('spa_rounded', 'Salud'),
      ('directions_run_rounded', 'Ejercicio'),
      ('fitness_center_rounded', 'Gimnasio'),
      ('self_improvement_rounded', 'Meditación'),
      ('water_drop_rounded', 'Agua'),
      ('bedtime_rounded', 'Descanso'),
    ],
    colors: [
      (0xFF466539, 'Bosque profundo'),
      (0xFF5F854F, 'Verde oliva'),
      (0xFF7EA86C, 'Salvia viva'),
      (0xFFB2D39C, 'Brote claro'),
    ],
  ),
  HabitPalette(
    category: 'Productividad y Mente',
    icons: [
      ('book_rounded', 'Lectura'),
      ('laptop_chromebook_rounded', 'Trabajo'),
      ('menu_book_rounded', 'Estudio'),
      ('alarm_rounded', 'Puntualidad'),
      ('code_rounded', 'Programar'),
      ('school_rounded', 'Aprendizaje'),
    ],
    colors: [
      (0xFF735085, 'Ciruela intenso'),
      (0xFF8E66A3, 'Mora silvestre'),
      (0xFFA980BE, 'Amatista suave'),
      (0xFFD9B7ED, 'Lila empolvado'),
    ],
  ),
  HabitPalette(
    category: 'Creatividad y Pasión',
    icons: [
      ('palette_rounded', 'Arte'),
      ('music_note_rounded', 'Música'),
      ('camera_alt_rounded', 'Fotografía'),
      ('brush_rounded', 'Dibujo'),
      ('draw_rounded', 'Escritura'),
      ('mic_rounded', 'Canto y Voz'),
    ],
    colors: [
      (0xFFA14665, 'Palo de rosa'),
      (0xFFBD5E7F, 'Terracota cálido'),
      (0xFFD77B9B, 'Rosa arcilla'),
      (0xFFF1B3C7, 'Rosa amanecer'),
    ],
  ),
  HabitPalette(
    category: 'Energía y Finanzas',
    icons: [
      ('local_fire_department_rounded', 'Racha y Energía'),
      ('savings_rounded', 'Ahorro'),
      ('bolt_rounded', 'Vitalidad'),
      ('emoji_events_rounded', 'Logros'),
      ('coffee_rounded', 'Café matutino'),
      ('eco_rounded', 'Naturaleza'),
    ],
    colors: [
      (0xFF806015, 'Miel profunda'),
      (0xFF9E771E, 'Ámbar tostado'),
      (0xFFBE932D, 'Oro cálido'),
      (0xFFE9CB81, 'Mostaza dorada'),
    ],
  ),
  HabitPalette(
    category: 'Equilibrio y Calma',
    icons: [
      ('spa_rounded', 'Armonía'),
      ('check_circle_rounded', 'Constancia'),
      ('favorite_rounded', 'Cuidado'),
      ('psychology_rounded', 'Reflexión'),
      ('wb_sunny_rounded', 'Despertar'),
      ('nights_stay_rounded', 'Rutina noche'),
    ],
    colors: [
      (0xFF3D4B3F, 'Pizarra bosque'),
      (0xFF555E50, 'Musgo neutro'),
      (0xFF758572, 'Salvia terrosa'),
      (0xFF8D9C8F, 'Verde ceniza'),
    ],
  ),
];

IconData getHabitIcon(String? key) {
  return switch (key) {
    'spa_rounded' || 'spa_outlined' => Icons.spa_rounded,
    'directions_run_rounded' => Icons.directions_run_rounded,
    'fitness_center_rounded' => Icons.fitness_center_rounded,
    'self_improvement_rounded' => Icons.self_improvement_rounded,
    'water_drop_rounded' => Icons.water_drop_rounded,
    'bedtime_rounded' => Icons.bedtime_rounded,
    'book_rounded' => Icons.book_rounded,
    'laptop_chromebook_rounded' => Icons.laptop_chromebook_rounded,
    'menu_book_rounded' => Icons.menu_book_rounded,
    'alarm_rounded' => Icons.alarm_rounded,
    'code_rounded' => Icons.code_rounded,
    'school_rounded' => Icons.school_rounded,
    'palette_rounded' => Icons.palette_rounded,
    'music_note_rounded' => Icons.music_note_rounded,
    'camera_alt_rounded' => Icons.camera_alt_rounded,
    'brush_rounded' => Icons.brush_rounded,
    'draw_rounded' => Icons.draw_rounded,
    'mic_rounded' => Icons.mic_rounded,
    'local_fire_department_rounded' => Icons.local_fire_department_rounded,
    'savings_rounded' => Icons.savings_rounded,
    'bolt_rounded' => Icons.bolt_rounded,
    'emoji_events_rounded' => Icons.emoji_events_rounded,
    'coffee_rounded' => Icons.coffee_rounded,
    'eco_rounded' => Icons.eco_rounded,
    _ => Icons.spa_rounded,
  };
}

class Habit {
  final String id;
  final String title;
  final String iconKey;
  final int colorValue;
  final String timeBlock;

  /// Daily reminder as HH:mm, or null when off.
  final String? reminderTime;

  /// ISO weekdays for the reminder ("135" = Mon, Wed, Fri); null is every day.
  final String? reminderDays;
  final List<HabitLog> logs;

  Habit({
    required this.id,
    required this.title,
    this.iconKey = 'spa_rounded',
    this.colorValue = 0xFF4CAF50,
    this.timeBlock = 'anytime',
    this.reminderTime,
    this.reminderDays,
    this.logs = const [],
  });

  bool remindsOn(int weekday) =>
      reminderDays == null || reminderDays!.contains('$weekday');

  // Built once: cards and trackers query many days per frame.
  late final Map<String, HabitLog> _byDay = {
    for (final log in logs) log.day: log,
  };

  IconData get icon => getHabitIcon(iconKey);
  Color get color => Color(colorValue);

  HabitLog? logFor(DateTime date) => _byDay[dayKey(date)];

  bool _done(DateTime day) => _byDay[dayKey(day)]?.completed == true;

  int streak(DateTime date) {
    var cursor = DateTime(date.year, date.month, date.day);
    if (!_done(cursor)) {
      if (logFor(date) != null) return 0;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var count = 0;
    while (_done(cursor)) {
      count++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return count;
  }

  /// Longest run of completed days ever recorded.
  int get bestStreak {
    final days = [
      for (final log in logs)
        if (log.completed) DateTime.tryParse(log.day),
    ].nonNulls.toList()..sort();
    var best = 0, run = 0;
    DateTime? previous;
    for (final day in days) {
      run = previous != null && day.difference(previous).inHours.abs() <= 25
          ? run + 1
          : 1;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }
}

/// A count to reach inside a date window: habit check-ins, finished list
/// tasks, or a free counter the user marks by hand.
