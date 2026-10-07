import 'dart:math';

import '../models/pattern.dart';
import '../models/tile_position.dart';

/// Generates a pattern of unique tiles inside the board.
///
/// Patterns avoid heavy clustering: a new tile is rejected if it would touch
/// too many existing tiles or overfill a row/column. If the constraints can't
/// be met (very dense boards) they are relaxed step by step, so generation
/// always terminates. With a [seed] the result is fully deterministic.
Pattern generatePattern({required int gridSize, required int tileCount, int? seed}) {
  if (gridSize < 1) throw ArgumentError.value(gridSize, 'gridSize');
  if (tileCount < 0 || tileCount > gridSize * gridSize) {
    throw ArgumentError.value(tileCount, 'tileCount');
  }
  final random = seed == null ? Random() : Random(seed);
  final lineCap = (tileCount / gridSize).ceil() + 1;

  // Strictest first; each pass relaxes the clustering rules.
  const neighbourLimits = [1, 2, 3, 8];
  for (final maxNeighbours in neighbourLimits) {
    for (var attempt = 0; attempt < 30; attempt++) {
      final result = _tryGenerate(random, gridSize, tileCount, maxNeighbours, maxNeighbours >= 8 ? gridSize : lineCap);
      if (result != null) return Pattern(gridSize: gridSize, positions: result, seed: seed);
    }
  }
  // Unreachable in practice: the last pass has no constraints.
  final all = [
    for (var r = 0; r < gridSize; r++)
      for (var c = 0; c < gridSize; c++) TilePosition(r, c),
  ]..shuffle(random);
  return Pattern(gridSize: gridSize, positions: all.take(tileCount), seed: seed);
}

Set<TilePosition>? _tryGenerate(Random random, int gridSize, int tileCount, int maxNeighbours, int lineCap) {
  final cells = [
    for (var r = 0; r < gridSize; r++)
      for (var c = 0; c < gridSize; c++) TilePosition(r, c),
  ]..shuffle(random);
  final chosen = <TilePosition>{};
  final rowCount = List.filled(gridSize, 0);
  final colCount = List.filled(gridSize, 0);
  final neighbours = <TilePosition, int>{};

  for (final cell in cells) {
    if (chosen.length == tileCount) break;
    if (rowCount[cell.row] >= lineCap || colCount[cell.column] >= lineCap) continue;
    final touching = chosen.where((t) => t.distanceTo(cell) == 1).toList();
    if (touching.length > maxNeighbours) continue;
    if (touching.any((t) => (neighbours[t] ?? 0) >= maxNeighbours)) continue;
    chosen.add(cell);
    rowCount[cell.row]++;
    colCount[cell.column]++;
    neighbours[cell] = touching.length;
    for (final t in touching) {
      neighbours[t] = (neighbours[t] ?? 0) + 1;
    }
  }
  return chosen.length == tileCount ? chosen : null;
}
