import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/manifest_repository.dart';

class ActiveBibleSelection {
  const ActiveBibleSelection({required this.id, required this.file});

  final String id;
  final String file;
}

final activeBibleSelectionProvider =
    AsyncNotifierProvider<
      ActiveBibleSelectionController,
      ActiveBibleSelection?
    >(ActiveBibleSelectionController.new);

class ActiveBibleSelectionController
    extends AsyncNotifier<ActiveBibleSelection?> {
  static const _prefsKeyId = 'active_bible_id';
  static const _prefsKeyFile = 'active_bible_file';

  @override
  Future<ActiveBibleSelection?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefsKeyId);
    final savedFile = prefs.getString(_prefsKeyFile);

    if (savedId != null &&
        savedFile != null &&
        await _looksInstalled(savedFile)) {
      return ActiveBibleSelection(id: savedId, file: savedFile);
    }

    const repo = ManifestRepository();
    final packs = await repo.loadBiblePacksFromAsset();
    for (final p in packs) {
      if (await _looksInstalled(p.file)) {
        final picked = ActiveBibleSelection(id: p.id, file: p.file);
        await _save(picked);
        return picked;
      }
    }

    return null;
  }

  Future<void> select({required String id, required String file}) async {
    final picked = ActiveBibleSelection(id: id, file: file);
    state = AsyncData(picked);
    await _save(picked);
  }

  Future<bool> _looksInstalled(String manifestFile) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final candidates = <String>[
        'assets/data/$manifestFile',
        p.join(Directory.current.path, 'assets/data', manifestFile),
        p.join(docsDir.path, 'bible_data', manifestFile),
      ];
      return candidates.any((path) => File(path).existsSync());
    } catch (_) {
      // In tests, getApplicationDocumentsDirectory might fail
      return [
        'assets/data/$manifestFile',
        p.join(Directory.current.path, 'assets/data', manifestFile),
      ].any((path) => File(path).existsSync());
    }
  }

  Future<void> _save(ActiveBibleSelection picked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyId, picked.id);
    await prefs.setString(_prefsKeyFile, picked.file);
  }
}
