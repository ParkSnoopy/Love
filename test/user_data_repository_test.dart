import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/features/study/data/user_data_repository.dart';

void main() {
  test('init creates tables and history capped at 50', () {
    final dir = Directory.systemTemp.createTempSync('love_user_data_test_');
    final dbPath = '${dir.path}/user_data.db';
    const repo = UserDataRepository();

    repo.init(dbPath);

    for (var i = 1; i <= 60; i++) {
      repo.addHistory(
        dbPath: dbPath,
        bookId: 1,
        chapter: 1,
        verse: i,
        visitedAt: i,
      );
    }

    final recent = repo.loadRecentHistory(dbPath: dbPath);
    expect(recent.length, 50);
    expect(recent.first.verse, 60);
    expect(recent.last.verse, 11);

    File(dbPath).deleteSync();
    dir.deleteSync(recursive: true);
  });

  test('bookmark dedup + note upsert work', () {
    final dir = Directory.systemTemp.createTempSync('love_user_data_test_');
    final dbPath = '${dir.path}/user_data.db';
    const repo = UserDataRepository();

    repo.init(dbPath);

    repo.addBookmark(
      dbPath: dbPath,
      bookId: 1,
      chapter: 1,
      verse: 1,
      createdAt: 100,
    );
    repo.addBookmark(
      dbPath: dbPath,
      bookId: 1,
      chapter: 1,
      verse: 1,
      createdAt: 200,
    );

    final bookmarks = repo.loadBookmarks(dbPath: dbPath);
    expect(bookmarks.length, 1);
    expect(bookmarks.first.createdAt, 200);

    repo.upsertNote(
      dbPath: dbPath,
      bookId: 1,
      chapter: 1,
      verse: 1,
      content: 'note v1',
      now: 1000,
    );
    repo.upsertNote(
      dbPath: dbPath,
      bookId: 1,
      chapter: 1,
      verse: 1,
      content: 'note v2',
      now: 2000,
    );

    final note = repo.loadNote(dbPath: dbPath, bookId: 1, chapter: 1, verse: 1);
    expect(note, isNotNull);
    expect(note!.content, 'note v2');
    expect(note.updatedAt, 2000);

    File(dbPath).deleteSync();
    dir.deleteSync(recursive: true);
  });
}
