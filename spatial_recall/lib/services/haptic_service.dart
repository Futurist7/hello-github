import 'package:flutter/services.dart';

/// Thin wrapper over Android haptics. Never throws; respects the setting.
class HapticService {
  bool enabled = true;

  Future<void> _run(Future<void> Function() f) async {
    if (!enabled) return;
    try {
      await f();
    } catch (_) {
      // Devices without a vibrator, or platform channel unavailable.
    }
  }

  Future<void> tileTap() => _run(HapticFeedback.selectionClick);
  Future<void> countdown() => _run(HapticFeedback.lightImpact);
  Future<void> success() => _run(HapticFeedback.mediumImpact);
  Future<void> error() => _run(HapticFeedback.lightImpact);

  /// Two quick pulses for completing a level.
  Future<void> levelComplete() => _run(() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.heavyImpact();
  });
}
