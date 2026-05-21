import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/library/providers/library_controller.dart';

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

  // 3. Copy from assets to documents directory
  try {
    final assetPath = 'assets/data/$manifestFile';
    final byteData = await rootBundle.load(assetPath);
    await targetFile.parent.create(recursive: true);
    final buffer = byteData.buffer;
    await targetFile.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );
    return targetPath;
  } catch (e) {
    // If asset loading fails, we might be in a state where nothing can be shown
    return null;
  }
});
