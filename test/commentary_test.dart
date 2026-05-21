import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:Love/features/reader/data/reader_repository.dart';

void main() {
  group('Commentary Database Tests', () {
    const repository = ReaderRepository();
    final commentaryDir = Directory('assets/data/comment');

    test('Loads Genesis 1 commentary from Geneva Bible commentary', () {
      final dbFile = File(p.join(commentaryDir.path, 'com_geneva.sqlite'));
      expect(dbFile.existsSync(), isTrue);

      final article = repository.loadCommentaryArticle(
        dbPath: dbFile.path,
        bookId: 1, // Genesis
        chapter: 1,
      );

      expect(article, isNotNull);
      expect(article!.title, contains('Genesis'));
      expect(article.title, contains('1'));
      expect(article.text, isNotEmpty);
    });

    test('Loads Matthew 5 commentary from Barnes commentary', () {
      final dbFile = File(p.join(commentaryDir.path, 'com_barne.sqlite'));
      expect(dbFile.existsSync(), isTrue);

      final article = repository.loadCommentaryArticle(
        dbPath: dbFile.path,
        bookId: 40, // Matthew
        chapter: 5,
      );

      expect(article, isNotNull);
      expect(article!.title, contains('Matthew'));
      expect(article.title, contains('5'));
      expect(article.text, isNotEmpty);
    });

    test('Loads Genesis 1 commentary from Korean Hochma commentary', () {
      final dbFile = File(p.join(commentaryDir.path, 'com_kor_hochma.sqlite'));
      expect(dbFile.existsSync(), isTrue);

      final article = repository.loadCommentaryArticle(
        dbPath: dbFile.path,
        bookId: 1, // Genesis / 창세기
        chapter: 1,
      );

      expect(article, isNotNull);
      expect(article!.title, contains('창세기'));
      expect(article.title, contains('1'));
      expect(article.text, isNotEmpty);
    });

    test('Returns null for invalid/out-of-bounds chapter', () {
      final dbFile = File(p.join(commentaryDir.path, 'com_geneva.sqlite'));
      final article = repository.loadCommentaryArticle(
        dbPath: dbFile.path,
        bookId: 1,
        chapter: 999, // Non-existent chapter
      );
      expect(article, isNull);
    });
  });
}
