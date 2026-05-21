import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/font_controller.dart';
import 'app/theme_controller.dart';
import 'app/router.dart';
import 'features/study/providers/user_data_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userDataInitProvider);
    final themeMode = ref.watch(themeModeProvider);
    final fontType = ref.watch(fontTypeProvider);
    final fontFamily = switch (fontType) {
      FontType.sans => 'NotoSansKR',
      FontType.serif => 'NotoSerifKR',
      FontType.mono => 'NanumGothicCoding',
    };
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Love',
      themeMode: themeMode,
      theme: ThemeData.light().copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: fontFamily),
      ),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: fontFamily),
      ),
      routerConfig: router,
    );
  }
}
