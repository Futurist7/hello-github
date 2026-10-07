import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Light, airy palette with vivid accents.
abstract final class AppColors {
  static const background = Color(0xFFF5F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF0F2F9);
  static const outline = Color(0xFFE5E8F1);

  static const textPrimary = Color(0xFF181B2C);
  static const textSecondary = Color(0xFF636A82);
  static const textMuted = Color(0xFFA0A6BB);

  static const violet = Color(0xFF6C5CE7);
  static const blue = Color(0xFF4F8CFF);
  static const coral = Color(0xFFFF7A59);
  static const amber = Color(0xFFFFB020);
  static const mint = Color(0xFF1EC28B);
  static const rose = Color(0xFFFF4D6D);
  static const sky = Color(0xFF38BDF8);

  // Board.
  static const tileEmpty = Color(0xFFEDF0F8);
  static const tileEmptyEdge = Color(0xFFE1E5F0);
  static const active = violet;
  static const activeDeep = blue;
  static const selected = Color(0xFFFF9F43);
  static const selectedDeep = coral;
  static const correct = Color(0xFF2BD49B);
  static const correctDeep = mint;
  static const wrong = Color(0xFFFF6B85);
  static const wrongDeep = rose;

  static const streak = Color(0xFFFF8A3D);
  static const star = Color(0xFFFFC23D);
}

abstract final class AppGradients {
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B61FF), Color(0xFF4F8CFF)],
  );
  static const sunrise = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8F6B), Color(0xFFFFB547)],
  );
  static const mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D8A5), Color(0xFF1AAE8C)],
  );
  static const ocean = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF43C6F5), Color(0xFF4F7CFF)],
  );
  static const berry = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B9A), Color(0xFFB45CFF)],
  );
}

abstract final class AppShadows {
  static const soft = [BoxShadow(color: Color(0x14212A5C), blurRadius: 24, offset: Offset(0, 10))];
  static const lifted = [BoxShadow(color: Color(0x1F212A5C), blurRadius: 32, offset: Offset(0, 16))];
  static List<BoxShadow> glow(Color c, {double strength = 0.35}) => [
    BoxShadow(
      color: c.withValues(alpha: strength),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
}

const _font = 'Poppins';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.violet, brightness: Brightness.light).copyWith(
    primary: AppColors.violet,
    onPrimary: Colors.white,
    secondary: AppColors.coral,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.rose,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: _font);
  TextStyle? t(TextStyle? s, double size, FontWeight w, {double ls = 0, double? h}) =>
      s?.copyWith(fontSize: size, fontWeight: w, letterSpacing: ls, height: h, color: AppColors.textPrimary);
  final tt = base.textTheme;
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
    textTheme: tt.copyWith(
      displayLarge: t(tt.displayLarge, 56, FontWeight.w800, ls: -1.5, h: 1.05),
      displayMedium: t(tt.displayMedium, 44, FontWeight.w800, ls: -1.2, h: 1.05),
      displaySmall: t(tt.displaySmall, 34, FontWeight.w800, ls: -0.8, h: 1.1),
      headlineMedium: t(tt.headlineMedium, 26, FontWeight.w700, ls: -0.4),
      headlineSmall: t(tt.headlineSmall, 22, FontWeight.w700, ls: -0.3),
      titleLarge: t(tt.titleLarge, 18, FontWeight.w700, ls: -0.2),
      titleMedium: t(tt.titleMedium, 16, FontWeight.w600),
      bodyLarge: t(tt.bodyLarge, 16, FontWeight.w400),
      bodyMedium: t(tt.bodyMedium, 14, FontWeight.w400),
      labelLarge: t(tt.labelLarge, 15, FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.textPrimary,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.violet : AppColors.outline,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentTextStyle: const TextStyle(fontFamily: _font, color: Colors.white, fontWeight: FontWeight.w500),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SoftPageTransitionsBuilder(),
        TargetPlatform.iOS: SoftPageTransitionsBuilder(),
      },
    ),
  );
}

/// Smooth, modern page transition: the new page fades in while gently
/// rising and settling from 96% scale; the old page recedes slightly.
class SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: Listenable.merge([inCurve, outCurve]),
      child: child,
      builder: (context, child) {
        final t = inCurve.value;
        final o = outCurve.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: Transform.scale(scale: (0.96 + 0.04 * t) * (1 - 0.03 * o), child: child),
          ),
        );
      },
    );
  }
}

/// Soft background with two blurred colour blobs.
class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.child, this.tint = AppColors.violet});
  final Widget child;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: ColoredBox(
        color: AppColors.background,
        child: Stack(
          children: [
            Positioned(top: -140, right: -100, child: _Blob(color: tint.withValues(alpha: 0.16), size: 340)),
            Positioned(top: 160, left: -160, child: _Blob(color: AppColors.sky.withValues(alpha: 0.10), size: 320)),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

/// Soft colour glow: a radial gradient (cheap, unlike a blur filter).
class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// White rounded card with a soft shadow.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color, this.gradient});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: gradient == null ? (color ?? AppColors.surface) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(26),
      boxShadow: AppShadows.soft,
    ),
    child: child,
  );
}

/// Small uppercase caption.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.color = AppColors.textMuted, this.align});
  final String text;
  final Color color;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textAlign: align,
    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: color),
  );
}

/// Whether to minimise motion: the in-app setting or the OS setting.
bool reduceMotionOf(BuildContext context, bool setting) =>
    setting || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
