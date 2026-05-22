import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/user_data_repository.dart';

String _desktopFallbackUserDataPath() {
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return p.join(home, '.local', 'share', 'love', 'user_data.db');
  }
  return p.join(Directory.current.path, '.love', 'user_data.db');
}

final userDataDbPathProvider = FutureProvider<String>((ref) async {
  try {
    final dir = Platform.isAndroid || Platform.isIOS
        ? await getApplicationDocumentsDirectory()
        : await getApplicationSupportDirectory();
    return p.join(dir.path, 'user_data.db');
  } catch (_) {
    return _desktopFallbackUserDataPath();
  }
});

final userDataRepositoryProvider = Provider<UserDataRepository>((ref) {
  return const UserDataRepository();
});

final userDataInitProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(userDataRepositoryProvider);
  final dbPath = await ref.watch(userDataDbPathProvider.future);
  repo.init(dbPath);
  return dbPath;
});

final bookmarksProvider = FutureProvider<List<BookmarkEntry>>((ref) async {
  final dbPath = await ref.watch(userDataInitProvider.future);
  final repo = ref.watch(userDataRepositoryProvider);
  return repo.loadBookmarks(dbPath: dbPath);
});

final highlightsProvider = FutureProvider<List<HighlightEntry>>((ref) async {
  final dbPath = await ref.watch(userDataInitProvider.future);
  final repo = ref.watch(userDataRepositoryProvider);
  return repo.loadHighlights(dbPath: dbPath);
});

final notesProvider = FutureProvider<List<NoteEntry>>((ref) async {
  final dbPath = await ref.watch(userDataInitProvider.future);
  final repo = ref.watch(userDataRepositoryProvider);
  return repo.loadAllNotes(dbPath: dbPath);
});
