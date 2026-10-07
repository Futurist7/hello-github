import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import 'daily_screen.dart';
import 'home_screen.dart';
import 'levels_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// Bottom-navigation shell: Home, Levels, Daily, Stats.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Rebuild on resume so date-dependent UI (daily challenge, streak)
    // rolls over if the app was left open past midnight.
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(onOpenDaily: () => _select(2)),
      const LevelsScreen(),
      const DailyScreen(),
      const StatsScreen(),
    ];
    return PopScope(
      // Back from another tab returns to Home; from Home it leaves the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: GameBackground(
          child: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _index,
              // Hidden tabs keep their state but must not animate in the background.
              children: [for (var i = 0; i < tabs.length; i++) TickerMode(enabled: i == _index, child: tabs[i])],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route_rounded),
              label: 'Levels',
            ),
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today_rounded),
              label: 'Daily',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Stats',
            ),
          ],
        ),
      ),
    );
  }
}

/// Header with a title and the settings button, shared by the tabs.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
        ),
        const SettingsButton(),
      ],
    ),
  );
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Settings',
    iconSize: 26,
    icon: const Icon(Icons.settings_rounded, color: AppColors.textSecondary),
    onPressed: () => Navigator.of(context).push(gameRoute<void>(context, (_) => const SettingsScreen())),
  );
}
