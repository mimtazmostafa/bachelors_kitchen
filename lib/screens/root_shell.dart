import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../theme/app_theme.dart';
import 'ai_chef_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'meal_planner_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Bottom-nav scaffold shown once the user is subscribed. The home shell.
/// Back button is disabled from popping it (the only legitimate exit is via
/// the Settings screen -> Log out flow, which calls pushAndRemoveUntil).
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static final _screens = <Widget>[
    const HomeScreen(),
    const SearchScreen(),
    const AiChefScreen(),
    const FavoritesScreen(),
    const MealPlannerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: _index == 0
            ? AppBar(
                title: Text(t.appName),
                actions: [
                  IconButton(
                    tooltip: t.settings,
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                ],
              )
            : null,
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home, color: AppTheme.primary),
              label: t.home,
            ),
            NavigationDestination(
              icon: const Icon(Icons.search),
              selectedIcon: const Icon(Icons.search, color: AppTheme.primary),
              label: t.search,
            ),
            NavigationDestination(
              icon: const Icon(Icons.psychology_alt_outlined),
              selectedIcon:
                  const Icon(Icons.psychology_alt, color: AppTheme.primary),
              label: t.aiChef,
            ),
            NavigationDestination(
              icon: const Icon(Icons.favorite_border),
              selectedIcon:
                  const Icon(Icons.favorite, color: AppTheme.primary),
              label: t.favorites,
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month,
                  color: AppTheme.primary),
              label: t.planner,
            ),
          ],
        ),
        floatingActionButton: _index == 0
            ? FloatingActionButton.extended(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                onPressed: () => setState(() => _index = 2),
                icon: const Icon(Icons.psychology_alt),
                label: Text(t.aiChef),
              )
            : null,
      ),
    );
  }
}