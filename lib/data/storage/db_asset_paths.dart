import 'dart:io';

import 'package:path/path.dart' as p;

String dbAssetCategory(String type) {
  return type == 'commentary' ? 'commentary' : 'bible';
}

String dbZipPath({required String manifestFile, required String type}) {
  return p.posix.join('data', dbAssetCategory(type), manifestFile);
}

List<String> localDbCandidates({
  required String manifestFile,
  required String type,
}) {
  final category = dbAssetCategory(type);
  return [
    'assets/data/$manifestFile',
    p.join(Directory.current.path, 'assets/data', manifestFile),
    'assets/data/$category/$manifestFile',
    p.join(Directory.current.path, 'assets/data', category, manifestFile),
  ];
}

String appDbPath({
  required String appDataPath,
  required String manifestFile,
  required String type,
}) {
  return p.join(appDataPath, 'bible_data', dbAssetCategory(type), manifestFile);
}
