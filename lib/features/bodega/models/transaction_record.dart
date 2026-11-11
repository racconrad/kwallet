class TransactionRecord {
  final String? currency;
  final String? toCurrency;
  final double? toAmount;
  final double? exchangeRate;
  final String id;
  final String accountId;
  final String? toAccountId;
  final String categoryId;
  final double amount;
  final String type; // 'expense', 'income', 'transfer'
  final String note;
  final DateTime date;
  final String? storedDate;
  final DateTime createdAt;

  TransactionRecord({
    this.currency,
    this.toCurrency,
    this.toAmount,
    this.exchangeRate,
    required this.id,
    required this.accountId,
    this.toAccountId,
    required this.categoryId,
    required this.amount,
    required this.type,
    this.note = '',
    required this.date,
    this.storedDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'currency': currency,
      'to_currency': toCurrency,
      'to_amount': toAmount,
      'exchange_rate': exchangeRate,
      'id': id,
      'account_id': accountId,
      'to_account_id': toAccountId,
      'category_id': categoryId,
      'amount': amount,
      'type': type,
      'note': note,
      'date': storedDate ?? date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      currency: map['currency'] as String?,
      toCurrency: map['to_currency'] as String?,
      toAmount: (map['to_amount'] as num?)?.toDouble(),
      exchangeRate: (map['exchange_rate'] as num?)?.toDouble(),
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      toAccountId: map['to_account_id'] as String?,
      categoryId: map['category_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      note: (map['note'] as String?) ?? '',
      storedDate: map['date'] as String?,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  bool get isAdjustment => type == 'adjustment_in' || type == 'adjustment_out';
  bool get isPositive => isIncome || type == 'adjustment_in';
  bool get isNegative => isExpense || type == 'adjustment_out';

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isTransfer => type == 'transfer';
}
