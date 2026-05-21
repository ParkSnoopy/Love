import 'import_service.dart';

enum ImportPhase {
  discover,
  extract,
  validateBible,
  validateCommentary,
  buildAliasMap,
  parseReferences,
  resolveReferences,
  buildMappingTable,
  finalize,
}

class ImportOrchestrator {
  const ImportOrchestrator({this.importService = const ImportService()});

  final ImportService importService;

  Future<List<ImportPhase>> runDry() async {
    return const [
      ImportPhase.discover,
      ImportPhase.extract,
      ImportPhase.validateBible,
      ImportPhase.validateCommentary,
      ImportPhase.buildAliasMap,
      ImportPhase.parseReferences,
      ImportPhase.resolveReferences,
      ImportPhase.buildMappingTable,
      ImportPhase.finalize,
    ];
  }

  Future<List<ImportPhase>> runValidateOnly({
    required String bibleDbPath,
    required String commentaryDbPath,
  }) async {
    final phases = <ImportPhase>[ImportPhase.validateBible];
    importService.validateBibleFile(bibleDbPath);
    phases.add(ImportPhase.validateCommentary);
    importService.validateCommentaryFile(commentaryDbPath);
    return phases;
  }
}
