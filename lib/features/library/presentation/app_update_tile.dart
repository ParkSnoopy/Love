import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_localizations.dart';
import '../../../app/app_update_checker.dart';

typedef ReleasePageOpener = Future<bool> Function(Uri uri);

class AppUpdateTile extends StatefulWidget {
  AppUpdateTile({
    super.key,
    AppUpdateChecker? checker,
    ReleasePageOpener? openReleasePage,
  }) : checker = checker ?? AppUpdateChecker(),
       openReleasePage = openReleasePage ?? _openReleasePage;

  final AppUpdateChecker checker;
  final ReleasePageOpener openReleasePage;

  static Future<bool> _openReleasePage(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  State<AppUpdateTile> createState() => _AppUpdateTileState();
}

class _AppUpdateTileState extends State<AppUpdateTile> {
  bool _checking = false;

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    final l10n = context.l10n;
    try {
      final result = await widget.checker.check();
      if (!mounted) return;
      if (!result.updateAvailable) {
        _showMessage(l10n.t('appUpToDate'));
        return;
      }

      setState(() => _checking = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.t('updateAvailable')),
          content: Text(l10n.t('updateAvailableMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final opened = await widget.openReleasePage(result.releasePage);
                if (!mounted || opened) return;
                _showMessage(l10n.t('releaseOpenFailed'));
              },
              child: Text(l10n.t('openLatestRelease')),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) _showMessage(l10n.t('updateCheckFailed'));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      key: const ValueKey('check-update'),
      enabled: !_checking,
      leading: Icon(
        Icons.system_update_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(l10n.t('checkUpdate')),
      subtitle: Text(l10n.t('checkUpdateSubtitle')),
      trailing: _checking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _checking ? null : _checkUpdate,
    );
  }
}
