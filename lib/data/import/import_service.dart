import 'package:sqlite3/sqlite3.dart';

import 'schema_inspector.dart';
import 'schema_validator.dart';

class ImportService {
  const ImportService();

  void validateBibleFile(String dbPath) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      const inspector = SchemaInspector();
      final validator = SchemaValidator();
      final snapshot = inspector.inspect(db);
      validator.validateBibleSchema(snapshot.tables, snapshot.columnsByTable);
    } finally {
      db.close();
    }
  }

  void validateCommentaryFile(String dbPath) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      const inspector = SchemaInspector();
      final validator = SchemaValidator();
      final snapshot = inspector.inspect(db);
      validator.validateCommentarySchema(
        snapshot.tables,
        snapshot.columnsByTable,
      );
    } finally {
      db.close();
    }
  }
}
