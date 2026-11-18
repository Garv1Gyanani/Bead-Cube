import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// A procedural 3D rounded-corner, beveled-rim square tile centered in XY on
/// `z = 0` and extruding along `+Z` to [height].
///
/// Smooth normals around the rounded corners and chamfered rim produce
/// glossy, toy-like specular highlights.
class BeveledTileGeometry extends MeshGeometry {
  factory BeveledTileGeometry({
    double halfWidth = 0.22,
    double height = 0.088,
    double bevel = 0.032,
    double cornerRadius = 0.055,
    int cornerSegments = 4,
  }) {
    return BeveledTileGeometry._(
      _buildRoundedBeveledTileArrays(
        halfWidth: halfWidth,
        height: height,
        bevel: bevel,
        cornerRadius: cornerRadius,
        cornerSegments: cornerSegments,
      ),
    );
  }

  BeveledTileGeometry._(
    ({
      Float32List positions,
      Float32List normals,
      Float32List texCoords,
      List<int> indices,
    }) arrays,
  ) : super.fromArrays(
          positions: arrays.positions,
          normals: arrays.normals,
          texCoords: arrays.texCoords,
          indices: arrays.indices,
        );
}

/// A procedural rounded-edge cube centered at the origin with outer extent
/// `[-halfSize, +halfSize]` on each axis.
class RoundedCubeGeometry extends MeshGeometry {
  factory RoundedCubeGeometry({
    double halfSize = 0.99,
    double cornerRadius = 0.08,
    int segments = 4,
  }) {
    return RoundedCubeGeometry._(
      _buildRoundedCubeArrays(
        halfSize: halfSize,
        cornerRadius: cornerRadius,
        segments: segments,
      ),
    );
  }

  RoundedCubeGeometry._(
    ({
      Float32List positions,
      Float32List normals,
      Float32List texCoords,
      List<int> indices,
    }) arrays,
  ) : super.fromArrays(
          positions: arrays.positions,
          normals: arrays.normals,
          texCoords: arrays.texCoords,
          indices: arrays.indices,
        );
}

List<({double x, double y, double nx, double ny})> _roundedSquareRing({
  required double halfWidth,
  required double cornerRadius,
  required int cornerSegments,
}) {
  final r = cornerRadius.clamp(0.005, halfWidth * 0.48);
  final inner = halfWidth - r;
  final points = <({double x, double y, double nx, double ny})>[];

  // Four quadrants in CCW order: (+,+), (-,+), (-,-), (+,-)
  final centers = [
    (cx: inner, cy: inner, startAngle: 0.0),
    (cx: -inner, cy: inner, startAngle: math.pi * 0.5),
    (cx: -inner, cy: -inner, startAngle: math.pi),
    (cx: inner, cy: -inner, startAngle: math.pi * 1.5),
  ];

  for (final q in centers) {
    for (int i = 0; i <= cornerSegments; i++) {
      final a = q.startAngle + (math.pi * 0.5) * (i / cornerSegments);
      final nx = math.cos(a);
      final ny = math.sin(a);
      points.add((
        x: q.cx + nx * r,
        y: q.cy + ny * r,
        nx: nx,
        ny: ny,
      ));
    }
  }
  return points;
}

({
  Float32List positions,
  Float32List normals,
  Float32List texCoords,
  List<int> indices,
}) _buildRoundedBeveledTileArrays({
  required double halfWidth,
  required double height,
  required double bevel,
  required double cornerRadius,
  required int cornerSegments,
}) {
  final midZ = (height - bevel).clamp(0.01, height);
  final topZ = height;
  final innerHalf = (halfWidth - bevel).clamp(0.02, halfWidth);
  final innerRadius = (cornerRadius - bevel * 0.65).clamp(0.005, innerHalf * 0.48);

  final outerRing = _roundedSquareRing(
    halfWidth: halfWidth,
    cornerRadius: cornerRadius,
    cornerSegments: cornerSegments,
  );
  final innerRing = _roundedSquareRing(
    halfWidth: innerHalf,
    cornerRadius: innerRadius,
    cornerSegments: cornerSegments,
  );
  final count = outerRing.length;

  final positions = <double>[];
  final normals = <double>[];
  final texCoords = <double>[];
  final indices = <int>[];

  void addVertex(Vector3 p, Vector3 n, double u, double v) {
    positions.addAll([p.x, p.y, p.z]);
    final nn = n.normalized();
    normals.addAll([nn.x, nn.y, nn.z]);
    texCoords.addAll([u, v]);
  }

  // 1. Side walls (base z=0 to midZ) with smooth radial normals.
  final sideStart = positions.length ~/ 3;
  for (int i = 0; i < count; i++) {
    final p = outerRing[i];
    final n = Vector3(p.nx, p.ny, 0);
    addVertex(Vector3(p.x, p.y, 0), n, i / count, 0);
    addVertex(Vector3(p.x, p.y, midZ), n, i / count, 1);
  }
  for (int i = 0; i < count; i++) {
    final next = (i + 1) % count;
    final b0 = sideStart + i * 2;
    final t0 = b0 + 1;
    final b1 = sideStart + next * 2;
    final t1 = b1 + 1;
    indices.addAll([b0, b1, t1, b0, t1, t0]);
  }

  // 2. Beveled chamfer rim (midZ to topZ) with 45-deg tilted smooth normals.
  final bevelStart = positions.length ~/ 3;
  for (int i = 0; i < count; i++) {
    final po = outerRing[i];
    final pi = innerRing[i];
    final n = Vector3(po.nx, po.ny, 1.0);
    addVertex(Vector3(po.x, po.y, midZ), n, i / count, 0);
    addVertex(Vector3(pi.x, pi.y, topZ), n, i / count, 1);
  }
  for (int i = 0; i < count; i++) {
    final next = (i + 1) % count;
    final b0 = bevelStart + i * 2;
    final t0 = b0 + 1;
    final b1 = bevelStart + next * 2;
    final t1 = b1 + 1;
    indices.addAll([b0, b1, t1, b0, t1, t0]);
  }

  // 3. Top flat cap (fan from center).
  final topCenterIdx = positions.length ~/ 3;
  addVertex(Vector3(0, 0, topZ), Vector3(0, 0, 1), 0.5, 0.5);
  final topRingStart = positions.length ~/ 3;
  for (int i = 0; i < count; i++) {
    final pi = innerRing[i];
    addVertex(
      Vector3(pi.x, pi.y, topZ),
      Vector3(0, 0, 1),
      0.5 + pi.x / (halfWidth * 2),
      0.5 + pi.y / (halfWidth * 2),
    );
  }
  for (int i = 0; i < count; i++) {
    final next = (i + 1) % count;
    indices.addAll([topCenterIdx, topRingStart + i, topRingStart + next]);
  }

  return (
    positions: Float32List.fromList(positions),
    normals: Float32List.fromList(normals),
    texCoords: Float32List.fromList(texCoords),
    indices: indices,
  );
}

({
  Float32List positions,
  Float32List normals,
  Float32List texCoords,
  List<int> indices,
}) _buildRoundedCubeArrays({
  required double halfSize,
  required double cornerRadius,
  required int segments,
}) {
  // Build a subdivided unit cube on each of the 6 faces, then project each
  // point onto an inset inner box + spherical radius offset so all 12 edges
  // and 8 corners are smoothly rounded.
  final r = cornerRadius.clamp(0.01, halfSize * 0.45);
  final inner = halfSize - r;
  final gridSteps = segments * 2 + 1;

  final positions = <double>[];
  final normals = <double>[];
  final texCoords = <double>[];
  final indices = <int>[];

  final faces = <({Vector3 n, Vector3 u, Vector3 v})>[
    (n: Vector3(0, 0, 1), u: Vector3(1, 0, 0), v: Vector3(0, 1, 0)), // +Z
    (n: Vector3(0, 0, -1), u: Vector3(-1, 0, 0), v: Vector3(0, 1, 0)), // -Z
    (n: Vector3(1, 0, 0), u: Vector3(0, 0, -1), v: Vector3(0, 1, 0)), // +X
    (n: Vector3(-1, 0, 0), u: Vector3(0, 0, 1), v: Vector3(0, 1, 0)), // -X
    (n: Vector3(0, 1, 0), u: Vector3(1, 0, 0), v: Vector3(0, 0, -1)), // +Y
    (n: Vector3(0, -1, 0), u: Vector3(1, 0, 0), v: Vector3(0, 0, 1)), // -Y
  ];

  for (final face in faces) {
    final baseVertex = positions.length ~/ 3;
    for (int iy = 0; iy <= gridSteps; iy++) {
      final tv = (iy / gridSteps) * 2.0 - 1.0;
      for (int ix = 0; ix <= gridSteps; ix++) {
        final tu = (ix / gridSteps) * 2.0 - 1.0;
        final raw = (face.n + face.u * tu + face.v * tv) * halfSize;
        final clamped = Vector3(
          raw.x.clamp(-inner, inner),
          raw.y.clamp(-inner, inner),
          raw.z.clamp(-inner, inner),
        );
        final diff = raw - clamped;
        final normal = diff.length2 > 1e-10 ? diff.normalized() : face.n;
        final pos = clamped + normal * r;

        positions.addAll([pos.x, pos.y, pos.z]);
        normals.addAll([normal.x, normal.y, normal.z]);
        texCoords.addAll([ix / gridSteps, iy / gridSteps]);
      }
    }

    final stride = gridSteps + 1;
    for (int iy = 0; iy < gridSteps; iy++) {
      for (int ix = 0; ix < gridSteps; ix++) {
        final a = baseVertex + iy * stride + ix;
        final b = a + 1;
        final c = a + stride + 1;
        final d = a + stride;
        indices.addAll([a, b, c, a, c, d]);
      }
    }
  }

  return (
    positions: Float32List.fromList(positions),
    normals: Float32List.fromList(normals),
    texCoords: Float32List.fromList(texCoords),
    indices: indices,
  );
}
