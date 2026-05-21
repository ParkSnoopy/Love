import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_data_repository.dart';

final userDataDbPathProvider = Provider<String>((ref) => 'assets/data/user_data.db');

final userDataRepositoryProvider = Provider<UserDataRepository>((ref) {
  return const UserDataRepository();
});

final userDataInitProvider = Provider<void>((ref) {
  final repo = ref.watch(userDataRepositoryProvider);
  final dbPath = ref.watch(userDataDbPathProvider);
  repo.init(dbPath);
});
