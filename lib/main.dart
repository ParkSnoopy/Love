import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/font_controller.dart';
import 'data/import/import_error_presenter.dart';
import 'data/import/import_orchestrator.dart';
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
      home: const LibraryPage(),
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
  static const _importOrchestrator = ImportOrchestrator();
  late final Future<List<BiblePack>> _packsFuture =
      _manifestRepository.loadBiblePacksFromAsset();

  Future<void> _validateImport() async {
    try {
      await _importOrchestrator.runValidateOnly(
        bibleDbPath: 'assets/data/getbible/en_kjv.sqlite',
        commentaryDbPath: 'assets/data/comment/com_tsk.sqlite',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import validate OK')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = ImportErrorPresenter.toUserMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

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
    final activePackId = ref.watch(activeBiblePackIdProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReaderPage(
                    dbPath: 'assets/data/getbible/en_kjv.sqlite',
                  ),
                ),
              );
            },
            child: const Text('Reader'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SearchPage(
                    dbPath: 'assets/data/getbible/en_kjv.sqlite',
                  ),
                ),
              );
            },
            child: const Text('Search'),
          ),
          TextButton(
            onPressed: _validateImport,
            child: const Text('Validate Import'),
          ),
          if (activePackId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: Text('Active: $activePackId')),
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
                      onTap: () =>
                          ref.read(activeBiblePackIdProvider.notifier).select(p.id),
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
