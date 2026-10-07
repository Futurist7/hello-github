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
    test('has 30 levels matching the specified opening progression', () {
      expect(LevelManager.levelCount, 30);
      final l1 = LevelManager.config(1);
      expect((l1.gridSize, l1.tileCount, l1.memorySeconds), (5, 3, 20));
      final l7 = LevelManager.config(7);
      expect((l7.gridSize, l7.tileCount, l7.memorySeconds), (6, 8, 13));
      final l20 = LevelManager.config(20);
      expect((l20.gridSize, l20.tileCount, l20.memorySeconds), (8, 17, 6));
    });

    test('difficulty stays within 1–5 and boards stay sparse', () {
      for (final l in LevelManager.levels) {
        expect(l.difficulty, inInclusiveRange(1, 5));
        expect(l.tileCount, lessThan(l.gridSize * l.gridSize ~/ 2));
      }
    });
  });
}
