import 'package:flutter/material.dart';

import '../data/search_repository.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.dbPath});

  final String dbPath;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _pageSize = 100;
  static const _repo = SearchRepository();

  final _queryController = TextEditingController();
  final _scrollController = ScrollController();

  List<SearchHit> _hits = const [];
  bool _loading = false;
  bool _hasMore = false;
  int _offset = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || !_hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _startSearch() async {
    final q = _queryController.text.trim();
    setState(() {
      _query = q;
      _hits = const [];
      _offset = 0;
      _hasMore = false;
    });
    if (q.isEmpty) return;
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final nextOffset = reset ? 0 : _offset;
      final page = _repo.searchLike(
        dbPath: widget.dbPath,
        query: _query,
        limit: _pageSize,
        offset: nextOffset,
      );
      setState(() {
        _hits = reset ? page : [..._hits, ...page];
        _offset = nextOffset + page.length;
        _hasMore = page.length == _pageSize;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    onSubmitted: (_) => _startSearch(),
                    decoration: const InputDecoration(
                      hintText: 'Search verse text',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _startSearch,
                  child: const Text('Find'),
                ),
              ],
            ),
          ),
          if (_query.isNotEmpty && _hits.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No hits'),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _hits.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _hits.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final h = _hits[index];
                return ListTile(
                  title: Text('[${h.chapter}:${h.verse}] ${h.text}'),
                  subtitle: Text('Book ${h.bookId}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
