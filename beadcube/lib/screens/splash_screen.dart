import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/level.dart';
import '../services/progress_store.dart';
import '../theme/game_theme.dart';

/// Animated game splash screen that warms up [LevelCatalog] and loads
/// [InitialGameData] while playing a glossy 3D Bead Cube reveal animation.
class BeadCubeSplashScreen extends StatefulWidget {
  const BeadCubeSplashScreen({
    super.key,
    required this.theme,
    required this.onThemeLoaded,
    required this.onReady,
  });

  final CubeTheme theme;
  final ValueChanged<CubeTheme> onThemeLoaded;
  final ValueChanged<InitialGameData> onReady;

  @override
  State<BeadCubeSplashScreen> createState() => _BeadCubeSplashScreenState();
}

class _BeadCubeSplashScreenState extends State<BeadCubeSplashScreen>
    with SingleTickerProviderStateMixin {
  final ProgressStore _store = ProgressStore();
  late final AnimationController _controller;

  InitialGameData? _loadedData;
  bool _dispatched = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _tryFinish();
        }
      });

    _controller.forward();
    _preload();
  }

  Future<void> _preload() async {
    // Warm up the 100-level catalog and load saved preferences/stars.
    final totalLevels = LevelCatalog.levels.length;
    final data = await _store.loadInitialData(totalLevels);
    if (!mounted) return;
    widget.onThemeLoaded(data.theme);
    _loadedData = data;
    if (_controller.status == AnimationStatus.completed) {
      _tryFinish();
    }
  }

  void _tryFinish() {
    if (_dispatched || !mounted || _loadedData == null) return;
    _dispatched = true;
    widget.onReady(_loadedData!);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Scaffold(
      body: AnimatedContainer(
        width: double.infinity,
        height: double.infinity,
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.gradient,
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final logoEntry = Curves.easeOutBack.transform(
                (t / 0.42).clamp(0.0, 1.0),
              );
              final textEntry = Curves.easeOutCubic.transform(
                ((t - 0.18) / 0.36).clamp(0.0, 1.0),
              );
              final hoverY = math.sin(t * math.pi * 3.0) * 6.0;

              return SizedBox.expand(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft ambient background sparkles
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SplashSparklePainter(
                          progress: t,
                          primaryColor: theme.primary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 3),
                          // 3D Glossy Bead Cube Hero Emblem + Soft Shadow
                          Transform.translate(
                            offset: Offset(0, hoverY),
                            child: Transform.scale(
                              scale: 0.72 + 0.28 * logoEntry,
                              child: Opacity(
                                opacity: (t / 0.22).clamp(0.0, 1.0),
                                child: SizedBox(
                                  width: 188,
                                  height: 188,
                                  child: CustomPaint(
                                    painter: _SplashCubeEmblemPainter(
                                      progress: t,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 110,
                            height: 16,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(60),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primary.withValues(alpha: 0.18),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Title + Pill Badge + Tagline
                          Opacity(
                            opacity: textEntry,
                            child: Transform.translate(
                              offset: Offset(0, (1.0 - textEntry) * 16.0),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          theme.surface.withValues(alpha: 0.92),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: theme.border),
                                    ),
                                    child: Text(
                                      '3D FOLDING PUZZLE',
                                      style: gameStyle(
                                        size: 10.5,
                                        weight: 700,
                                        letterSpacing: 1.2,
                                        color: theme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Bead Cube',
                                    style: gameStyle(
                                      size: 38,
                                      weight: 700,
                                      color: theme.textPrimary,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Fold · Match · Relax',
                                    style: gameStyle(
                                      size: 15,
                                      weight: 550,
                                      color: theme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(flex: 3),
                          // Smooth Loading Pill
                          Opacity(
                            opacity: textEntry,
                            child: Column(
                              children: [
                                Container(
                                  width: 176,
                                  padding: const EdgeInsets.all(3.5),
                                  decoration: BoxDecoration(
                                    color:
                                        theme.surface.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: theme.border),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: LinearProgressIndicator(
                                      value: Curves.easeInOutCubic.transform(t),
                                      minHeight: 7,
                                      backgroundColor: theme.primarySoft,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Preparing 3D Cube...',
                                  style: gameStyle(
                                    size: 12,
                                    weight: 600,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Paints soft floating star/circle sparkles in the splash background.
class _SplashSparklePainter extends CustomPainter {
  const _SplashSparklePainter({
    required this.progress,
    required this.primaryColor,
  });

  final double progress;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(77);
    for (int i = 0; i < 18; i++) {
      final bx = rng.nextDouble() * size.width;
      final by = rng.nextDouble() * size.height * 0.85;
      final phase = rng.nextDouble() * math.pi * 2.0;
      final radius = 2.2 + rng.nextDouble() * 3.8;
      final pulse =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin(progress * 6.2 + phase));
      final dy = -progress * (18.0 + rng.nextDouble() * 24.0);

      final paint = Paint()
        ..color = (i.isEven ? Colors.white : primaryColor)
            .withValues(alpha: (0.18 + 0.28 * pulse).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(bx, by + dy), radius * pulse, paint);
    }
  }

  @override
  bool shouldRepaint(_SplashSparklePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.primaryColor != primaryColor;
}

/// Paints a stylized 3D isometric glossy Bead Cube with staggered colored beads
/// snapping onto its Top, Left, and Right visible faces.
class _SplashCubeEmblemPainter extends CustomPainter {
  const _SplashCubeEmblemPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    // Scaled so the full isometric hexagon fits comfortably inside `size`.
    final scale = size.width * 0.265;

    const cos30 = 0.8660254;
    const sin30 = 0.5;

    Offset project(double x, double y, double z) {
      return Offset(
        cx + (x - z) * cos30 * scale,
        cy + ((x + z) * sin30 - y) * scale,
      );
    }

    // Colored beads pattern across the 3x3 emblem faces (including a Cyan fold!).
    const topColors = <List<Color?>>[
      [Color(0xFFFCCC24), Color(0xFFF2383D), null],
      [null, Color(0xFFF2383D), Color(0xFFF2383D)],
      [null, null, Color(0xFF1AD6EB)],
    ];
    const leftColors = <List<Color?>>[
      [null, null, Color(0xFF1AD6EB)],
      [Color(0xFF2485FA), Color(0xFF2485FA), Color(0xFF1AD6EB)],
      [Color(0xFF2485FA), Color(0xFF2485FA), null],
    ];
    const rightColors = <List<Color?>>[
      [null, Color(0xFF9E47EB), null],
      [Color(0xFF9E47EB), Color(0xFF9E47EB), Color(0xFF9E47EB)],
      [null, null, Color(0xFFFCCC24)],
    ];

    void drawTileQuad(
      Offset Function(double u, double v) mapper,
      double uc,
      double vc,
      double half,
      Color color,
      double shade, {
      bool glossy = false,
    }) {
      final p0 = mapper(uc - half, vc - half);
      final p1 = mapper(uc + half, vc - half);
      final p2 = mapper(uc + half, vc + half);
      final p3 = mapper(uc - half, vc + half);

      final tilePath = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();

      final shaded = Color.lerp(color, Colors.black, shade)!;
      canvas.drawPath(tilePath, Paint()..color = shaded);

      if (glossy) {
        final hiPath = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo((p1.dx + p2.dx) * 0.5, (p1.dy + p2.dy) * 0.5)
          ..lineTo((p0.dx + p3.dx) * 0.5, (p0.dy + p3.dy) * 0.5)
          ..close();
        canvas.drawPath(
          hiPath,
          Paint()..color = Colors.white.withValues(alpha: 0.24),
        );
      }
    }

    void drawFace(
      List<List<Color?>> grid,
      Offset Function(double u, double v) mapper,
      double shade,
      int faceOrder,
    ) {
      // Recessed core face background.
      final bgPath = Path()
        ..moveTo(mapper(0, 0).dx, mapper(0, 0).dy)
        ..lineTo(mapper(1, 0).dx, mapper(1, 0).dy)
        ..lineTo(mapper(1, 1).dx, mapper(1, 1).dy)
        ..lineTo(mapper(0, 1).dx, mapper(0, 1).dy)
        ..close();
      final coreColor = Color.lerp(
        const Color(0xFF9EB1C8),
        const Color(0xFF64748B),
        shade * 1.4,
      )!;
      canvas.drawPath(bgPath, Paint()..color = coreColor);

      const n = 3;
      const gap = 0.028;
      final baseHalf = 0.5 / n - gap;

      for (int r = 0; r < n; r++) {
        for (int c = 0; c < n; c++) {
          final uc = (c + 0.5) / n;
          final vc = (r + 0.5) / n;

          // Always draw the clean white empty slot first so the cube looks solid.
          drawTileQuad(
            mapper,
            uc,
            vc,
            baseHalf,
            const Color(0xFFF8FAFC),
            shade,
          );

          final beadColor = grid[r][c];
          if (beadColor == null) continue;

          final cellIdx = faceOrder * 9 + r * 3 + c;
          final delay = 0.06 + cellIdx * 0.02;
          final rawPop = ((progress - delay) / 0.28).clamp(0.0, 1.0);
          if (rawPop <= 0.0) continue;

          final pop = Curves.elasticOut.transform(rawPop).clamp(0.0, 1.08);
          drawTileQuad(
            mapper,
            uc,
            vc,
            baseHalf * pop,
            beadColor,
            shade,
            glossy: true,
          );
        }
      }
    }

    drawFace(
      topColors,
      (u, v) => project(-1 + 2 * u, 1, -1 + 2 * v),
      0.0,
      0,
    );
    drawFace(
      leftColors,
      (u, v) => project(-1 + 2 * u, 1 - 2 * v, 1),
      0.08,
      1,
    );
    drawFace(
      rightColors,
      (u, v) => project(1, 1 - 2 * v, 1 - 2 * u),
      0.17,
      2,
    );
  }

  @override
  bool shouldRepaint(_SplashCubeEmblemPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
