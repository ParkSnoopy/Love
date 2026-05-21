import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/manifest_repository.dart';

class ActiveBibleSelection {
  const ActiveBibleSelection({required this.id, required this.file});

  final String id;
  final String file;
}

final activeBibleSelectionProvider =
    AsyncNotifierProvider<ActiveBibleSelectionController, ActiveBibleSelection?>(
      ActiveBibleSelectionController.new,
    );

class ActiveBibleSelectionController extends AsyncNotifier<ActiveBibleSelection?> {
  static const _prefsKeyId = 'active_bible_id';
  static const _prefsKeyFile = 'active_bible_file';

  @override
  Future<ActiveBibleSelection?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefsKeyId);
    final savedFile = prefs.getString(_prefsKeyFile);

    if (savedId != null && savedFile != null && _looksInstalled(savedFile)) {
      return ActiveBibleSelection(id: savedId, file: savedFile);
    }

    const repo = ManifestRepository();
    final packs = await repo.loadBiblePacksFromAsset();
    for (final p in packs) {
      if (_looksInstalled(p.file)) {
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

  bool _looksInstalled(String manifestFile) {
    final candidates = <String>[
      'assets/data/$manifestFile',
      '${Directory.current.path}/assets/data/$manifestFile',
      '${Directory.current.path}/data/flutter_assets/assets/data/$manifestFile',
      '${File(Platform.resolvedExecutable).parent.path}/data/flutter_assets/assets/data/$manifestFile',
    ];
    return candidates.any((p) => File(p).existsSync());
  }

  Future<void> _save(ActiveBibleSelection picked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyId, picked.id);
    await prefs.setString(_prefsKeyFile, picked.file);
  }
}
