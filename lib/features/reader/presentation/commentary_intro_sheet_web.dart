import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';

void showCommentaryIntros(
  BuildContext context,
  String manifestFile,
  String commentaryName,
) {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(context.l10n.t('noIntroInfo'), textAlign: TextAlign.center),
      ),
    ),
  );
}
