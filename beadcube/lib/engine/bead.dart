import 'cube_topology.dart';

/// Available bead colors in the Bead Cube prototype.
enum BeadColor {
  empty,
  red,
  yellow,
  blue,
  purple,
  cyan,
}

/// Pure-Dart state of all 96 slots (6 faces x 4x4 grid) on the cube.
class CubeBoard {
  CubeBoard()
      : _slots = List<BeadColor>.filled(
          CubeTopology.totalSlots,
          BeadColor.empty,
        );

  final List<BeadColor> _slots;

  int _indexOf(CubeCoord coord) =>
      coord.face.index * (CubeTopology.gridSize * CubeTopology.gridSize) +
      coord.row * CubeTopology.gridSize +
      coord.col;

  BeadColor get(CubeCoord coord) => _slots[_indexOf(coord)];

  void set(CubeCoord coord, BeadColor color) {
    _slots[_indexOf(coord)] = color;
  }

  void clear() {
    _slots.fillRange(0, _slots.length, BeadColor.empty);
  }

  /// Populates a sample multi-face pattern for Milestone 1 visual verification
  /// of face orientations, glossy materials, and edge continuity.
  void loadSamplePattern() {
    clear();

    // Top face: yellow corners + red cross
    for (final c in const [
      CubeCoord(CubeFace.top, 0, 0),
      CubeCoord(CubeFace.top, 0, 3),
      CubeCoord(CubeFace.top, 3, 0),
      CubeCoord(CubeFace.top, 3, 3),
    ]) {
      set(c, BeadColor.yellow);
    }
    for (final c in const [
      CubeCoord(CubeFace.top, 1, 1),
      CubeCoord(CubeFace.top, 1, 2),
      CubeCoord(CubeFace.top, 2, 1),
      CubeCoord(CubeFace.top, 2, 2),
      CubeCoord(CubeFace.top, 0, 1),
      CubeCoord(CubeFace.top, 3, 2),
    ]) {
      set(c, BeadColor.red);
    }

    // Front face: blue L-pattern
    for (final c in const [
      CubeCoord(CubeFace.front, 1, 0),
      CubeCoord(CubeFace.front, 2, 0),
      CubeCoord(CubeFace.front, 2, 1),
      CubeCoord(CubeFace.front, 3, 1),
      CubeCoord(CubeFace.front, 3, 2),
    ]) {
      set(c, BeadColor.blue);
    }

    // Right face: purple T-pattern
    for (final c in const [
      CubeCoord(CubeFace.right, 1, 1),
      CubeCoord(CubeFace.right, 2, 0),
      CubeCoord(CubeFace.right, 2, 1),
      CubeCoord(CubeFace.right, 2, 2),
      CubeCoord(CubeFace.right, 3, 1),
    ]) {
      set(c, BeadColor.purple);
    }

    // Folded cyan L-piece spanning Top -> Front edge
    set(const CubeCoord(CubeFace.top, 3, 2), BeadColor.cyan);
    set(const CubeCoord(CubeFace.front, 0, 2), BeadColor.cyan);
    set(const CubeCoord(CubeFace.front, 0, 1), BeadColor.cyan);
  }
}

