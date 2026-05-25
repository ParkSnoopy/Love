import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../features/library/providers/library_controller.dart';
import '../import/zip_extractor.dart';
import 'app_storage.dart';
import 'db_asset_paths.dart';

bool _isDatabaseValid(String path) {
  try {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='verses'",
      );
      return rows.isNotEmpty;
    } finally {
      db.close();
    }
  } catch (_) {
    return false;
  }
}

Future<String?> _resolveDbPath({
  required String manifestFile,
  required String type,
}) async {
  // 1. Try local file (for development/desktop)
  for (final path in localDbCandidates(
    manifestFile: manifestFile,
    type: type,
  )) {
    if (File(path).existsSync()) return path;
  }

  // 2. Try app data directory
  final appDataDir = await getAppDataDirectory();
  final targetPath = appDbPath(
    appDataPath: appDataDir.path,
    manifestFile: manifestFile,
    type: type,
  );
  final targetFile = File(targetPath);

  if (targetFile.existsSync()) {
    if (_isDatabaseValid(targetPath)) {
      return targetPath;
    } else {
      try {
        targetFile.deleteSync();
      } catch (_) {}
    }
  }

  // 3. Extract from assets/data.zip to app data directory
  try {
    const extractor = ZipExtractor();
    await extractor.extractFile(
      targetZipPath: dbZipPath(manifestFile: manifestFile, type: type),
      destinationPath: targetPath,
    );
    return targetPath;
  } catch (_) {
    return null;
  }
}

final activeDbPathProvider = FutureProvider<String?>((ref) async {
  final selection = ref.watch(activeBibleSelectionProvider).asData?.value;
  if (selection == null) return null;

  return _resolveDbPath(manifestFile: selection.file, type: 'bible');
});

final activeCommentaryDbPathProvider = FutureProvider<String?>((ref) async {
  final selection = ref.watch(activeCommentarySelectionProvider).asData?.value;
  if (selection == null) return null;

  return _resolveDbPath(manifestFile: selection.file, type: 'commentary');
});
