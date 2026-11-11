class QuickExpense {
  final String id;
  final String title;
  final double amount;
  final String categoryId;
  final String? accountId;
  final String iconKey;
  final DateTime createdAt;

  const QuickExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    this.accountId,
    this.iconKey = 'bolt',
    required this.createdAt,
  });

  QuickExpense copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    String? accountId,
    String? iconKey,
    DateTime? createdAt,
  }) {
    return QuickExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      iconKey: iconKey ?? this.iconKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category_id': categoryId,
      'account_id': accountId,
      'icon_key': iconKey,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory QuickExpense.fromMap(Map<String, dynamic> map) {
    return QuickExpense(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: (map['category_id'] as String?) ?? 'cat_other',
      accountId: map['account_id'] as String?,
      iconKey: (map['icon_key'] as String?) ?? 'bolt',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
