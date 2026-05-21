import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../features/library/providers/library_controller.dart';
import '../import/zip_extractor.dart';

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

final activeDbPathProvider = FutureProvider<String?>((ref) async {
  final selection = ref.watch(activeBibleSelectionProvider).asData?.value;
  if (selection == null) return null;

  final manifestFile = selection.file;

  // 1. Try local file (for development/desktop)
  final localCandidates = [
    'assets/data/$manifestFile',
    p.join(Directory.current.path, 'assets/data', manifestFile),
  ];
  for (final path in localCandidates) {
    if (File(path).existsSync()) return path;
  }

  // 2. Try app documents directory (for mobile)
  final docsDir = await getApplicationDocumentsDirectory();
  final targetPath = p.join(docsDir.path, 'bible_data', manifestFile);
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

  // 3. Extract from assets/data.zip to documents directory
  try {
    const extractor = ZipExtractor();
    await extractor.extractFile(
      targetZipPath: manifestFile,
      destinationPath: targetPath,
    );
    return targetPath;
  } catch (e) {
    return null;
  }
});

final activeCommentaryDbPathProvider = FutureProvider<String?>((ref) async {
  final selection = ref.watch(activeCommentarySelectionProvider).asData?.value;
  if (selection == null) return null;

  final manifestFile = selection.file;

  // 1. Try local file (for development/desktop)
  final localCandidates = [
    'assets/data/$manifestFile',
    p.join(Directory.current.path, 'assets/data', manifestFile),
  ];
  for (final path in localCandidates) {
    if (File(path).existsSync()) return path;
  }

  // 2. Try app documents directory (for mobile)
  final docsDir = await getApplicationDocumentsDirectory();
  final targetPath = p.join(docsDir.path, 'bible_data', manifestFile);
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

  // 3. Extract from assets/data.zip to documents directory
  try {
    const extractor = ZipExtractor();
    await extractor.extractFile(
      targetZipPath: manifestFile,
      destinationPath: targetPath,
    );
    return targetPath;
  } catch (e) {
    return null;
  }
});
