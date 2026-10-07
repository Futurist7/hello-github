import 'package:flutter/services.dart';

enum SoundEffect { tileSelect, countdown, correct, incorrect, levelComplete, xpEarned }

/// Plays a [SoundEffect]. Swap in an asset-based player (e.g. `flame_audio`
/// or `audioplayers`) by implementing this and passing it to [AudioService].
abstract class SoundPlayer {
  Future<void> play(SoundEffect effect);
}

/// Default player: uses the platform's built-in click sound so the game has
/// audio feedback without bundling assets. Effects without a sensible system
/// sound are silent until real assets are added.
///
/// To add real sounds:
///   1. Put files in `assets/audio/` (e.g. `tile_select.ogg`) and list the
///      folder under `flutter: assets:` in pubspec.yaml.
///   2. Implement [SoundPlayer] using an audio package and map each
///      [SoundEffect] to its file.
///   3. Pass it to `AudioService(player: ...)` in `main.dart`.
class SystemSoundPlayer implements SoundPlayer {
  @override
  Future<void> play(SoundEffect effect) async {
    switch (effect) {
      case SoundEffect.tileSelect:
      case SoundEffect.countdown:
        await SystemSound.play(SystemSoundType.click);
      case SoundEffect.correct:
      case SoundEffect.incorrect:
      case SoundEffect.levelComplete:
      case SoundEffect.xpEarned:
        break;
    }
  }
}

class AudioService {
  AudioService({SoundPlayer? player}) : _player = player ?? SystemSoundPlayer();

  final SoundPlayer _player;
  bool enabled = true;

  Future<void> play(SoundEffect effect) async {
    if (!enabled) return;
    try {
      await _player.play(effect);
    } catch (_) {
      // Audio must never break gameplay.
    }
  }
}
