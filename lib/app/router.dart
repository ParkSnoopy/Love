import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/library/presentation/library_page.dart';
import '../features/reader/presentation/reader_page.dart';
import '../features/search/presentation/search_page.dart';
import '../features/study/presentation/saved_page.dart';
import 'home_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorSettingKey = GlobalKey<NavigatorState>(
  debugLabel: 'setting',
);
final shellNavigatorReaderKey = GlobalKey<NavigatorState>(debugLabel: 'reader');
final shellNavigatorSearchKey = GlobalKey<NavigatorState>(debugLabel: 'search');
final shellNavigatorSavedKey = GlobalKey<NavigatorState>(debugLabel: 'saved');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/reader',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: shellNavigatorReaderKey,
            routes: [
              GoRoute(
                path: '/reader',
                builder: (context, state) => const ReaderPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorSearchKey,
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorSavedKey,
            routes: [
              GoRoute(
                path: '/saved',
                builder: (context, state) => const SavedPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorSettingKey,
            routes: [
              GoRoute(
                path: '/setting',
                builder: (context, state) => const SettingPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
