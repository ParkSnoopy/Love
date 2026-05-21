import 'import_exception.dart';

class SchemaValidator {
  static const _bibleTables = {'books', 'verses', 'version'};
  static const _commentaryTables = {'articles', 'indexing', 'comment'};

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

    // Validate books columns (with support for both getbible and nocr schemas)
    final gotBooks = columnsByTable['books'] ?? const <String>{};
    final requiredBooks = {'book_id', 'osis', 'testament'};
    for (final col in requiredBooks) {
      if (!gotBooks.contains(col)) {
        throw ImportException(
          code: 'MISSING_COLUMN',
          message: 'Required column missing: books.$col',
          phase: 'Validate Bible',
          detail: 'books.$col',
        );
      }
    }
    if (!gotBooks.contains('name_en') && !gotBooks.contains('eng_name')) {
      throw ImportException(
        code: 'MISSING_COLUMN',
        message: 'Required column missing: books.name_en (or eng_name)',
        phase: 'Validate Bible',
        detail: 'books.name_en',
      );
    }
    if (!gotBooks.contains('name_native') && !gotBooks.contains('name')) {
      throw ImportException(
        code: 'MISSING_COLUMN',
        message: 'Required column missing: books.name_native (or name)',
        phase: 'Validate Bible',
        detail: 'books.name_native',
      );
    }
    if (!gotBooks.contains('chapter_count') && !gotBooks.contains('chapters')) {
      throw ImportException(
        code: 'MISSING_COLUMN',
        message: 'Required column missing: books.chapter_count (or chapters)',
        phase: 'Validate Bible',
        detail: 'books.chapter_count',
      );
    }

    // Validate verses columns
    final gotVerses = columnsByTable['verses'] ?? const <String>{};
    final requiredVerses = {'book_id', 'chapter', 'verse', 'text'};
    for (final col in requiredVerses) {
      if (!gotVerses.contains(col)) {
        throw ImportException(
          code: 'MISSING_COLUMN',
          message: 'Required column missing: verses.$col',
          phase: 'Validate Bible',
          detail: 'verses.$col',
        );
      }
    }

    // Validate version columns
    final gotVersion = columnsByTable['version'] ?? const <String>{};
    final requiredVersion = {'slug', 'label'};
    for (final col in requiredVersion) {
      if (!gotVersion.contains(col)) {
        throw ImportException(
          code: 'MISSING_COLUMN',
          message: 'Required column missing: version.$col',
          phase: 'Validate Bible',
          detail: 'version.$col',
        );
      }
    }
  }

  void validateCommentarySchema(
    Set<String> tables,
    Map<String, Set<String>> columnsByTable,
  ) {
    final hasArticles = tables.contains('articles');
    final hasVerses = tables.contains('verses');

    if (!hasArticles && !hasVerses) {
      throw ImportException(
        code: 'MISSING_TABLE',
        message:
            'Required tables missing: commentary must have either articles or verses table',
        phase: 'Validate Commentary',
        detail: 'articles/verses',
      );
    }

    if (hasArticles) {
      // Schema A: articles, indexing, comment
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
    } else {
      // Schema B: books, verses, version, indexing
      final requiredTables = {'books', 'verses', 'version', 'indexing'};
      for (final table in requiredTables) {
        if (!tables.contains(table)) {
          throw ImportException(
            code: 'MISSING_TABLE',
            message: 'Required table missing: $table',
            phase: 'Validate Commentary',
            detail: table,
          );
        }
      }

      // Validate books
      final gotBooks = columnsByTable['books'] ?? const <String>{};
      final requiredBooks = {'book_id', 'osis', 'testament'};
      for (final col in requiredBooks) {
        if (!gotBooks.contains(col)) {
          throw ImportException(
            code: 'MISSING_COLUMN',
            message: 'Required column missing: books.$col',
            phase: 'Validate Commentary',
            detail: 'books.$col',
          );
        }
      }

      // Validate verses
      final gotVerses = columnsByTable['verses'] ?? const <String>{};
      final requiredVerses = {'book_id', 'chapter', 'verse', 'text'};
      for (final col in requiredVerses) {
        if (!gotVerses.contains(col)) {
          throw ImportException(
            code: 'MISSING_COLUMN',
            message: 'Required column missing: verses.$col',
            phase: 'Validate Commentary',
            detail: 'verses.$col',
          );
        }
      }
    }
  }
}
