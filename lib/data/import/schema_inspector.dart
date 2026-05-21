import 'package:sqlite3/sqlite3.dart';

class SchemaSnapshot {
  const SchemaSnapshot({required this.tables, required this.columnsByTable});

  final Set<String> tables;
  final Map<String, Set<String>> columnsByTable;
}

class SchemaInspector {
  const SchemaInspector();

  SchemaSnapshot inspect(Database db) {
    final tableRows = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    final tables = tableRows
        .map((r) => (r['name'] as String?) ?? '')
        .where((t) => t.isNotEmpty)
        .toSet();

    final columnsByTable = <String, Set<String>>{};
    for (final table in tables) {
      final pragmaRows = db.select('PRAGMA table_info($table)');
      columnsByTable[table] = pragmaRows
          .map((r) => (r['name'] as String?) ?? '')
          .where((c) => c.isNotEmpty)
          .toSet();
    }

    return SchemaSnapshot(tables: tables, columnsByTable: columnsByTable);
  }
}
