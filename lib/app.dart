// lib/app.dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sub_tracker/core/notifications/notification_service.dart';
import 'package:sub_tracker/core/theme/app_theme.dart';
import 'package:sub_tracker/features/analytics/screens/analytics_screen.dart';
import 'package:sub_tracker/features/settings/providers/settings_provider.dart';
import 'package:sub_tracker/features/settings/screens/settings_screen.dart';
import 'package:sub_tracker/features/subscriptions/screens/subscription_detail_screen.dart';
import 'package:sub_tracker/features/subscriptions/screens/subscription_form_screen.dart';
import 'package:sub_tracker/features/subscriptions/screens/subscriptions_list_screen.dart';

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
          GoRoute(
            path: '/subscriptions',
            builder: (context, state) => const SubscriptionsListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, _) => const SubscriptionFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => SubscriptionDetailScreen(
                  subscriptionId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
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

class SubTrackerApp extends ConsumerStatefulWidget {
  const SubTrackerApp({super.key});

  @override
  ConsumerState<SubTrackerApp> createState() => _SubTrackerAppState();
}

class _SubTrackerAppState extends ConsumerState<SubTrackerApp> {
  @override
  void initState() {
    super.initState();
    // Wire notification tap handler to navigate to the relevant subscription
    NotificationService.onNotificationTap = (payload) {
      if (payload != null && payload.isNotEmpty) {
        _rootNavigatorKey.currentContext?.go('/subscriptions/$payload');
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeNotifierProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'SubTracker',
          theme: AppTheme.light(lightDynamic),
          darkTheme: AppTheme.dark(darkDynamic),
          themeMode: themeMode,
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
