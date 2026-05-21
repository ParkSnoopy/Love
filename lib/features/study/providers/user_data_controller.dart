import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_data_repository.dart';

final userDataDbPathProvider = Provider<String>((ref) => 'user_data.db');

final userDataRepositoryProvider = Provider<UserDataRepository>((ref) {
  return const UserDataRepository();
});

final userDataInitProvider = Provider<void>((ref) {
  final repo = ref.watch(userDataRepositoryProvider);
  final dbPath = ref.watch(userDataDbPathProvider);
  repo.init(dbPath);
});

final bookmarksProvider = FutureProvider<List<BookmarkEntry>>((ref) {
  ref.watch(userDataInitProvider);
  final repo = ref.watch(userDataRepositoryProvider);
  final dbPath = ref.watch(userDataDbPathProvider);
  return repo.loadBookmarks(dbPath: dbPath);
});

final highlightsProvider = FutureProvider<List<HighlightEntry>>((ref) {
  ref.watch(userDataInitProvider);
  final repo = ref.watch(userDataRepositoryProvider);
  final dbPath = ref.watch(userDataDbPathProvider);
  return repo.loadHighlights(dbPath: dbPath);
});

final notesProvider = FutureProvider<List<NoteEntry>>((ref) {
  ref.watch(userDataInitProvider);
  final repo = ref.watch(userDataRepositoryProvider);
  final dbPath = ref.watch(userDataDbPathProvider);
  return repo.loadAllNotes(dbPath: dbPath);
});
