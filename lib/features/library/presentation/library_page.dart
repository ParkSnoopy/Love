import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/bible_pack.dart';
import '../domain/manifest_repository.dart';
import '../providers/library_controller.dart';
import '../../reader/presentation/commentary_intro_sheet.dart';
import '../../../data/storage/db_path_provider.dart';
import '../../../app/theme_controller.dart';
import '../../../app/font_controller.dart';
import '../../../app/locale_controller.dart';
import '../../../app/reader_settings_controller.dart';
import '../../../app/app_localizations.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  String _themeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
    ThemeMode.system => l10n.t('system'),
    ThemeMode.light => l10n.t('light'),
    ThemeMode.dark => l10n.t('dark'),
  };

  String _fontLabel(AppLocalizations l10n, FontType type) => switch (type) {
    FontType.sans => l10n.t('sansSerif'),
    FontType.serif => l10n.t('serif'),
  };

  String _languageLabel(AppLocalizations l10n, Locale? locale) =>
      switch (locale?.languageCode) {
        'ko' => l10n.t('korean'),
        'en' => l10n.t('english'),
        'zh' => l10n.t('simplifiedChinese'),
        'ja' => l10n.t('japanese'),
        _ => l10n.t('system'),
      };

  IconData _themeIcon(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };

  IconData _fontIcon(FontType type) => switch (type) {
    FontType.sans => Icons.font_download_outlined,
    FontType.serif => Icons.font_download,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final locale = ref.watch(appLocaleProvider).value;
    final fontType = ref.watch(fontTypeProvider).value ?? FontType.serif;
    final activeBibleAsync = ref.watch(activeBibleSelectionProvider);
    final activeCommentaryAsync = ref.watch(activeCommentarySelectionProvider);
    final activeBibleDbPath = ref.watch(activeDbPathProvider).asData?.value;
    final readerSettingsAsync = ref.watch(readerSettingsProvider);
    final readerSettings =
        readerSettingsAsync.value ??
        const ReaderSettingsState(fontSize: 18.0, lineSpacing: 1.5);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('settings')),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildSectionHeader(l10n.t('appearance')),
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _themeIcon(themeMode),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(l10n.t('themeMode')),
                  subtitle: Text(_themeLabel(l10n, themeMode)),
                  trailing: const Icon(Icons.sync, size: 20),
                  onTap: () => ref.read(themeModeProvider.notifier).cycle(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.language,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(l10n.t('appLanguage')),
                  subtitle: Text(_languageLabel(l10n, locale)),
                  trailing: const Icon(Icons.sync, size: 20),
                  onTap: () => ref.read(appLocaleProvider.notifier).cycle(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    _fontIcon(fontType),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(l10n.t('readerFont')),
                  subtitle: Text(_fontLabel(l10n, fontType)),
                  trailing: const Icon(Icons.sync, size: 20),
                  onTap: () => ref.read(fontTypeProvider.notifier).cycle(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(l10n.t('readerTypography')),
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.t('fontSize'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${readerSettings.fontSize.toStringAsFixed(1)} px',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: readerSettings.fontSize,
                    min: 12.0,
                    max: 30.0,
                    divisions: 18,
                    onChanged: (val) {
                      ref
                          .read(readerSettingsProvider.notifier)
                          .setFontSize(val);
                    },
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.t('lineSpacing'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${readerSettings.lineSpacing.toStringAsFixed(2)} x',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: readerSettings.lineSpacing,
                    min: 1.0,
                    max: 2.5,
                    divisions: 15,
                    onChanged: (val) {
                      ref
                          .read(readerSettingsProvider.notifier)
                          .setLineSpacing(val);
                    },
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.t('uiScale'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(readerSettings.uiScale * 100).round()}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: readerSettings.uiScale,
                    min: 0.85,
                    max: 1.25,
                    divisions: 8,
                    onChanged: (val) {
                      ref.read(readerSettingsProvider.notifier).setUiScale(val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(l10n.t('biblesCommentaries')),
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                activeBibleAsync.when(
                  data: (activeBible) => ListTile(
                    leading: Icon(
                      Icons.book,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(l10n.t('activeBible')),
                    subtitle: Text(
                      activeBible != null
                          ? activeBible.name
                          : l10n.t('selectBible'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showBibleSelection(context),
                  ),
                  loading: () => ListTile(
                    leading: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text(l10n.t('loadingBible')),
                  ),
                  error: (err, stack) => ListTile(
                    title: Text(l10n.t('errorLoadingBible')),
                    subtitle: Text(err.toString()),
                  ),
                ),
                const Divider(height: 1),
                activeCommentaryAsync.when(
                  data: (activeCommentary) => ListTile(
                    leading: Icon(
                      Icons.comment_bank,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(l10n.t('activeCommentary')),
                    subtitle: Text(
                      activeCommentary != null
                          ? activeCommentary.name
                          : l10n.t('noneOff'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: activeCommentary != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.info_outline, size: 20),
                                tooltip: l10n.t('viewIntro'),
                                onPressed: () async {
                                  final activeBibleDbPathFuture = ref.read(
                                    activeDbPathProvider.future,
                                  );
                                  final bibleDbPath =
                                      activeBibleDbPath ??
                                      await activeBibleDbPathFuture;
                                  if (!context.mounted) return;
                                  showCommentaryIntros(
                                    context,
                                    activeCommentary.file,
                                    activeCommentary.name,
                                    bibleDbPath,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                tooltip: l10n.t('turnOffCommentary'),
                                onPressed: () {
                                  ref
                                      .read(
                                        activeCommentarySelectionProvider
                                            .notifier,
                                      )
                                      .clear();
                                },
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => _showCommentarySelection(context),
                  ),
                  loading: () => ListTile(
                    leading: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text(l10n.t('loadingCommentary')),
                  ),
                  error: (err, stack) => ListTile(
                    title: Text(l10n.t('errorLoadingCommentary')),
                    subtitle: Text(err.toString()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  void _showBibleSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _BibleSelectionSheet(),
    );
  }

  void _showCommentarySelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CommentarySelectionSheet(),
    );
  }
}

class _BibleSelectionSheet extends ConsumerStatefulWidget {
  const _BibleSelectionSheet();

  @override
  ConsumerState<_BibleSelectionSheet> createState() =>
      _BibleSelectionSheetState();
}

class _BibleSelectionSheetState extends ConsumerState<_BibleSelectionSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeBible = ref.watch(activeBibleSelectionProvider).asData?.value;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('selectBibleTranslation'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.t('searchByPack'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                ),
              ),
              Expanded(
                child: FutureBuilder<List<BiblePack>>(
                  future: const ManifestRepository().loadBiblePacksFromAsset(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final bibles = snapshot.data!
                        .where((p) => p.type == 'bible')
                        .where((p) {
                          if (_searchQuery.isEmpty) return true;
                          return p.name.toLowerCase().contains(_searchQuery) ||
                              p.shortName.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              p.language.toLowerCase().contains(_searchQuery) ||
                              p.source.toLowerCase().contains(_searchQuery);
                        })
                        .toList();

                    if (bibles.isEmpty) {
                      return Center(child: Text(l10n.t('noTranslationsFound')));
                    }

                    final grouped = <String, List<BiblePack>>{};
                    for (final pack in bibles) {
                      grouped.putIfAbsent(pack.language, () => []).add(pack);
                    }
                    final languages = grouped.keys.toList()
                      ..sort((a, b) {
                        if (a == 'Korean') return -1;
                        if (b == 'Korean') return 1;
                        return a.compareTo(b);
                      });

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: languages.length,
                      itemBuilder: (context, index) {
                        final language = languages[index];
                        final packs = grouped[language]!;
                        final hasSelected = packs.any(
                          (p) => activeBible?.id == p.id,
                        );
                        return ExpansionTile(
                          initiallyExpanded:
                              hasSelected || _searchQuery.isNotEmpty,
                          title: Text(
                            language,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${packs.length} ${l10n.t('versions')}',
                          ),
                          children: [
                            for (final p in packs)
                              ListTile(
                                selected: activeBible?.id == p.id,
                                contentPadding: const EdgeInsets.only(
                                  left: 32,
                                  right: 16,
                                ),
                                title: Text(
                                  p.shortName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(p.name),
                                trailing: activeBible?.id == p.id
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      )
                                    : null,
                                onTap: () async {
                                  await ref
                                      .read(
                                        activeBibleSelectionProvider.notifier,
                                      )
                                      .select(
                                        id: p.id,
                                        file: p.file,
                                        name: p.name,
                                      );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentarySelectionSheet extends ConsumerStatefulWidget {
  const _CommentarySelectionSheet();

  @override
  ConsumerState<_CommentarySelectionSheet> createState() =>
      _CommentarySelectionSheetState();
}

class _CommentarySelectionSheetState
    extends ConsumerState<_CommentarySelectionSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeCommentary = ref
        .watch(activeCommentarySelectionProvider)
        .asData
        ?.value;
    final activeBibleDbPath = ref.watch(activeDbPathProvider).asData?.value;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('selectCommentary'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.t('searchByPack'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                ),
              ),
              Expanded(
                child: FutureBuilder<List<BiblePack>>(
                  future: const ManifestRepository().loadBiblePacksFromAsset(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final commentaries = snapshot.data!
                        .where((p) => p.type == 'commentary')
                        .where((p) {
                          if (_searchQuery.isEmpty) return true;
                          return p.name.toLowerCase().contains(_searchQuery) ||
                              p.shortName.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              p.language.toLowerCase().contains(_searchQuery) ||
                              p.source.toLowerCase().contains(_searchQuery);
                        })
                        .toList();

                    if (commentaries.isEmpty) {
                      return Center(child: Text(l10n.t('noCommentariesFound')));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: commentaries.length,
                      itemBuilder: (context, index) {
                        final p = commentaries[index];
                        final isSelected = activeCommentary?.id == p.id;
                        return ListTile(
                          selected: isSelected,
                          title: Text(
                            p.shortName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${p.language} • ${p.name}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.info_outline),
                                tooltip: l10n.t('viewIntro'),
                                onPressed: () async {
                                  final activeBibleDbPathFuture = ref.read(
                                    activeDbPathProvider.future,
                                  );
                                  final bibleDbPath =
                                      activeBibleDbPath ??
                                      await activeBibleDbPathFuture;
                                  if (!context.mounted) return;
                                  showCommentaryIntros(
                                    context,
                                    p.file,
                                    p.name,
                                    bibleDbPath,
                                  );
                                },
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                            ],
                          ),
                          onTap: () async {
                            await ref
                                .read(
                                  activeCommentarySelectionProvider.notifier,
                                )
                                .select(id: p.id, file: p.file, name: p.name);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
