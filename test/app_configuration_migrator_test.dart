import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Love/app/app_configuration_migrator.dart';

void main() {
  var counter = 0;
  final createdDirectories = <Directory>[];

  Directory createDirectory() {
    final directory = Directory('test/app_configuration_migrator_${counter++}')
      ..createSync(recursive: true);
    createdDirectories.add(directory);
    return directory;
  }

  tearDown(() {
    for (final directory in createdDirectories.reversed) {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
    createdDirectories.clear();
  });

  test('app update overlays local values onto the latest defaults', () async {
    final directory = createDirectory();
    await File('${directory.path}/preferences.json').writeAsString(
      jsonEncode({'existing_setting': 7, 'legacy_setting': 'preserved'}),
    );
    const migrator = AppConfigurationMigrator(
      defaults: {'existing_setting': 1, 'new_setting': 2},
    );

    await migrator.migrateIfNeeded(
      appDataPath: directory.path,
      appVersion: '2.0.0+4',
    );

    expect(
      jsonDecode(
        await File('${directory.path}/preferences.json').readAsString(),
      ),
      {'existing_setting': 7, 'new_setting': 2, 'legacy_setting': 'preserved'},
    );
    expect(
      await File('${directory.path}/configuration.version').readAsString(),
      '2.0.0+4',
    );
  });

  test('configuration migration runs only once per app version', () async {
    final directory = createDirectory();
    await File(
      '${directory.path}/preferences.json',
    ).writeAsString(jsonEncode({'existing_setting': 7}));
    await File(
      '${directory.path}/configuration.version',
    ).writeAsString('2.0.0+4');
    const migrator = AppConfigurationMigrator(
      defaults: {'existing_setting': 1, 'new_setting': 2},
    );

    await migrator.migrateIfNeeded(
      appDataPath: directory.path,
      appVersion: '2.0.0+4',
    );

    expect(
      jsonDecode(
        await File('${directory.path}/preferences.json').readAsString(),
      ),
      {'existing_setting': 7},
    );
  });

  test('configuration migration removes retired settings', () async {
    final directory = createDirectory();
    await File(
      '${directory.path}/preferences.json',
    ).writeAsString(jsonEncode({'app_theme_mode': 2, 'custom_theme_base': 1}));
    const migrator = AppConfigurationMigrator(
      defaults: {'custom_theme_base': 0},
      removedKeys: {'app_theme_mode'},
    );

    await migrator.migrateIfNeeded(
      appDataPath: directory.path,
      appVersion: '2.0.0+5',
    );

    expect(
      jsonDecode(
        await File('${directory.path}/preferences.json').readAsString(),
      ),
      {'custom_theme_base': 1},
    );
  });
}
