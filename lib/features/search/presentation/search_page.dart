import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import '../data/search_repository.dart';
import '../../reader/data/reader_repository.dart';
import '../../reader/providers/reader_controller.dart';
import '../../reader/providers/verse_selection_controller.dart';
import '../../reader/providers/commentary_visibility_provider.dart';
import '../../../data/storage/db_path_provider.dart';
import '../../../data/storage/db_asset_paths.dart';
import '../../../data/storage/app_storage.dart';
import '../../library/providers/library_controller.dart';
import '../../library/domain/bible_pack.dart';
import '../../../data/import/zip_extractor.dart';
import '../../../app/font_controller.dart';
import '../../../app/reader_settings_controller.dart';
import '../../../app/app_localizations.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbPathAsync = ref.watch(activeDbPathProvider);
    final commDbPathAsync = ref.watch(activeCommentaryDbPathProvider);

    return dbPathAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text(context.l10n.error(err)))),
      data: (dbPath) {
        if (dbPath == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.t('noBibleSelected'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return commDbPathAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) =>
              Scaffold(body: Center(child: Text(context.l10n.error(err)))),
          data: (commDbPath) {
            return _SearchContentView(
              dbPath: dbPath,
              commentaryDbPath: commDbPath,
            );
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
    final localCandidates = localDbCandidates(
      manifestFile: manifestFile,
      type: pack.type,
    );
    for (final path in localCandidates) {
      if (File(path).existsSync()) return path;
    }

    try {
      final appDataDir = await getAppDataDirectory();
      final targetPath = appDbPath(
        appDataPath: appDataDir.path,
        manifestFile: manifestFile,
        type: pack.type,
      );
      final targetFile = File(targetPath);
      if (targetFile.existsSync()) {
        return targetPath;
      }

      const extractor = ZipExtractor();
      await extractor.extractFile(
        targetZipPath: dbZipPath(manifestFile: manifestFile, type: pack.type),
        destinationPath: targetPath,
      );
      return targetPath;
    } catch (_) {
      try {
        final targetPath = p.join(
          Directory.current.path,
          'assets/data',
          dbAssetCategory(pack.type),
          manifestFile,
        );
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
            tempHits.add(
              SearchHit(
                bookId: h.bookId,
                chapter: h.chapter,
                verse: h.verse,
                text: h.text,
                bibleName: pack.shortName,
              ),
            );
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
    final l10n = context.l10n;
    final isComm = _selectedRange == 'commentary';
    final packsAsync = ref.watch(biblePacksProvider);
    final readerSettings =
        ref.watch(readerSettingsProvider).value ??
        const ReaderSettingsState(fontSize: 18.0, lineSpacing: 1.5);
    final fontType = ref.watch(fontTypeProvider).value ?? FontType.serif;
    final resultTextStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: fontFamilyForType(fontType),
          fontSize: readerSettings.fontSize,
          height: readerSettings.lineSpacing,
        ) ??
        TextStyle(
          fontFamily: fontFamilyForType(fontType),
          fontSize: readerSettings.fontSize,
          height: readerSettings.lineSpacing,
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('search'))),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(l10n.error(err))),
        data: (packs) {
          final languages = packs
              .where((p) => isComm ? p.type == 'commentary' : p.type == 'bible')
              .map((p) => p.language)
              .toSet()
              .toList();
          languages.sort();
          final languageOptions = [...languages];
          if (_selectedLanguage != 'active' &&
              !languageOptions.contains(_selectedLanguage)) {
            languageOptions.insert(0, _selectedLanguage);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: l10n.t('searchVerseText'),
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRangeChip(l10n.t('allBible'), 'all'),
                      const SizedBox(width: 8),
                      _buildRangeChip(l10n.t('ot'), 'ot'),
                      const SizedBox(width: 8),
                      _buildRangeChip(l10n.t('nt'), 'nt'),
                      const SizedBox(width: 8),
                      _buildRangeChip(l10n.t('commentary'), 'commentary'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.language,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.t('languageRange'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                                child: Text(
                                  l10n.currentLanguageOnly(commentary: isComm),
                                ),
                              ),
                              ...languageOptions.map((lang) {
                                final isUnavailable = !languages.contains(lang);
                                return DropdownMenuItem(
                                  value: lang,
                                  child: Text(
                                    isUnavailable
                                        ? l10n.unavailableLanguage(lang)
                                        : l10n.wholeLanguage(
                                            lang,
                                            commentary: isComm,
                                          ),
                                  ),
                                );
                              }),
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
              if (isComm &&
                  widget.commentaryDbPath == null &&
                  _selectedLanguage == 'active')
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    l10n.t('noActiveCommentary'),
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_query.isNotEmpty &&
                  _hits.isEmpty &&
                  !_loading &&
                  !(isComm &&
                      widget.commentaryDbPath == null &&
                      _selectedLanguage == 'active'))
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l10n.t('noHits')),
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
                    const repo = ReaderRepository();
                    final bookName = repo.loadBookName(
                      dbPath: widget.dbPath,
                      bookId: h.bookId,
                    );
                    final versionPrefix = h.bibleName != null
                        ? '[${h.bibleName}] '
                        : '';
                    final titleText = isComm
                        ? '[${l10n.t('commentaryPrefix')}] $versionPrefix$bookName ${h.chapter}:${h.verse}'
                        : '$versionPrefix$bookName ${h.chapter}:${h.verse}';

                    return ListTile(
                      title: Text(titleText),
                      subtitle: Text.rich(
                        TextSpan(
                          style: resultTextStyle,
                          children: _highlightQuerySpans(
                            text: h.text,
                            query: _query,
                            baseStyle: resultTextStyle,
                            highlightStyle: resultTextStyle.copyWith(
                              fontStyle: FontStyle.normal,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      onTap: () async {
                        final targetKey = VerseKey(
                          bookId: h.bookId,
                          chapter: h.chapter,
                          verse: h.verse,
                        );

                        if (h.bibleName != null) {
                          final expectedType = isComm ? 'commentary' : 'bible';
                          final match = packs.where(
                            (p) =>
                                p.type == expectedType &&
                                (p.shortName == h.bibleName ||
                                    p.name == h.bibleName),
                          );
                          if (match.isNotEmpty) {
                            final pack = match.first;
                            if (pack.type == 'bible') {
                              await ref
                                  .read(activeBibleSelectionProvider.notifier)
                                  .select(
                                    id: pack.id,
                                    file: pack.file,
                                    name: pack.name,
                                  );
                              await ref.read(activeDbPathProvider.future);
                            } else if (pack.type == 'commentary') {
                              await ref
                                  .read(
                                    activeCommentarySelectionProvider.notifier,
                                  )
                                  .select(
                                    id: pack.id,
                                    file: pack.file,
                                    name: pack.name,
                                  );
                              await ref.read(
                                activeCommentaryDbPathProvider.future,
                              );
                            }
                          }
                        }

                        await ref
                            .read(readerRefProvider.notifier)
                            .jumpTo(bookId: h.bookId, chapter: h.chapter);
                        ref.read(verseSelectionProvider.notifier).clear();
                        ref
                            .read(verseSelectionProvider.notifier)
                            .tap(targetKey);
                        ref.read(targetScrollVerseProvider.notifier).state =
                            targetKey;

                        if (isComm) {
                          ref
                              .read(commentaryVisibilityProvider.notifier)
                              .show();
                          ref
                              .read(
                                targetScrollCommentaryVerseProvider.notifier,
                              )
                              .state = h
                              .verse;
                        }

                        if (context.mounted) context.go('/reader');
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

List<TextSpan> _highlightQuerySpans({
  required String text,
  required String query,
  required TextStyle baseStyle,
  required TextStyle highlightStyle,
}) {
  final needle = query.trim();
  if (needle.isEmpty) return [TextSpan(text: text, style: baseStyle)];

  final lowerText = text.toLowerCase();
  final lowerNeedle = needle.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;

  while (start < text.length) {
    final match = lowerText.indexOf(lowerNeedle, start);
    if (match == -1) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      break;
    }
    if (match > start) {
      spans.add(TextSpan(text: text.substring(start, match), style: baseStyle));
    }
    final end = match + needle.length;
    spans.add(
      TextSpan(text: text.substring(match, end), style: highlightStyle),
    );
    start = end;
  }

  return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
}
