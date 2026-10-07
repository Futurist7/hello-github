/// A single cell on the board, addressed by zero-based [row] and [column].
class TilePosition implements Comparable<TilePosition> {
  const TilePosition(this.row, this.column);

  final int row;
  final int column;

  bool isInside(int gridSize) => row >= 0 && column >= 0 && row < gridSize && column < gridSize;

  /// Chebyshev distance: 1 means the tiles touch (including diagonally).
  int distanceTo(TilePosition other) {
    final dr = (row - other.row).abs();
    final dc = (column - other.column).abs();
    return dr > dc ? dr : dc;
  }

  @override
  int compareTo(TilePosition other) => row != other.row ? row - other.row : column - other.column;

  @override
  bool operator ==(Object other) => other is TilePosition && other.row == row && other.column == column;

  @override
  int get hashCode => row * 1000 + column;

  @override
  String toString() => 'TilePosition($row, $column)';
}
