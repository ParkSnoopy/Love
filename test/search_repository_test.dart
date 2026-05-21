import 'package:flutter_test/flutter_test.dart';

import '../lib/features/search/data/search_repository.dart';

void main() {
  test('search returns hits for query with limit and offset', () {
    const repo = SearchRepository();

    final page1 = repo.searchLike(
      dbPath: 'assets/data/getbible/en_kjv.sqlite',
      query: 'God',
      limit: 100,
      offset: 0,
    );
    final page2 = repo.searchLike(
      dbPath: 'assets/data/getbible/en_kjv.sqlite',
      query: 'God',
      limit: 100,
      offset: 100,
    );

    expect(page1.length <= 100, isTrue);
    expect(page1, isNotEmpty);
    expect(page2.length <= 100, isTrue);
  });

  test('search enforces min length for non-CJK', () {
    const repo = SearchRepository();

    final hits = repo.searchLike(
      dbPath: 'assets/data/getbible/en_kjv.sqlite',
      query: 'a',
      limit: 100,
      offset: 0,
    );

    expect(hits, isEmpty);
  });
}
