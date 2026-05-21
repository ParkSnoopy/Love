import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../lib/data/import/schema_inspector.dart';

void main() {
  test('inspector returns table and column sets from sqlite db', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);

    db.execute('CREATE TABLE books(book_id INTEGER, name_en TEXT);');
    db.execute('CREATE TABLE verses(book_id INTEGER, chapter INTEGER, verse INTEGER, text TEXT);');

    final inspector = SchemaInspector();
    final snapshot = inspector.inspect(db);

    expect(snapshot.tables.contains('books'), isTrue);
    expect(snapshot.tables.contains('verses'), isTrue);
    expect(snapshot.columnsByTable['books'], containsAll(['book_id', 'name_en']));
    expect(
      snapshot.columnsByTable['verses'],
      containsAll(['book_id', 'chapter', 'verse', 'text']),
    );
  });
}
