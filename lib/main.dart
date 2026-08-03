import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_localizations.dart';
import 'app/app_theme.dart';
import 'app/bug_reporter.dart';
import 'app/font_controller.dart';
import 'app/locale_controller.dart';
import 'app/reader_settings_controller.dart';
import 'app/theme_controller.dart';
import 'app/router.dart';
import 'features/study/providers/user_data_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final originalFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    BugReportLog.recordFlutterError(details);
    originalFlutterError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    BugReportLog.record(error, stack);
    return false;
  };
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runZonedGuarded(
    () => runApp(const ProviderScope(child: MyApp())),
    BugReportLog.record,
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userDataInitProvider);
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final locale = ref.watch(appLocaleProvider).value;
    final fontType = ref.watch(fontTypeProvider).value ?? FontType.serif;
    final fontFamily = fontFamilyForType(fontType);
    final uiScale = ref.watch(readerSettingsProvider).value?.uiScale ?? 1.0;
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Love',
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeMode,
      theme: buildLightTheme(fontFamily),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: fontFamily),
      ),
      routerConfig: router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.linear(uiScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
