import 'package:beadcube/engine/bead.dart';
import 'package:beadcube/engine/cube_topology.dart';
import 'package:beadcube/screens/splash_screen.dart';
import 'package:beadcube/services/progress_store.dart';
import 'package:beadcube/theme/game_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('CubeBoard initializes with 96 empty slots', () {
    final board = CubeBoard();
    for (final coord in CubeTopology.allCoords) {
      expect(board.get(coord), BeadColor.empty);
    }
  });

  testWidgets('BeadCubeSplashScreen renders branding and completes preload',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    InitialGameData? loaded;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameThemeData(CubeTheme.sky),
        home: BeadCubeSplashScreen(
          theme: CubeTheme.sky,
          onThemeLoaded: (_) {},
          onReady: (data) => loaded = data,
        ),
      ),
    );

    expect(find.text('Bead Cube'), findsOneWidget);
    expect(find.text('Fold · Match · Relax'), findsOneWidget);
    expect(
      tester.getSize(find.byType(AnimatedContainer)).width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );

    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(loaded, isNotNull);
    expect(loaded!.remainingDailyHints, ProgressStore.maxDailyHints);
  });
}
