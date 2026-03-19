// lib/app.dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sub_tracker/core/theme/app_theme.dart';
import 'package:sub_tracker/features/subscriptions/screens/subscriptions_list_screen.dart';
import 'package:sub_tracker/features/analytics/screens/analytics_screen.dart';
import 'package:sub_tracker/features/settings/screens/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/subscriptions',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ScaffoldWithNav(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/subscriptions', builder: (context, state) => const SubscriptionsListScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);

// NOTE: This will be upgraded to ConsumerStatefulWidget in a later task when
// settings_provider and notification_service are created.
class SubTrackerApp extends StatelessWidget {
  const SubTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'SubTracker',
          theme: AppTheme.light(lightDynamic),
          darkTheme: AppTheme.dark(darkDynamic),
          routerConfig: goRouter,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class ScaffoldWithNav extends StatelessWidget {
  const ScaffoldWithNav({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.subscriptions_outlined), selectedIcon: Icon(Icons.subscriptions), label: 'Подписки'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Аналитика'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}
