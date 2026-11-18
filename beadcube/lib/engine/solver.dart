import 'dart:math' as math;

import 'bead.dart';
import 'cube_topology.dart';
import 'folding_engine.dart';
import 'level.dart';
import 'piece.dart';

/// A concrete valid move found by [PuzzleSolver].
class SolvedMove {
  const SolvedMove({
    required this.pieceIndex,
    required this.anchor,
    required this.quarterTurns,
    required this.coords,
  });

  final int pieceIndex;
  final CubeCoord anchor;
  final int quarterTurns;
  final List<CubeCoord> coords;
}

class _CandidatePlacement {
  const _CandidatePlacement({
    required this.shape,
    required this.anchor,
    required this.quarterTurns,
    required this.coords,
    required this.mask,
  });

  final PieceShape shape;
  final CubeCoord anchor;
  final int quarterTurns;
  final List<CubeCoord> coords;
  final int mask;
}

/// Pure-Dart color-decomposed Exact Cover puzzle solver and procedural generator.
class PuzzleSolver {
  const PuzzleSolver._();

  /// Finds a valid next move for one of the unused pieces in [pieces] that
  /// allows all remaining pieces across all colors to complete [target].
  ///
  /// Returns `null` if the current [board] state is unsolvable.
  static SolvedMove? findHintMove({
    required CubeBoard board,
    required CubeBoard target,
    required List<PieceDefinition> pieces,
    required Set<int> usedPieceIndices,
    int? preferredPieceIndex,
  }) {
    final remainingByColor = <BeadColor, List<int>>{};
    for (int i = 0; i < pieces.length; i++) {
      if (usedPieceIndices.contains(i)) continue;
      final c = pieces[i].color;
      (remainingByColor[c] ??= <int>[]).add(i);
    }
    if (remainingByColor.isEmpty) return null;

    // Order colors so preferredPieceIndex's color is solved first, while still
    // verifying every other color remains solvable!
    final colors = remainingByColor.keys.toList();
    if (preferredPieceIndex != null &&
        !usedPieceIndices.contains(preferredPieceIndex)) {
      final prefColor = pieces[preferredPieceIndex].color;
      if (colors.remove(prefColor)) {
        colors.insert(0, prefColor);
      }
      final list = remainingByColor[prefColor]!;
      if (list.remove(preferredPieceIndex)) {
        list.insert(0, preferredPieceIndex);
      }
    }

    SolvedMove? chosenHint;
    for (final color in colors) {
      final colorMoves = _solveColor(
        board: board,
        target: target,
        color: color,
        pieces: pieces,
        pieceIndices: remainingByColor[color]!,
      );
      if (colorMoves == null || colorMoves.isEmpty) {
        return null; // Unsolvable dead-end in this color!
      }
      chosenHint ??= _pickPreferredMove(colorMoves, preferredPieceIndex);
    }

    return chosenHint;
  }

  static SolvedMove _pickPreferredMove(
    List<SolvedMove> moves,
    int? preferredPieceIndex,
  ) {
    if (preferredPieceIndex != null) {
      for (final m in moves) {
        if (m.pieceIndex == preferredPieceIndex) return m;
      }
    }
    return moves.first;
  }

  /// Verifies that [pieces] can completely solve [target] from an empty board.
  static bool isSolvable({
    required CubeBoard target,
    required List<PieceDefinition> pieces,
  }) {
    final board = CubeBoard();
    final byColor = <BeadColor, List<int>>{};
    for (int i = 0; i < pieces.length; i++) {
      (byColor[pieces[i].color] ??= <int>[]).add(i);
    }
    for (final entry in byColor.entries) {
      final solved = _solveColor(
        board: board,
        target: target,
        color: entry.key,
        pieces: pieces,
        pieceIndices: entry.value,
      );
      if (solved == null) return false;
    }
    return true;
  }

  /// Solves a single color's remaining pieces using bitmask Exact Cover with
  /// Most-Constrained-Cell branching and symmetry deduplication.
  static List<SolvedMove>? _solveColor({
    required CubeBoard board,
    required CubeBoard target,
    required BeadColor color,
    required List<PieceDefinition> pieces,
    required List<int> pieceIndices,
  }) {
    final emptyCells = <CubeCoord>[
      for (final coord in CubeTopology.allCoords)
        if (target.get(coord) == color && board.get(coord) == BeadColor.empty)
          coord,
    ];

    final expectedBeads = pieceIndices.fold<int>(
      0,
      (sum, idx) => sum + pieces[idx].beadCount,
    );
    if (emptyCells.length != expectedBeads) {
      return null;
    }
    if (emptyCells.isEmpty) {
      return const [];
    }

    // Map each empty cell of this color to a bit index [0 .. N-1] (N <= 60).
    final cellToBit = <CubeCoord, int>{
      for (int i = 0; i < emptyCells.length; i++) emptyCells[i]: i,
    };
    final fullMask = (1 << emptyCells.length) - 1;

    // Group available piece indices by PieceShape to avoid permuting identical shapes.
    final shapeCounts = <PieceShape, List<int>>{};
    for (final idx in pieceIndices) {
      (shapeCounts[pieces[idx].shape] ??= <int>[]).add(idx);
    }

    // Precompute all distinct valid placements per cell bit.
    final placementsByBit = List<List<_CandidatePlacement>>.generate(
      emptyCells.length,
      (_) => <_CandidatePlacement>[],
    );

    for (final shape in shapeCounts.keys) {
      final proto = PieceDefinition.of(shape, color);
      final seenMasks = <int>{};

      for (final anchor in emptyCells) {
        for (int turns = 0; turns < 4; turns++) {
          final res = FoldingEngine.validatePlacement(
            board: board,
            target: target,
            anchor: anchor,
            piece: proto,
            quarterTurns: turns,
          );
          if (!res.isValid) continue;

          var mask = 0;
          var allMapped = true;
          for (final c in res.coords) {
            final bit = cellToBit[c];
            if (bit == null) {
              allMapped = false;
              break;
            }
            mask |= (1 << bit);
          }
          if (!allMapped || !seenMasks.add(mask)) continue;

          final candidate = _CandidatePlacement(
            shape: shape,
            anchor: anchor,
            quarterTurns: turns,
            coords: res.coords,
            mask: mask,
          );
          for (final c in res.coords) {
            placementsByBit[cellToBit[c]!].add(candidate);
          }
        }
      }
    }

    final remainingPerShape = <PieceShape, int>{
      for (final e in shapeCounts.entries) e.key: e.value.length,
    };
    final chosenPlacements = <_CandidatePlacement>[];

    bool search(int coveredMask) {
      if (coveredMask == fullMask) return true;

      // Most-Constrained-Cell: pick the uncovered bit with the fewest valid
      // non-overlapping placements using available shapes.
      int bestBit = -1;
      List<_CandidatePlacement>? bestOptions;

      for (int bit = 0; bit < emptyCells.length; bit++) {
        if ((coveredMask & (1 << bit)) != 0) continue;

        final options = <_CandidatePlacement>[];
        for (final cand in placementsByBit[bit]) {
          if ((cand.mask & coveredMask) != 0) continue;
          if ((remainingPerShape[cand.shape] ?? 0) <= 0) continue;
          options.add(cand);
        }
        if (options.isEmpty) {
          return false; // Immediate dead-end!
        }
        if (bestOptions == null || options.length < bestOptions.length) {
          bestBit = bit;
          bestOptions = options;
          if (options.length == 1) break; // Forced move!
        }
      }

      if (bestBit == -1 || bestOptions == null) return false;

      for (final cand in bestOptions) {
        remainingPerShape[cand.shape] = remainingPerShape[cand.shape]! - 1;
        chosenPlacements.add(cand);

        if (search(coveredMask | cand.mask)) {
          return true;
        }

        chosenPlacements.removeLast();
        remainingPerShape[cand.shape] = remainingPerShape[cand.shape]! + 1;
      }
      return false;
    }

    if (!search(0)) return null;

    // Assign concrete pieceIndices back to chosenPlacements.
    final queues = <PieceShape, List<int>>{
      for (final e in shapeCounts.entries) e.key: List<int>.from(e.value),
    };
    return [
      for (final p in chosenPlacements)
        SolvedMove(
          pieceIndex: queues[p.shape]!.removeAt(0),
          anchor: p.anchor,
          quarterTurns: p.quarterTurns,
          coords: p.coords,
        ),
    ];
  }

  /// Generates a guaranteed-solvable procedural level (e.g. for Daily Cube)
  /// seeded by [seed].
  static LevelDefinition generateProceduralLevel({
    required int number,
    required int seed,
    int pieceCount = 8,
    String title = 'Daily Cube',
    bool isDaily = true,
  }) {
    final rng = math.Random(seed);
    final shapes = <PieceShape>[
      PieceShape.square2x2,
      PieceShape.tPiece,
      PieceShape.bar3,
      PieceShape.cornerL,
      PieceShape.lTetromino,
      PieceShape.jTetromino,
      PieceShape.zTetromino,
      PieceShape.sTetromino,
      PieceShape.domino,
    ];
    const colors = [
      BeadColor.red,
      BeadColor.yellow,
      BeadColor.blue,
      BeadColor.purple,
      BeadColor.cyan,
    ];

    final occupied = <CubeCoord>{};
    final solution = <SolutionPlacement>[];
    final faces = CubeFace.values;

    var attempts = 0;
    while (solution.length < pieceCount && attempts < 400) {
      attempts++;
      final shape = shapes[rng.nextInt(shapes.length)];
      final color = colors[solution.length % colors.length];
      final piece = PieceDefinition.of(shape, color);
      final face = faces[rng.nextInt(faces.length)];
      final anchor = CubeCoord(face, rng.nextInt(4), rng.nextInt(4));
      final turns = rng.nextInt(4);

      final coords = FoldingEngine.resolveCoords(
        anchor: anchor,
        piece: piece,
        quarterTurns: turns,
      );
      if (coords == null || coords.any(occupied.contains)) continue;

      occupied.addAll(coords);
      solution.add(
        SolutionPlacement(piece: piece, anchor: anchor, quarterTurns: turns),
      );
    }

    return LevelDefinition.fromSolution(
      number: number,
      title: title,
      subtitle: 'Procedural · ${solution.length} pieces',
      solution: solution,
      isDaily: isDaily,
    );
  }
}
