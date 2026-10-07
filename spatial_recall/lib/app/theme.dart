import 'package:flutter/material.dart';

/// Palette for the game's dark, tactile look.
abstract final class AppColors {
  static const background = Color(0xFF0D1120);
  static const backgroundTop = Color(0xFF151B33);
  static const surface = Color(0xFF181E36);
  static const surfaceHigh = Color(0xFF212947);
  static const outline = Color(0xFF2C3559);

  static const tileEmpty = Color(0xFF232B4B);
  static const tileEmptyEdge = Color(0xFF333D66);
  static const active = Color(0xFF5CE1FF);
  static const activeDeep = Color(0xFF6E7BFF);
  static const selected = Color(0xFFFFC25C);
  static const selectedDeep = Color(0xFFFF9447);
  static const correct = Color(0xFF3EE29B);
  static const correctDeep = Color(0xFF1FB57A);
  static const wrong = Color(0xFFFF5D7D);
  static const wrongDeep = Color(0xFFE23D63);

  static const textPrimary = Color(0xFFF3F5FF);
  static const textSecondary = Color(0xFFA2AACC);
  static const textMuted = Color(0xFF6B7499);
  static const streak = Color(0xFFFF8A3D);
  static const star = Color(0xFFFFD25C);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.active, brightness: Brightness.dark).copyWith(
    primary: AppColors.active,
    onPrimary: const Color(0xFF04202B),
    secondary: AppColors.selected,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.wrong,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark, fontFamily: 'Roboto');
  final text = base.textTheme.apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text.copyWith(
      displayLarge: text.displayLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
      displayMedium: text.displayMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
      headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.textPrimary,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.active.withValues(alpha: 0.18),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected) ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.active : AppColors.textMuted),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 58),
        backgroundColor: AppColors.active,
        foregroundColor: const Color(0xFF04202B),
        disabledBackgroundColor: AppColors.surfaceHigh,
        disabledForegroundColor: AppColors.textMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.4),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 54),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? const Color(0xFF04202B) : AppColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.active : AppColors.surfaceHigh,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

/// Subtle vertical gradient used behind every screen.
class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.backgroundTop, AppColors.background],
      ),
    ),
    child: child,
  );
}

/// Rounded card surface used on menus.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 10))],
    ),
    child: child,
  );
}

/// Small uppercase caption.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.color = AppColors.textSecondary, this.align});
  final String text;
  final Color color;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textAlign: align,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.8, color: color),
  );
}

/// Whether to minimise motion: the in-app setting or the OS setting.
bool reduceMotionOf(BuildContext context, bool setting) =>
    setting || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
