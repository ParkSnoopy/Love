import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/font_controller.dart';
import 'app/theme_controller.dart';
import 'features/library/domain/bible_pack.dart';
import 'features/library/domain/manifest_repository.dart';
import 'features/library/providers/library_controller.dart';
import 'features/reader/presentation/reader_page.dart';
import 'features/search/presentation/search_page.dart';
import 'features/study/providers/user_data_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userDataInitProvider);
    final themeMode = ref.watch(themeModeProvider);
    final fontType = ref.watch(fontTypeProvider);
    final fontFamily = switch (fontType) {
      FontType.sans => 'NotoSansKR',
      FontType.serif => 'NotoSerifKR',
      FontType.mono => 'NanumGothicCoding',
    };
    return MaterialApp(
      title: 'Love',
      themeMode: themeMode,
      theme: ThemeData.light().copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: fontFamily),
      ),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: fontFamily),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  String _resolveDbPath(String manifestFile) {
    final candidates = <String>[
      'assets/data/$manifestFile',
      '${Directory.current.path}/assets/data/$manifestFile',
      '${Directory.current.path}/data/flutter_assets/assets/data/$manifestFile',
      '${File(Platform.resolvedExecutable).parent.path}/data/flutter_assets/assets/data/$manifestFile',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return candidates.first;
  }

  @override
  Widget build(BuildContext context) {
    final activeSelectionAsync = ref.watch(activeBibleSelectionProvider);
    final activeDbPath = _resolveDbPath(
      activeSelectionAsync.asData?.value?.file ?? 'nocr/ko_korkjv.sqlite',
    );
    final noInstalled =
        activeSelectionAsync.hasValue && activeSelectionAsync.asData?.value == null;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const LibraryPage(),
          noInstalled
              ? const _NoBibleInstalledView()
              : ReaderPage(dbPath: activeDbPath),
          noInstalled
              ? const _NoBibleInstalledView()
              : SearchPage(dbPath: activeDbPath),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Reader',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
        ],
      ),
    );
  }
}

class _NoBibleInstalledView extends StatelessWidget {
  const _NoBibleInstalledView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No installed Bible DB found.\nGo Library and select/install version first.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  static const _manifestRepository = ManifestRepository();
  late final Future<List<BiblePack>> _packsFuture =
      _manifestRepository.loadBiblePacksFromAsset();

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  String _fontLabel(FontType type) => switch (type) {
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
              child: Center(child: Text('Active: ${activeSelectionAsync.asData!.value!.id}')),
            ),
          IconButton(
            tooltip: 'Theme: ${_themeLabel(themeMode)}',
            onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          IconButton(
            tooltip: 'Font: ${_fontLabel(fontType)}',
            onPressed: () => ref.read(fontTypeProvider.notifier).cycle(),
            icon: const Icon(Icons.font_download_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text('Theme: ${_themeLabel(themeMode)}'),
                const SizedBox(width: 16),
                Text('Font: ${_fontLabel(fontType)}'),
              ],
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
                return ListView.separated(
                  itemCount: packs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = packs[index];
                    return ListTile(
                      onTap: () => ref
                          .read(activeBibleSelectionProvider.notifier)
                          .select(id: p.id, file: p.file),
                      title: Text(p.shortName),
                      subtitle: Text(p.language),
                      trailing: Text(p.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
