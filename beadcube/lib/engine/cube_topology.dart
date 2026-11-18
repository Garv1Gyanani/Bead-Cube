import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// The six faces of the Bead Cube.
enum CubeFace {
  front, // +Z
  back, // -Z
  right, // +X
  left, // -X
  top, // +Y
  bottom, // -Y
}

/// Grid step directions in a face's local `(row, col)` coordinate space.
enum GridDirection { up, right, down, left }

/// A discrete slot coordinate on the cube (`face`, `row`, `col`).
///
/// Each face is a `gridSize x gridSize` grid (default 4x4).
class CubeCoord {
  const CubeCoord(this.face, this.row, this.col);

  final CubeFace face;
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CubeCoord &&
          face == other.face &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(face, row, col);

  @override
  String toString() => 'CubeCoord(${face.name}, r$row, c$col)';
}

/// Result of stepping one cell across the cube surface, including the
/// transformed local direction after any face-edge fold.
class CubeStepResult {
  const CubeStepResult({
    required this.coord,
    required this.direction,
    required this.crossedEdge,
  });

  final CubeCoord coord;
  final GridDirection direction;
  final bool crossedEdge;
}

/// Result of raycasting against the 3D cube.
class CubeHit {
  const CubeHit({
    required this.coord,
    required this.worldPoint,
    required this.distance,
  });

  final CubeCoord coord;
  final Vector3 worldPoint;
  final double distance;
}

/// Pure-Dart mathematical model of the 6-face cube surface, its 3D basis
/// frames, edge-folding adjacency, and ray-box cell hit-testing.
class CubeTopology {
  const CubeTopology._();

  static const int gridSize = 4;
  static const int totalSlots = 6 * gridSize * gridSize;

  /// All 96 coordinates on the cube in deterministic order.
  static final List<CubeCoord> allCoords = List<CubeCoord>.unmodifiable([
    for (final face in CubeFace.values)
      for (int r = 0; r < gridSize; r++)
        for (int c = 0; c < gridSize; c++) CubeCoord(face, r, c),
  ]);

  /// Outward unit normal for [face] in cube-local 3D space.
  static Vector3 faceNormal(CubeFace face) {
    switch (face) {
      case CubeFace.front:
        return Vector3(0, 0, 1);
      case CubeFace.back:
        return Vector3(0, 0, -1);
      case CubeFace.right:
        return Vector3(1, 0, 0);
      case CubeFace.left:
        return Vector3(-1, 0, 0);
      case CubeFace.top:
        return Vector3(0, 1, 0);
      case CubeFace.bottom:
        return Vector3(0, -1, 0);
    }
  }

  /// Unit vector along +col (left-to-right when looking directly at [face]).
  static Vector3 faceRight(CubeFace face) {
    switch (face) {
      case CubeFace.front:
        return Vector3(1, 0, 0);
      case CubeFace.back:
        return Vector3(-1, 0, 0);
      case CubeFace.right:
        return Vector3(0, 0, -1);
      case CubeFace.left:
        return Vector3(0, 0, 1);
      case CubeFace.top:
        return Vector3(1, 0, 0);
      case CubeFace.bottom:
        return Vector3(1, 0, 0);
    }
  }

  /// Unit vector along +row (top-to-bottom when looking directly at [face]).
  static Vector3 faceDown(CubeFace face) {
    switch (face) {
      case CubeFace.front:
      case CubeFace.back:
      case CubeFace.right:
      case CubeFace.left:
        return Vector3(0, -1, 0);
      case CubeFace.top:
        return Vector3(0, 0, 1);
      case CubeFace.bottom:
        return Vector3(0, 0, -1);
    }
  }

  /// Returns the 3D position of the center of [coord] in cube-local space.
  ///
  /// [cubeHalfSize] is half the side length of the cube (e.g. `1.0` for a
  /// `2x2x2` cube). [surfaceOffset] pushes the point outward along the face
  /// normal.
  static Vector3 cellCenter3D(
    CubeCoord coord, {
    double cubeHalfSize = 1.0,
    double surfaceOffset = 0.0,
  }) {
    final cellSpan = (cubeHalfSize * 2.0) / gridSize;
    final u = (coord.col + 0.5 - gridSize * 0.5) * cellSpan;
    final v = (coord.row + 0.5 - gridSize * 0.5) * cellSpan;
    final n = faceNormal(coord.face);
    final r = faceRight(coord.face);
    final d = faceDown(coord.face);
    return n * (cubeHalfSize + surfaceOffset) + r * u + d * v;
  }

  /// Returns a 4x4 local transform that places a bead oriented with its local
  /// `+Z` pointing along the face normal, `+X` along `faceRight`, and `+Y`
  /// along `-faceDown`.
  static Matrix4 cellTransform(
    CubeCoord coord, {
    double cubeHalfSize = 1.0,
    double surfaceOffset = 0.0,
    Vector3? scale,
  }) {
    final pos = cellCenter3D(
      coord,
      cubeHalfSize: cubeHalfSize,
      surfaceOffset: surfaceOffset,
    );
    final xAxis = faceRight(coord.face);
    final yAxis = -faceDown(coord.face);
    final zAxis = faceNormal(coord.face);
    final sx = scale?.x ?? 1.0;
    final sy = scale?.y ?? 1.0;
    final sz = scale?.z ?? 1.0;

    return Matrix4(
      xAxis.x * sx,
      xAxis.y * sx,
      xAxis.z * sx,
      0.0,
      yAxis.x * sy,
      yAxis.y * sy,
      yAxis.z * sy,
      0.0,
      zAxis.x * sz,
      zAxis.y * sz,
      zAxis.z * sz,
      0.0,
      pos.x,
      pos.y,
      pos.z,
      1.0,
    );
  }

  static final List<CubeStepResult> _stepCache = _buildStepCache();

  static List<CubeStepResult> _buildStepCache() {
    return List<CubeStepResult>.generate(totalSlots * 4, (idx) {
      final dir = GridDirection.values[idx & 3];
      final slot = idx >> 2;
      final face = CubeFace.values[slot ~/ (gridSize * gridSize)];
      final rem = slot % (gridSize * gridSize);
      final row = rem ~/ gridSize;
      final col = rem % gridSize;
      return _computeStep(CubeCoord(face, row, col), dir);
    }, growable: false);
  }

  /// Steps one cell from [coord] in [direction], folding smoothly across cube
  /// edges onto adjacent faces using 3D surface tangent continuity.
  static CubeStepResult step(CubeCoord coord, GridDirection direction) {
    final slot =
        coord.face.index * (gridSize * gridSize) + coord.row * gridSize + coord.col;
    return _stepCache[(slot << 2) | direction.index];
  }

  static CubeStepResult _computeStep(CubeCoord coord, GridDirection direction) {
    final (dr, dc) = _deltaFor(direction);
    final nextRow = coord.row + dr;
    final nextCol = coord.col + dc;

    if (nextRow >= 0 &&
        nextRow < gridSize &&
        nextCol >= 0 &&
        nextCol < gridSize) {
      return CubeStepResult(
        coord: CubeCoord(coord.face, nextRow, nextCol),
        direction: direction,
        crossedEdge: false,
      );
    }

    // Crossed a face edge: the 3D step direction becomes the new face's
    // inward normal (-faceNormal), and the old face's outward normal becomes
    // the new step direction!
    final oldNormal = faceNormal(coord.face);
    final stepVec = _directionVector3D(coord.face, direction);

    final newFace = _faceFromNormal(stepVec);
    final newStepVec = -oldNormal;
    final newDir = _directionFromVector3D(newFace, newStepVec);

    // Map the 3D position of the edge cell onto the adjacent face's (row, col).
    final clampedRow = coord.row.clamp(0, gridSize - 1);
    final clampedCol = coord.col.clamp(0, gridSize - 1);
    final edgePos = cellCenter3D(CubeCoord(coord.face, clampedRow, clampedCol));
    final (mappedRow, mappedCol) = _projectPointToFaceGrid(newFace, edgePos);

    return CubeStepResult(
      coord: CubeCoord(newFace, mappedRow, mappedCol),
      direction: newDir,
      crossedEdge: true,
    );
  }

  /// Raycasts a world-space ray (`rayOrigin`, `rayDir`) against an
  /// axis-aligned cube centered at the origin with half-extent [cubeHalfSize].
  ///
  /// Returns the closest [CubeHit] or `null` if the ray misses the cube.
  static CubeHit? raycastCube(
    Vector3 rayOrigin,
    Vector3 rayDir, {
    double cubeHalfSize = 1.0,
  }) {
    final dir = rayDir.normalized();
    var tMin = double.negativeInfinity;
    var tMax = double.infinity;
    CubeFace? hitFace;

    bool testAxis(
      double origin,
      double d,
      CubeFace negFace,
      CubeFace posFace,
    ) {
      if (d.abs() < 1e-8) {
        return origin.abs() <= cubeHalfSize;
      }
      var t1 = (-cubeHalfSize - origin) / d;
      var t2 = (cubeHalfSize - origin) / d;
      var f1 = negFace;
      var f2 = posFace;
      if (t1 > t2) {
        final tmpT = t1;
        t1 = t2;
        t2 = tmpT;
        final tmpF = f1;
        f1 = f2;
        f2 = tmpF;
      }
      if (t1 > tMin) {
        tMin = t1;
        hitFace = f1;
      }
      tMax = math.min(tMax, t2);
      return tMin <= tMax;
    }

    if (!testAxis(rayOrigin.x, dir.x, CubeFace.left, CubeFace.right)) {
      return null;
    }
    if (!testAxis(rayOrigin.y, dir.y, CubeFace.bottom, CubeFace.top)) {
      return null;
    }
    if (!testAxis(rayOrigin.z, dir.z, CubeFace.back, CubeFace.front)) {
      return null;
    }

    if (tMax < 0 || tMin < 0 || hitFace == null) {
      return null;
    }

    final hitPoint = rayOrigin + dir * tMin;
    final (row, col) = _projectPointToFaceGrid(
      hitFace!,
      hitPoint,
      cubeHalfSize: cubeHalfSize,
    );
    return CubeHit(
      coord: CubeCoord(hitFace!, row, col),
      worldPoint: hitPoint,
      distance: tMin,
    );
  }

  static (int, int) _deltaFor(GridDirection dir) {
    switch (dir) {
      case GridDirection.up:
        return (-1, 0);
      case GridDirection.right:
        return (0, 1);
      case GridDirection.down:
        return (1, 0);
      case GridDirection.left:
        return (0, -1);
    }
  }

  static Vector3 _directionVector3D(CubeFace face, GridDirection dir) {
    switch (dir) {
      case GridDirection.up:
        return -faceDown(face);
      case GridDirection.right:
        return faceRight(face);
      case GridDirection.down:
        return faceDown(face);
      case GridDirection.left:
        return -faceRight(face);
    }
  }

  static CubeFace _faceFromNormal(Vector3 n) {
    for (final face in CubeFace.values) {
      if (faceNormal(face).dot(n) > 0.9) {
        return face;
      }
    }
    throw ArgumentError('Invalid face normal: $n');
  }

  static GridDirection _directionFromVector3D(CubeFace face, Vector3 v) {
    final r = faceRight(face);
    final d = faceDown(face);
    if (v.dot(r) > 0.9) return GridDirection.right;
    if (v.dot(r) < -0.9) return GridDirection.left;
    if (v.dot(d) > 0.9) return GridDirection.down;
    if (v.dot(d) < -0.9) return GridDirection.up;
    throw ArgumentError('Vector $v is not aligned with face $face');
  }

  static (int, int) _projectPointToFaceGrid(
    CubeFace face,
    Vector3 point, {
    double cubeHalfSize = 1.0,
  }) {
    final u = point.dot(faceRight(face));
    final v = point.dot(faceDown(face));
    final size = cubeHalfSize * 2.0;
    final normCol = ((u + cubeHalfSize) / size).clamp(0.0, 0.9999);
    final normRow = ((v + cubeHalfSize) / size).clamp(0.0, 0.9999);
    final col = (normCol * gridSize).floor().clamp(0, gridSize - 1);
    final row = (normRow * gridSize).floor().clamp(0, gridSize - 1);
    return (row, col);
  }
}

