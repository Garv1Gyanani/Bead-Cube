import 'dart:math' as math;

import 'bead.dart';
import 'cube_topology.dart';
import 'folding_engine.dart';
import 'piece.dart';

/// A single placement in a level's verified reference solution.
class SolutionPlacement {
  const SolutionPlacement({
    required this.piece,
    required this.anchor,
    this.quarterTurns = 0,
  });

  final PieceDefinition piece;
  final CubeCoord anchor;
  final int quarterTurns;
}

/// Optional guided hint for tutorial levels.
class TutorialHint {
  const TutorialHint({
    required this.message,
    required this.pieceIndex,
    required this.anchor,
    this.quarterTurns = 0,
  });

  final String message;
  final int pieceIndex;
  final CubeCoord anchor;
  final int quarterTurns;
}

/// Complete definition of a playable Bead Cube level.
class LevelDefinition {
  LevelDefinition._({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.isTutorial,
    required this.isDaily,
    required this.tutorialHints,
    required this.pieces,
    required this.firstPieceCoords,
    required this.target,
    required this.totalBeads,
    required this.foldCount,
    required this.activeFaceCount,
    required this.difficultyScore,
    required this.initialYaw,
    required this.initialPitch,
  });

  factory LevelDefinition.fromSolution({
    required int number,
    required String title,
    String? subtitle,
    required List<SolutionPlacement> solution,
    bool isTutorial = false,
    bool isDaily = false,
    List<TutorialHint> tutorialHints = const [],
    double initialYaw = 0.785398, // 45 deg (front + right + top)
    double initialPitch = 0.48,
  }) {
    final target = CubeBoard();
    final pieces = <PieceDefinition>[];
    var firstPieceCoords = const <CubeCoord>[];
    var totalBeads = 0;
    var foldCount = 0;
    final touchedFaces = <CubeFace>{};

    for (int i = 0; i < solution.length; i++) {
      final step = solution[i];
      final coords = FoldingEngine.resolveCoords(
        anchor: step.anchor,
        piece: step.piece,
        quarterTurns: step.quarterTurns,
      );
      if (coords == null) {
        throw StateError(
          'Level $number has invalid/self-overlapping solution piece ${step.piece.id}',
        );
      }
      if (i == 0) {
        firstPieceCoords = List<CubeCoord>.unmodifiable(coords);
      }
      final pieceFaces = <CubeFace>{};
      for (final c in coords) {
        if (target.get(c) != BeadColor.empty) {
          throw StateError(
            'Level $number has overlapping solution at $c',
          );
        }
        target.set(c, step.piece.color);
        touchedFaces.add(c.face);
        pieceFaces.add(c.face);
        totalBeads++;
      }
      if (pieceFaces.length > 1) {
        foldCount++;
      }
      pieces.add(step.piece);
    }

    final activeFaceCount = touchedFaces.length;
    final complexCount = pieces.where((p) => p.beadCount >= 4).length;
    final difficultyScore = totalBeads * 100 +
        foldCount * 40 +
        activeFaceCount * 25 +
        pieces.length * 12 +
        complexCount * 8;

    final resolvedSubtitle = subtitle ??
        '$activeFaceCount ${activeFaceCount == 1 ? "face" : "faces"} · '
            '$foldCount ${foldCount == 1 ? "fold" : "folds"} · '
            '$totalBeads beads';

    return LevelDefinition._(
      number: number,
      title: title,
      subtitle: resolvedSubtitle,
      isTutorial: isTutorial,
      isDaily: isDaily,
      tutorialHints: tutorialHints,
      pieces: List<PieceDefinition>.unmodifiable(pieces),
      firstPieceCoords: firstPieceCoords,
      target: target,
      totalBeads: totalBeads,
      foldCount: foldCount,
      activeFaceCount: activeFaceCount,
      difficultyScore: difficultyScore,
      initialYaw: initialYaw,
      initialPitch: initialPitch,
    );
  }

  final int number;
  final String title;
  final String subtitle;
  final bool isTutorial;
  final bool isDaily;
  final List<TutorialHint> tutorialHints;
  final List<PieceDefinition> pieces;
  final List<CubeCoord> firstPieceCoords;
  final CubeBoard target;
  final int totalBeads;
  final int foldCount;
  final int activeFaceCount;
  final int difficultyScore;
  final double initialYaw;
  final double initialPitch;

  /// Chapter index (`1..5`, 20 levels per chapter).
  int get chapter => ((number - 1) ~/ 20).clamp(0, 4) + 1;

  /// From Level 4 onward (and Daily Cube), Overlay Target is locked so players
  /// deduce placements from the unfolded Target Plan map.
  bool get overlayLocked => isDaily || number >= 4;

  /// From Level 4 onward, the first piece is pre-marked on the cube as an
  /// orientation anchor.
  bool get preplaceFirstBlock => isDaily || number >= 4;
}

/// Chapter metadata for the 100-level campaign.
class CampaignChapter {
  const CampaignChapter({
    required this.number,
    required this.name,
    required this.rangeLabel,
  });

  final int number;
  final String name;
  final String rangeLabel;
}

/// The 100 campaign levels (Levels 1–2 are guided tutorials, Levels 3–100
/// strictly ramp in difficulty across 5 chapters).
class LevelCatalog {
  const LevelCatalog._();

  static const List<CampaignChapter> chapters = [
    CampaignChapter(number: 1, name: 'Sky Foundations', rangeLabel: '1–20'),
    CampaignChapter(number: 2, name: 'Sunset Corners', rangeLabel: '21–40'),
    CampaignChapter(number: 3, name: 'Night Garden', rangeLabel: '41–60'),
    CampaignChapter(number: 4, name: 'Candy Labyrinth', rangeLabel: '61–80'),
    CampaignChapter(number: 5, name: 'Ocean Grandmaster', rangeLabel: '81–100'),
  ];

  static final List<LevelDefinition> levels = _buildAllLevels();

  static List<LevelDefinition> _buildAllLevels() {
    final result = <LevelDefinition>[
      // LEVEL 1 — Tutorial 1: Single face, tap, rotate, place (8 beads, 0 folds).
      LevelDefinition.fromSolution(
        number: 1,
        title: 'First Beads',
        subtitle: 'Tutorial · One face, no folding',
        isTutorial: true,
        initialYaw: 0.35,
        initialPitch: 0.30,
        solution: const [
          SolutionPlacement(
            piece: PieceDefinition.squareBlue,
            anchor: CubeCoord(CubeFace.front, 1, 2),
            quarterTurns: 0,
          ),
          SolutionPlacement(
            piece: PieceDefinition.cornerLRed,
            anchor: CubeCoord(CubeFace.front, 0, 0),
            quarterTurns: 0,
          ),
          SolutionPlacement(
            piece: PieceDefinition.singleYellow,
            anchor: CubeCoord(CubeFace.front, 0, 3),
            quarterTurns: 0,
          ),
        ],
        tutorialHints: const [
          TutorialHint(
            message:
                'Step 1: Select the Blue 2×2 piece below, then tap the glowing slot on the Front face. Tap again to place!',
            pieceIndex: 0,
            anchor: CubeCoord(CubeFace.front, 1, 2),
            quarterTurns: 0,
          ),
          TutorialHint(
            message:
                'Step 2: Select the Red L-piece and tap the top-left glowing slot to fit it cleanly.',
            pieceIndex: 1,
            anchor: CubeCoord(CubeFace.front, 0, 0),
            quarterTurns: 0,
          ),
          TutorialHint(
            message:
                'Step 3: Finish Level 1 by placing the Yellow single bead in the glowing corner!',
            pieceIndex: 2,
            anchor: CubeCoord(CubeFace.front, 0, 3),
            quarterTurns: 0,
          ),
        ],
      ),

      // LEVEL 2 — Tutorial 2: Folding across an edge + 90° rotation (8 beads, 1 fold).
      LevelDefinition.fromSolution(
        number: 2,
        title: 'Fold the Edge',
        subtitle: 'Tutorial · Rotate & fold across Front → Top',
        isTutorial: true,
        initialYaw: 0.45,
        initialPitch: 0.55,
        solution: const [
          SolutionPlacement(
            piece: PieceDefinition.bar3Cyan,
            anchor: CubeCoord(CubeFace.front, 1, 1),
            quarterTurns: 3, // Folds Front -> Top
          ),
          SolutionPlacement(
            piece: PieceDefinition.cornerLRed,
            anchor: CubeCoord(CubeFace.top, 1, 1),
            quarterTurns: 0,
          ),
          SolutionPlacement(
            piece: PieceDefinition.dominoYellow,
            anchor: CubeCoord(CubeFace.front, 2, 1),
            quarterTurns: 0,
          ),
        ],
        tutorialHints: const [
          TutorialHint(
            message:
                'Step 1: Select the Cyan 3-bar, tap Rotate 3× (so it points UP), then tap the glowing Front slot to fold it onto the Top face!',
            pieceIndex: 0,
            anchor: CubeCoord(CubeFace.front, 1, 1),
            quarterTurns: 3,
          ),
          TutorialHint(
            message:
                'Step 2: Select the Red L-piece and place it on the Top face at the glowing slot.',
            pieceIndex: 1,
            anchor: CubeCoord(CubeFace.top, 1, 1),
            quarterTurns: 0,
          ),
          TutorialHint(
            message:
                'Step 3: Place the Yellow 2-bead domino on the Front face to complete the tutorial!',
            pieceIndex: 2,
            anchor: CubeCoord(CubeFace.front, 2, 1),
            quarterTurns: 0,
          ),
        ],
      ),
    ];

    // Generate Levels 3 through 100 with strictly increasing difficultyScore
    // and monotonically increasing bead density, face count, shape variety,
    // and required edge folds.
    for (int number = 3; number <= 100; number++) {
      final prev = result.last;
      final level = _generateProgressiveLevel(
        number: number,
        title: _titles[number - 1],
        minDifficultyScore: prev.difficultyScore + 1,
        minTotalBeads: prev.totalBeads,
      );
      result.add(level);
    }

    return List<LevelDefinition>.unmodifiable(result);
  }

  static LevelDefinition _generateProgressiveLevel({
    required int number,
    required String title,
    required int minDifficultyScore,
    required int minTotalBeads,
  }) {
    final allowedFaces = _allowedFacesFor(number);
    final allowedShapes = _allowedShapesFor(number);

    const palette = [
      BeadColor.blue,
      BeadColor.red,
      BeadColor.purple,
      BeadColor.cyan,
      BeadColor.yellow,
    ];

    // Fast path: pre-verified deterministic (seed, targetBeads, minFolds) table
    // constructs every campaign level (3..100) on the very first pass.
    final bakedIndex = number - 3;
    if (bakedIndex >= 0 && bakedIndex < _bakedSeeds.length) {
      final (bakedSeed, bakedBeads, bakedMinFolds) = _bakedSeeds[bakedIndex];
      final solution = _packCube(
        rng: math.Random(bakedSeed),
        targetBeads: bakedBeads,
        allowedFaces: allowedFaces,
        allowedShapes: allowedShapes,
        palette: palette,
        minFolds: bakedMinFolds,
      );
      if (solution != null) {
        return LevelDefinition.fromSolution(
          number: number,
          title: title,
          solution: solution,
        );
      }
    }

    // Smoothly ramp targetBeads from 10 (Level 3) up to 88 (Level 100).
    final scheduledBeads = 10 + ((number - 3) * 78) ~/ 97;
    final targetBeads = math.max(minTotalBeads, scheduledBeads).clamp(10, 90);
    final minFolds = _minFoldsFor(number);
    final minActiveFaces = math.min(allowedFaces.length, _minFacesFor(number));

    for (int attempt = 0; attempt < 250; attempt++) {
      final rng = math.Random(number * 7919 + attempt * 104729 + 17);
      final solution = _packCube(
        rng: rng,
        targetBeads: targetBeads,
        allowedFaces: allowedFaces,
        allowedShapes: allowedShapes,
        palette: palette,
        minFolds: minFolds,
      );
      if (solution == null || solution.length < 3) continue;

      final candidate = LevelDefinition.fromSolution(
        number: number,
        title: title,
        solution: solution,
      );

      if (candidate.foldCount < minFolds) continue;
      if (candidate.activeFaceCount < minActiveFaces) continue;
      if (candidate.difficultyScore < minDifficultyScore) continue;

      return candidate;
    }

    // Fallback: relax fold target by 1 while strictly preserving progressive
    // difficultyScore > previous level.
    for (int attempt = 0; attempt < 250; attempt++) {
      final rng = math.Random(number * 31337 + attempt * 65537 + 99);
      final solution = _packCube(
        rng: rng,
        targetBeads: targetBeads + 1,
        allowedFaces: allowedFaces,
        allowedShapes: allowedShapes,
        palette: palette,
        minFolds: math.max(1, minFolds - 1),
      );
      if (solution == null) continue;
      final candidate = LevelDefinition.fromSolution(
        number: number,
        title: title,
        solution: solution,
      );
      if (candidate.difficultyScore >= minDifficultyScore) {
        return candidate;
      }
    }

    throw StateError('Failed to generate valid campaign level $number');
  }

  static List<SolutionPlacement>? _packCube({
    required math.Random rng,
    required int targetBeads,
    required Set<CubeFace> allowedFaces,
    required List<PieceShape> allowedShapes,
    required List<BeadColor> palette,
    required int minFolds,
  }) {
    final occupied = <CubeCoord>{};
    final placements = <SolutionPlacement>[];
    final colorCounts = <BeadColor, int>{for (final c in palette) c: 0};

    var remaining = targetBeads;
    var foldsSoFar = 0;
    var singlesUsed = 0;

    final candidateAnchors = <CubeCoord>[
      for (final coord in CubeTopology.allCoords)
        if (allowedFaces.contains(coord.face)) coord,
    ];

    while (remaining > 0) {
      // Filter shapes that fit in `remaining` (avoid leaving a 1-bead remainder
      // unless we have no choice, and cap 1-bead singles to at most 1).
      final usableShapes = allowedShapes.where((s) {
        final sz = PieceDefinition.cellsForShape(s).length;
        if (sz > remaining) return false;
        if (sz == 1 && singlesUsed >= 1 && remaining > 1) return false;
        if (remaining - sz == 1 && singlesUsed >= 1) return false;
        return true;
      }).toList();

      if (usableShapes.isEmpty) return null;

      // Prefer larger shapes early so high-bead levels stay around 18-23 pieces
      // (<= 5 pieces per color).
      usableShapes.sort((a, b) {
        final sa = PieceDefinition.cellsForShape(a).length;
        final sb = PieceDefinition.cellsForShape(b).length;
        return sb.compareTo(sa);
      });

      // Shuffle within same-size tiers for rich shape variety.
      final orderedShapes = <PieceShape>[];
      var i = 0;
      while (i < usableShapes.length) {
        var j = i + 1;
        final sz = PieceDefinition.cellsForShape(usableShapes[i]).length;
        while (j < usableShapes.length &&
            PieceDefinition.cellsForShape(usableShapes[j]).length == sz) {
          j++;
        }
        final tier = usableShapes.sublist(i, j)..shuffle(rng);
        orderedShapes.addAll(tier);
        i = j;
      }

      // First piece on Level 4+ is the anchor block: place it on Front/Top/Right
      // so it's immediately visible from the starting isometric camera!
      final isFirstAnchor = placements.isEmpty;
      final needFold = foldsSoFar < minFolds;

      SolutionPlacement? bestPlacement;
      List<CubeCoord>? bestCoords;
      int bestScore = -999999;

      // Sample a shuffled subset of empty anchors for speed + variety.
      final freeAnchors = candidateAnchors
          .where((c) => !occupied.contains(c))
          .toList()
        ..shuffle(rng);

      final anchorLimit = math.min(freeAnchors.length, 28);

      for (final shape in orderedShapes.take(5)) {
        // Pick the least-used color so colors stay balanced (4-5 per color max).
        final sortedColors = List<BeadColor>.from(palette)
          ..shuffle(rng)
          ..sort((a, b) => colorCounts[a]!.compareTo(colorCounts[b]!));
        final chosenColor = sortedColors.first;
        final piece = PieceDefinition.of(shape, chosenColor);

        for (int aIdx = 0; aIdx < anchorLimit; aIdx++) {
          final anchor = freeAnchors[aIdx];
          if (isFirstAnchor &&
              anchor.face != CubeFace.front &&
              anchor.face != CubeFace.top &&
              anchor.face != CubeFace.right) {
            continue;
          }

          for (int turns = 0; turns < 4; turns++) {
            final coords = FoldingEngine.resolveCoords(
              anchor: anchor,
              piece: piece,
              quarterTurns: turns,
            );
            if (coords == null) continue;
            if (coords.any(
              (c) => !allowedFaces.contains(c.face) || occupied.contains(c),
            )) {
              continue;
            }

            final spansEdge = coords.map((c) => c.face).toSet().length > 1;

            // Score placement: reward folding when needed, and reward touching
            // occupied cells so empty space stays contiguous!
            var score = piece.beadCount * 12 + rng.nextInt(9);
            if (spansEdge) {
              score += needFold ? 80 : 18;
            }
            if (occupied.isNotEmpty) {
              var neighborTouches = 0;
              for (final c in coords) {
                for (final dir in GridDirection.values) {
                  final adj = CubeTopology.step(c, dir).coord;
                  if (occupied.contains(adj) || !allowedFaces.contains(adj.face)) {
                    neighborTouches++;
                  }
                }
              }
              score += neighborTouches * 10;
            }

            if (score > bestScore) {
              bestScore = score;
              bestCoords = coords;
              bestPlacement = SolutionPlacement(
                piece: piece,
                anchor: anchor,
                quarterTurns: turns,
              );
            }
          }
        }
        if (bestPlacement != null && (!needFold || bestScore >= 90)) {
          break;
        }
      }

      if (bestPlacement == null || bestCoords == null) {
        return null;
      }

      occupied.addAll(bestCoords);
      placements.add(bestPlacement);
      colorCounts[bestPlacement.piece.color] =
          colorCounts[bestPlacement.piece.color]! + 1;
      remaining -= bestPlacement.piece.beadCount;
      if (bestPlacement.piece.beadCount == 1) singlesUsed++;
      if (bestCoords.map((c) => c.face).toSet().length > 1) {
        foldsSoFar++;
      }
    }

    return placements;
  }

  static Set<CubeFace> _allowedFacesFor(int number) {
    if (number <= 3) return const {CubeFace.front, CubeFace.right};
    if (number <= 6) {
      return const {CubeFace.front, CubeFace.top, CubeFace.right};
    }
    if (number <= 14) {
      return const {
        CubeFace.front,
        CubeFace.top,
        CubeFace.right,
        CubeFace.left,
      };
    }
    if (number <= 24) {
      return const {
        CubeFace.front,
        CubeFace.top,
        CubeFace.right,
        CubeFace.left,
        CubeFace.bottom,
      };
    }
    return CubeFace.values.toSet();
  }

  static int _minFacesFor(int number) {
    if (number <= 3) return 2;
    if (number <= 6) return 3;
    if (number <= 14) return 4;
    if (number <= 24) return 5;
    return 6;
  }

  static int _minFoldsFor(int number) {
    if (number <= 3) return 1;
    if (number <= 8) return 2;
    if (number <= 16) return 3;
    if (number <= 28) return 4;
    if (number <= 42) return 5;
    if (number <= 56) return 6;
    if (number <= 70) return 7;
    if (number <= 85) return 8;
    return 9;
  }

  static List<PieceShape> _allowedShapesFor(int number) {
    if (number <= 10) {
      return const [
        PieceShape.square2x2,
        PieceShape.tPiece,
        PieceShape.bar3,
        PieceShape.cornerL,
        PieceShape.domino,
        PieceShape.single,
      ];
    }
    if (number <= 20) {
      return const [
        PieceShape.lTetromino,
        PieceShape.jTetromino,
        PieceShape.square2x2,
        PieceShape.tPiece,
        PieceShape.bar3,
        PieceShape.cornerL,
        PieceShape.domino,
        PieceShape.single,
      ];
    }
    if (number <= 40) {
      return const [
        PieceShape.zTetromino,
        PieceShape.sTetromino,
        PieceShape.lTetromino,
        PieceShape.jTetromino,
        PieceShape.square2x2,
        PieceShape.tPiece,
        PieceShape.bar3,
        PieceShape.cornerL,
        PieceShape.domino,
        PieceShape.single,
      ];
    }
    if (number <= 60) {
      return const [
        PieceShape.bar4,
        PieceShape.zTetromino,
        PieceShape.sTetromino,
        PieceShape.lTetromino,
        PieceShape.jTetromino,
        PieceShape.square2x2,
        PieceShape.tPiece,
        PieceShape.bar3,
        PieceShape.cornerL,
        PieceShape.domino,
        PieceShape.single,
      ];
    }
    if (number <= 80) {
      return const [
        PieceShape.uPentomino,
        PieceShape.wPentomino,
        PieceShape.bar4,
        PieceShape.zTetromino,
        PieceShape.sTetromino,
        PieceShape.lTetromino,
        PieceShape.jTetromino,
        PieceShape.square2x2,
        PieceShape.tPiece,
        PieceShape.bar3,
        PieceShape.cornerL,
        PieceShape.domino,
        PieceShape.single,
      ];
    }
    return const [
      PieceShape.plusPentomino,
      PieceShape.uPentomino,
      PieceShape.wPentomino,
      PieceShape.bar4,
      PieceShape.zTetromino,
      PieceShape.sTetromino,
      PieceShape.lTetromino,
      PieceShape.jTetromino,
      PieceShape.square2x2,
      PieceShape.tPiece,
      PieceShape.bar3,
      PieceShape.cornerL,
      PieceShape.domino,
      PieceShape.single,
    ];
  }

  static const List<String> _titles = [
    // Chapter 1: Sky Foundations (1–20)
    'First Beads',
    'Fold the Edge',
    'Right Turn',
    'Corner Trio',
    'Twin Blues',
    'T-Junction',
    'Ribbon Fold',
    'Mirror Bridge',
    'Sky Terrace',
    'Cloud Seam',
    'Twin Hooks',
    'Breeze Wrap',
    'Four Winds',
    'Prism Step',
    'Horizon Hinge',
    'Loft Latch',
    'Cirrus Bend',
    'Edge Weave',
    'Zephyr Knot',
    'Sky Citadel',
    // Chapter 2: Sunset Corners (21–40)
    'Amber Zigzag',
    'Dusk Hinge',
    'Sunbeam Twist',
    'Coral Corner',
    'Saffron Step',
    'Six-Face Dawn',
    'Golden Seam',
    'Crimson Hook',
    'Twilight Cross',
    'Copper Fold',
    'Ember Bridge',
    'Solstice Wrap',
    'Ochre Braid',
    'Flare Vertex',
    'Vermilion Turn',
    'Canyon Clasp',
    'Radiant Loop',
    'Sunstone Lock',
    'Afterglow Arch',
    'Sunset Crown',
    // Chapter 3: Night Garden (41–60)
    'Moonlit Span',
    'Long Bar',
    'Starlight Seam',
    'Ivy Trellis',
    'Midnight Hinge',
    'Cobalt Vine',
    'Dewdrop Fold',
    'Lantern Cross',
    'Orchid Twist',
    'Shadow Lattice',
    'Firefly Bridge',
    'Nocturne Knot',
    'Velvet Corner',
    'Silver Bough',
    'Jasmine Wrap',
    'Astral Weave',
    'Crescent Lock',
    'Twilight Maze',
    'Nebula Ring',
    'Garden Sanctum',
    // Chapter 4: Candy Labyrinth (61–80)
    'Sugar Arch',
    'Staircase Fold',
    'Ribbon Candy',
    'Caramel Clasp',
    'Sherbet Twist',
    'Berry Trellis',
    'Jelly Seam',
    'Lollipop Loop',
    'Mint Mosaic',
    'Taffy Bridge',
    'Prism Bonbon',
    'Nougat Corner',
    'Glaze Vertex',
    'Macaron Lock',
    'Confetti Wrap',
    'Sorbet Weave',
    'Marzipan Knot',
    'Crystal Sweet',
    'Truffle Spire',
    'Candy Palace',
    // Chapter 5: Ocean Grandmaster (81–100)
    'Tidal Cross',
    'Reef Labyrinth',
    'Abyssal Fold',
    'Nautilus Spiral',
    'Riptide Seam',
    'Coral Bastion',
    'Maelstrom Twist',
    'Pearl Matrix',
    'Kraken Clasp',
    'Trench Bridge',
    'Sapphire Surge',
    'Poseidon Knot',
    'Lagoon Tessera',
    'Monsoon Wrap',
    'Leviathan Lock',
    'Glacier Weave',
    'Zenith Current',
    'Sovereign Reef',
    'Omega Vertex',
    'Grandmaster Cube',
  ];

  // Pre-verified (seed, targetBeads, minFolds) tuples for Levels 3..100 so
  // all 100 levels construct in a single pass (<50ms total).
  static const List<(int, int, int)> _bakedSeeds = [
    (23774, 10, 1),
    (136422, 10, 2),
    (39612, 11, 2),
    (47531, 12, 2),
    (55450, 13, 2),
    (796472, 14, 2),
    (176017, 14, 3),
    (498123, 15, 3),
    (191855, 16, 3),
    (304503, 17, 3),
    (207693, 18, 3),
    (425070, 18, 3),
    (118802, 19, 3),
    (126721, 20, 3),
    (448827, 21, 4),
    (352017, 22, 4),
    (359936, 22, 4),
    (367855, 23, 4),
    (480503, 24, 4),
    (697880, 25, 4),
    (182154, 26, 4),
    (190073, 26, 4),
    (15697884, 27, 4),
    (21989543, 28, 4),
    (24510958, 29, 4),
    (640665, 30, 4),
    (10178923, 30, 5),
    (865961, 31, 5),
    (8100181, 32, 5),
    (1091257, 33, 5),
    (3507943, 34, 5),
    (9590144, 34, 5),
    (8550773, 35, 5),
    (599288, 36, 5),
    (1445039, 37, 5),
    (510397, 38, 5),
    (1222242, 39, 4),
    (1678254, 39, 5),
    (743612, 40, 5),
    (1589363, 41, 5),
    (445263, 42, 6),
    (1378927, 43, 5),
    (356372, 43, 6),
    (469020, 44, 6),
    (372210, 45, 6),
    (380129, 46, 6),
    (1749525, 46, 6),
    (395967, 47, 6),
    (508615, 48, 6),
    (411805, 49, 6),
    (419724, 50, 6),
    (427643, 51, 6),
    (749749, 51, 6),
    (757668, 52, 6),
    (451400, 53, 7),
    (668777, 54, 7),
    (467238, 55, 7),
    (1941363, 55, 7),
    (1911656, 57, 6),
    (595724, 57, 7),
    (498914, 58, 7),
    (506833, 59, 7),
    (2037004, 60, 6),
    (627400, 60, 7),
    (530590, 61, 7),
    (538509, 62, 7),
    (651157, 63, 7),
    (554347, 63, 7),
    (562266, 64, 8),
    (570185, 65, 8),
    (578104, 66, 8),
    (586023, 67, 8),
    (2350374, 68, 7),
    (601861, 68, 8),
    (609780, 69, 8),
    (617699, 70, 8),
    (625618, 71, 8),
    (633537, 71, 8),
    (641456, 72, 8),
    (649375, 73, 8),
    (657294, 74, 8),
    (665213, 75, 8),
    (1615693, 75, 8),
    (681051, 76, 9),
    (688970, 77, 9),
    (696889, 78, 9),
    (704808, 79, 9),
    (2820429, 80, 8),
    (720646, 80, 9),
    (728565, 81, 9),
    (736484, 82, 9),
    (744403, 83, 9),
    (857051, 83, 9),
    (760241, 84, 9),
    (768160, 85, 9),
    (776079, 86, 9),
    (783998, 87, 9),
    (791917, 88, 9),
  ];
}
