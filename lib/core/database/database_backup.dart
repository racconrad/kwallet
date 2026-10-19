import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseBackup {
  static const version = 8;
  static const tables = [
    'accounts',
    'categories',
    'transactions',
    'transaction_archive',
    'budget_allocations',
    'budget_allocation_history',
    'planned_expenses',
    'planned_expense_payments',
    'app_settings',
    'personal_notes',
    'habits',
    'habit_logs',
    'reward_events',
    'account_currency_history',
    'global_currency_rates',
    'global_currency_history',
    'front_pending_items',
    'quick_expenses',
    'user_currencies',
  ];
  static const deleteOrder = [
    'user_currencies',
    'quick_expenses',
    'front_pending_items',
    'account_currency_history',
    'global_currency_history',
    'global_currency_rates',
    'planned_expense_payments',
    'budget_allocation_history',
    'habit_logs',
    'reward_events',
    'transactions',
    'transaction_archive',
    'planned_expenses',
    'budget_allocations',
    'personal_notes',
    'habits',
    'accounts',
    'categories',
    'app_settings',
  ];

  static Object? _canonical(Object? value) {
    if (value is Map) {
      return SplayTreeMap<String, Object?>.from(
        value.map((key, item) => MapEntry(key as String, _canonical(item))),
      );
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  static String _digest(Object? value) =>
      sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

  static Future<String> encode(DatabaseExecutor db, int schemaVersion) async {
    final existing = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((r) => r['name']).toSet();
    final data = <String, Object?>{};
    for (final table in tables.where(existing.contains)) {
      final rows = await db.query(table);
      data[table] = table == 'app_settings'
          ? rows
                .where((row) => !(row['key'] as String).startsWith('github_'))
                .toList()
          : rows;
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'kwall',
      'version': schemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'checksum': _digest(data),
      'data': data,
    });
  }

  static Map<String, List<Map<String, Object?>>> decode(String source) {
    final raw = jsonDecode(source);
    if (raw is! Map ||
        raw['app'] != 'kwall' ||
        raw['version'] is! int ||
        raw['data'] is! Map) {
      throw const FormatException('El archivo no es un respaldo de kwall.');
    }
    final schemaVersion = raw['version'] as int;
    if (schemaVersion < 1 || schemaVersion > version) {
      throw const FormatException(
        'Este respaldo requiere otra versión de kwall. Actualiza la app antes de restaurarlo.',
      );
    }
    final data = raw['data'] as Map;
    if ((schemaVersion >= 4 || raw.containsKey('checksum')) &&
        raw['checksum'] != _digest(data)) {
      throw const FormatException(
        'El respaldo está incompleto o fue modificado. No se restauró ningún dato.',
      );
    }
    for (final required in ['accounts', 'categories', 'transactions']) {
      if (data[required] is! List) {
        throw FormatException('Falta la tabla $required.');
      }
    }
    if (schemaVersion >= 6 &&
        tables
            .where((t) => t != 'user_currencies')
            .any((table) => data[table] is! List)) {
      throw const FormatException('El respaldo está incompleto.');
    }
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      final rows = data[table] ?? [];
      if (rows is! List || rows.any((r) => r is! Map)) {
        throw FormatException('Tabla inválida: $table.');
      }
      result[table] = rows
          .map((r) => Map<String, Object?>.from(r as Map))
          .toList();
      final ids = <Object?>{};
      for (final row in result[table]!) {
        final key =
            row[table == 'global_currency_rates'
                ? 'currency'
                : table == 'user_currencies'
                ? 'code'
                : table == 'app_settings'
                ? 'key'
                : table == 'budget_allocations'
                ? 'period_key'
                : 'id'];
        if (key is! String || key.isEmpty || !ids.add(key)) {
          throw FormatException(
            'Identificador inválido o duplicado en $table.',
          );
        }
        for (final field in row.entries) {
          if (field.value is num && !(field.value as num).isFinite) {
            throw FormatException('Monto inválido en $table.');
          }
        }
      }
    }
    if (result['user_currencies']!.isEmpty) {
      final now = DateTime.now().toIso8601String();
      final seen = <String>{};
      for (final a in result['accounts']!) {
        final c = (a['currency'] as String?)?.trim();
        if (c != null && c.isNotEmpty && seen.add(c)) {
          result['user_currencies']!.add({
            'code': c,
            'name': '',
            'created_at': now,
          });
        }
      }
      final mainCur =
          (result['app_settings']!.firstWhere(
                    (r) => r['key'] == 'currency',
                    orElse: () => {'value': '\$'},
                  )['value']
                  as String?)
              ?.trim() ??
          '\$';
      if (seen.add(mainCur)) {
        result['user_currencies']!.add({
          'code': mainCur,
          'name': '',
          'created_at': now,
        });
      }
    }
    result['app_settings']!.removeWhere(
      (row) => (row['key'] as String).startsWith('github_'),
    );
    final accountCurrencies = {
      for (final row in result['accounts']!) row['id']: row['currency'] ?? '\$',
    };
    for (final row in [
      ...result['transactions']!,
      ...result['transaction_archive']!,
    ]) {
      row['currency'] ??= accountCurrencies[row['account_id']];
      if (row['type'] == 'transfer') {
        // Preserve the actual credited amount of pre-v5 transfers, never reprice history.
        if (schemaVersion < 5) {
          row['to_amount'] ??= row['amount'];
          row['exchange_rate'] ??= 1.0;
          row['to_currency'] ??= accountCurrencies[row['to_account_id']];
        }
        if (row['to_amount'] is! num ||
            (row['to_amount'] as num) <= 0 ||
            row['exchange_rate'] is! num ||
            (row['exchange_rate'] as num) <= 0 ||
            row['to_currency'] is! String) {
          throw const FormatException('Transferencia inválida.');
        }
      }
    }
    for (final row in [
      ...result['global_currency_rates']!,
      ...result['global_currency_history']!,
    ]) {
      final rate = row['rate'] ?? row['new_rate'];
      if (rate is! num || rate <= 0) {
        throw const FormatException('Tasa inválida.');
      }
    }
    final activeIds = result['transactions']!.map((row) => row['id']).toSet();
    if (result['transaction_archive']!.any(
      (row) => activeIds.contains(row['id']),
    )) {
      throw const FormatException(
        'Un movimiento no puede estar activo y anulado a la vez.',
      );
    }
    final accounts = result['accounts']!.map((r) => r['id']).toSet();
    final habits = result['habits']!.map((r) => r['id']).toSet();
    for (final row in result['accounts']!) {
      if (schemaVersion < 8) row['exclude_from_available'] ??= 0;
      if (![0, 1].contains(row['exclude_from_available'])) {
        throw const FormatException('Opción de saldo libre inválida.');
      }
      if (row['balance'] is! num ||
          (row['minimum_balance'] as num? ?? 0) < 0 ||
          (row['savings_target'] as num? ?? 0) < 0) {
        throw const FormatException('Saldo de cuenta inválido.');
      }
    }
    for (final row in [
      ...result['transactions']!,
      ...result['transaction_archive']!,
    ]) {
      if (!accounts.contains(row['account_id']) ||
          row['amount'] is! num ||
          (row['amount'] as num) <= 0 ||
          ![
            'expense',
            'income',
            'transfer',
            'adjustment_in',
            'adjustment_out',
          ].contains(row['type']) ||
          (row['type'] == 'transfer' &&
              (!accounts.contains(row['to_account_id']) ||
                  row['account_id'] == row['to_account_id']))) {
        throw const FormatException(
          'El respaldo contiene movimientos o cuentas de destino inválidos.',
        );
      }
    }
    for (final row in result['planned_expenses']!) {
      if (row['amount'] is! num ||
          (row['amount'] as num) < 0 ||
          ![
            'one_time',
            'weekly',
            'monthly',
            'yearly',
          ].contains(row['recurrence']) ||
          (row['account_id'] != null &&
              !accounts.contains(row['account_id']))) {
        throw const FormatException('Compromiso inválido.');
      }
    }
    final days = <String>{};
    for (final row in result['habit_logs']!) {
      if (!habits.contains(row['habit_id']) ||
          ![0, 1].contains(row['completed']) ||
          !days.add('${row['habit_id']}:${row['day']}')) {
        throw const FormatException('Registro de hábito inválido.');
      }
    }
    for (final row in result['personal_notes']!) {
      final items = jsonDecode(row['items'] as String);
      if (!['note', 'list'].contains(row['kind']) ||
          items is! List ||
          items.any(
            (item) =>
                item is! Map ||
                item['text'] is! String ||
                item['done'] is! bool,
          )) {
        throw const FormatException('Lista personal inválida.');
      }
    }
    for (final table in result.entries) {
      for (final row in table.value) {
        for (final field in [
          'date',
          'due_date',
          'created_at',
          'updated_at',
          'day',
          'period_start',
          'voided_at',
        ]) {
          if (row[field] != null &&
              (row[field] is! String ||
                  DateTime.tryParse(row[field] as String) == null)) {
            throw FormatException('Fecha inválida en ${table.key}.');
          }
        }
      }
    }
    if (data.containsKey('budgets') && data['budgets'] is List) {
      final oldBudgets = data['budgets'] as List;
      for (final b in oldBudgets) {
        if (b is Map &&
            b['month'] is int &&
            b['year'] is int &&
            b['monthly_limit'] is num) {
          final m = (b['month'] as int).toString().padLeft(2, '0');
          final y = b['year'];
          final start = '$y-$m-01';
          final key = 'monthly:$start';
          if (!result['budget_allocations']!.any(
            (r) => r['period_key'] == key,
          )) {
            result['budget_allocations']!.add({
              'period_key': key,
              'period': 'monthly',
              'period_start': start,
              'amount': (b['monthly_limit'] as num).toDouble(),
              'updated_at':
                  b['created_at']?.toString() ??
                  DateTime.now().toIso8601String(),
            });
          }
        }
      }
    }
    for (final row in result['budget_allocations']!) {
      if (!['daily', 'weekly', 'monthly'].contains(row['period']) ||
          row['amount'] is! num ||
          (row['amount'] as num) < 0) {
        throw const FormatException('Asignación de presupuesto inválida.');
      }
    }
    if (!data.containsKey('personal_notes')) {
      final legacy = result['app_settings']!
          .where((row) => row['key'] == 'quick_notes')
          .firstOrNull;
      if (legacy != null && (legacy['value'] as String).trim().isNotEmpty) {
        result['personal_notes']!.add({
          'id': 'legacy-quick-notes',
          'title': 'Mis notas',
          'body': legacy['value'],
          'kind': 'note',
          'items': '[]',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
    for (final row in result['reward_events']!) {
      if (row['points'] is! int || (row['points'] as int) < 0) {
        throw const FormatException('Recompensa inválida.');
      }
    }
    final deltas = <Object?, double>{};
    for (final tx in result['transactions']!) {
      final amount = (tx['amount'] as num).toDouble();
      deltas.update(
        tx['account_id'],
        (value) =>
            value +
            (['income', 'adjustment_in'].contains(tx['type'])
                ? amount
                : -amount),
        ifAbsent: () =>
            ['income', 'adjustment_in'].contains(tx['type']) ? amount : -amount,
      );
      if (tx['type'] == 'transfer') {
        deltas.update(
          tx['to_account_id'],
          (value) => value + (tx['to_amount'] as num).toDouble(),
          ifAbsent: () => (tx['to_amount'] as num).toDouble(),
        );
      }
    }
    for (final account in result['accounts']!) {
      if (account['opening_balance'] == null) continue;
      if (account['opening_balance'] is! num) {
        throw const FormatException('Saldo inicial inválido.');
      }
      final expected =
          (account['opening_balance'] as num).toDouble() +
          (deltas[account['id']] ?? 0);
      if ((expected - (account['balance'] as num).toDouble()).abs() > .00001) {
        throw const FormatException(
          'El saldo y los movimientos del respaldo no coinciden. No se modificaron datos.',
        );
      }
    }
    return result;
  }

  static Future<void> validateColumns(
    DatabaseExecutor db,
    Map<String, List<Map<String, Object?>>> data,
  ) async {
    for (final entry in data.entries) {
      final columns = await db.rawQuery('PRAGMA table_info(${entry.key})');
      final names = columns.map((c) => c['name']).toSet();
      for (final row in entry.value) {
        if (row.keys.any((key) => !names.contains(key))) {
          throw FormatException('Campos no compatibles en ${entry.key}.');
        }
        for (final column in columns) {
          final name = column['name'] as String;
          final value = row[name];
          if (value == null) {
            if ((column['notnull'] == 1 || column['pk'] == 1) &&
                column['dflt_value'] == null) {
              throw FormatException('Falta $name en ${entry.key}.');
            }
          } else {
            final type = column['type'];
            if ((type == 'TEXT' && value is! String) ||
                (type == 'INTEGER' && value is! int) ||
                (type == 'REAL' && value is! num)) {
              throw FormatException('Tipo inválido en ${entry.key}.$name.');
            }
          }
        }
      }
    }
  }

  static Future<String> writeRecovery(
    String databasePath,
    String content,
    String reason,
  ) async {
    final path =
        '$databasePath.$reason-${DateTime.now().microsecondsSinceEpoch}.json';
    final temporary = File('$path.tmp');
    await temporary.writeAsString(content, flush: true);
    await temporary.rename(path);
    return path;
  }
}
