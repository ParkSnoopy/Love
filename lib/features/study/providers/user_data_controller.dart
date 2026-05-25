import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../data/storage/app_storage.dart';
import '../data/user_data_repository.dart';

String _fallbackUserDataPath() {
  return p.join(fallbackAppDataPath(), 'user_data.db');
}

final userDataDbPathProvider = FutureProvider<String>((ref) async {
  try {
    final dir = await getAppDataDirectory();
    return p.join(dir.path, 'user_data.db');
  } catch (_) {
    return _fallbackUserDataPath();
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
