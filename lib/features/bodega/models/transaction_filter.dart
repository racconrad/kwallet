import 'package:knotes/features/bodega/models/transaction_record.dart';

class TransactionFilter {
  final String? accountId;
  final bool archived;
  final String? type;
  final String search;
  final DateTime? start;
  final DateTime? end;
  const TransactionFilter({
    this.accountId,
    this.archived = false,
    this.type,
    this.search = '',
    this.start,
    this.end,
  });
  ({String where, List<Object?> args}) sql({TransactionRecord? before}) {
    final clauses = <String>[];
    final args = <Object?>[];
    if (accountId != null) {
      clauses.add('(account_id = ? OR to_account_id = ?)');
      args.addAll([accountId, accountId]);
    }
    if (type == 'adjustment') {
      clauses.add("type IN ('adjustment_in','adjustment_out')");
    } else if (type != null) {
      clauses.add('type = ?');
      args.add(type);
    }
    if (start != null) {
      clauses.add('date >= ?');
      args.add(
        DateTime(
          start!.year,
          start!.month,
          start!.day,
        ).toIso8601String().substring(0, 10),
      );
    }
    if (end != null) {
      clauses.add('date < ?');
      args.add(
        DateTime(
          end!.year,
          end!.month,
          end!.day + 1,
        ).toIso8601String().substring(0, 10),
      );
    }
    if (search.trim().isNotEmpty) {
      final text = search
          .trim()
          .replaceAll('!', '!!')
          .replaceAll('%', '!%')
          .replaceAll('_', '!_');
      clauses.add(
        "(note LIKE ? ESCAPE '!' OR category_id IN (SELECT id FROM categories WHERE name LIKE ? ESCAPE '!'))",
      );
      args.addAll(['%$text%', '%$text%']);
    }
    if (before != null) {
      clauses.add('(date < ? OR (date = ? AND id < ?))');
      args.addAll([
        before.storedDate ?? before.date.toIso8601String(),
        before.storedDate ?? before.date.toIso8601String(),
        before.id,
      ]);
    }
    return (
      where: clauses.isEmpty ? '1 = 1' : clauses.join(' AND '),
      args: args,
    );
  }
}
