import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:knotes/features/journal/models/journal_day.dart';

class NoteItem {
  final String? id;
  final String text;
  final bool done;
  final DateTime? dueDate;
  const NoteItem(this.text, {this.id, this.done = false, this.dueDate});
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'text': text,
    'done': done,
    if (dueDate != null) 'due_date': dayKey(dueDate!),
  };
}

class PersonalNote {
  final String id;
  final String title;
  final String body;
  final String kind;
  final List<NoteItem> items;
  final String iconKey;
  final int colorValue;
  final DateTime updatedAt;
  const PersonalNote({
    required this.id,
    required this.title,
    this.body = '',
    this.kind = 'note',
    this.items = const [],
    this.iconKey = 'note',
    this.colorValue = 0,
    required this.updatedAt,
  });
  Map<String, Object> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'kind': kind,
    'items': jsonEncode(items.map((e) => e.toMap()).toList()),
    'icon_key': iconKey,
    'color_value': colorValue,
    'updated_at': updatedAt.toIso8601String(),
  };

  /// Tolerates damaged rows: bad fields fall back to safe defaults instead of
  /// hiding every note behind one parse error.
  factory PersonalNote.fromMap(Map<String, Object?> map) {
    List<NoteItem> items;
    try {
      final raw = jsonDecode((map['items'] as String?) ?? '[]');
      items = [
        for (final (index, item) in (raw is List ? raw : const []).indexed)
          if (item is Map && item['text'] != null)
            NoteItem(
              item['text'].toString(),
              id: item['id'] is String && (item['id'] as String).isNotEmpty
                  ? item['id'] as String
                  : 'legacy:${map['id']}:$index',
              done: item['done'] == true,
              dueDate: item['due_date'] is String
                  ? DateTime.tryParse(item['due_date'] as String)
                  : null,
            ),
      ];
    } on FormatException {
      items = const [];
    }
    final kind = map['kind'];
    return PersonalNote(
      id: map['id'] as String,
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      kind: kind == 'list' ? 'list' : 'note',
      iconKey: (map['icon_key'] as String?) ?? 'note',
      colorValue: map['color_value'] is int ? map['color_value'] as int : 0,
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      items: items,
    );
  }
}

final _quickItem = RegExp(r'^(?:[-*•]|\[ ?\])\s*');

/// Quick-capture syntax: the first line is the title, lines starting with
/// "-", "*" or "[ ]" become tasks, the rest the body. Null for blank text.
PersonalNote? parseQuickNote(
  String text, {
  required String id,
  required String Function() newItemId,
  DateTime? now,
}) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return null;
  final items = [
    for (final line in lines.skip(1))
      if (_quickItem.hasMatch(line))
        NoteItem(line.replaceFirst(_quickItem, ''), id: newItemId()),
  ];
  return PersonalNote(
    id: id,
    title: lines.first.replaceFirst(_quickItem, ''),
    body: lines.skip(1).where((l) => !_quickItem.hasMatch(l)).join('\n'),
    kind: items.isEmpty ? 'note' : 'list',
    iconKey: items.isEmpty ? 'note' : 'list',
    items: items,
    updatedAt: now ?? DateTime.now(),
  );
}

IconData getNoteIcon(String? key) => switch (key) {
  'list' => Icons.checklist_rounded,
  'idea' => Icons.lightbulb_outline_rounded,
  'work' => Icons.work_outline_rounded,
  'study' => Icons.school_outlined,
  'personal' => Icons.person_outline_rounded,
  'star' => Icons.star_outline_rounded,
  'heart' => Icons.favorite_border_rounded,
  'shopping' => Icons.shopping_cart_outlined,
  'book' => Icons.menu_book_rounded,
  'note' || _ => Icons.edit_note_rounded,
};

const noteIcons = [
  ('note', Icons.edit_note_rounded, 'Nota'),
  ('list', Icons.checklist_rounded, 'Lista'),
  ('idea', Icons.lightbulb_outline_rounded, 'Idea'),
  ('work', Icons.work_outline_rounded, 'Trabajo'),
  ('study', Icons.school_outlined, 'Estudio'),
  ('personal', Icons.person_outline_rounded, 'Personal'),
  ('star', Icons.star_outline_rounded, 'Destacado'),
  ('heart', Icons.favorite_border_rounded, 'Favorito'),
  ('shopping', Icons.shopping_cart_outlined, 'Compras'),
  ('book', Icons.menu_book_rounded, 'Lectura'),
];

const noteColors = [
  (0, 'Predeterminado'),
  (0xFF10B981, 'Verde'),
  (0xFF3B82F6, 'Azul'),
  (0xFF8B5CF6, 'Púrpura'),
  (0xFFEC4899, 'Rosa'),
  (0xFFF59E0B, 'Ámbar'),
  (0xFFEF4444, 'Rojo'),
  (0xFF14B8A6, 'Turquesa'),
  (0xFF6366F1, 'Índigo'),
];
