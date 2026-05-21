import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/library/providers/library_controller.dart';
import '../import/zip_extractor.dart';

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

  if (targetFile.existsSync()) return targetPath;

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

  if (targetFile.existsSync()) return targetPath;

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

