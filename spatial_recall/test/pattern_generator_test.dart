import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_recall/game/logic/level_manager.dart';
import 'package:spatial_recall/game/logic/pattern_generator.dart';

void main() {
  group('generatePattern', () {
    test('produces the requested number of unique, in-bounds positions for every level', () {
      for (final level in LevelManager.levels) {
        for (var i = 0; i < 50; i++) {
          final p = generatePattern(gridSize: level.gridSize, tileCount: level.tileCount);
          expect(p.positions.length, level.tileCount, reason: 'level ${level.level}');
          expect(p.positions.every((t) => t.isInside(level.gridSize)), isTrue);
        }
      }
    });

    test('no duplicates even when the board is full', () {
      final p = generatePattern(gridSize: 5, tileCount: 25, seed: 1);
      expect(p.positions.length, 25);
    });

    test('is deterministic with a seed', () {
      final a = generatePattern(gridSize: 7, tileCount: 12, seed: 20261007);
      final b = generatePattern(gridSize: 7, tileCount: 12, seed: 20261007);
      expect(a.positions, b.positions);
      final c = generatePattern(gridSize: 7, tileCount: 12, seed: 20261008);
      expect(a.positions, isNot(c.positions));
    });

    test('avoids heavy clustering on sparse boards', () {
      for (var seed = 0; seed < 200; seed++) {
        final p = generatePattern(gridSize: 6, tileCount: 8, seed: seed);
        for (final t in p.positions) {
          final touching = p.positions.where((o) => o.distanceTo(t) == 1).length;
          expect(touching, lessThanOrEqualTo(2), reason: 'seed $seed');
        }
        // No row or column hogs the pattern.
        for (var i = 0; i < 6; i++) {
          expect(p.positions.where((t) => t.row == i).length, lessThanOrEqualTo(3));
          expect(p.positions.where((t) => t.column == i).length, lessThanOrEqualTo(3));
        }
      }
    });

    test('rejects impossible requests', () {
      expect(() => generatePattern(gridSize: 3, tileCount: 10), throwsArgumentError);
      expect(() => generatePattern(gridSize: 0, tileCount: 0), throwsArgumentError);
    });
  });

  group('levels', () {
    test('30 levels of 10 rounds, memory time never above 5 seconds', () {
      expect(LevelManager.levelCount, 30);
      for (final l in LevelManager.levels) {
        expect(l.memoryMs, inInclusiveRange(2500, 5000), reason: 'level ${l.level}');
        expect(l.rounds, 10);
        expect(l.passPercentage, 80);
      }
      final l1 = LevelManager.config(1);
      expect((l1.gridSize, l1.tileCount, l1.memoryMs), (5, 3, 5000));
      expect(l1.memoryLabel, '5s');
      expect(LevelManager.config(3).memoryLabel, '4.5s');
    });

    test('difficulty rises overall and stays within 1–5', () {
      for (final l in LevelManager.levels) {
        expect(l.difficulty, inInclusiveRange(1, 5));
        expect(l.tileCount, lessThan(l.gridSize * l.gridSize ~/ 2));
      }
      expect(LevelManager.config(1).difficulty, lessThan(LevelManager.config(30).difficulty));
      for (var i = 1; i < LevelManager.levelCount; i++) {
        final a = LevelManager.levels[i - 1], b = LevelManager.levels[i];
        // Each step adds tiles, a bigger board, or less time — never eases all three.
        expect(
          b.tileCount > a.tileCount || b.gridSize > a.gridSize || b.memoryMs < a.memoryMs,
          isTrue,
          reason: 'level ${b.level}',
        );
      }
    });
  });
}
