import 'package:flutter_test/flutter_test.dart';

import '../lib/data/import/import_orchestrator.dart';

void main() {
  test('orchestrator emits strict phase order', () async {
    final orchestrator = ImportOrchestrator();

    final phases = await orchestrator.runDry();

    expect(
      phases,
      const [
        ImportPhase.discover,
        ImportPhase.extract,
        ImportPhase.validateBible,
        ImportPhase.validateCommentary,
        ImportPhase.buildAliasMap,
        ImportPhase.parseReferences,
        ImportPhase.resolveReferences,
        ImportPhase.buildMappingTable,
        ImportPhase.finalize,
      ],
    );
  });

  test('orchestrator validate-only runs bible then commentary', () async {
    final orchestrator = ImportOrchestrator();

    final phases = await orchestrator.runValidateOnly(
      bibleDbPath: 'assets/data/getbible/en_kjv.sqlite',
      commentaryDbPath: 'assets/data/comment/com_tsk.sqlite',
    );

    expect(phases, const [ImportPhase.validateBible, ImportPhase.validateCommentary]);
  });
}
