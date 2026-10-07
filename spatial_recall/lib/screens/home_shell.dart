import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../ui/components.dart';
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
        extendBody: true,
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
        bottomNavigationBar: _NavBar(index: _index, onSelect: _select),
      ),
    );
  }
}

/// Floating white navigation bar with an animated pill on the active tab.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.route_rounded, 'Levels'),
    (Icons.calendar_today_rounded, 'Daily'),
    (Icons.insights_rounded, 'Stats'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom : 12),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: AppShadows.lifted,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  child: Pressable(
                    onTap: () => onSelect(i),
                    semanticLabel: _items[i].$2,
                    scale: 0.9,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(horizontal: i == index ? 14 : 8, vertical: 9),
                        decoration: BoxDecoration(
                          color: i == index ? AppColors.violet.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_items[i].$1, size: 23, color: i == index ? AppColors.violet : AppColors.textMuted),
                              const SizedBox(height: 2),
                              Text(
                                _items[i].$2,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: i == index ? AppColors.violet : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Header with a title and the settings button, shared by the tabs.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 20, 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
            ],
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
  Widget build(BuildContext context) => CircleIconButton(
    icon: Icons.tune_rounded,
    tooltip: 'Settings',
    onPressed: () => Navigator.of(context).push(gameRoute<void>(context, (_) => const SettingsScreen())),
  );
}

/// Bottom padding so scrolling content clears the floating nav bar.
double navBarClearance(BuildContext context) => 100 + MediaQuery.paddingOf(context).bottom;
