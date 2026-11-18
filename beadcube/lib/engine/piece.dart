import 'bead.dart';

/// Standard polyomino shapes used across the 100 Bead Cube levels.
enum PieceShape {
  single,
  domino,
  cornerL,
  bar3,
  square2x2,
  tPiece,
  lTetromino,
  jTetromino,
  zTetromino,
  sTetromino,
  bar4,
  uPentomino,
  plusPentomino,
  wPentomino,
}

/// Immutable definition of a puzzle piece (shape, color, and relative offsets).
class PieceDefinition {
  const PieceDefinition({
    required this.id,
    required this.shape,
    required this.color,
    required this.cells,
  });

  /// Creates a [PieceDefinition] for any [shape] and [color] combination.
  factory PieceDefinition.of(PieceShape shape, BeadColor color) {
    return PieceDefinition(
      id: '${shape.name}_${color.name}',
      shape: shape,
      color: color,
      cells: cellsForShape(shape),
    );
  }

  final String id;
  final PieceShape shape;
  final BeadColor color;

  /// Relative `(dRow, dCol)` offsets from anchor `(0, 0)` at 0° rotation.
  /// Always includes `(0, 0)` and forms a 4-connected polyomino.
  final List<({int dr, int dc})> cells;

  int get beadCount => cells.length;

  /// Canonical relative cell offsets for [shape] (always containing `(0, 0)`).
  static List<({int dr, int dc})> cellsForShape(PieceShape shape) {
    switch (shape) {
      case PieceShape.single:
        return const [(dr: 0, dc: 0)];
      case PieceShape.domino:
        return const [(dr: 0, dc: 0), (dr: 0, dc: 1)];
      case PieceShape.cornerL:
        return const [(dr: 0, dc: 0), (dr: 1, dc: 0), (dr: 1, dc: 1)];
      case PieceShape.bar3:
        return const [(dr: 0, dc: 0), (dr: 0, dc: 1), (dr: 0, dc: 2)];
      case PieceShape.square2x2:
        return const [
          (dr: 0, dc: 0),
          (dr: 0, dc: 1),
          (dr: 1, dc: 0),
          (dr: 1, dc: 1),
        ];
      case PieceShape.tPiece:
        return const [
          (dr: 0, dc: 0),
          (dr: 0, dc: 1),
          (dr: 0, dc: 2),
          (dr: 1, dc: 1),
        ];
      case PieceShape.lTetromino:
        return const [
          (dr: 0, dc: 0),
          (dr: 1, dc: 0),
          (dr: 2, dc: 0),
          (dr: 2, dc: 1),
        ];
      case PieceShape.jTetromino:
        return const [
          (dr: 0, dc: 0),
          (dr: 1, dc: 0),
          (dr: 2, dc: 0),
          (dr: 2, dc: -1),
        ];
      case PieceShape.zTetromino:
        return const [
          (dr: 0, dc: 0),
          (dr: 0, dc: 1),
          (dr: 1, dc: 1),
          (dr: 1, dc: 2),
        ];
      case PieceShape.sTetromino:
        return const [
          (dr: 0, dc: 0),
          (dr: 0, dc: 1),
          (dr: 1, dc: -1),
          (dr: 1, dc: 0),
        ];
      case PieceShape.bar4:
        return const [
          (dr: 0, dc: 0),
          (dr: 0, dc: 1),
          (dr: 0, dc: 2),
          (dr: 0, dc: 3),
        ];
      case PieceShape.uPentomino:
        return const [
          (dr: 0, dc: 0),
          (dr: 1, dc: 0),
          (dr: 1, dc: 1),
          (dr: 1, dc: 2),
          (dr: 0, dc: 2),
        ];
      case PieceShape.plusPentomino:
        return const [
          (dr: 0, dc: 0),
          (dr: -1, dc: 0),
          (dr: 1, dc: 0),
          (dr: 0, dc: -1),
          (dr: 0, dc: 1),
        ];
      case PieceShape.wPentomino:
        return const [
          (dr: 0, dc: 0),
          (dr: 1, dc: 0),
          (dr: 1, dc: 1),
          (dr: 2, dc: 1),
          (dr: 2, dc: 2),
        ];
    }
  }

  /// Returns the `(dRow, dCol)` offsets rotated clockwise by [quarterTurns]
  /// (each 90° clockwise turn maps `(dr, dc) -> (dc, -dr)`), keeping `(0, 0)`
  /// in the returned list.
  List<({int dr, int dc})> rotatedCells(int quarterTurns) {
    final turns = ((quarterTurns % 4) + 4) % 4;
    if (turns == 0) return cells;

    return cells.map((c) {
      var dr = c.dr;
      var dc = c.dc;
      for (int i = 0; i < turns; i++) {
        final nextDr = dc;
        final nextDc = -dr;
        dr = nextDr;
        dc = nextDc;
      }
      return (dr: dr, dc: dc);
    }).toList(growable: false);
  }

  // Standard reusable piece presets.
  static const singleYellow = PieceDefinition(
    id: 'single_yellow',
    shape: PieceShape.single,
    color: BeadColor.yellow,
    cells: [(dr: 0, dc: 0)],
  );

  static const dominoYellow = PieceDefinition(
    id: 'domino_yellow',
    shape: PieceShape.domino,
    color: BeadColor.yellow,
    cells: [(dr: 0, dc: 0), (dr: 0, dc: 1)],
  );

  static const cornerLRed = PieceDefinition(
    id: 'corner_l_red',
    shape: PieceShape.cornerL,
    color: BeadColor.red,
    cells: [(dr: 0, dc: 0), (dr: 1, dc: 0), (dr: 1, dc: 1)],
  );

  static const cornerLCyan = PieceDefinition(
    id: 'corner_l_cyan',
    shape: PieceShape.cornerL,
    color: BeadColor.cyan,
    cells: [(dr: 0, dc: 0), (dr: 1, dc: 0), (dr: 1, dc: 1)],
  );

  static const bar3Cyan = PieceDefinition(
    id: 'bar3_cyan',
    shape: PieceShape.bar3,
    color: BeadColor.cyan,
    cells: [(dr: 0, dc: 0), (dr: 0, dc: 1), (dr: 0, dc: 2)],
  );

  static const bar3Red = PieceDefinition(
    id: 'bar3_red',
    shape: PieceShape.bar3,
    color: BeadColor.red,
    cells: [(dr: 0, dc: 0), (dr: 0, dc: 1), (dr: 0, dc: 2)],
  );

  static const squareBlue = PieceDefinition(
    id: 'square_blue',
    shape: PieceShape.square2x2,
    color: BeadColor.blue,
    cells: [
      (dr: 0, dc: 0),
      (dr: 0, dc: 1),
      (dr: 1, dc: 0),
      (dr: 1, dc: 1),
    ],
  );

  static const tPurple = PieceDefinition(
    id: 't_purple',
    shape: PieceShape.tPiece,
    color: BeadColor.purple,
    cells: [
      (dr: 0, dc: 0),
      (dr: 0, dc: 1),
      (dr: 0, dc: 2),
      (dr: 1, dc: 1),
    ],
  );

  static const lTetrominoBlue = PieceDefinition(
    id: 'l_tetromino_blue',
    shape: PieceShape.lTetromino,
    color: BeadColor.blue,
    cells: [
      (dr: 0, dc: 0),
      (dr: 1, dc: 0),
      (dr: 2, dc: 0),
      (dr: 2, dc: 1),
    ],
  );
}
