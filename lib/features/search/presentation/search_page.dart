import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/search_repository.dart';
import '../../reader/data/reader_repository.dart';
import '../../reader/providers/reader_controller.dart';
import '../../reader/providers/verse_selection_controller.dart';
import '../../reader/providers/commentary_visibility_provider.dart';
import '../../../data/storage/db_path_provider.dart';
import '../../library/providers/library_controller.dart';
import '../../library/domain/bible_pack.dart';
import '../../../data/import/zip_extractor.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbPathAsync = ref.watch(activeDbPathProvider);
    final commDbPathAsync = ref.watch(activeCommentaryDbPathProvider);

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
        return commDbPathAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
          data: (commDbPath) {
            return _SearchContentView(dbPath: dbPath, commentaryDbPath: commDbPath);
          },
        );
      },
    );
  }
}

class _SearchContentView extends ConsumerStatefulWidget {
  const _SearchContentView({
    required this.dbPath,
    required this.commentaryDbPath,
  });

  final String dbPath;
  final String? commentaryDbPath;

  @override
  ConsumerState<_SearchContentView> createState() => _SearchContentViewState();
}

class _SearchContentViewState extends ConsumerState<_SearchContentView> {
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
  String _selectedRange = 'all'; // 'all', 'ot', 'nt', 'commentary'
  String _selectedLanguage = 'active'; // 'active' or specific language

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

  Future<String?> _getOrExtractDbPath(BiblePack pack) async {
    final manifestFile = pack.file;
    final localCandidates = [
      'assets/data/$manifestFile',
      p.join(Directory.current.path, 'assets/data', manifestFile),
    ];
    for (final path in localCandidates) {
      if (File(path).existsSync()) return path;
    }

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final targetPath = p.join(docsDir.path, 'bible_data', manifestFile);
      final targetFile = File(targetPath);
      if (targetFile.existsSync()) {
        return targetPath;
      }

      const extractor = ZipExtractor();
      await extractor.extractFile(
        targetZipPath: manifestFile,
        destinationPath: targetPath,
      );
      return targetPath;
    } catch (_) {
      try {
        final targetPath = p.join(Directory.current.path, 'assets/data', manifestFile);
        if (File(targetPath).existsSync()) return targetPath;
      } catch (_) {}
      return null;
    }
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) return;
    final isComm = _selectedRange == 'commentary';

    setState(() => _loading = true);
    try {
      final nextOffset = reset ? 0 : _offset;
      int? bookIdStart;
      int? bookIdEnd;
      if (_selectedRange == 'ot') {
        bookIdStart = 1;
        bookIdEnd = 39;
      } else if (_selectedRange == 'nt') {
        bookIdStart = 40;
        bookIdEnd = 66;
      }

      final allHits = <SearchHit>[];
      if (_selectedLanguage == 'active') {
        final targetDbPath = isComm ? widget.commentaryDbPath : widget.dbPath;
        if (targetDbPath != null) {
          final page = _repo.searchLike(
            dbPath: targetDbPath,
            query: _query,
            limit: _pageSize,
            offset: nextOffset,
            bookIdStart: bookIdStart,
            bookIdEnd: bookIdEnd,
          );
          allHits.addAll(page);
        }
        setState(() {
          _hits = reset ? allHits : [..._hits, ...allHits];
          _offset = nextOffset + allHits.length;
          _hasMore = allHits.length == _pageSize;
        });
      } else {
        final packs = ref.read(biblePacksProvider).asData?.value ?? [];
        final matchingPacks = packs.where((p) {
          if (isComm) {
            return p.type == 'commentary' && p.language == _selectedLanguage;
          } else {
            return p.type == 'bible' && p.language == _selectedLanguage;
          }
        }).toList();

        final tempHits = <SearchHit>[];
        for (final pack in matchingPacks) {
          final path = await _getOrExtractDbPath(pack);
          if (path == null) continue;
          final page = _repo.searchLike(
            dbPath: path,
            query: _query,
            limit: 1000,
            offset: 0,
            bookIdStart: bookIdStart,
            bookIdEnd: bookIdEnd,
          );
          for (final h in page) {
            tempHits.add(SearchHit(
              bookId: h.bookId,
              chapter: h.chapter,
              verse: h.verse,
              text: h.text,
              bibleName: pack.shortName,
            ));
          }
        }

        tempHits.sort((a, b) {
          if (a.bookId != b.bookId) return a.bookId.compareTo(b.bookId);
          if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
          if (a.verse != b.verse) return a.verse.compareTo(b.verse);
          return (a.bibleName ?? '').compareTo(b.bibleName ?? '');
        });

        final sliced = tempHits.skip(nextOffset).take(_pageSize).toList();
        setState(() {
          _hits = reset ? sliced : [..._hits, ...sliced];
          _offset = nextOffset + sliced.length;
          _hasMore = nextOffset + sliced.length < tempHits.length;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildRangeChip(String label, String value) {
    final isSelected = _selectedRange == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedRange = value;
            _selectedLanguage = 'active'; // Reset language when scope changes
            _hits = const [];
            _offset = 0;
            _hasMore = false;
          });
          _loadMore(reset: true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isComm = _selectedRange == 'commentary';
    final packsAsync = ref.watch(biblePacksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (packs) {
          final languages = packs
              .where((p) => isComm ? p.type == 'commentary' : p.type == 'bible')
              .map((p) => p.language)
              .toSet()
              .toList();
          languages.sort();

          return Column(
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
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRangeChip('성경 전체', 'all'),
                      const SizedBox(width: 8),
                      _buildRangeChip('구약 (OT)', 'ot'),
                      const SizedBox(width: 8),
                      _buildRangeChip('신약 (NT)', 'nt'),
                      const SizedBox(width: 8),
                      _buildRangeChip('주석', 'commentary'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.language, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('언어 범위: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLanguage,
                            isDense: true,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(
                                value: 'active',
                                child: Text(isComm ? '현재 설정된 주석만' : '현재 설정된 번역만'),
                              ),
                              ...languages.map((lang) => DropdownMenuItem(
                                value: lang,
                                child: Text(isComm ? '$lang 주석 전체' : '$lang 번역 전체'),
                              )),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedLanguage = val;
                                  _hits = const [];
                                  _offset = 0;
                                  _hasMore = false;
                                });
                                _loadMore(reset: true);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isComm && widget.commentaryDbPath == null && _selectedLanguage == 'active')
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    '선택된 주석이 없습니다. 설정/라이브러리에서 주석을 선택해주세요.',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_query.isNotEmpty && _hits.isEmpty && !_loading && !(isComm && widget.commentaryDbPath == null && _selectedLanguage == 'active'))
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
                    final versionPrefix = h.bibleName != null ? '[${h.bibleName}] ' : '';
                    final titleText = isComm
                        ? '[주석] $versionPrefix$bookName ${h.chapter}:${h.verse}'
                        : '$versionPrefix$bookName ${h.chapter}:${h.verse}';

                    return ListTile(
                      title: Text(titleText),
                      subtitle: Text(h.text),
                      onTap: () {
                        final targetKey = VerseKey(
                          bookId: h.bookId,
                          chapter: h.chapter,
                          verse: h.verse,
                        );

                        if (h.bibleName != null) {
                          final match = packs.where((p) => p.shortName == h.bibleName || p.name == h.bibleName);
                          if (match.isNotEmpty) {
                            final pack = match.first;
                            if (pack.type == 'bible') {
                              ref.read(activeBibleSelectionProvider.notifier).select(
                                    id: pack.id,
                                    file: pack.file,
                                    name: pack.name,
                                  );
                            } else if (pack.type == 'commentary') {
                              ref.read(activeCommentarySelectionProvider.notifier).select(
                                    id: pack.id,
                                    file: pack.file,
                                    name: pack.name,
                                  );
                            }
                          }
                        }

                        ref.read(readerRefProvider.notifier).jumpTo(
                              bookId: h.bookId,
                              chapter: h.chapter,
                            );
                        ref.read(verseSelectionProvider.notifier).clear();
                        ref.read(verseSelectionProvider.notifier).tap(targetKey);
                        ref.read(targetScrollVerseProvider.notifier).state = targetKey;

                        if (isComm) {
                          ref.read(commentaryVisibilityProvider.notifier).show();
                          ref.read(targetScrollCommentaryVerseProvider.notifier).state = h.verse;
                        }

                        context.go('/reader');
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
