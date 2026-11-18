import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../engine/bead.dart';
import '../engine/cube_topology.dart';
import 'beveled_tile_geometry.dart';

/// Manages the 3D `flutter_scene` [Scene], glossy beveled tile meshes/materials,
/// quaternion trackball cube rotation with smooth flick inertia & pinch-zoom,
/// tactile bead tap-bounce animation, and exact local-space raycasting.
class BeadCubeSceneController {
  BeadCubeSceneController({required this.board}) {
    _initScene();
    syncAllBeads();
  }

  static const double cubeHalfSize = 1.0;
  static const double _tileSurfaceOffset = -0.02;
  static const double _minDistance = 4.8;
  static const double _maxDistance = 9.0;
  static const double _defaultDistance = 6.6;

  final CubeBoard board;
  final Scene scene = Scene();

  late final Node _cubeRoot;
  final Map<CubeCoord, Node> _beadNodes = <CubeCoord, Node>{};
  final Map<BeadColor, PhysicallyBasedMaterial> _materials =
      <BeadColor, PhysicallyBasedMaterial>{};
  final Map<BeadColor, PhysicallyBasedMaterial> _targetOverlayMaterials =
      <BeadColor, PhysicallyBasedMaterial>{};
  final Map<CubeCoord, double> _beadPulse = <CubeCoord, double>{};

  late final BeveledTileGeometry _beadGeometry;
  late final PhysicallyBasedMaterial _ghostValidMaterial;
  late final PhysicallyBasedMaterial _ghostInvalidMaterial;
  late final PhysicallyBasedMaterial _tutorialHintMaterial;

  CubeBoard? _targetBoard;
  bool _overlayTarget = true;
  Set<CubeCoord> _ghostCoords = const {};
  bool _ghostIsValid = true;
  CubeCoord? _tutorialHintCoord;

  // Quaternion trackball orientation of the cube (no gimbal lock).
  Quaternion _rotation = _eulerToQuat(0.55, 0.42);
  Quaternion? _targetRotation;
  double _yawVelocity = 0.0;
  double _pitchVelocity = 0.0;

  double _distance = _defaultDistance;
  double _targetDistance = _defaultDistance;
  double _gestureStartDistance = _defaultDistance;
  bool _isDragging = false;

  // Ambient float, level-intro scale-in, and highlight shimmer timers.
  double _elapsedTime = 0.0;
  double _introProgress = 1.0;

  static Quaternion _eulerToQuat(double yaw, double pitch) {
    final qY = Quaternion.axisAngle(Vector3(0, 1, 0), -yaw);
    // Negative X rotation tilts the +Y (Top) face toward the +Z camera.
    final qX = Quaternion.axisAngle(Vector3(1, 0, 0), -pitch);
    return (qX * qY).normalized();
  }

  void _initScene() {
    scene.environmentIntensity = 1.05;
    scene.directionalLight = DirectionalLight(
      direction: Vector3(0.45, -1.0, -0.65),
      color: Vector3(1.0, 0.99, 0.97),
      intensity: 3.4,
    );

    _cubeRoot = Node(name: 'cube_root');
    _applyCubeTransform();
    scene.add(_cubeRoot);

    // Rounded-edge cube core so the outer silhouette has smooth toy edges
    // and the tile gaps read as crisp seams.
    final coreMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = Vector4(0.62, 0.70, 0.80, 1.0)
      ..roughnessFactor = 0.45
      ..metallicFactor = 0.05;
    final coreGeometry = RoundedCubeGeometry(
      halfSize: cubeHalfSize * 0.985,
      cornerRadius: 0.09,
      segments: 5,
    );
    _cubeRoot.add(
      Node(
        name: 'cube_core',
        mesh: Mesh(coreGeometry, coreMaterial),
      ),
    );

    // Shared rounded-corner beveled-tile geometry and glossy PBR materials.
    _beadGeometry = BeveledTileGeometry(
      halfWidth: 0.218,
      height: 0.088,
      bevel: 0.032,
      cornerRadius: 0.055,
      cornerSegments: 4,
    );

    _materials[BeadColor.empty] = PhysicallyBasedMaterial()
      ..baseColorFactor = Vector4(0.92, 0.94, 0.97, 1.0)
      ..roughnessFactor = 0.30
      ..metallicFactor = 0.02;

    _materials[BeadColor.red] = _glossyMaterial(0.95, 0.20, 0.24);
    _materials[BeadColor.yellow] = _glossyMaterial(0.99, 0.80, 0.12);
    _materials[BeadColor.blue] = _glossyMaterial(0.14, 0.52, 0.98);
    _materials[BeadColor.purple] = _glossyMaterial(0.62, 0.26, 0.92);
    _materials[BeadColor.cyan] = _glossyMaterial(0.08, 0.84, 0.92);

    // Clear, readable target-overlay tints on empty slots.
    _targetOverlayMaterials[BeadColor.red] = _overlayMaterial(0.96, 0.62, 0.64);
    _targetOverlayMaterials[BeadColor.yellow] =
        _overlayMaterial(0.98, 0.87, 0.50);
    _targetOverlayMaterials[BeadColor.blue] =
        _overlayMaterial(0.56, 0.76, 0.98);
    _targetOverlayMaterials[BeadColor.purple] =
        _overlayMaterial(0.78, 0.62, 0.96);
    _targetOverlayMaterials[BeadColor.cyan] =
        _overlayMaterial(0.54, 0.89, 0.94);

    _ghostValidMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = Vector4(0.22, 0.92, 0.48, 1.0)
      ..emissiveFactor = Vector4(0.08, 0.35, 0.16, 1.0)
      ..roughnessFactor = 0.14
      ..metallicFactor = 0.05;

    _ghostInvalidMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = Vector4(0.96, 0.26, 0.30, 1.0)
      ..emissiveFactor = Vector4(0.35, 0.06, 0.08, 1.0)
      ..roughnessFactor = 0.18
      ..metallicFactor = 0.05;

    _tutorialHintMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = Vector4(0.99, 0.88, 0.32, 1.0)
      ..emissiveFactor = Vector4(0.24, 0.18, 0.02, 1.0)
      ..roughnessFactor = 0.18
      ..metallicFactor = 0.04;

    for (final coord in CubeTopology.allCoords) {
      final node = Node(
        name: 'bead_${coord.face.name}_${coord.row}_${coord.col}',
        localTransform: _transformForBead(coord, highlighted: false),
        mesh: Mesh(_beadGeometry, _materials[BeadColor.empty]!),
      );
      _beadNodes[coord] = node;
      _cubeRoot.add(node);
    }
  }

  void _applyCubeTransform() {
    // Subtle easeOutBack scale during level intro + gentle vertical hover.
    double scale = 1.0;
    if (_introProgress < 1.0) {
      final t = _introProgress.clamp(0.0, 1.0);
      const c1 = 1.70158;
      const c3 = c1 + 1.0;
      final tm1 = t - 1.0;
      final eased = 1.0 + c3 * tm1 * tm1 * tm1 + c1 * tm1 * tm1;
      scale = 0.82 + 0.18 * eased;
    }
    final floatY = _isDragging ? 0.0 : math.sin(_elapsedTime * 1.8) * 0.032;

    final rotMat = Matrix4.compose(
      Vector3(0.0, floatY, 0.0),
      _rotation,
      Vector3.all(scale),
    );
    final mirrorX = Matrix4.diagonal3Values(-1, 1, 1);
    _cubeRoot.localTransform = rotMat * mirrorX;
  }

  PhysicallyBasedMaterial _glossyMaterial(double r, double g, double b) {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = Vector4(r, g, b, 1.0)
      ..roughnessFactor = 0.12
      ..metallicFactor = 0.08;
  }

  PhysicallyBasedMaterial _overlayMaterial(double r, double g, double b) {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = Vector4(r, g, b, 1.0)
      ..roughnessFactor = 0.34
      ..metallicFactor = 0.02;
  }

  Matrix4 _transformForBead(CubeCoord coord, {required bool highlighted}) {
    final pulse = _beadPulse[coord] ?? 0.0;
    final shimmer =
        highlighted ? (0.5 + 0.5 * math.sin(_elapsedTime * 5.2)) : 0.0;
    final xyScale =
        (highlighted ? 1.02 + shimmer * 0.035 : 1.0) + pulse * 0.08;
    final zScale =
        (highlighted ? 1.22 + shimmer * 0.22 : 1.0) + pulse * 0.65;
    return CubeTopology.cellTransform(
      coord,
      cubeHalfSize: cubeHalfSize,
      surfaceOffset: _tileSurfaceOffset,
      scale: Vector3(xyScale, xyScale, zScale),
    );
  }

  void setTargetOverlay(CubeBoard? target, bool enabled) {
    _targetBoard = target;
    _overlayTarget = enabled;
    syncAllBeads();
  }

  void setGhostPreview(List<CubeCoord> coords, {required bool isValid}) {
    final previous = _ghostCoords;
    _ghostCoords = coords.toSet();
    _ghostIsValid = isValid;
    for (final c in previous) {
      syncBead(c);
    }
    for (final c in _ghostCoords) {
      syncBead(c);
    }
  }

  void clearGhostPreview() {
    if (_ghostCoords.isEmpty) return;
    final previous = _ghostCoords;
    _ghostCoords = const {};
    for (final c in previous) {
      syncBead(c);
    }
  }

  void setTutorialHint(CubeCoord? coord) {
    final previous = _tutorialHintCoord;
    _tutorialHintCoord = coord;
    if (previous != null) syncBead(previous);
    if (coord != null) syncBead(coord);
  }

  /// Smoothly rotates the cube to a preset `(yaw, pitch)` viewing angle.
  void setViewAngle(double yaw, double pitch) {
    _isDragging = false;
    _yawVelocity = 0.0;
    _pitchVelocity = 0.0;
    _targetRotation = _eulerToQuat(yaw, pitch);
  }

  /// Smoothly resets to the default isometric 3-face view and zoom.
  void resetView() {
    _targetDistance = _defaultDistance;
    setViewAngle(0.65, 0.45);
  }

  /// Plays an elastic entrance scale-in and bead ripple when loading a level.
  void playLevelIntro() {
    _introProgress = 0.0;
    for (final coord in CubeTopology.allCoords) {
      if (board.get(coord) != BeadColor.empty ||
          (_overlayTarget && (_targetBoard?.get(coord) ?? BeadColor.empty) != BeadColor.empty)) {
        _beadPulse[coord] = 0.75;
      }
    }
  }

  /// Triggers a celebratory 360° spin flourish + full-cube ripple on win.
  void playWinFlourish() {
    _isDragging = false;
    _targetRotation = null;
    _yawVelocity = 6.8;
    _pitchVelocity = 1.6;
    for (final coord in CubeTopology.allCoords) {
      if (board.get(coord) != BeadColor.empty) {
        _beadPulse[coord] = 1.15;
      }
    }
  }

  void syncAllBeads() {
    for (final coord in CubeTopology.allCoords) {
      syncBead(coord);
    }
  }

  void syncBead(CubeCoord coord, {bool pulse = false}) {
    final node = _beadNodes[coord];
    if (node == null) return;
    if (pulse) {
      _beadPulse[coord] = 1.0;
    }

    final isGhost = _ghostCoords.contains(coord);
    final isTutorialHint = !isGhost &&
        coord == _tutorialHintCoord &&
        board.get(coord) == BeadColor.empty;
    final color = board.get(coord);

    late final PhysicallyBasedMaterial material;
    if (isGhost) {
      material = _ghostIsValid ? _ghostValidMaterial : _ghostInvalidMaterial;
    } else if (color != BeadColor.empty) {
      material = _materials[color]!;
    } else if (isTutorialHint) {
      material = _tutorialHintMaterial;
    } else if (_overlayTarget && _targetBoard != null) {
      final targetColor = _targetBoard!.get(coord);
      material = targetColor != BeadColor.empty
          ? _targetOverlayMaterials[targetColor]!
          : _materials[BeadColor.empty]!;
    } else {
      material = _materials[BeadColor.empty]!;
    }

    node.mesh = Mesh(_beadGeometry, material);
    node.localTransform = _transformForBead(
      coord,
      highlighted: isGhost || isTutorialHint,
    );
  }

  void beginGesture() {
    _isDragging = true;
    _targetRotation = null;
    _yawVelocity = 0.0;
    _pitchVelocity = 0.0;
    _gestureStartDistance = _targetDistance;
  }

  void updateGesture({
    required double dx,
    required double dy,
    double scale = 1.0,
    int pointerCount = 1,
  }) {
    const sensitivity = 0.0085;
    _applyTrackballDelta(dx * sensitivity, dy * sensitivity);

    if (pointerCount >= 2 && (scale - 1.0).abs() > 0.001) {
      _targetDistance = (_gestureStartDistance / scale).clamp(
        _minDistance,
        _maxDistance,
      );
    }
  }

  void _applyTrackballDelta(double dYaw, double dPitch) {
    // Dragging right (dYaw > 0) spins the front face right (-Y rotation in
    // flutter_scene's left-handed camera). Dragging down (dPitch > 0) tilts
    // the top face toward the camera (+X rotation).
    final qY = Quaternion.axisAngle(Vector3(0, 1, 0), -dYaw);
    final qX = Quaternion.axisAngle(Vector3(1, 0, 0), dPitch);
    _rotation = (qX * qY * _rotation).normalized();
    _applyCubeTransform();
  }

  void endGesture({ui.Offset velocityPixelsPerSecond = ui.Offset.zero}) {
    _isDragging = false;
    const sensitivity = 0.0085;
    _yawVelocity = (velocityPixelsPerSecond.dx * sensitivity).clamp(-12.0, 12.0);
    _pitchVelocity =
        (velocityPixelsPerSecond.dy * sensitivity).clamp(-12.0, 12.0);
  }

  void tick(double deltaSeconds) {
    final dt = deltaSeconds.clamp(0.0, 0.05);
    _elapsedTime += dt;

    if (_introProgress < 1.0) {
      _introProgress = (_introProgress + dt * 2.1).clamp(0.0, 1.0);
    }

    // Smooth zoom interpolation.
    final zoomLerp = 1.0 - math.exp(-14.0 * dt);
    _distance += (_targetDistance - _distance) * zoomLerp;

    // Breathing shimmer on active ghost preview & tutorial hint beads.
    for (final coord in _ghostCoords) {
      final node = _beadNodes[coord];
      if (node != null) {
        node.localTransform = _transformForBead(coord, highlighted: true);
      }
    }
    if (_tutorialHintCoord != null &&
        !_ghostCoords.contains(_tutorialHintCoord) &&
        board.get(_tutorialHintCoord!) == BeadColor.empty) {
      final node = _beadNodes[_tutorialHintCoord!];
      if (node != null) {
        node.localTransform =
            _transformForBead(_tutorialHintCoord!, highlighted: true);
      }
    }

    // Decay any active bead tap-bounce pulses.
    if (_beadPulse.isNotEmpty) {
      final finished = <CubeCoord>[];
      final decay = math.exp(-12.0 * dt);
      for (final entry in _beadPulse.entries.toList()) {
        final next = entry.value * decay;
        if (next < 0.01) {
          finished.add(entry.key);
        } else {
          _beadPulse[entry.key] = next;
          final node = _beadNodes[entry.key];
          if (node != null) {
            node.localTransform = _transformForBead(
              entry.key,
              highlighted: _ghostCoords.contains(entry.key),
            );
          }
        }
      }
      for (final coord in finished) {
        _beadPulse.remove(coord);
        final node = _beadNodes[coord];
        if (node != null) {
          node.localTransform = _transformForBead(
            coord,
            highlighted: _ghostCoords.contains(coord),
          );
        }
      }
    }

    if (_isDragging) return;

    if (_targetRotation != null) {
      // Smooth slerp to preset view angle.
      final t = 1.0 - math.exp(-10.0 * dt);
      _rotation = _slerp(_rotation, _targetRotation!, t);
      _applyCubeTransform();
      if ((_rotation.x - _targetRotation!.x).abs() < 1e-3 &&
          (_rotation.y - _targetRotation!.y).abs() < 1e-3 &&
          (_rotation.z - _targetRotation!.z).abs() < 1e-3) {
        _rotation = _targetRotation!;
        _targetRotation = null;
        _applyCubeTransform();
      }
      return;
    }

    // Smooth free-spin inertia with exponential friction (no forced snap-back).
    if (_yawVelocity.abs() > 0.01 || _pitchVelocity.abs() > 0.01) {
      _applyTrackballDelta(_yawVelocity * dt, _pitchVelocity * dt);
      final friction = math.exp(-6.5 * dt);
      _yawVelocity *= friction;
      _pitchVelocity *= friction;
      if (_yawVelocity.abs() <= 0.01) _yawVelocity = 0.0;
      if (_pitchVelocity.abs() <= 0.01) _pitchVelocity = 0.0;
    } else {
      // Keep ambient hover updated when resting.
      _applyCubeTransform();
    }
  }

  static Quaternion _slerp(Quaternion a, Quaternion b, double t) {
    var dot = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
    var bx = b.x;
    var by = b.y;
    var bz = b.z;
    var bw = b.w;
    if (dot < 0) {
      dot = -dot;
      bx = -bx;
      by = -by;
      bz = -bz;
      bw = -bw;
    }
    return Quaternion(
      a.x + (bx - a.x) * t,
      a.y + (by - a.y) * t,
      a.z + (bz - a.z) * t,
      a.w + (bw - a.w) * t,
    ).normalized();
  }

  PerspectiveCamera buildCamera() {
    return PerspectiveCamera(
      position: Vector3(0, 0, _distance),
      target: Vector3.zero(),
      up: Vector3(0, 1, 0),
      fovRadiansY: 42 * degrees2Radians,
    );
  }

  CubeHit? hitTest(ui.Offset localPosition, ui.Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return null;

    final camera = buildCamera();
    final viewProj = camera.getViewTransform(viewportSize);
    final invViewProj = Matrix4.identity();
    if (invViewProj.copyInverse(viewProj).abs() < 1e-10) return null;

    final ndcX = (2.0 * localPosition.dx / viewportSize.width) - 1.0;
    final ndcY = 1.0 - (2.0 * localPosition.dy / viewportSize.height);

    final nearWorld4 = invViewProj.transformed(Vector4(ndcX, ndcY, 0.0, 1.0));
    final farWorld4 = invViewProj.transformed(Vector4(ndcX, ndcY, 1.0, 1.0));
    if (nearWorld4.w.abs() < 1e-8 || farWorld4.w.abs() < 1e-8) return null;

    final nearWorld = Vector3(
      nearWorld4.x / nearWorld4.w,
      nearWorld4.y / nearWorld4.w,
      nearWorld4.z / nearWorld4.w,
    );
    final farWorld = Vector3(
      farWorld4.x / farWorld4.w,
      farWorld4.y / farWorld4.w,
      farWorld4.z / farWorld4.w,
    );

    // Transform world ray into cube_root local space (exact inverse of rotation + mirrorX).
    final invCube = Matrix4.identity();
    if (invCube.copyInverse(_cubeRoot.localTransform).abs() < 1e-10) {
      return null;
    }
    final nearLocal = invCube.transformed3(nearWorld);
    final farLocal = invCube.transformed3(farWorld);

    return CubeTopology.raycastCube(
      nearLocal,
      farLocal - nearLocal,
      cubeHalfSize: cubeHalfSize,
    );
  }
}
