import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/bible_pack.dart';
import '../domain/manifest_repository.dart';
import '../providers/library_controller.dart';
import '../../../app/theme_controller.dart';
import '../../../app/font_controller.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  static const _manifestRepository = ManifestRepository();
  late final Future<List<BiblePack>> _packsFuture = _manifestRepository
      .loadBiblePacksFromAsset();

  String _filter = '';
  final _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  String _getFontLabel(FontType type) => switch (type) {
    FontType.sans => 'Sans',
    FontType.serif => 'Serif',
    FontType.mono => 'Mono',
  };

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final fontType = ref.watch(fontTypeProvider);
    final activeSelectionAsync = ref.watch(activeBibleSelectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          if (activeSelectionAsync.asData?.value != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  'Active: ${activeSelectionAsync.asData!.value!.id}',
                ),
              ),
            ),
          IconButton(
            tooltip: 'Theme: ${_themeLabel(themeMode)}',
            onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          IconButton(
            tooltip: 'Font: ${_getFontLabel(fontType)}',
            onPressed: () => ref.read(fontTypeProvider.notifier).cycle(),
            icon: const Icon(Icons.font_download_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: 'Filter by language, source, or name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _filter = '';
                          _filterController.clear();
                        }),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) =>
                  setState(() => _filter = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<BiblePack>>(
              future: _packsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Load failed: ${snapshot.error}'));
                }
                final packs = snapshot.data ?? const <BiblePack>[];
                if (packs.isEmpty) {
                  return const Center(child: Text('No packs loaded'));
                }

                if (_filter.isNotEmpty) {
                  final filtered = packs
                      .where(
                        (p) =>
                            p.language.toLowerCase().contains(_filter) ||
                            p.source.toLowerCase().contains(_filter) ||
                            p.name.toLowerCase().contains(_filter) ||
                            p.shortName.toLowerCase().contains(_filter),
                      )
                      .toList();
                  return _buildFlatList(filtered);
                }

                return _buildGroupedList(packs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatList(List<BiblePack> packs) {
    if (packs.isEmpty) return const Center(child: Text('No matches found'));
    return ListView.separated(
      itemCount: packs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildPackTile(packs[index]),
    );
  }

  Widget _buildGroupedList(List<BiblePack> packs) {
    final groupsByType = groupBy(packs, (p) => p.type);
    final sortedTypes = groupsByType.keys.toList()..sort();

    return ListView(
      children: sortedTypes.map((type) {
        final packsInType = groupsByType[type]!;
        final groupsBySource = groupBy(packsInType, (p) => p.source);
        final sortedSources = groupsBySource.keys.toList()..sort();

        return ExpansionTile(
          title: Text(
            type.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          children: sortedSources.map((source) {
            final packsInSource = groupsBySource[source]!;
            return ExpansionTile(
              title: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(source),
              ),
              children: packsInSource.map(_buildPackTile).toList(),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildPackTile(BiblePack p) {
    return ListTile(
      onTap: () => ref
          .read(activeBibleSelectionProvider.notifier)
          .select(id: p.id, file: p.file),
      title: Text(p.shortName),
      subtitle: Text('${p.language} - ${p.name}'),
      trailing: Text(p.id),
    );
  }
}
