import 'package:flutter/material.dart';

import '../game/logic/daily_challenge.dart';
import '../game/logic/level_manager.dart';
import '../game/logic/pattern_generator.dart';
import '../game/models/round_result.dart';
import '../screens/game_screen.dart';
import '../screens/level_intro_screen.dart';
import '../state/app_state.dart';

/// Page route that respects reduced motion (short fade instead of the
/// default transition).
Route<T> gameRoute<T>(BuildContext context, WidgetBuilder builder) {
  final reduced =
      AppScope.read(context).settings.reducedMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  if (!reduced) return MaterialPageRoute<T>(builder: builder);
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 120),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
}

/// Builds round specs. Each call makes a new pattern (or the fixed daily one).
abstract final class Rounds {
  static RoundSpec level(int level) {
    final config = LevelManager.config(level);
    return RoundSpec(
      mode: RoundMode.level,
      config: config,
      pattern: generatePattern(gridSize: config.gridSize, tileCount: config.tileCount),
    );
  }

  static RoundSpec daily(DailyChallenge challenge, {required bool official}) => RoundSpec(
    mode: RoundMode.daily,
    config: challenge.config,
    pattern: challenge.pattern,
    dailyDate: challenge.key,
    officialDaily: official,
  );

  /// Same round settings with a fresh pattern for levels; daily stays fixed.
  static RoundSpec again(RoundSpec spec) => spec.mode == RoundMode.level ? level(spec.config.level) : spec;
}

abstract final class Nav {
  static Future<void> levelIntro(BuildContext context, int level, {bool replace = false}) {
    final route = gameRoute<void>(context, (_) => LevelIntroScreen(level: level));
    return replace ? Navigator.of(context).pushReplacement(route) : Navigator.of(context).push(route);
  }

  static Future<void> play(BuildContext context, RoundSpec spec, {bool replace = false}) {
    final route = gameRoute<void>(context, (_) => GameScreen(spec: spec));
    return replace ? Navigator.of(context).pushReplacement(route) : Navigator.of(context).push(route);
  }

  /// Starts today's daily challenge; the first finished attempt is official.
  static Future<void> playDaily(BuildContext context) {
    final state = AppScope.read(context);
    final challenge = state.todaysChallenge;
    final official = state.dailyRecordFor(challenge.key) == null;
    return play(context, Rounds.daily(challenge, official: official));
  }
}
