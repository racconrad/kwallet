import 'package:knotes/features/journal/models/journal_day.dart';

class Goal {
  final String id;
  final String title;
  final String kind;
  final String? habitId;
  final int target;
  final int progress;
  final DateTime startDay;
  final DateTime endDay;
  final String? reminderTime;
  final DateTime createdAt;

  const Goal({
    required this.id,
    required this.title,
    required this.kind,
    this.habitId,
    required this.target,
    this.progress = 0,
    required this.startDay,
    required this.endDay,
    this.reminderTime,
    required this.createdAt,
  });

  bool get reached => progress >= target;
  double get ratio => (progress / target).clamp(0, 1).toDouble();
  bool isExpired(DateTime now) =>
      DateTime(now.year, now.month, now.day).isAfter(endDay);
  int daysLeft(DateTime now) =>
      endDay.difference(DateTime(now.year, now.month, now.day)).inDays + 1;

  Goal copyWith({int? progress}) => Goal(
    id: id,
    title: title,
    kind: kind,
    habitId: habitId,
    target: target,
    progress: progress ?? this.progress,
    startDay: startDay,
    endDay: endDay,
    reminderTime: reminderTime,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'kind': kind,
    'habit_id': habitId,
    'target': target,
    'progress': progress,
    'start_day': dayKey(startDay),
    'end_day': dayKey(endDay),
    'reminder_time': reminderTime,
    'created_at': createdAt.toIso8601String(),
  };

  factory Goal.fromMap(Map<String, Object?> map) => Goal(
    id: map['id'] as String,
    title: map['title'] as String,
    kind: map['kind'] as String,
    habitId: map['habit_id'] as String?,
    target: map['target'] as int,
    progress: (map['progress'] as int?) ?? 0,
    startDay: DateTime.parse(map['start_day'] as String),
    endDay: DateTime.parse(map['end_day'] as String),
    reminderTime: map['reminder_time'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
