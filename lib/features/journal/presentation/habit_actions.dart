import 'package:flutter/material.dart';

import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/journal/presentation/journal_sheets.dart';

Future<void> editHabit(BuildContext context, {Habit? habit}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => HabitSheet(initial: habit?.title ?? '', habit: habit),
  );
}
