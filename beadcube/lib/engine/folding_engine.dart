import 'dart:collection';

import 'bead.dart';
import 'cube_topology.dart';
import 'piece.dart';

/// Result of resolving and validating a piece placement on the cube.
class PlacementResult {
  const PlacementResult({
    required this.coords,
    required this.isValid,
    required this.foldedAcrossEdge,
    this.invalidReason,
  });

  final List<CubeCoord> coords;
  final bool isValid;
  final bool foldedAcrossEdge;
  final String? invalidReason;
}

/// Maps 2D rotated piece shapes onto the 3D cube surface, folding across
/// cube edges via [CubeTopology.step] and validating against [CubeBoard].
class FoldingEngine {
  const FoldingEngine._();

  /// Resolves the list of [CubeCoord]s occupied by [piece] anchored at
  /// [anchor] with [quarterTurns] clockwise 90° rotations.
  ///
  /// Returns `null` if two cells of the same piece fold onto the same slot.
  static List<CubeCoord>? resolveCoords({
    required CubeCoord anchor,
    required PieceDefinition piece,
    required int quarterTurns,
  }) {
    final offsets = piece.rotatedCells(quarterTurns);
    final offsetSet = offsets.toSet();
    final visited = <({int dr, int dc}), ({CubeCoord coord, int frameRot})>{};
    final queue = Queue<({int dr, int dc})>();

    const start = (dr: 0, dc: 0);
    visited[start] = (coord: anchor, frameRot: 0);
    queue.add(start);

    const localDirs = [
      (dr: -1, dc: 0, dirIdx: 0), // up
      (dr: 0, dc: 1, dirIdx: 1), // right
      (dr: 1, dc: 0, dirIdx: 2), // down
      (dr: 0, dc: -1, dirIdx: 3), // left
    ];

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final state = visited[current]!;

      for (final d in localDirs) {
        final next = (dr: current.dr + d.dr, dc: current.dc + d.dc);
        if (!offsetSet.contains(next) || visited.containsKey(next)) {
          continue;
        }
        final faceDirIdx = (d.dirIdx + state.frameRot) % 4;
        final stepRes = CubeTopology.step(
          state.coord,
          GridDirection.values[faceDirIdx],
        );
        final nextFrameRot = (stepRes.direction.index - d.dirIdx + 4) % 4;
        visited[next] = (coord: stepRes.coord, frameRot: nextFrameRot);
        queue.add(next);
      }
    }

    if (visited.length != offsets.length) {
      return null;
    }

    final coords = [
      for (final o in offsets) visited[o]!.coord,
    ];
    if (coords.toSet().length != coords.length) {
      return null; // Self-overlap across a corner.
    }

    // Ensure closed loops (e.g. 2x2 squares) don't tear across a 3-face corner
    // vertex: every 4-connected pair in piece space must remain adjacent on the
    // cube surface.
    for (int i = 0; i < offsets.length; i++) {
      for (int j = i + 1; j < offsets.length; j++) {
        final manhattan = (offsets[i].dr - offsets[j].dr).abs() +
            (offsets[i].dc - offsets[j].dc).abs();
        if (manhattan == 1 && !_areAdjacentOnCube(coords[i], coords[j])) {
          return null;
        }
      }
    }

    return coords;
  }

  static bool _areAdjacentOnCube(CubeCoord a, CubeCoord b) {
    for (final dir in GridDirection.values) {
      if (CubeTopology.step(a, dir).coord == b) return true;
    }
    return false;
  }

  /// Validates placing [piece] at [anchor] with [quarterTurns] rotation on
  /// [board] against [target].
  static PlacementResult validatePlacement({
    required CubeBoard board,
    required CubeBoard target,
    required CubeCoord anchor,
    required PieceDefinition piece,
    required int quarterTurns,
  }) {
    final coords = resolveCoords(
      anchor: anchor,
      piece: piece,
      quarterTurns: quarterTurns,
    );

    if (coords == null) {
      return const PlacementResult(
        coords: [],
        isValid: false,
        foldedAcrossEdge: false,
        invalidReason: 'Piece folds onto itself',
      );
    }

    final folded = coords.map((c) => c.face).toSet().length > 1;

    for (final c in coords) {
      if (board.get(c) != BeadColor.empty) {
        return PlacementResult(
          coords: coords,
          isValid: false,
          foldedAcrossEdge: folded,
          invalidReason: 'Overlap',
        );
      }
      final targetColor = target.get(c);
      if (targetColor == BeadColor.empty) {
        return PlacementResult(
          coords: coords,
          isValid: false,
          foldedAcrossEdge: folded,
          invalidReason: 'Must stay empty',
        );
      }
      if (targetColor != piece.color) {
        return PlacementResult(
          coords: coords,
          isValid: false,
          foldedAcrossEdge: folded,
          invalidReason: 'Wrong color',
        );
      }
    }

    return PlacementResult(
      coords: coords,
      isValid: true,
      foldedAcrossEdge: folded,
    );
  }

  /// Tries anchoring [piece] at [tappedCoord] first; if that is invalid,
  /// checks whether shifting [piece] so any of its other cells lands on
  /// [tappedCoord] produces a valid placement.
  static PlacementResult findBestPlacementAt({
    required CubeBoard board,
    required CubeBoard target,
    required CubeCoord tappedCoord,
    required PieceDefinition piece,
    required int quarterTurns,
  }) {
    final direct = validatePlacement(
      board: board,
      target: target,
      anchor: tappedCoord,
      piece: piece,
      quarterTurns: quarterTurns,
    );
    if (direct.isValid) return direct;

    final offsets = piece.rotatedCells(quarterTurns);
    for (final offset in offsets) {
      if (offset.dr == 0 && offset.dc == 0) continue;
      final candidateAnchor = _walkOffset(tappedCoord, -offset.dr, -offset.dc);
      final candidate = validatePlacement(
        board: board,
        target: target,
        anchor: candidateAnchor,
        piece: piece,
        quarterTurns: quarterTurns,
      );
      if (candidate.isValid && candidate.coords.contains(tappedCoord)) {
        return candidate;
      }
    }

    return direct;
  }

  static CubeCoord _walkOffset(CubeCoord start, int dRow, int dCol) {
    var current = start;
    var rowSteps = dRow;
    var colSteps = dCol;

    // Track local frame orientation as we step across edges.
    var frameRot = 0;
    while (rowSteps != 0) {
      final localDir = rowSteps > 0 ? 2 : 0; // down : up
      final stepRes = CubeTopology.step(
        current,
        GridDirection.values[(localDir + frameRot) % 4],
      );
      frameRot = (stepRes.direction.index - localDir + 4) % 4;
      current = stepRes.coord;
      rowSteps += rowSteps > 0 ? -1 : 1;
    }
    while (colSteps != 0) {
      final localDir = colSteps > 0 ? 1 : 3; // right : left
      final stepRes = CubeTopology.step(
        current,
        GridDirection.values[(localDir + frameRot) % 4],
      );
      frameRot = (stepRes.direction.index - localDir + 4) % 4;
      current = stepRes.coord;
      colSteps += colSteps > 0 ? -1 : 1;
    }
    return current;
  }
}

