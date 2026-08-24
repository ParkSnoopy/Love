import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';
import '../../../app/theme_controller.dart';

const customThemePrimaryChoices = <int>[
  0xFFCC785C,
  0xFF228B22,
  0xFF1565C0,
  0xFF6A1B9A,
  0xFFC62828,
  0xFF00838F,
  0xFFF9A825,
  0xFF455A64,
];

class ThemeSelectionSheet extends StatefulWidget {
  const ThemeSelectionSheet({required this.settings, super.key});

  final AppThemeSettings settings;

  @override
  State<ThemeSelectionSheet> createState() => _ThemeSelectionSheetState();
}

class _ThemeSelectionSheetState extends State<ThemeSelectionSheet> {
  late AppThemeMode _mode;
  late CustomThemeBase _customBase;
  late int _customPrimaryValue;

  @override
  void initState() {
    super.initState();
    _mode = widget.settings.mode;
    _customBase = widget.settings.customBase;
    _customPrimaryValue = widget.settings.customPrimaryValue;
  }

  String _themeLabel(AppLocalizations l10n, AppThemeMode mode) =>
      switch (mode) {
        AppThemeMode.system => l10n.t('system'),
        AppThemeMode.lightOrange => l10n.t('lightOrange'),
        AppThemeMode.lightGreen => l10n.t('lightGreen'),
        AppThemeMode.darkOrange => l10n.t('darkOrange'),
        AppThemeMode.darkPurple => l10n.t('darkPurple'),
        AppThemeMode.custom => l10n.t('customTheme'),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.t('themeMode'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            for (final mode in AppThemeMode.values)
              ListTile(
                key: ValueKey('theme-mode-${mode.name}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _mode == mode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(_themeLabel(l10n, mode)),
                onTap: () => setState(() => _mode = mode),
              ),
            if (_mode == AppThemeMode.custom) ...[
              const Divider(),
              Text(
                l10n.t('customThemeBase'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<CustomThemeBase>(
                segments: [
                  ButtonSegment(
                    value: CustomThemeBase.light,
                    label: Text(l10n.t('lightBase')),
                  ),
                  ButtonSegment(
                    value: CustomThemeBase.dark,
                    label: Text(l10n.t('darkBase')),
                  ),
                ],
                selected: {_customBase},
                onSelectionChanged: (selection) {
                  setState(() => _customBase = selection.single);
                },
              ),
              const SizedBox(height: 20),
              Text(
                l10n.t('primaryColor'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final value in customThemePrimaryChoices)
                    _ColorChoice(
                      value: value,
                      selected: _customPrimaryValue == value,
                      onSelected: () {
                        setState(() => _customPrimaryValue = value);
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.t('cancel')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    ThemeSelectionResult(
                      mode: _mode,
                      customBase: _customBase,
                      customPrimaryValue: _customPrimaryValue,
                    ),
                  ),
                  child: Text(l10n.t('apply')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeSelectionResult {
  const ThemeSelectionResult({
    required this.mode,
    required this.customBase,
    required this.customPrimaryValue,
  });

  final AppThemeMode mode;
  final CustomThemeBase customBase;
  final int customPrimaryValue;
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final int value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final color = Color(value);
    final label = '#${value.toRadixString(16).substring(2).toUpperCase()}';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        key: ValueKey('custom-theme-color-$value'),
        customBorder: const CircleBorder(),
        onTap: onSelected,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  color:
                      ThemeData.estimateBrightnessForColor(color) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                )
              : null,
        ),
      ),
    );
  }
}
