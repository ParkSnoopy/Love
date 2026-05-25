import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/app_preferences.dart';
import '../../../data/import/zip_extractor.dart';
import '../../../data/storage/app_storage.dart';
import '../../../data/storage/db_asset_paths.dart';

import '../domain/manifest_repository.dart';
import '../domain/bible_pack.dart';

final biblePacksProvider = FutureProvider<List<BiblePack>>((ref) async {
  const repo = ManifestRepository();
  return repo.loadBiblePacksFromAsset();
});

class ActiveBibleSelection {
  const ActiveBibleSelection({
    required this.id,
    required this.file,
    required this.name,
  });

  final String id;
  final String file;
  final String name;
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
  static const _prefsKeyName = 'active_bible_name';

  @override
  Future<ActiveBibleSelection?> build() async {
    final prefs = await AppPreferences.getInstance();
    final savedId = prefs.getString(_prefsKeyId);
    final savedFile = prefs.getString(_prefsKeyFile);
    final savedName = prefs.getString(_prefsKeyName);

    if (savedId != null && savedFile != null) {
      const repo = ManifestRepository();
      final packs = await repo.loadBiblePacksFromAsset();
      final existsInManifest = packs.any(
        (p) => p.id == savedId || p.file == savedFile,
      );
      if (existsInManifest || await _looksInstalled(savedFile, type: 'bible')) {
        String name = savedName ?? savedId;
        if (savedName == null) {
          final match = packs.where(
            (p) => p.id == savedId || p.file == savedFile,
          );
          if (match.isNotEmpty) {
            name = match.first.name;
          }
        }
        return ActiveBibleSelection(id: savedId, file: savedFile, name: name);
      }
    }

    const repo = ManifestRepository();
    final packs = await repo.loadBiblePacksFromAsset();
    for (final p in packs) {
      if (p.type == 'bible' && await _looksInstalled(p.file, type: p.type)) {
        final picked = ActiveBibleSelection(
          id: p.id,
          file: p.file,
          name: p.name,
        );
        await _save(picked);
        return picked;
      }
    }

    return null;
  }

  Future<void> select({
    required String id,
    required String file,
    required String name,
  }) async {
    final picked = ActiveBibleSelection(id: id, file: file, name: name);
    state = AsyncData(picked);
    await _save(picked);
  }

  Future<bool> _looksInstalled(
    String manifestFile, {
    required String type,
  }) async {
    try {
      final appDataDir = await getAppDataDirectory();
      final candidates = <String>[
        ...localDbCandidates(manifestFile: manifestFile, type: type),
        appDbPath(
          appDataPath: appDataDir.path,
          manifestFile: manifestFile,
          type: type,
        ),
      ];
      if (candidates.any((path) => File(path).existsSync())) return true;
      return const ZipExtractor().containsFile(
        targetZipPath: dbZipPath(manifestFile: manifestFile, type: type),
      );
    } catch (_) {
      // In tests, getApplicationSupportDirectory might fail
      return localDbCandidates(
        manifestFile: manifestFile,
        type: type,
      ).any((path) => File(path).existsSync());
    }
  }

  Future<void> _save(ActiveBibleSelection picked) async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setString(_prefsKeyId, picked.id);
    await prefs.setString(_prefsKeyFile, picked.file);
    await prefs.setString(_prefsKeyName, picked.name);
  }
}

class ActiveCommentarySelection {
  const ActiveCommentarySelection({
    required this.id,
    required this.file,
    required this.name,
  });

  final String id;
  final String file;
  final String name;
}

final activeCommentarySelectionProvider =
    AsyncNotifierProvider<
      ActiveCommentarySelectionController,
      ActiveCommentarySelection?
    >(ActiveCommentarySelectionController.new);

class ActiveCommentarySelectionController
    extends AsyncNotifier<ActiveCommentarySelection?> {
  static const _prefsKeyId = 'active_commentary_id';
  static const _prefsKeyFile = 'active_commentary_file';
  static const _prefsKeyName = 'active_commentary_name';

  @override
  Future<ActiveCommentarySelection?> build() async {
    final prefs = await AppPreferences.getInstance();
    final savedId = prefs.getString(_prefsKeyId);
    final savedFile = prefs.getString(_prefsKeyFile);
    final savedName = prefs.getString(_prefsKeyName);

    if (savedId != null && savedFile != null) {
      const repo = ManifestRepository();
      final packs = await repo.loadBiblePacksFromAsset();
      final existsInManifest = packs.any(
        (p) => p.id == savedId || p.file == savedFile,
      );
      if (existsInManifest ||
          await _looksInstalled(savedFile, type: 'commentary')) {
        String name = savedName ?? savedId;
        if (savedName == null) {
          final match = packs.where(
            (p) => p.id == savedId || p.file == savedFile,
          );
          if (match.isNotEmpty) {
            name = match.first.name;
          }
        }
        return ActiveCommentarySelection(
          id: savedId,
          file: savedFile,
          name: name,
        );
      }
    }
    return null;
  }

  Future<void> select({
    required String id,
    required String file,
    required String name,
  }) async {
    final picked = ActiveCommentarySelection(id: id, file: file, name: name);
    state = AsyncData(picked);
    await _save(picked);
  }

  Future<void> clear() async {
    state = const AsyncData(null);
    final prefs = await AppPreferences.getInstance();
    await prefs.remove(_prefsKeyId);
    await prefs.remove(_prefsKeyFile);
    await prefs.remove(_prefsKeyName);
  }

  Future<bool> _looksInstalled(
    String manifestFile, {
    required String type,
  }) async {
    try {
      final appDataDir = await getAppDataDirectory();
      final candidates = <String>[
        ...localDbCandidates(manifestFile: manifestFile, type: type),
        appDbPath(
          appDataPath: appDataDir.path,
          manifestFile: manifestFile,
          type: type,
        ),
      ];
      if (candidates.any((path) => File(path).existsSync())) return true;
      return const ZipExtractor().containsFile(
        targetZipPath: dbZipPath(manifestFile: manifestFile, type: type),
      );
    } catch (_) {
      return localDbCandidates(
        manifestFile: manifestFile,
        type: type,
      ).any((path) => File(path).existsSync());
    }
  }

  Future<void> _save(ActiveCommentarySelection picked) async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setString(_prefsKeyId, picked.id);
    await prefs.setString(_prefsKeyFile, picked.file);
    await prefs.setString(_prefsKeyName, picked.name);
  }
}
