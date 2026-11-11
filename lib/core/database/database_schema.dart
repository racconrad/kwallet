import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:knotes/features/journal/models/journal_models.dart';

class DatabaseSchema {
  static Future<void> create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL,
        minimum_balance REAL NOT NULL DEFAULT 0,
        opening_balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT '\$',
        currencies TEXT NOT NULL DEFAULT '[]',
        icon_key TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon_key TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        to_account_id TEXT,
        category_id TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE planned_expenses (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        due_date TEXT NOT NULL,
        recurrence TEXT NOT NULL,
        recurrence_day INTEGER,
        category_id TEXT NOT NULL,
        account_id TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        icon_key TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _createV4Tables(db);
    await migrateV5(db);
    await migrateV6(db);
    await migrateV7(db);
    await migrateV8(db);
    await migrateV9(db);
    await migrateV10(db);

    await db.insert('app_settings', {
      'key': 'db_version',
      'value': '$version',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _createV4Tables(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS budget_allocations (period_key TEXT PRIMARY KEY, period TEXT NOT NULL, period_start TEXT NOT NULL, amount REAL NOT NULL CHECK(amount >= 0), updated_at TEXT NOT NULL)',
    );
    await db.execute(
      "CREATE TABLE IF NOT EXISTS personal_notes (id TEXT PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '', kind TEXT NOT NULL DEFAULT 'note', items TEXT NOT NULL DEFAULT '[]', icon_key TEXT NOT NULL DEFAULT 'note', color_value INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)",
    );
    await db.execute(
      "CREATE TABLE IF NOT EXISTS habits (id TEXT PRIMARY KEY, title TEXT NOT NULL, icon_key TEXT NOT NULL DEFAULT 'spa_rounded', color_value INTEGER NOT NULL DEFAULT 4283226960, time_block TEXT NOT NULL DEFAULT 'anytime', created_at TEXT NOT NULL)",
    );
    await db.execute(
      "CREATE TABLE IF NOT EXISTS habit_logs (id TEXT PRIMARY KEY, habit_id TEXT NOT NULL REFERENCES habits(id) ON DELETE CASCADE, day TEXT NOT NULL, completed INTEGER NOT NULL CHECK(completed IN (0,1)), mood TEXT NOT NULL DEFAULT 'neutral', reason TEXT NOT NULL DEFAULT '', UNIQUE(habit_id,day))",
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS reward_events (id TEXT PRIMARY KEY, points INTEGER NOT NULL CHECK(points >= 0), created_at TEXT NOT NULL)',
    );
    await db.execute(
      "CREATE TABLE IF NOT EXISTS transaction_archive (id TEXT PRIMARY KEY, account_id TEXT NOT NULL, to_account_id TEXT, category_id TEXT NOT NULL, amount REAL NOT NULL, type TEXT NOT NULL, note TEXT NOT NULL DEFAULT '', date TEXT NOT NULL, created_at TEXT NOT NULL, voided_at TEXT NOT NULL)",
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transaction_archive_date ON transaction_archive(date DESC,id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(account_id,date DESC,id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_destination ON transactions(to_account_id,date DESC,id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_type_date ON transactions(type,date DESC,id DESC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS front_pending_items (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL DEFAULT '',
        due_date TEXT,
        source_id TEXT NOT NULL,
        source_index INTEGER,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_front_pending_cat ON front_pending_items(category, is_completed)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS account_currency_history (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        base_currency TEXT NOT NULL,
        currency TEXT NOT NULL,
        conversion_rate REAL NOT NULL DEFAULT 1.0,
        previous_rate REAL,
        change_type TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS global_currency_rates (
        currency TEXT PRIMARY KEY,
        rate REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS global_currency_history (
        id TEXT PRIMARY KEY,
        currency TEXT NOT NULL,
        previous_rate REAL,
        new_rate REAL NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_global_curr_hist ON global_currency_history(currency, created_at DESC)',
    );
  }

  static Future<void> backfillOpeningBalances(
    DatabaseExecutor db, {
    String? accountId,
  }) async {
    final columns = (await db.rawQuery('PRAGMA table_info(transactions)'))
        .map((row) => row['name'])
        .toSet();
    final received = columns.contains('to_amount')
        ? 'COALESCE(t.to_amount,t.amount)'
        : 't.amount';
    await db.rawUpdate(
      """UPDATE accounts SET opening_balance = balance - COALESCE((
      SELECT SUM(CASE WHEN t.account_id = accounts.id AND t.type IN ('income','adjustment_in') THEN t.amount
        WHEN t.account_id = accounts.id AND t.type IN ('expense','transfer','adjustment_out') THEN -t.amount ELSE 0 END
        + CASE WHEN t.to_account_id = accounts.id AND t.type = 'transfer' THEN $received ELSE 0 END)
      FROM transactions t WHERE t.account_id = accounts.id OR t.to_account_id = accounts.id),0)
      ${accountId == null ? '' : 'WHERE id = ?'}""",
      accountId == null ? [] : [accountId],
    );
  }

  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE budgets ADD COLUMN weekly_limit REAL');
      await db.execute('ALTER TABLE budgets ADD COLUMN daily_limit REAL');
    }
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS planned_expenses (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          due_date TEXT NOT NULL,
          recurrence TEXT NOT NULL,
          category_id TEXT NOT NULL,
          account_id TEXT,
          is_completed INTEGER NOT NULL DEFAULT 0,
          note TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      final kittyColumns = (await db.rawQuery(
        'PRAGMA table_info(kitty_profile)',
      )).map((row) => row['name']).toSet();
      if (!kittyColumns.contains('coat_color')) {
        await db.execute(
          "ALTER TABLE kitty_profile ADD COLUMN coat_color TEXT NOT NULL DEFAULT 'orange'",
        );
      }
      if (!kittyColumns.contains('personality')) {
        await db.execute(
          "ALTER TABLE kitty_profile ADD COLUMN personality TEXT NOT NULL DEFAULT 'curious'",
        );
      }

      await db.insert('app_settings', {
        'key': 'currency',
        'value': '\$',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE planned_expenses ADD COLUMN recurrence_day INTEGER',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN minimum_balance REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN opening_balance REAL NOT NULL DEFAULT 0',
      );
      await backfillOpeningBalances(db);
      await _createV4Tables(db);
      final oldNotes = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['quick_notes'],
      );
      if (oldNotes.isNotEmpty &&
          (oldNotes.first['value'] as String).trim().isNotEmpty) {
        await db.insert(
          'personal_notes',
          PersonalNote(
            id: 'legacy-quick-notes',
            title: 'Mis notas',
            body: oldNotes.first['value'] as String,
            updatedAt: DateTime.now(),
          ).toMap(),
        );
      }
    }
    if (oldVersion < 5) await migrateV5(db);
    if (oldVersion < 6) await migrateV6(db);
    if (oldVersion < 7) await migrateV7(db);
    if (oldVersion < 8) await migrateV8(db);
    if (oldVersion < 9) await migrateV9(db);
    if (oldVersion < 10) await migrateV10(db);
    await db.insert('app_settings', {
      'key': 'db_version',
      'value': '$newVersion',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Versioned migration shared by fresh databases and upgrades. Never run DDL in onOpen.
  static Future<void> migrateV5(DatabaseExecutor db) async {
    await _migrateLegacyColumns(db);
    for (final table in ['transactions', 'transaction_archive']) {
      final columns = (await db.rawQuery('PRAGMA table_info($table)'))
          .map((r) => r['name'])
          .toSet();
      for (final entry in {
        'currency': 'TEXT',
        'to_currency': 'TEXT',
        'to_amount': 'REAL',
        'exchange_rate': 'REAL',
      }.entries) {
        if (!columns.contains(entry.key)) {
          await db.execute(
            'ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}',
          );
        }
      }
      await db.execute(
        "UPDATE $table SET currency = (SELECT currency FROM accounts WHERE id = account_id) WHERE currency IS NULL",
      );
      await db.execute(
        "UPDATE $table SET to_amount = amount, exchange_rate = 1, to_currency = (SELECT currency FROM accounts WHERE id = to_account_id) WHERE type = 'transfer' AND to_amount IS NULL",
      );
      for (final operation in ['INSERT', 'UPDATE']) {
        await db.execute(
          "CREATE TRIGGER IF NOT EXISTS validate_${table}_${operation.toLowerCase()} BEFORE $operation ON $table WHEN NEW.amount <= 0 OR NEW.type NOT IN ('income','expense','transfer') OR (NEW.type = 'transfer' AND (NEW.to_account_id IS NULL OR NEW.to_account_id = NEW.account_id OR NEW.to_amount IS NULL OR NEW.to_amount <= 0 OR NEW.exchange_rate IS NULL OR NEW.exchange_rate <= 0 OR NOT EXISTS (SELECT 1 FROM accounts WHERE id = NEW.to_account_id))) BEGIN SELECT RAISE(ABORT, 'Invalid movement'); END",
        );
      }
    }
    final historyColumns = (await db.rawQuery(
      'PRAGMA table_info(global_currency_history)',
    )).map((r) => r['name']).toSet();
    if (!historyColumns.contains('base_currency')) {
      await db.execute(
        'ALTER TABLE global_currency_history ADD COLUMN base_currency TEXT',
      );
      await db.execute(
        "UPDATE global_currency_history SET base_currency = COALESCE((SELECT value FROM app_settings WHERE key = 'currency'),'\$')",
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_acc_curr_hist ON account_currency_history(account_id, created_at DESC)',
    );
    for (final operation in ['INSERT', 'UPDATE']) {
      await db.execute(
        "CREATE TRIGGER IF NOT EXISTS validate_rate_${operation.toLowerCase()} BEFORE $operation ON global_currency_rates WHEN NEW.rate <= 0 BEGIN SELECT RAISE(ABORT, 'Invalid exchange rate'); END",
      );
    }
  }

  static Future<void> _migrateLegacyColumns(DatabaseExecutor db) async {
    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((r) => r['name']).toSet();

    if (tables.contains('habits')) {
      final columns = (await db.rawQuery('PRAGMA table_info(habits)'))
          .map((r) => r['name'])
          .toSet();
      if (!columns.contains('icon_key')) {
        await db.execute(
          "ALTER TABLE habits ADD COLUMN icon_key TEXT NOT NULL DEFAULT 'spa_rounded'",
        );
      }
      if (!columns.contains('color_value')) {
        await db.execute(
          'ALTER TABLE habits ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4283226960',
        );
      }
      if (!columns.contains('time_block')) {
        await db.execute(
          "ALTER TABLE habits ADD COLUMN time_block TEXT NOT NULL DEFAULT 'anytime'",
        );
      }
    }

    if (tables.contains('personal_notes')) {
      final noteCols = (await db.rawQuery('PRAGMA table_info(personal_notes)'))
          .map((r) => r['name'])
          .toSet();
      if (!noteCols.contains('icon_key')) {
        await db.execute(
          "ALTER TABLE personal_notes ADD COLUMN icon_key TEXT NOT NULL DEFAULT 'note'",
        );
      }
      if (!noteCols.contains('color_value')) {
        await db.execute(
          'ALTER TABLE personal_notes ADD COLUMN color_value INTEGER NOT NULL DEFAULT 0',
        );
      }
    }

    if (tables.contains('accounts')) {
      final accountCols = (await db.rawQuery('PRAGMA table_info(accounts)'))
          .map((r) => r['name'])
          .toSet();
      if (!accountCols.contains('currencies')) {
        await db.execute(
          "ALTER TABLE accounts ADD COLUMN currencies TEXT NOT NULL DEFAULT '[]'",
        );
      }
    }

    await _createV4Tables(db);
  }

  static Future<void> migrateV6(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budget_allocation_history (
        id TEXT PRIMARY KEY,
        period_key TEXT NOT NULL,
        period TEXT NOT NULL,
        period_start TEXT NOT NULL,
        previous_amount REAL,
        new_amount REAL NOT NULL,
        change_type TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budget_alloc_hist ON budget_allocation_history(period_key, created_at DESC)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS planned_expense_payments (
        id TEXT PRIMARY KEY,
        planned_expense_id TEXT NOT NULL REFERENCES planned_expenses(id) ON DELETE CASCADE,
        transaction_id TEXT,
        due_date TEXT NOT NULL,
        paid_at TEXT NOT NULL,
        amount REAL NOT NULL,
        account_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plan_payments_plan ON planned_expense_payments(planned_expense_id, paid_at DESC)',
    );

    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((r) => r['name']).toSet();

    if (tables.contains('budgets')) {
      final oldBudgets = await db.query('budgets');
      for (final b in oldBudgets) {
        final m = (b['month'] as int).toString().padLeft(2, '0');
        final y = b['year'];
        final start = '$y-$m-01';
        final key = 'monthly:$start';
        final monthlyLimit = (b['monthly_limit'] as num?)?.toDouble() ?? 0.0;
        await db.insert('budget_allocations', {
          'period_key': key,
          'period': 'monthly',
          'period_start': start,
          'amount': monthlyLimit,
          'updated_at':
              b['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await db.execute('DROP TABLE IF EXISTS budgets');
    }

    if (tables.contains('kitty_profile')) {
      await db.execute('DROP TABLE IF EXISTS kitty_profile');
    }

    final planCols = (await db.rawQuery("PRAGMA table_info(planned_expenses)"))
        .map((r) => r['name'])
        .toSet();
    if (!planCols.contains('icon_key')) {
      await db.execute('ALTER TABLE planned_expenses ADD COLUMN icon_key TEXT');
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS quick_expenses (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id TEXT NOT NULL,
        account_id TEXT,
        icon_key TEXT NOT NULL DEFAULT 'bolt',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_currencies (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    final ucRows = await db.query('user_currencies', limit: 1);
    if (ucRows.isEmpty) {
      final nowStr = DateTime.now().toIso8601String();
      final mainCurRows = await db.query(
        'app_settings',
        where: "key = 'currency'",
      );
      final mainCur = (mainCurRows.firstOrNull?['value'] as String?)?.trim();
      if (mainCur != null && mainCur.isNotEmpty) {
        await db.insert('user_currencies', {
          'code': mainCur,
          'name': '',
          'created_at': nowStr,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final rateRows = await db.query('global_currency_rates');
      for (final r in rateRows) {
        final c = (r['currency'] as String?)?.trim();
        if (c != null && c.isNotEmpty) {
          await db.insert('user_currencies', {
            'code': c,
            'name': '',
            'created_at': nowStr,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      final accRows = await db.query('accounts');
      for (final a in accRows) {
        final c = (a['currency'] as String?)?.trim();
        if (c != null && c.isNotEmpty) {
          await db.insert('user_currencies', {
            'code': c,
            'name': '',
            'created_at': nowStr,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    }
  }

  // Goals count existing habit logs and task rewards, so only manual goals store progress.
  static Future<void> migrateV9(DatabaseExecutor db) async {
    final columns = (await db.rawQuery('PRAGMA table_info(habits)'))
        .map((r) => r['name'])
        .toSet();
    if (!columns.contains('reminder_time')) {
      await db.execute('ALTER TABLE habits ADD COLUMN reminder_time TEXT');
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        kind TEXT NOT NULL CHECK(kind IN ('habits','tasks','manual')),
        habit_id TEXT REFERENCES habits(id) ON DELETE CASCADE,
        target INTEGER NOT NULL CHECK(target > 0),
        progress INTEGER NOT NULL DEFAULT 0 CHECK(progress >= 0),
        start_day TEXT NOT NULL,
        end_day TEXT NOT NULL,
        reminder_time TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_habit_logs_day ON habit_logs(day, completed)',
    );
  }

  /// Weekdays a habit reminder rings on, as ISO digits ("12345" = Mon–Fri).
  static Future<void> migrateV10(DatabaseExecutor db) async {
    final columns = (await db.rawQuery('PRAGMA table_info(habits)'))
        .map((r) => r['name'])
        .toSet();
    if (!columns.contains('reminder_days')) {
      await db.execute('ALTER TABLE habits ADD COLUMN reminder_days TEXT');
    }
  }

  static Future<void> migrateV8(DatabaseExecutor db) async {
    final columns = (await db.rawQuery('PRAGMA table_info(accounts)'))
        .map((r) => r['name'])
        .toSet();
    if (!columns.contains('exclude_from_available')) {
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN exclude_from_available INTEGER NOT NULL DEFAULT 0 CHECK(exclude_from_available IN (0,1))',
      );
    }
  }

  static Future<void> migrateV7(DatabaseExecutor db) async {
    final columns = (await db.rawQuery('PRAGMA table_info(accounts)'))
        .map((r) => r['name'])
        .toSet();
    if (!columns.contains('savings_target')) {
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN savings_target REAL NOT NULL DEFAULT 0 CHECK(savings_target >= 0)',
      );
    }
    if (!columns.contains('is_deleted')) {
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0,1))',
      );
    }
    for (final table in ['transactions', 'transaction_archive']) {
      for (final operation in ['INSERT', 'UPDATE']) {
        final name = 'validate_${table}_${operation.toLowerCase()}';
        await db.execute('DROP TRIGGER IF EXISTS $name');
        await db.execute(
          "CREATE TRIGGER $name BEFORE $operation ON $table WHEN NEW.amount <= 0 OR NEW.type NOT IN ('income','expense','transfer','adjustment_in','adjustment_out') OR (NEW.type = 'transfer' AND (NEW.to_account_id IS NULL OR NEW.to_account_id = NEW.account_id OR NEW.to_amount IS NULL OR NEW.to_amount <= 0 OR NEW.exchange_rate IS NULL OR NEW.exchange_rate <= 0 OR NOT EXISTS (SELECT 1 FROM accounts WHERE id = NEW.to_account_id))) BEGIN SELECT RAISE(ABORT, 'Invalid movement'); END",
        );
      }
    }
  }
}
