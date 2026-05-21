import 'import_exception.dart';

class SchemaValidator {
  static const _bibleTables = {'books', 'verses', 'version'};
  static const _commentaryTables = {'articles', 'indexing', 'comment'};

  static const _requiredColumns = {
    'books': {
      'book_id',
      'osis',
      'name_en',
      'name_native',
      'testament',
      'chapter_count',
    },
    'verses': {'book_id', 'chapter', 'verse', 'text'},
    'version': {'slug', 'label'},
  };

  static const _requiredCommentaryColumns = {
    'articles': {'article_id', 'title', 'text'},
    'indexing': {
      'book_id',
      'osis',
      'name_en',
      'name_native',
      'testament',
      'chapter_count',
    },
    'comment': {'slug', 'label'},
  };

  void validateBibleSchema(
    Set<String> tables,
    Map<String, Set<String>> columnsByTable,
  ) {
    for (final table in _bibleTables) {
      if (!tables.contains(table)) {
        throw ImportException(
          code: 'MISSING_TABLE',
          message: 'Required table missing: $table',
          phase: 'Validate Bible',
          detail: table,
        );
      }
    }

    for (final entry in _requiredColumns.entries) {
      final table = entry.key;
      final required = entry.value;
      final got = columnsByTable[table] ?? const <String>{};
      for (final col in required) {
        if (!got.contains(col)) {
          throw ImportException(
            code: 'MISSING_COLUMN',
            message: 'Required column missing: $table.$col',
            phase: 'Validate Bible',
            detail: '$table.$col',
          );
        }
      }
    }
  }

  void validateCommentarySchema(
    Set<String> tables,
    Map<String, Set<String>> columnsByTable,
  ) {
    for (final table in _commentaryTables) {
      if (!tables.contains(table)) {
        throw ImportException(
          code: 'MISSING_TABLE',
          message: 'Required table missing: $table',
          phase: 'Validate Commentary',
          detail: table,
        );
      }
    }

    for (final entry in _requiredCommentaryColumns.entries) {
      final table = entry.key;
      final required = entry.value;
      final got = columnsByTable[table] ?? const <String>{};
      for (final col in required) {
        if (!got.contains(col)) {
          throw ImportException(
            code: 'MISSING_COLUMN',
            message: 'Required column missing: $table.$col',
            phase: 'Validate Commentary',
            detail: '$table.$col',
          );
        }
      }
    }
  }
}
