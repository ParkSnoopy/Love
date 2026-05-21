import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/library/presentation/library_page.dart';
import '../features/reader/presentation/reader_page.dart';
import '../features/search/presentation/search_page.dart';
import 'home_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorLibraryKey = GlobalKey<NavigatorState>(
  debugLabel: 'library',
);
final shellNavigatorReaderKey = GlobalKey<NavigatorState>(debugLabel: 'reader');
final shellNavigatorSearchKey = GlobalKey<NavigatorState>(debugLabel: 'search');

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
            navigatorKey: shellNavigatorLibraryKey,
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryPage(),
              ),
            ],
          ),
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
        ],
      ),
    ],
  );
});
