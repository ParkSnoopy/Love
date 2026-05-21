import 'package:flutter_test/flutter_test.dart';

import '../lib/data/import/import_exception.dart';
import '../lib/data/import/schema_validator.dart';

void main() {
  test('validator fails if required bible table missing', () {
    final validator = SchemaValidator();

    expect(
      () => validator.validateBibleSchema(
        const {'books', 'version'},
        const {
          'books': {
            'book_id',
            'osis',
            'name_en',
            'name_native',
            'testament',
            'chapter_count',
          },
          'version': {'slug', 'label'},
        },
      ),
      throwsA(
        isA<ImportException>().having((e) => e.code, 'code', 'MISSING_TABLE'),
      ),
    );
  });

  test('validator passes for minimum required bible schema', () {
    final validator = SchemaValidator();

    validator.validateBibleSchema(
      const {'books', 'verses', 'version'},
      const {
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
      },
    );
  });

  test('validator fails if commentary required table missing', () {
    final validator = SchemaValidator();

    expect(
      () => validator.validateCommentarySchema(
        const {'articles', 'comment'},
        const {
          'articles': {'article_id', 'title', 'text'},
          'comment': {'slug', 'label'},
        },
      ),
      throwsA(
        isA<ImportException>().having((e) => e.code, 'code', 'MISSING_TABLE'),
      ),
    );
  });
}
