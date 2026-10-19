/// Rates express units of the dominant currency per unit of the quoted currency.
class CurrencyConversion {
  static String code(String value) {
    final key = value.trim();
    final upper = key.toUpperCase();
    return const {'\$': 'USD', 'C\$': 'NIO', '€': 'EUR', '£': 'GBP'}[upper] ??
        (RegExp(r'^[a-zA-Z]{3}$').hasMatch(key) ? upper : key);
  }

  static String symbol(String value) =>
      const {
        'USD': '\$',
        'NIO': 'C\$',
        'EUR': '€',
        'GBP': '£',
        'JPY': '¥',
        'CNY': '¥',
        'MXN': 'MX\$',
        'CAD': 'CA\$',
        'CRC': '₡',
        'HNL': 'L',
        'GTQ': 'Q',
        'BRL': 'R\$',
        'BTC': '₿',
      }[code(value)] ??
      value.trim();

  static String label(String value, [Map<String, String>? names]) {
    final canonical = code(value);
    final customName = names?.entries
        .where((e) => code(e.key) == canonical && e.value.trim().isNotEmpty)
        .firstOrNull
        ?.value
        .trim();
    final name =
        customName ??
        const {
          'USD': 'Dólar estadounidense',
          'NIO': 'Córdoba',
          'EUR': 'Euro',
          'GBP': 'Libra esterlina',
          'JPY': 'Yen',
          'CNY': 'Yuan',
          'MXN': 'Peso mexicano',
          'CAD': 'Dólar canadiense',
          'CRC': 'Colón',
          'HNL': 'Lempira',
          'GTQ': 'Quetzal',
          'BRL': 'Real',
          'BTC': 'Bitcoin',
        }[canonical];
    return name == null || name.isEmpty
        ? symbol(value)
        : '${symbol(value)} $name';
  }

  static double convert(
    double amount, {
    required String from,
    required String to,
    required Map<String, double> rates,
    required String dominantCurrency,
  }) {
    if (!amount.isFinite) throw ArgumentError('Monto inválido');
    final origin = code(from),
        destination = code(to),
        base = code(dominantCurrency);
    if (origin.toUpperCase() == destination.toUpperCase() || amount == 0) {
      return amount;
    }
    double rate(String currency) {
      if (currency.toUpperCase() == base.toUpperCase()) return 1;
      final value = rates.entries
          .where((e) => code(e.key).toUpperCase() == currency.toUpperCase())
          .firstOrNull
          ?.value;
      if (value == null || !value.isFinite || value <= 0) {
        throw StateError('Configura la tasa de $currency en Ajustes');
      }
      return value;
    }

    final result = amount * rate(origin) / rate(destination);
    if (!result.isFinite) throw ArgumentError('Conversión fuera de rango');
    return result;
  }
}
