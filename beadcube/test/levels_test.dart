import 'package:beadcube/engine/bead.dart';
import 'package:beadcube/engine/cube_topology.dart';
import 'package:beadcube/engine/folding_engine.dart';
import 'package:beadcube/engine/level.dart';
import 'package:beadcube/engine/piece.dart';
import 'package:beadcube/engine/solver.dart';
import 'package:beadcube/services/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FoldingEngine', () {
    test('bar3Cyan rotated UP from front(1,1) folds onto top(3,1)', () {
      final coords = FoldingEngine.resolveCoords(
        anchor: const CubeCoord(CubeFace.front, 1, 1),
        piece: PieceDefinition.bar3Cyan,
        quarterTurns: 3,
      );
      expect(coords, [
        const CubeCoord(CubeFace.front, 1, 1),
        const CubeCoord(CubeFace.front, 0, 1),
        const CubeCoord(CubeFace.top, 3, 1),
      ]);
    });

    test('rejects 2x2 square tearing across a 3-face corner vertex', () {
      final coords = FoldingEngine.resolveCoords(
        anchor: const CubeCoord(CubeFace.top, 3, 3),
        piece: PieceDefinition.squareBlue,
        quarterTurns: 0,
      );
      expect(coords, isNull);
    });

    test('validatePlacement rejects wrong color and overlap', () {
      final board = CubeBoard();
      final target = CubeBoard()
        ..set(const CubeCoord(CubeFace.front, 0, 0), BeadColor.red);

      final wrongColor = FoldingEngine.validatePlacement(
        board: board,
        target: target,
        anchor: const CubeCoord(CubeFace.front, 0, 0),
        piece: PieceDefinition.singleYellow,
        quarterTurns: 0,
      );
      expect(wrongColor.isValid, isFalse);
      expect(wrongColor.invalidReason, 'Wrong color');

      final mustStayEmpty = FoldingEngine.validatePlacement(
        board: board,
        target: target,
        anchor: const CubeCoord(CubeFace.front, 0, 1),
        piece: PieceDefinition.singleYellow,
        quarterTurns: 0,
      );
      expect(mustStayEmpty.isValid, isFalse);
      expect(mustStayEmpty.invalidReason, 'Must stay empty');
    });

    test('findBestPlacementAt snaps when tapping middle cell of 3-bar', () {
      final board = CubeBoard();
      final target = CubeBoard()
        ..set(const CubeCoord(CubeFace.front, 1, 0), BeadColor.cyan)
        ..set(const CubeCoord(CubeFace.front, 1, 1), BeadColor.cyan)
        ..set(const CubeCoord(CubeFace.front, 1, 2), BeadColor.cyan);

      final res = FoldingEngine.findBestPlacementAt(
        board: board,
        target: target,
        tappedCoord: const CubeCoord(CubeFace.front, 1, 2),
        piece: PieceDefinition.bar3Cyan,
        quarterTurns: 0,
      );
      expect(res.isValid, isTrue);
      expect(res.coords, [
        const CubeCoord(CubeFace.front, 1, 0),
        const CubeCoord(CubeFace.front, 1, 1),
        const CubeCoord(CubeFace.front, 1, 2),
      ]);
    });
  });

  group('LevelCatalog (100 Progressive Levels)', () {
    test('contains 100 valid levels with strictly increasing difficulty', () {
      final levels = LevelCatalog.levels;
      expect(levels.length, 100);
      expect(levels[0].isTutorial, isTrue);
      expect(levels[1].isTutorial, isTrue);
      expect(levels[0].tutorialHints.length, levels[0].pieces.length);
      expect(levels[1].tutorialHints.length, levels[1].pieces.length);

      final seenTitles = <String>{};
      for (int i = 0; i < levels.length; i++) {
        final level = levels[i];
        expect(level.number, i + 1);
        expect(seenTitles.add(level.title), isTrue,
            reason: 'Duplicate title at level ${level.number}: ${level.title}');

        if (i >= 2) {
          expect(level.isTutorial, isFalse);
        }

        final pieceBeadSum =
            level.pieces.fold<int>(0, (sum, p) => sum + p.beadCount);
        expect(level.totalBeads, pieceBeadSum);
        expect(level.firstPieceCoords.length, level.pieces.first.beadCount);
        expect(level.overlayLocked, level.number >= 4);
        expect(level.preplaceFirstBlock, level.number >= 4);

        if (i > 0) {
          final prev = levels[i - 1];
          expect(
            level.difficultyScore,
            greaterThan(prev.difficultyScore),
            reason:
                'Level ${level.number} (${level.difficultyScore}) must be strictly harder than Level ${prev.number} (${prev.difficultyScore})',
          );
          expect(
            level.totalBeads,
            greaterThanOrEqualTo(prev.totalBeads),
            reason:
                'Level ${level.number} beads (${level.totalBeads}) dropped below Level ${prev.number} (${prev.totalBeads})',
          );
        }
      }

      // Verify Grandmaster finale density & folds.
      expect(levels.last.totalBeads, greaterThanOrEqualTo(85));
      expect(levels.last.activeFaceCount, 6);
      expect(levels.last.foldCount, greaterThanOrEqualTo(8));
    });

    test('PuzzleSolver verifies solvability across all 100 campaign levels', () {
      for (final level in LevelCatalog.levels) {
        expect(
          PuzzleSolver.isSolvable(target: level.target, pieces: level.pieces),
          isTrue,
          reason: 'Level ${level.number} (${level.title}) failed solver check',
        );
      }
    });
  });

  group('PuzzleSolver & ProgressStore', () {
    test('findHintMove returns a valid completable move for Level 2 and Level 100', () {
      for (final idx in [1, 99]) {
        final level = LevelCatalog.levels[idx];
        final board = CubeBoard();
        final used = <int>{};
        if (level.preplaceFirstBlock) {
          for (final c in level.firstPieceCoords) {
            board.set(c, level.pieces.first.color);
          }
          used.add(0);
        }
        final hint = PuzzleSolver.findHintMove(
          board: board,
          target: level.target,
          pieces: level.pieces,
          usedPieceIndices: used,
        );
        expect(hint, isNotNull, reason: 'Expected hint for Level ${level.number}');
        expect(hint!.coords.length, level.pieces[hint.pieceIndex].beadCount);
      }
    });

    test('generateProceduralLevel creates a solvable Daily Cube', () {
      final daily = PuzzleSolver.generateProceduralLevel(
        number: 1000,
        seed: 20261118,
        pieceCount: 8,
      );
      expect(daily.pieces.length, 8);
      expect(daily.overlayLocked, isTrue);
      expect(
        PuzzleSolver.isSolvable(target: daily.target, pieces: daily.pieces),
        isTrue,
      );
    });

    test('computeStars awards 3, 2, or 1 star accurately', () {
      expect(ProgressStore.computeStars(hintsUsed: 0, undosUsed: 0), 3);
      expect(ProgressStore.computeStars(hintsUsed: 0, undosUsed: 1), 3);
      expect(ProgressStore.computeStars(hintsUsed: 1, undosUsed: 2), 2);
      expect(ProgressStore.computeStars(hintsUsed: 2, undosUsed: 0), 1);
    });

    test('enforces 4 daily hints and resets on next calendar day', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ProgressStore();
      final day1 = DateTime(2026, 11, 18, 10, 30);

      expect(await store.loadRemainingDailyHints(day1), 4);

      for (int expectedLeft = 3; expectedLeft >= 0; expectedLeft--) {
        final res = await store.consumeDailyHint(day1);
        expect(res.consumed, isTrue);
        expect(res.remaining, expectedLeft);
      }

      // 5th attempt on the same day is blocked.
      final blocked = await store.consumeDailyHint(day1);
      expect(blocked.consumed, isFalse);
      expect(blocked.remaining, 0);
      expect(await store.loadRemainingDailyHints(day1), 0);

      // Next calendar day resets back to 4 hints!
      final day2 = DateTime(2026, 11, 19, 8, 0);
      expect(await store.loadRemainingDailyHints(day2), 4);
    });

    test('enforces sequential level unlocking without skipping', () {
      // Fresh profile: only Level 1 (index 0) is unlocked.
      expect(ProgressStore.maxUnlockedLevelIndex(const {}, 100), 0);
      expect(ProgressStore.isLevelUnlocked(0, const {}, 100), isTrue);
      expect(ProgressStore.isLevelUnlocked(1, const {}, 100), isFalse);

      // Completing Level 1 & 2 unlocks Level 3 (index 2), but Level 4 (index 3) stays locked.
      final stars = <int, int>{1: 3, 2: 2};
      expect(ProgressStore.maxUnlockedLevelIndex(stars, 100), 2);
      expect(ProgressStore.isLevelUnlocked(2, stars, 100), isTrue);
      expect(ProgressStore.isLevelUnlocked(3, stars, 100), isFalse);

      // Cannot skip an uncompleted intermediate level.
      final gapped = <int, int>{1: 3, 3: 3};
      expect(ProgressStore.maxUnlockedLevelIndex(gapped, 100), 1);
      expect(ProgressStore.isLevelUnlocked(2, gapped, 100), isFalse);
    });

    test('tracks Daily Cube streak and resets all progress cleanly', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ProgressStore();
      await store.saveLevelStars(1, 3);
      await store.saveLevelStars(2, 2);

      final day1 = DateTime(2026, 11, 18);
      final day2 = DateTime(2026, 11, 19);
      final day4 = DateTime(2026, 11, 21);

      expect(await store.isDailyCompletedToday(day1), isFalse);
      expect(await store.markDailyCompleted(day1), 1);
      expect(await store.isDailyCompletedToday(day1), isTrue);
      // Consecutive day increments streak to 2.
      expect(await store.markDailyCompleted(day2), 2);
      // Skipping day3 resets streak to 1 on day4.
      expect(await store.markDailyCompleted(day4), 1);

      await store.resetAllProgress(100);
      expect(await store.loadStars(100), isEmpty);
      expect(await store.loadDailyStreak(), 0);
      expect(await store.isDailyCompletedToday(day4), isFalse);
      expect(kLandingPageUrl, 'https://beadcube.netlify.app');
      expect(kPrivacyPolicyUrl, 'https://beadcube.netlify.app/privacy-policy');
    });
  });
}
