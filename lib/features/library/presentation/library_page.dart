import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/bible_pack.dart';
import '../domain/manifest_repository.dart';
import '../providers/library_controller.dart';
import '../../../app/theme_controller.dart';
import '../../../app/font_controller.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  String _getFontLabel(FontType type) => switch (type) {
    FontType.sans => 'Sans-Serif',
    FontType.serif => 'Serif',
    FontType.mono => 'Monospace',
  };

  IconData _themeIcon(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };

  IconData _fontIcon(FontType type) => switch (type) {
    FontType.sans => Icons.font_download_outlined,
    FontType.serif => Icons.font_download,
    FontType.mono => Icons.integration_instructions_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final fontType = ref.watch(fontTypeProvider);
    final activeBibleAsync = ref.watch(activeBibleSelectionProvider);
    final activeCommentaryAsync = ref.watch(activeCommentarySelectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildSectionHeader('Appearance'),
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(_themeIcon(themeMode), color: Theme.of(context).colorScheme.primary),
                  title: const Text('Theme Mode'),
                  subtitle: Text(_themeLabel(themeMode)),
                  trailing: const Icon(Icons.sync, size: 20),
                  onTap: () => ref.read(themeModeProvider.notifier).cycle(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(_fontIcon(fontType), color: Theme.of(context).colorScheme.primary),
                  title: const Text('Reader Font'),
                  subtitle: Text(_getFontLabel(fontType)),
                  trailing: const Icon(Icons.sync, size: 20),
                  onTap: () => ref.read(fontTypeProvider.notifier).cycle(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Bibles & Commentaries'),
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                activeBibleAsync.when(
                  data: (activeBible) => ListTile(
                    leading: Icon(Icons.book, color: Theme.of(context).colorScheme.primary),
                    title: const Text('Active Bible'),
                    subtitle: Text(
                      activeBible != null ? activeBible.name : 'Select Bible',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showBibleSelection(context),
                  ),
                  loading: () => const ListTile(
                    leading: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Loading Bible...'),
                  ),
                  error: (err, stack) => ListTile(
                    title: const Text('Error loading Bible'),
                    subtitle: Text(err.toString()),
                  ),
                ),
                const Divider(height: 1),
                activeCommentaryAsync.when(
                  data: (activeCommentary) => ListTile(
                    leading: Icon(Icons.comment_bank, color: Theme.of(context).colorScheme.primary),
                    title: const Text('Active Commentary'),
                    subtitle: Text(
                      activeCommentary != null ? activeCommentary.name : 'None (Off)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: activeCommentary != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                tooltip: 'Turn off commentary',
                                onPressed: () {
                                  ref.read(activeCommentarySelectionProvider.notifier).clear();
                                },
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => _showCommentarySelection(context),
                  ),
                  loading: () => const ListTile(
                    leading: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Loading Commentary...'),
                  ),
                  error: (err, stack) => ListTile(
                    title: const Text('Error loading Commentary'),
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
  ConsumerState<_BibleSelectionSheet> createState() => _BibleSelectionSheetState();
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
              const Text(
                'Select Bible Translation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by language, source, or name...',
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
                              p.shortName.toLowerCase().contains(_searchQuery) ||
                              p.language.toLowerCase().contains(_searchQuery) ||
                              p.source.toLowerCase().contains(_searchQuery);
                        })
                        .toList();

                    if (bibles.isEmpty) {
                      return const Center(child: Text('No translations found'));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: bibles.length,
                      itemBuilder: (context, index) {
                        final p = bibles[index];
                        final isSelected = activeBible?.id == p.id;
                        return ListTile(
                          selected: isSelected,
                          title: Text(
                            p.shortName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${p.language} • ${p.name}'),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () async {
                            await ref
                                .read(activeBibleSelectionProvider.notifier)
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

class _CommentarySelectionSheet extends ConsumerStatefulWidget {
  const _CommentarySelectionSheet();

  @override
  ConsumerState<_CommentarySelectionSheet> createState() => _CommentarySelectionSheetState();
}

class _CommentarySelectionSheetState extends ConsumerState<_CommentarySelectionSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCommentary = ref.watch(activeCommentarySelectionProvider).asData?.value;

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
              const Text(
                'Select Commentary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by language, source, or name...',
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
                              p.shortName.toLowerCase().contains(_searchQuery) ||
                              p.language.toLowerCase().contains(_searchQuery) ||
                              p.source.toLowerCase().contains(_searchQuery);
                        })
                        .toList();

                    if (commentaries.isEmpty) {
                      return const Center(child: Text('No commentaries found'));
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
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () async {
                            await ref
                                .read(activeCommentarySelectionProvider.notifier)
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
