import 'package:beadcube/engine/bead.dart';
import 'package:beadcube/engine/cube_topology.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('CubeTopology', () {
    test('has 96 unique coordinates across 6 faces', () {
      expect(CubeTopology.allCoords.length, 96);
      expect(CubeTopology.allCoords.toSet().length, 96);
    });

    test('stepping 16 times around equator returns to start', () {
      const start = CubeCoord(CubeFace.front, 1, 2);
      var current = start;
      var dir = GridDirection.right;

      for (int i = 0; i < 16; i++) {
        final step = CubeTopology.step(current, dir);
        current = step.coord;
        dir = step.direction;
      }

      expect(current, start);
      expect(dir, GridDirection.right);
    });

    test('stepping up from front row 0 crosses onto top row 3', () {
      const start = CubeCoord(CubeFace.front, 0, 2);
      final res = CubeTopology.step(start, GridDirection.up);
      expect(res.crossedEdge, isTrue);
      expect(res.coord, const CubeCoord(CubeFace.top, 3, 2));
      expect(res.direction, GridDirection.up);
    });

    test('raycastCube hits exact cell center for every slot', () {
      for (final coord in CubeTopology.allCoords) {
        final center = CubeTopology.cellCenter3D(coord);
        final normal = CubeTopology.faceNormal(coord.face);
        final rayOrigin = center + normal * 3.0;
        final hit = CubeTopology.raycastCube(rayOrigin, -normal);
        expect(hit, isNotNull, reason: 'Expected hit for $coord');
        expect(hit!.coord, coord);
      }
    });

    test('raycastCube returns null when ray misses cube', () {
      final hit = CubeTopology.raycastCube(
        Vector3(5, 5, 5),
        Vector3(0, 1, 0),
      );
      expect(hit, isNull);
    });
  });

  group('CubeBoard', () {
    test('sample pattern populates colored beads', () {
      final board = CubeBoard()..loadSamplePattern();
      expect(board.get(const CubeCoord(CubeFace.top, 0, 0)), BeadColor.yellow);
      expect(board.get(const CubeCoord(CubeFace.front, 0, 2)), BeadColor.cyan);
      expect(board.get(const CubeCoord(CubeFace.back, 0, 0)), BeadColor.empty);
    });
  });
}

