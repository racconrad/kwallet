class FrontPendingItem {
  final String id;
  final String category; // 'task', 'habit', 'plan'
  final String title;
  final String subtitle;
  final DateTime? dueDate;
  final String sourceId;
  final int? sourceIndex;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FrontPendingItem({
    required this.id,
    required this.category,
    required this.title,
    this.subtitle = '',
    this.dueDate,
    required this.sourceId,
    this.sourceIndex,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  FrontPendingItem copyWith({
    String? id,
    String? category,
    String? title,
    String? subtitle,
    DateTime? dueDate,
    String? sourceId,
    int? sourceIndex,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FrontPendingItem(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      dueDate: dueDate ?? this.dueDate,
      sourceId: sourceId ?? this.sourceId,
      sourceIndex: sourceIndex ?? this.sourceIndex,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'subtitle': subtitle,
      'due_date': dueDate?.toIso8601String(),
      'source_id': sourceId,
      'source_index': sourceIndex,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FrontPendingItem.fromMap(Map<String, dynamic> map) {
    return FrontPendingItem(
      id: map['id'] as String,
      category: map['category'] as String,
      title: map['title'] as String,
      subtitle: (map['subtitle'] as String?) ?? '',
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'] as String)
          : null,
      sourceId: map['source_id'] as String,
      sourceIndex: map['source_index'] as int?,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
