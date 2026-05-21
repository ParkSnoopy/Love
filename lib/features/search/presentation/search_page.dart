import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/search_repository.dart';
import '../../reader/data/reader_repository.dart';
import '../../../data/storage/db_path_provider.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbPathAsync = ref.watch(activeDbPathProvider);

    return dbPathAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (dbPath) {
        if (dbPath == null) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No Bible selected or installed.\nPlease go to Library and select a version.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _SearchContentView(dbPath: dbPath);
      },
    );
  }
}

class _SearchContentView extends StatefulWidget {
  const _SearchContentView({required this.dbPath});

  final String dbPath;

  @override
  State<_SearchContentView> createState() => _SearchContentViewState();
}

class _SearchContentViewState extends State<_SearchContentView> {
  static const _pageSize = 100;
  static const _repo = SearchRepository();

  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<SearchHit> _hits = const [];
  bool _loading = false;
  bool _hasMore = false;
  int _offset = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
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

  void _onQueryChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _startSearch();
    });
  }

  Future<void> _startSearch() async {
    final q = _queryController.text.trim();
    if (q == _query) return;
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
            child: TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                hintText: 'Search verse text...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_query.isNotEmpty && _hits.isEmpty && !_loading)
            const Padding(padding: EdgeInsets.all(12), child: Text('No hits')),
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
                const repo = ReaderRepository();
                final bookName = repo.loadBookName(
                  dbPath: widget.dbPath,
                  bookId: h.bookId,
                );
                return ListTile(
                  title: Text('$bookName ${h.chapter}:${h.verse}'),
                  subtitle: Text(h.text),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
