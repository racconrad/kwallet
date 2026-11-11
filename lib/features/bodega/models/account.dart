import 'dart:convert';

class Account {
  final String id;
  final String name;
  final String type; // 'cash', 'bank', 'vault', 'credit'
  final double balance;
  final double minimumBalance;
  final double savingsTarget;
  final double openingBalance;
  final String currency;
  final List<String> currencies;
  final String iconKey;
  final int colorValue;
  final bool isArchived;
  final bool isDeleted;
  final bool excludeFromAvailable;
  final DateTime createdAt;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.minimumBalance = 0,
    this.savingsTarget = 0,
    double? openingBalance,
    this.currency = '\$',
    List<String>? currencies,
    this.iconKey = 'wallet',
    this.colorValue = 0xFF00FF9D,
    this.isArchived = false,
    this.isDeleted = false,
    this.excludeFromAvailable = false,
    required this.createdAt,
  }) : openingBalance = openingBalance ?? balance,
       currencies = (currencies != null && currencies.isNotEmpty)
           ? List.unmodifiable(currencies)
           : List.unmodifiable([currency]);

  Account copyWith({
    String? id,
    String? name,
    String? type,
    double? balance,
    double? minimumBalance,
    double? savingsTarget,
    String? currency,
    List<String>? currencies,
    String? iconKey,
    int? colorValue,
    bool? isArchived,
    bool? isDeleted,
    bool? excludeFromAvailable,
    DateTime? createdAt,
  }) {
    final nextCurrency = currency ?? this.currency;
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      minimumBalance: minimumBalance ?? this.minimumBalance,
      savingsTarget: savingsTarget ?? this.savingsTarget,
      openingBalance: openingBalance,
      currency: nextCurrency,
      currencies:
          currencies ??
          (currency != null && !this.currencies.contains(currency)
              ? [currency, ...this.currencies]
              : this.currencies),
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      excludeFromAvailable: excludeFromAvailable ?? this.excludeFromAvailable,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'minimum_balance': minimumBalance,
      'savings_target': savingsTarget,
      'opening_balance': openingBalance,
      'currency': currency,
      'currencies': jsonEncode(currencies),
      'icon_key': iconKey,
      'color_value': colorValue,
      'is_archived': isArchived ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'exclude_from_available': excludeFromAvailable ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    final baseCurrency = (map['currency'] as String?) ?? '\$';
    List<String> currenciesList = [];
    final rawCurrencies = map['currencies'];
    if (rawCurrencies is String && rawCurrencies.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCurrencies);
        if (decoded is List) {
          currenciesList = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    if (currenciesList.isEmpty) {
      currenciesList = [baseCurrency];
    } else if (!currenciesList.contains(baseCurrency)) {
      currenciesList = [baseCurrency, ...currenciesList];
    }

    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      balance: (map['balance'] as num).toDouble(),
      minimumBalance: (map['minimum_balance'] as num?)?.toDouble() ?? 0,
      savingsTarget: (map['savings_target'] as num?)?.toDouble() ?? 0,
      openingBalance: (map['opening_balance'] as num?)?.toDouble(),
      currency: baseCurrency,
      currencies: currenciesList,
      iconKey: (map['icon_key'] as String?) ?? 'wallet',
      colorValue: (map['color_value'] as int?) ?? 0xFF00FF9D,
      isArchived: (map['is_archived'] as int?) == 1,
      isDeleted: (map['is_deleted'] as int?) == 1,
      excludeFromAvailable: (map['exclude_from_available'] as int?) == 1,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Convierte un monto hacia una moneda objetivo. Por defecto la tasa es 1 a 1 para monedas de la lista.
  double convert(double amount, String targetCurrency, {double rate = 1.0}) {
    if (targetCurrency == currency) return amount;
    return amount * rate;
  }

  String get typeLabel {
    switch (type) {
      case 'cash':
        return 'Efectivo';
      case 'bank':
        return 'Banco';
      case 'vault':
        return 'Ahorro';
      case 'credit':
        return 'Crédito';
      default:
        return 'Bóveda';
    }
  }
}
