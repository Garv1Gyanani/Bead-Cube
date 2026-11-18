import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:url_launcher/url_launcher.dart';

import 'engine/bead.dart';
import 'engine/cube_topology.dart';
import 'engine/folding_engine.dart';
import 'engine/level.dart';
import 'engine/piece.dart';
import 'engine/solver.dart';
import 'render/bead_cube_scene.dart';
import 'screens/splash_screen.dart';
import 'services/progress_store.dart';
import 'services/sound_service.dart';
import 'theme/game_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const BeadCubeApp());
}

class BeadCubeApp extends StatefulWidget {
  const BeadCubeApp({super.key});

  @override
  State<BeadCubeApp> createState() => _BeadCubeAppState();
}

class _BeadCubeAppState extends State<BeadCubeApp> {
  CubeTheme _activeTheme = CubeTheme.sky;
  InitialGameData? _initialData;

  void _handleThemeChanged(CubeTheme next) {
    if (_activeTheme == next) return;
    setState(() => _activeTheme = next);
  }

  void _handleSplashReady(InitialGameData data) {
    setState(() {
      _activeTheme = data.theme;
      _initialData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bead Cube',
      debugShowCheckedModeBanner: false,
      theme: buildGameThemeData(_activeTheme),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          final scale = Tween<double>(begin: 0.97, end: 1.0).animate(anim);
          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
        child: _initialData == null
            ? BeadCubeSplashScreen(
                key: const ValueKey('splash_screen'),
                theme: _activeTheme,
                onThemeLoaded: _handleThemeChanged,
                onReady: _handleSplashReady,
              )
            : BeadCubeGamePage(
                key: const ValueKey('game_page'),
                initialData: _initialData!,
                theme: _activeTheme,
                onThemeChanged: _handleThemeChanged,
              ),
      ),
    );
  }
}

/// Animated 100-Level & Settings modal bottom sheet featuring:
/// - Diagonal staggered entrance wave across the 20 chapter tiles
/// - Subtle breathing glow on the active frontier level tile
/// - Damped horizontal lock-shake + lock jiggle when tapping a locked tile
/// - Smooth chapter subtitle crossfades and bouncy toggle icons
class _LevelPickerSheet extends StatefulWidget {
  const _LevelPickerSheet({
    required this.initialChapter,
    required this.currentLevelIndex,
    required this.isDailyMode,
    required this.maxUnlockedIndex,
    required this.levelStars,
    required this.initialTheme,
    required this.initialAutoNext,
    required this.initialColorBlind,
    required this.initialSound,
    required this.dailyCompletedToday,
    required this.dailyStreak,
    required this.onSelectLevel,
    required this.onLockedTap,
    required this.onOpenCollection,
    required this.onOpenDaily,
    required this.onOpenPrivacyPolicy,
    required this.onResetProgress,
    required this.onToggleAutoNext,
    required this.onToggleColorBlind,
    required this.onToggleSound,
    required this.onSelectTheme,
  });

  final int initialChapter;
  final int currentLevelIndex;
  final bool isDailyMode;
  final int maxUnlockedIndex;
  final Map<int, int> levelStars;
  final CubeTheme initialTheme;
  final bool initialAutoNext;
  final bool initialColorBlind;
  final bool initialSound;
  final bool dailyCompletedToday;
  final int dailyStreak;
  final ValueChanged<int> onSelectLevel;
  final VoidCallback onLockedTap;
  final VoidCallback onOpenCollection;
  final VoidCallback onOpenDaily;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onResetProgress;
  final bool Function() onToggleAutoNext;
  final bool Function() onToggleColorBlind;
  final bool Function() onToggleSound;
  final ValueChanged<CubeTheme> onSelectTheme;

  @override
  State<_LevelPickerSheet> createState() => _LevelPickerSheetState();
}

class _LevelPickerSheetState extends State<_LevelPickerSheet>
    with TickerProviderStateMixin {
  late int _selectedChapter;
  late CubeTheme _theme;
  late bool _autoNext;
  late bool _colorBlind;
  late bool _sound;

  String? _lockedNotice;
  int? _shakenLevelIndex;

  late final AnimationController _cascadeController;
  late final AnimationController _pulseController;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _selectedChapter = widget.initialChapter;
    _theme = widget.initialTheme;
    _autoNext = widget.initialAutoNext;
    _colorBlind = widget.initialColorBlind;
    _sound = widget.initialSound;

    _cascadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  @override
  void dispose() {
    _cascadeController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _switchChapter(int nextChapter) {
    if (_selectedChapter == nextChapter) return;
    setState(() {
      _selectedChapter = nextChapter;
      _lockedNotice = null;
      _shakenLevelIndex = null;
    });
    _cascadeController.forward(from: 0.0);
  }

  void _triggerLockedShake(int index, int levelNumber) {
    widget.onLockedTap();
    setState(() {
      _shakenLevelIndex = index;
      _lockedNotice =
          'Complete Level ${widget.maxUnlockedIndex + 1} first to unlock Level $levelNumber!';
    });
    _shakeController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final chapter = LevelCatalog.chapters[_selectedChapter];
    final startIdx = _selectedChapter * 20;
    final endIdx = math.min(startIdx + 20, LevelCatalog.levels.length);
    var chapterStars = 0;
    for (int i = startIdx; i < endIdx; i++) {
      chapterStars += widget.levelStars[LevelCatalog.levels[i].number] ?? 0;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        color: _theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: _theme.border, width: 1.5),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Subtle top drag handle pill
              Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _theme.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '100 Levels & Settings',
                          style: gameStyle(
                            size: 17.5,
                            weight: 700,
                            color: _theme.textPrimary,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) {
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.25),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            'Ch.${chapter.number} ${chapter.name} · ★ $chapterStars/60',
                            key: ValueKey<int>(chapter.number),
                            overflow: TextOverflow.ellipsis,
                            style: gameStyle(
                              size: 12,
                              weight: 600,
                              color: _theme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _autoNext
                            ? 'Auto-Next Level: ON'
                            : 'Auto-Next Level: OFF',
                        onPressed: () {
                          final next = widget.onToggleAutoNext();
                          setState(() => _autoNext = next);
                        },
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutBack,
                            ),
                            child: child,
                          ),
                          child: Icon(
                            Icons.fast_forward_rounded,
                            key: ValueKey<bool>(_autoNext),
                            color: _autoNext
                                ? const Color(0xFF16A34A)
                                : _theme.textSecondary.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cube Collection',
                        onPressed: widget.onOpenCollection,
                        icon: Icon(
                          Icons.collections_bookmark_rounded,
                          color: _theme.primary,
                        ),
                      ),
                      IconButton(
                        tooltip: _colorBlind
                            ? 'Color-Blind Symbols: ON'
                            : 'Color-Blind Symbols: OFF',
                        onPressed: () {
                          final next = widget.onToggleColorBlind();
                          setState(() => _colorBlind = next);
                        },
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutBack,
                            ),
                            child: child,
                          ),
                          child: Icon(
                            Icons.accessibility_new_rounded,
                            key: ValueKey<bool>(_colorBlind),
                            color: _colorBlind
                                ? const Color(0xFF16A34A)
                                : _theme.textSecondary.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _sound
                            ? 'Sound & Haptics: ON'
                            : 'Sound & Haptics: OFF',
                        onPressed: () {
                          final next = widget.onToggleSound();
                          setState(() => _sound = next);
                        },
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutBack,
                            ),
                            child: child,
                          ),
                          child: Icon(
                            _sound
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            key: ValueKey<bool>(_sound),
                            color: _theme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: LevelCatalog.chapters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, cIdx) {
                    final ch = LevelCatalog.chapters[cIdx];
                    final chapterLocked = cIdx * 20 > widget.maxUnlockedIndex;
                    return ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      avatar: chapterLocked
                          ? Icon(
                              Icons.lock_outline_rounded,
                              size: 13,
                              color: _theme.textSecondary,
                            )
                          : null,
                      label: Text('Ch.${ch.number} (${ch.rangeLabel})'),
                      selected: _selectedChapter == cIdx,
                      onSelected: (_) => _switchChapter(cIdx),
                    );
                  },
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: _lockedNotice == null
                    ? const SizedBox.shrink()
                    : Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _theme.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _theme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: _theme.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _lockedNotice!,
                                style: gameStyle(
                                  size: 11.5,
                                  weight: 600,
                                  color: _theme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: Listenable.merge([
                  _cascadeController,
                  _pulseController,
                  _shakeController,
                ]),
                builder: (context, _) {
                  final pulse =
                      Curves.easeInOutSine.transform(_pulseController.value);
                  final shakeT = _shakeController.value;
                  final shakeWave =
                      math.sin(shakeT * math.pi * 4.0) * (1.0 - shakeT);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.08,
                    ),
                    itemCount: endIdx - startIdx,
                    itemBuilder: (context, offset) {
                      final index = startIdx + offset;
                      final lvl = LevelCatalog.levels[index];
                      final isUnlocked = index <= widget.maxUnlockedIndex;
                      final isCurrent = !widget.isDailyMode &&
                          index == widget.currentLevelIndex;
                      final stars = widget.levelStars[lvl.number] ?? 0;

                      // Diagonal wave stagger: (row + col) in [0 .. 7]
                      final diag = (offset ~/ 5) + (offset % 5);
                      final startDelay = diag * 0.048;
                      final rawEntry = ((_cascadeController.value - startDelay) /
                              0.52)
                          .clamp(0.0, 1.0);
                      final entryScale =
                          0.84 + 0.16 * Curves.easeOutBack.transform(rawEntry);
                      final entryY = (1.0 -
                              Curves.easeOutCubic.transform(rawEntry)) *
                          8.0;

                      final isShaking = _shakenLevelIndex == index &&
                          _shakeController.isAnimating;
                      final shakeDx = isShaking ? shakeWave * 5.5 : 0.0;
                      final lockTilt = isShaking ? shakeWave * 0.24 : 0.0;

                      final activeScale =
                          isCurrent ? (1.0 + 0.032 * pulse) : 1.0;

                      return Opacity(
                        opacity: rawEntry,
                        child: Transform.translate(
                          offset: Offset(shakeDx, entryY),
                          child: Transform.scale(
                            scale: entryScale * activeScale,
                            child: GestureDetector(
                              onTap: () {
                                if (!isUnlocked) {
                                  _triggerLockedShake(index, lvl.number);
                                  return;
                                }
                                widget.onSelectLevel(index);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !isUnlocked
                                      ? Colors.white.withValues(alpha: 0.55)
                                      : isCurrent
                                          ? _theme.primary
                                          : stars > 0
                                              ? _theme.primarySoft
                                              : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: !isUnlocked
                                        ? _theme.border.withValues(alpha: 0.55)
                                        : isCurrent
                                            ? _theme.primary
                                            : _theme.border,
                                    width: isCurrent ? 2.0 : 1.0,
                                  ),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: _theme.primary.withValues(
                                              alpha: 0.18 + 0.18 * pulse,
                                            ),
                                            blurRadius: 8 + 6 * pulse,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${lvl.number}',
                                      style: gameStyle(
                                        size: 15,
                                        weight: 700,
                                        color: !isUnlocked
                                            ? _theme.textSecondary
                                                .withValues(alpha: 0.45)
                                            : isCurrent
                                                ? Colors.white
                                                : _theme.textPrimary,
                                      ),
                                    ),
                                    if (!isUnlocked)
                                      Transform.rotate(
                                        angle: lockTilt,
                                        child: Icon(
                                          Icons.lock_rounded,
                                          size: 11.5,
                                          color: isShaking
                                              ? _theme.primary
                                              : _theme.textSecondary
                                                  .withValues(alpha: 0.45),
                                        ),
                                      )
                                    else if (stars > 0)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          for (int s = 0; s < 3; s++)
                                            Icon(
                                              Icons.star_rounded,
                                              size: 10.5,
                                              color: s < stars
                                                  ? const Color(0xFFF59E0B)
                                                  : (isCurrent
                                                      ? Colors.white38
                                                      : Colors.black12),
                                            ),
                                        ],
                                      )
                                    else if (lvl.isTutorial)
                                      Text(
                                        'GUIDE',
                                        style: gameStyle(
                                          size: 8.5,
                                          weight: 700,
                                          color: isCurrent
                                              ? Colors.white70
                                              : _theme.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: CubeTheme.values.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final t = CubeTheme.values[index];
                          return ChoiceChip(
                            label: Text(t.label),
                            selected: _theme == t,
                            onSelected: (_) {
                              setState(() => _theme = t);
                              widget.onSelectTheme(t);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: widget.onOpenDaily,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.dailyCompletedToday
                          ? const Color(0xFF16A34A)
                          : _theme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: Icon(
                      widget.dailyCompletedToday
                          ? Icons.task_alt_rounded
                          : Icons.today_rounded,
                      size: 17,
                    ),
                    label: Text(
                      widget.dailyCompletedToday
                          ? (widget.dailyStreak > 1
                              ? 'Daily · ${widget.dailyStreak}d'
                              : 'Daily ✓')
                          : 'Daily',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: _theme.border.withValues(alpha: 0.7)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: widget.onOpenPrivacyPolicy,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: _theme.textSecondary,
                    ),
                    icon: const Icon(Icons.privacy_tip_outlined, size: 15),
                    label: Text(
                      'Privacy Policy',
                      style: gameStyle(
                        size: 12,
                        weight: 600,
                        color: _theme.textSecondary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onResetProgress,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                    icon: const Icon(Icons.restart_alt_rounded, size: 15),
                    label: Text(
                      'Reset Progress',
                      style: gameStyle(
                        size: 12,
                        weight: 600,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlacedMove {
  const _PlacedMove({
    required this.pieceIndex,
    required this.coords,
    required this.color,
  });

  final int pieceIndex;
  final List<CubeCoord> coords;
  final BeadColor color;
}

class BeadCubeGamePage extends StatefulWidget {
  const BeadCubeGamePage({
    super.key,
    this.initialData = const InitialGameData(),
    required this.theme,
    required this.onThemeChanged,
  });

  final InitialGameData initialData;
  final CubeTheme theme;
  final ValueChanged<CubeTheme> onThemeChanged;

  @override
  State<BeadCubeGamePage> createState() => _BeadCubeGamePageState();
}

class _BeadCubeGamePageState extends State<BeadCubeGamePage>
    with TickerProviderStateMixin {
  final ProgressStore _store = ProgressStore();
  final SoundService _soundService = SoundService();
  final GlobalKey _viewportKey = GlobalKey();
  final ScrollController _trayScrollController = ScrollController();

  late final CubeBoard _board;
  late final BeadCubeSceneController _sceneController;
  late final AnimationController _winController;

  int _levelIndex = 0;
  LevelDefinition? _customDailyLevel;
  Map<int, int> _levelStars = <int, int>{};
  bool _soundEnabled = true;
  bool _colorBlindMode = false;
  bool _autoNextEnabled = true;
  int _remainingDailyHints = ProgressStore.maxDailyHints;
  bool _dailyCompletedToday = false;
  int _dailyStreak = 0;

  late Set<int> _usedPieceIndices;
  late List<_PlacedMove> _undoStack;

  int _hintsUsed = 0;
  int _undosUsed = 0;
  int? _selectedPieceIndex;
  int _rotationTurns = 0;
  int _cumulativeTurns = 0;
  int _rotateButtonTurns = 0;
  CubeCoord? _previewAnchor;
  PlacementResult? _previewResult;
  bool _overlayTarget = true;
  bool _levelCompleted = false;
  int _earnedWinStars = 3;

  CubeTheme get _theme => widget.theme;

  LevelDefinition get _level =>
      _customDailyLevel ?? LevelCatalog.levels[_levelIndex];

  bool get _isDailyMode => _customDailyLevel != null;

  bool get _hasNextLevel =>
      !_isDailyMode && _levelIndex < LevelCatalog.levels.length - 1;

  /// Highest unlocked 0-based campaign level index (`0 .. 99`).
  /// Level `N + 1` unlocks strictly after Level `N` is completed.
  int get _maxUnlockedLevelIndex => ProgressStore.maxUnlockedLevelIndex(
        _levelStars,
        LevelCatalog.levels.length,
      );

  bool _isLevelUnlocked(int index) => ProgressStore.isLevelUnlocked(
        index,
        _levelStars,
        LevelCatalog.levels.length,
      );

  bool get _canAdvanceToNextLevel =>
      _hasNextLevel && _isLevelUnlocked(_levelIndex + 1);

  int get _placedBeads {
    var sum = 0;
    for (final coord in CubeTopology.allCoords) {
      if (_board.get(coord) != BeadColor.empty) {
        sum++;
      }
    }
    return sum;
  }

  TutorialHint? get _activeTutorialHint {
    if (!_level.isTutorial) return null;
    for (final hint in _level.tutorialHints) {
      if (!_usedPieceIndices.contains(hint.pieceIndex)) {
        return hint;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _levelStars = Map<int, int>.from(widget.initialData.levelStars);
    _soundEnabled = widget.initialData.soundEnabled;
    _soundService.enabled = _soundEnabled;
    _colorBlindMode = widget.initialData.colorBlindMode;
    _autoNextEnabled = widget.initialData.autoNextEnabled;
    _remainingDailyHints = widget.initialData.remainingDailyHints;
    _dailyCompletedToday = widget.initialData.dailyCompletedToday;
    _dailyStreak = widget.initialData.dailyStreak;

    _board = CubeBoard();
    _sceneController = BeadCubeSceneController(board: _board);
    _winController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            mounted &&
            _levelCompleted &&
            _autoNextEnabled &&
            _canAdvanceToNextLevel) {
          setState(() => _loadLevel(_levelIndex + 1));
        }
      });

    // Start on the player's current frontier unlocked level.
    _loadLevel(_maxUnlockedLevelIndex);
  }

  @override
  void dispose() {
    _soundService.dispose();
    _winController.dispose();
    _trayScrollController.dispose();
    super.dispose();
  }

  void _playTapFeedback({bool heavy = false, bool error = false}) {
    _soundService.enabled = _soundEnabled;
    if (error) {
      _soundService.playError();
    } else if (heavy) {
      _soundService.playSnap();
    } else {
      _soundService.playTick();
    }
  }

  /// Shows a floating, frosted-glass pill toast matching the active [_theme]
  /// and `Fredoka` game font instead of default dark Material snackbars.
  void _showGameToast(
    String message, {
    IconData icon = Icons.info_outline_rounded,
    Color? accentColor,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final accent = accentColor ?? _theme.primary;

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 96),
        padding: EdgeInsets.zero,
        duration: const Duration(milliseconds: 2300),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: _theme.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _theme.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _theme.primary.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: gameStyle(
                    size: 12.8,
                    weight: 600,
                    color: _theme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _loadLevel(int index, {LevelDefinition? customLevel}) {
    _winController.stop();
    _winController.reset();

    _customDailyLevel = customLevel;
    if (customLevel == null) {
      // Prevent skipping past any uncompleted campaign level.
      final maxAllowed = _maxUnlockedLevelIndex;
      _levelIndex = index.clamp(0, maxAllowed);
    }
    _board.clear();
    _usedPieceIndices = <int>{};
    _undoStack = <_PlacedMove>[];
    _hintsUsed = 0;
    _undosUsed = 0;
    _rotationTurns = 0;
    _cumulativeTurns = 0;
    _previewAnchor = null;
    _previewResult = null;
    _levelCompleted = false;

    _overlayTarget = !_level.overlayLocked;

    if (_level.preplaceFirstBlock &&
        _level.pieces.isNotEmpty &&
        _level.firstPieceCoords.isNotEmpty) {
      final firstColor = _level.pieces.first.color;
      for (final c in _level.firstPieceCoords) {
        _board.set(c, firstColor);
      }
      _usedPieceIndices.add(0);
    }

    _selectedPieceIndex = _nextUnusedPieceIndex();

    _sceneController.clearGhostPreview();
    _sceneController.setTargetOverlay(_level.target, _overlayTarget);
    _sceneController.setTutorialHint(_activeTutorialHint?.anchor);
    _sceneController.setViewAngle(_level.initialYaw, _level.initialPitch);
    _sceneController.syncAllBeads();
    _sceneController.playLevelIntro();

    if (_trayScrollController.hasClients) {
      _trayScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openDailyCube() {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final daily = PuzzleSolver.generateProceduralLevel(
      number: 1000,
      seed: seed,
      pieceCount: 8,
      title: 'Daily Cube',
    );
    setState(() => _loadLevel(_levelIndex, customLevel: daily));
  }

  void _selectPiece(int index) {
    if (_usedPieceIndices.contains(index) || _levelCompleted) return;
    _playTapFeedback();
    setState(() {
      if (_selectedPieceIndex == index) {
        _rotationTurns = (_rotationTurns + 1) % 4;
        _cumulativeTurns++;
        _rotateButtonTurns++;
      } else {
        _selectedPieceIndex = index;
        _rotationTurns = 0;
        _cumulativeTurns = 0;
      }
      _refreshPreview();
    });
  }

  void _rotateSelectedPiece() {
    if (_selectedPieceIndex == null || _levelCompleted) return;
    _playTapFeedback();
    setState(() {
      _rotationTurns = (_rotationTurns + 1) % 4;
      _cumulativeTurns++;
      _rotateButtonTurns++;
      _refreshPreview();
    });
  }

  Future<void> _triggerHint() async {
    if (_levelCompleted) return;

    // Refresh daily quota first in case midnight rolled over while playing.
    final availableToday = await _store.loadRemainingDailyHints();
    if (!mounted) return;
    if (availableToday <= 0) {
      setState(() => _remainingDailyHints = 0);
      _playTapFeedback(error: true);
      // TODO(ads): Offer a rewarded ad option here to grant +1 bonus hint once
      // AdMob / ad SDK integration is added.
      _showGameToast(
        'All ${ProgressStore.maxDailyHints}/${ProgressStore.maxDailyHints} daily hints used! Resets tomorrow (Ad hints coming soon).',
        icon: Icons.hourglass_empty_rounded,
        accentColor: const Color(0xFFD97706),
      );
      return;
    }

    final move = PuzzleSolver.findHintMove(
      board: _board,
      target: _level.target,
      pieces: _level.pieces,
      usedPieceIndices: _usedPieceIndices,
      preferredPieceIndex: _selectedPieceIndex,
    );
    if (move == null) {
      _playTapFeedback(error: true);
      _showGameToast(
        'No valid move from here — Undo or tap a placed piece to remove it!',
        icon: Icons.undo_rounded,
        accentColor: const Color(0xFFDC2626),
      );
      return;
    }

    final quota = await _store.consumeDailyHint();
    if (!mounted) return;
    if (!quota.consumed) {
      setState(() => _remainingDailyHints = 0);
      return;
    }

    _playTapFeedback();
    setState(() {
      _remainingDailyHints = quota.remaining;
      _hintsUsed++;
      _selectedPieceIndex = move.pieceIndex;
      _rotationTurns = move.quarterTurns;
      _cumulativeTurns = move.quarterTurns;
      _previewAnchor = move.anchor;
      _previewResult = PlacementResult(
        coords: move.coords,
        isValid: true,
        foldedAcrossEdge: move.coords.map((c) => c.face).toSet().length > 1,
      );
      _sceneController.setGhostPreview(move.coords, isValid: true);
    });
    _showGameToast(
      'Hint shown · $_remainingDailyHints/${ProgressStore.maxDailyHints} daily hints left today',
      icon: Icons.tips_and_updates_rounded,
      accentColor: const Color(0xFFD97706),
    );
  }

  void _refreshPreview() {
    if (_previewAnchor == null || _selectedPieceIndex == null) {
      _previewResult = null;
      _sceneController.clearGhostPreview();
      return;
    }
    final piece = _level.pieces[_selectedPieceIndex!];
    final result = FoldingEngine.findBestPlacementAt(
      board: _board,
      target: _level.target,
      tappedCoord: _previewAnchor!,
      piece: piece,
      quarterTurns: _rotationTurns,
    );
    _previewResult = result;
    _sceneController.setGhostPreview(
      result.coords,
      isValid: result.isValid,
    );
  }

  void _handleCubeTap(Offset localPosition, Size viewportSize) {
    if (_levelCompleted) return;
    final hit = _sceneController.hitTest(localPosition, viewportSize);
    if (hit == null) {
      setState(() {
        _previewAnchor = null;
        _previewResult = null;
        _sceneController.clearGhostPreview();
      });
      return;
    }

    // Tap-to-remove: if tapping an already-placed player piece, pop it back to tray.
    if (_board.get(hit.coord) != BeadColor.empty) {
      final moveIdx = _undoStack.lastIndexWhere(
        (m) => m.coords.contains(hit.coord),
      );
      if (moveIdx != -1) {
        _removePlacedMoveAt(moveIdx);
        return;
      }
    }

    if (_selectedPieceIndex == null) return;

    if (_previewAnchor == hit.coord && (_previewResult?.isValid ?? false)) {
      _commitPlacement();
      return;
    }

    _playTapFeedback();
    setState(() {
      _previewAnchor = hit.coord;
      _refreshPreview();
    });
  }

  void _removePlacedMoveAt(int moveIdx) {
    _playTapFeedback();
    setState(() {
      _undosUsed++;
      final removed = _undoStack.removeAt(moveIdx);
      for (final c in removed.coords) {
        _board.set(c, BeadColor.empty);
        _sceneController.syncBead(c);
      }
      _usedPieceIndices.remove(removed.pieceIndex);
      _selectedPieceIndex = removed.pieceIndex;
      _rotationTurns = 0;
      _cumulativeTurns = 0;
      _previewAnchor = null;
      _previewResult = null;
      _sceneController.clearGhostPreview();
      _sceneController.setTutorialHint(_activeTutorialHint?.anchor);
    });
  }

  void _handleDragOverCube(Offset globalPosition, int pieceIndex) {
    if (_levelCompleted) return;
    final renderBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPos = renderBox.globalToLocal(globalPosition);
    final hit = _sceneController.hitTest(localPos, renderBox.size);

    if (_selectedPieceIndex != pieceIndex) {
      _selectedPieceIndex = pieceIndex;
      _rotationTurns = 0;
      _cumulativeTurns = 0;
    }

    if (hit == null) {
      if (_previewAnchor != null) {
        setState(() {
          _previewAnchor = null;
          _previewResult = null;
          _sceneController.clearGhostPreview();
        });
      }
      return;
    }

    if (hit.coord != _previewAnchor) {
      setState(() {
        _previewAnchor = hit.coord;
        _refreshPreview();
      });
    }
  }

  void _commitPlacement() {
    final idx = _selectedPieceIndex;
    final result = _previewResult;
    if (idx == null || result == null || !result.isValid) return;

    final piece = _level.pieces[idx];
    _playTapFeedback(heavy: true);

    setState(() {
      for (final c in result.coords) {
        _board.set(c, piece.color);
        _sceneController.syncBead(c, pulse: true);
      }
      _usedPieceIndices.add(idx);
      _undoStack.add(
        _PlacedMove(pieceIndex: idx, coords: result.coords, color: piece.color),
      );
      _previewAnchor = null;
      _previewResult = null;
      _sceneController.clearGhostPreview();

      _selectedPieceIndex = _nextUnusedPieceIndex();
      _rotationTurns = 0;
      _cumulativeTurns = 0;
      _sceneController.setTutorialHint(_activeTutorialHint?.anchor);

      if (_trayScrollController.hasClients) {
        _trayScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }

      if (_usedPieceIndices.length == _level.pieces.length) {
        _levelCompleted = true;
        final stars = ProgressStore.computeStars(
          hintsUsed: _hintsUsed,
          undosUsed: _undosUsed,
        );
        _earnedWinStars = stars;
        if (_isDailyMode) {
          _dailyCompletedToday = true;
          _store.markDailyCompleted().then((streak) {
            if (mounted) {
              setState(() => _dailyStreak = streak);
            }
          });
        } else {
          final existing = _levelStars[_level.number] ?? 0;
          if (stars > existing) {
            _levelStars[_level.number] = stars;
          }
          _store.saveLevelStars(_level.number, stars);
        }
        _soundService.enabled = _soundEnabled;
        _soundService.playWin();
        _sceneController.playWinFlourish();
        _winController.forward(from: 0.0);
      }
    });
  }

  int? _nextUnusedPieceIndex() {
    for (int i = 0; i < _level.pieces.length; i++) {
      if (!_usedPieceIndices.contains(i)) return i;
    }
    return null;
  }

  void _undoLastMove() {
    if (_undoStack.isEmpty || _levelCompleted) return;
    _removePlacedMoveAt(_undoStack.length - 1);
  }

  void _toggleOverlayTarget() {
    if (_level.overlayLocked) {
      _playTapFeedback(error: true);
      _showGameToast(
        'Overlay Target is locked from Level 4+ — use the Target Plan map & anchor block!',
        icon: Icons.lock_outline_rounded,
      );
      return;
    }
    _playTapFeedback();
    setState(() {
      _overlayTarget = !_overlayTarget;
      _sceneController.setTargetOverlay(_level.target, _overlayTarget);
    });
  }

  void _toggleAutoNext() {
    _playTapFeedback();
    final nextVal = !_autoNextEnabled;
    setState(() => _autoNextEnabled = nextVal);
    _store.saveAutoNextEnabled(nextVal);
    if (_levelCompleted && nextVal && _hasNextLevel) {
      if (_winController.status == AnimationStatus.completed) {
        setState(() => _loadLevel(_levelIndex + 1));
      } else if (!_winController.isAnimating) {
        _winController.forward();
      }
    }
  }

  void _showCollectionShelf() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Collection',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, _, _) {
        final completed = LevelCatalog.levels
            .where((l) => (_levelStars[l.number] ?? 0) > 0)
            .toList();
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.collections_bookmark_rounded, color: _theme.primary),
              const SizedBox(width: 8),
              Text(
                'Cube Collection',
                style: gameStyle(
                  size: 18,
                  weight: 700,
                  color: _theme.textPrimary,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            height: 280,
            child: completed.isEmpty
                ? Center(
                    child: Text(
                      'Complete levels to add finished cubes to your shelf!',
                      textAlign: TextAlign.center,
                      style: gameStyle(
                        size: 13.5,
                        weight: 500,
                        color: _theme.textSecondary,
                      ),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: completed.length,
                    itemBuilder: (context, idx) {
                      final lvl = completed[idx];
                      final stars = _levelStars[lvl.number] ?? 0;
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _theme.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: CustomPaint(
                                painter: _IsometricTargetCubePainter(
                                  target: lvl.target,
                                  viewPreset: 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lv.${lvl.number} · ${lvl.title}',
                              overflow: TextOverflow.ellipsis,
                              style: gameStyle(
                                size: 11.5,
                                weight: 650,
                                color: _theme.textPrimary,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int s = 0; s < 3; s++)
                                  Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: s < stars
                                        ? const Color(0xFFF59E0B)
                                        : _theme.border,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  Future<void> _openPrivacyPolicy() async {
    _playTapFeedback();
    final uri = Uri.parse(kPrivacyPolicyUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showGameToast(
          'Privacy Policy: $kPrivacyPolicyUrl',
          icon: Icons.privacy_tip_outlined,
        );
      }
    } catch (_) {
      if (mounted) {
        _showGameToast(
          'Privacy Policy: $kPrivacyPolicyUrl',
          icon: Icons.privacy_tip_outlined,
        );
      }
    }
  }

  Future<void> _confirmResetProgress() async {
    _playTapFeedback();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.restart_alt_rounded,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              Text(
                'Reset All Progress?',
                style: gameStyle(
                  size: 17.5,
                  weight: 700,
                  color: _theme.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'This clears your unlocked levels, earned stars, and Daily Cube streak so you can replay from Level 1.',
            style: gameStyle(
              size: 13.5,
              weight: 500,
              color: _theme.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await _store.resetAllProgress(LevelCatalog.levels.length);
    if (!mounted) return;
    setState(() {
      _levelStars = <int, int>{};
      _dailyCompletedToday = false;
      _dailyStreak = 0;
      _loadLevel(0);
    });
    _showGameToast(
      'Progress reset — starting fresh at Level 1!',
      icon: Icons.restart_alt_rounded,
    );
  }

  void _showLevelPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _LevelPickerSheet(
          initialChapter: (_levelIndex ~/ 20).clamp(0, 4),
          currentLevelIndex: _levelIndex,
          isDailyMode: _isDailyMode,
          maxUnlockedIndex: _maxUnlockedLevelIndex,
          levelStars: _levelStars,
          initialTheme: _theme,
          initialAutoNext: _autoNextEnabled,
          initialColorBlind: _colorBlindMode,
          initialSound: _soundEnabled,
          dailyCompletedToday: _dailyCompletedToday,
          dailyStreak: _dailyStreak,
          onSelectLevel: (index) {
            Navigator.of(sheetContext).pop();
            setState(() => _loadLevel(index));
          },
          onLockedTap: () => _playTapFeedback(error: true),
          onOpenCollection: () {
            Navigator.of(sheetContext).pop();
            _showCollectionShelf();
          },
          onOpenDaily: () {
            Navigator.of(sheetContext).pop();
            _openDailyCube();
          },
          onOpenPrivacyPolicy: () {
            Navigator.of(sheetContext).pop();
            _openPrivacyPolicy();
          },
          onResetProgress: () {
            Navigator.of(sheetContext).pop();
            _confirmResetProgress();
          },
          onToggleAutoNext: () {
            _toggleAutoNext();
            return _autoNextEnabled;
          },
          onToggleColorBlind: () {
            _playTapFeedback();
            setState(() => _colorBlindMode = !_colorBlindMode);
            _store.saveColorBlindMode(_colorBlindMode);
            return _colorBlindMode;
          },
          onToggleSound: () {
            setState(() {
              _soundEnabled = !_soundEnabled;
              _soundService.enabled = _soundEnabled;
            });
            _store.saveSoundEnabled(_soundEnabled);
            if (_soundEnabled) _playTapFeedback();
            return _soundEnabled;
          },
          onSelectTheme: (t) {
            _playTapFeedback();
            widget.onThemeChanged(t);
            _store.saveTheme(t);
          },
        );
      },
    );
  }

  void _showEnlargedTargetPlan() {
    var show3D = false;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Target Plan',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, _, _) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    show3D ? 'Target (3D)' : 'Target (Unfolded)',
                    style: gameStyle(
                      size: 18,
                      weight: 700,
                      color: _theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Unfolded')),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.lock_outline_rounded, size: 15),
                        label: Text('3D Cube'),
                      ),
                    ],
                    selected: {show3D},
                    onSelectionChanged: (s) {
                      setDialogState(() => show3D = s.first);
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 260,
                height: 210,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: show3D
                      // TODO(ads): Unlock unblurred 3D Target Cube preview +
                      // rotation controls after watching a rewarded ad once
                      // AdMob / ad SDK integration is added.
                      ? ClipRRect(
                          key: const ValueKey('3d_view_blurred'),
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: 8.5,
                                  sigmaY: 8.5,
                                ),
                                child: SizedBox(
                                  width: 164,
                                  height: 164,
                                  child: CustomPaint(
                                    size: const Size(164, 164),
                                    painter: _IsometricTargetCubePainter(
                                      target: _level.target,
                                      viewPreset: 0,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _theme.surface.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _theme.border,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _theme.primary
                                          .withValues(alpha: 0.14),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_circle_fill_rounded,
                                      size: 28,
                                      color: _theme.primary,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '3D Preview Locked',
                                      textAlign: TextAlign.center,
                                      style: gameStyle(
                                        size: 13.5,
                                        weight: 700,
                                        color: _theme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Unlock with Ad · Coming Soon',
                                      textAlign: TextAlign.center,
                                      style: gameStyle(
                                        size: 11.5,
                                        weight: 500,
                                        color: _theme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          key: const ValueKey('unfolded_view'),
                          child: _UnfoldedTargetGrid(
                            target: _level.target,
                            board: _board,
                            cellSize: 14,
                            colorBlindMode: _colorBlindMode,
                          ),
                        ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _theme.gradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: _activeTutorialHint != null
                    ? _buildTutorialBanner()
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: DragTarget<int>(
                  onMove: (details) =>
                      _handleDragOverCube(details.offset, details.data),
                  onLeave: (_) {
                    setState(() {
                      _previewAnchor = null;
                      _previewResult = null;
                      _sceneController.clearGhostPreview();
                    });
                  },
                  onAcceptWithDetails: (details) {
                    _handleDragOverCube(details.offset, details.data);
                    if (_previewResult?.isValid ?? false) {
                      _commitPlacement();
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return LayoutBuilder(
                      key: _viewportKey,
                      builder: (context, constraints) {
                        final viewportSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return Stack(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onScaleStart: (_) =>
                                  _sceneController.beginGesture(),
                              onScaleUpdate: (details) {
                                _sceneController.updateGesture(
                                  dx: details.focalPointDelta.dx,
                                  dy: details.focalPointDelta.dy,
                                  scale: details.scale,
                                  pointerCount: details.pointerCount,
                                );
                              },
                              onScaleEnd: (details) =>
                                  _sceneController.endGesture(
                                velocityPixelsPerSecond:
                                    details.velocity.pixelsPerSecond,
                              ),
                              onTapUp: (details) => _handleCubeTap(
                                details.localPosition,
                                viewportSize,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    bottom: 18,
                                    child: Container(
                                      width: 210,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(105),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _theme.primary
                                                .withValues(alpha: 0.16),
                                            blurRadius: 28,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SceneView(
                                    _sceneController.scene,
                                    cameraBuilder: (_) =>
                                        _sceneController.buildCamera(),
                                    onTick: (_, dt) =>
                                        _sceneController.tick(dt),
                                  ),
                                ],
                              ),
                            ),
                            // Top-left: Reset View + Daily Hint Button (4/day)
                            Positioned(
                              left: 12,
                              top: 6,
                              child: Column(
                                children: [
                                  IconButton.filledTonal(
                                    tooltip: 'Reset Camera Angle',
                                    onPressed: _sceneController.resetView,
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          _theme.surface.withValues(alpha: 0.9),
                                      foregroundColor: _theme.textPrimary,
                                      side: BorderSide(color: _theme.border),
                                      minimumSize: const Size(40, 40),
                                    ),
                                    icon: const Icon(
                                      Icons.center_focus_strong_rounded,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: _triggerHint,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _theme.surface
                                            .withValues(alpha: 0.92),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: _remainingDailyHints > 0
                                              ? _theme.border
                                              : const Color(0xFFCBD5E1),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _theme.primary
                                                .withValues(alpha: 0.12),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.tips_and_updates_rounded,
                                            size: 19,
                                            color: _remainingDailyHints > 0
                                                ? const Color(0xFFD97706)
                                                : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$_remainingDailyHints/${ProgressStore.maxDailyHints}',
                                            style: gameStyle(
                                              size: 10,
                                              weight: 700,
                                              color: _remainingDailyHints > 0
                                                  ? _theme.textPrimary
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Top-right: Unfolded Target Mini-Map
                            Positioned(
                              right: 12,
                              top: 6,
                              child: GestureDetector(
                                onTap: _showEnlargedTargetPlan,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 240),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _theme.surface.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _theme.border),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _theme.primary
                                            .withValues(alpha: 0.12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Target Plan · Tap',
                                        style: gameStyle(
                                          size: 10,
                                          weight: 650,
                                          color: _theme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _UnfoldedTargetGrid(
                                        target: _level.target,
                                        board: _board,
                                        cellSize: 6.2,
                                        colorBlindMode: _colorBlindMode,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Confetti sparkles + Auto-Next Win Celebration Banner
                            if (_levelCompleted) ...[
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _winController,
                                    builder: (context, _) {
                                      return CustomPaint(
                                        painter: _ConfettiSparklePainter(
                                          progress: _winController.value,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  child: _buildWinCelebrationBanner(),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              _buildStatusAndCounters(),
              const SizedBox(height: 8),
              _buildPieceTray(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinCelebrationBanner() {
    return AnimatedBuilder(
      animation: _winController,
      builder: (context, _) {
        final rawEntry = (_winController.value / 0.25).clamp(0.0, 1.0);
        final entryScale = Curves.easeOutBack.transform(rawEntry);

        return Transform.scale(
          scale: entryScale,
          child: Opacity(
            opacity: rawEntry,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: _theme.surface.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _theme.border,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _theme.primary.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFF59E0B),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isDailyMode
                              ? 'Daily Cube Complete!'
                              : 'Level ${_level.number} Complete!',
                          style: gameStyle(
                            size: 16.5,
                            weight: 700,
                            color: _theme.textPrimary,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < 3; i++)
                            Builder(
                              builder: (context) {
                                final delay = 0.08 + i * 0.1;
                                final starT = ((_winController.value - delay) /
                                        0.22)
                                    .clamp(0.0, 1.0);
                                final starScale =
                                    Curves.elasticOut.transform(starT);
                                return Transform.scale(
                                  scale: starScale,
                                  child: Icon(
                                    Icons.star_rounded,
                                    size: 24,
                                    color: i < _earnedWinStars
                                        ? const Color(0xFFF59E0B)
                                        : _theme.border,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (_hasNextLevel && _autoNextEnabled) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _winController.value,
                        minHeight: 5,
                        backgroundColor: _theme.primarySoft,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _theme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Auto-advancing to Level ${_level.number + 1}...',
                      style: gameStyle(
                        size: 11.5,
                        weight: 600,
                        color: _theme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FilterChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('Auto-Next'),
                        selected: _autoNextEnabled,
                        onSelected: (_) => _toggleAutoNext(),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(
                                () => _loadLevel(
                                  _levelIndex,
                                  customLevel: _customDailyLevel,
                                ),
                              );
                            },
                            child: const Text('Replay'),
                          ),
                          if (_hasNextLevel) ...[
                            const SizedBox(width: 6),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() => _loadLevel(_levelIndex + 1));
                              },
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                              ),
                              label: const Text('Next'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final titleText = _isDailyMode
        ? 'Daily Cube'
        : 'Lv ${_level.number}/${LevelCatalog.levels.length} · ${_level.title}';

    ButtonStyle headerBtnStyle({bool active = false, bool locked = false}) {
      return IconButton.styleFrom(
        backgroundColor: locked
            ? _theme.surface.withValues(alpha: 0.6)
            : active
                ? _theme.primary
                : _theme.surface.withValues(alpha: 0.9),
        foregroundColor: locked
            ? _theme.textSecondary.withValues(alpha: 0.55)
            : active
                ? Colors.white
                : _theme.textPrimary,
        side: BorderSide(
          color: active ? _theme.primary : _theme.border,
        ),
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Previous Level',
            onPressed: !_isDailyMode && _levelIndex > 0
                ? () => setState(() => _loadLevel(_levelIndex - 1))
                : null,
            style: headerBtnStyle(),
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: _showLevelPicker,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                transitionBuilder: (child, anim) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(anim);
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: Column(
                  key: ValueKey<String>(titleText),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            titleText,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: gameStyle(
                              size: 14.5,
                              weight: 700,
                              color: _theme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.expand_more_rounded,
                          size: 16,
                          color: _theme.textSecondary,
                        ),
                      ],
                    ),
                    Text(
                      _level.subtitle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: gameStyle(
                        size: 11.2,
                        weight: 550,
                        color: _theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: _canAdvanceToNextLevel
                ? 'Next Level'
                : 'Complete Level ${_level.number} to Unlock Next',
            onPressed: !_hasNextLevel
                ? null
                : _canAdvanceToNextLevel
                    ? () => setState(() => _loadLevel(_levelIndex + 1))
                    : () {
                        _playTapFeedback();
                        _showGameToast(
                          'Complete Level ${_level.number} first to unlock Level ${_level.number + 1}!',
                          icon: Icons.lock_outline_rounded,
                        );
                      },
            style: headerBtnStyle(locked: _hasNextLevel && !_canAdvanceToNextLevel),
            icon: Icon(
              _hasNextLevel && !_canAdvanceToNextLevel
                  ? Icons.lock_outline_rounded
                  : Icons.chevron_right_rounded,
              size: _hasNextLevel && !_canAdvanceToNextLevel ? 17 : 20,
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: _level.overlayLocked
                ? 'Overlay Target Locked (Use Map)'
                : _overlayTarget
                    ? 'Overlay Target: ON'
                    : 'Overlay Target: OFF',
            onPressed: _toggleOverlayTarget,
            style: headerBtnStyle(
              active: !_level.overlayLocked && _overlayTarget,
              locked: _level.overlayLocked,
            ),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                _level.overlayLocked
                    ? Icons.lock_outline_rounded
                    : Icons.visibility_rounded,
                key: ValueKey<bool>(_level.overlayLocked),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: 'Undo',
            onPressed:
                _undoStack.isNotEmpty && !_levelCompleted ? _undoLastMove : null,
            style: headerBtnStyle(),
            icon: const Icon(Icons.undo_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialBanner() {
    final hint = _activeTutorialHint!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _theme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _theme.border, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _theme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_rounded,
            color: Color(0xFFF59E0B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                hint.message,
                key: ValueKey<String>(hint.message),
                style: gameStyle(
                  size: 12.6,
                  weight: 580,
                  color: _theme.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAndCounters() {
    final total = _level.totalBeads;
    final placed = _placedBeads;
    final remaining = total - placed;
    final progress = total > 0 ? (placed / total).clamp(0.0, 1.0) : 0.0;

    String statusText;
    Color statusColor = _theme.textPrimary;

    if (_previewResult != null) {
      if (_previewResult!.isValid) {
        if (_previewResult!.foldedAcrossEdge) {
          final faces = _previewResult!.coords
              .map(
                (c) =>
                    c.face.name[0].toUpperCase() + c.face.name.substring(1),
              )
              .toSet()
              .join(' → ');
          statusText = 'Fold: $faces · Tap again or Place';
        } else {
          statusText = 'Valid fit! Tap slot again or Place';
        }
        statusColor = const Color(0xFF15803D);
      } else {
        statusText = _previewResult!.invalidReason ?? 'Invalid placement';
        statusColor = const Color(0xFFDC2626);
      }
    } else {
      statusText = 'Total: $total  ·  Placed: $placed  ·  Remaining: $remaining';
    }

    final showPlace = (_previewResult?.isValid ?? false) && !_levelCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
              decoration: BoxDecoration(
                color: _theme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _theme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      statusText,
                      key: ValueKey<String>(statusText),
                      overflow: TextOverflow.ellipsis,
                      style: gameStyle(
                        size: 12.6,
                        weight: 650,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: progress),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) {
                          return LinearProgressIndicator(
                            value: val,
                            minHeight: 4.5,
                            backgroundColor: _theme.primarySoft,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              val >= 1.0
                                  ? const Color(0xFF16A34A)
                                  : _theme.primary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) {
              return ScaleTransition(
                scale: CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(opacity: anim, child: child),
              );
            },
            child: showPlace
                ? Padding(
                    key: const ValueKey('place_btn'),
                    padding: const EdgeInsets.only(left: 8),
                    child: FilledButton.icon(
                      onPressed: _commitPlacement,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Place'),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no_place_btn')),
          ),
        ],
      ),
    );
  }

  Widget _buildPieceTray() {
    final tutorialHintPiece = _activeTutorialHint?.pieceIndex;
    final orderedPieceIndices = <int>[
      for (int i = 0; i < _level.pieces.length; i++)
        if (!_usedPieceIndices.contains(i)) i,
      for (int i = 0; i < _level.pieces.length; i++)
        if (_usedPieceIndices.contains(i)) i,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _theme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _theme.border, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _theme.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 68,
              child: ListView.separated(
                controller: _trayScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: orderedPieceIndices.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, slotIdx) {
                  final index = orderedPieceIndices[slotIdx];
                  final piece = _level.pieces[index];
                  final isUsed = _usedPieceIndices.contains(index);
                  final isSelected = _selectedPieceIndex == index && !isUsed;
                  final isHinted = tutorialHintPiece == index && !isUsed;
                  final discreteTurns = isSelected ? _rotationTurns : 0;

                  final card = AnimatedScale(
                    key: ValueKey<int>(index),
                    scale: isSelected ? 1.04 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: 64,
                      transform: Matrix4.translationValues(
                        0.0,
                        isSelected ? -3.0 : 0.0,
                        0.0,
                      ),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isUsed
                            ? Colors.white.withValues(alpha: 0.5)
                            : isSelected
                                ? _theme.primarySoft
                                : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected
                              ? _theme.primary
                              : isHinted
                                  ? const Color(0xFFF59E0B)
                                  : _theme.border,
                          width: isSelected || isHinted ? 2.2 : 1.1,
                        ),
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: isUsed ? 0.35 : 1.0,
                        child: Stack(
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: AnimatedRotation(
                                    turns: isSelected
                                        ? _cumulativeTurns * 0.25
                                        : 0.0,
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutBack,
                                    child: _PieceMiniPreview(
                                      piece: piece,
                                      quarterTurns: 0,
                                      color: uiColorForBead(piece.color),
                                      symbol: _colorBlindMode
                                          ? symbolForBead(piece.color)
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${piece.beadCount}',
                                  style: gameStyle(
                                    size: 11,
                                    weight: 700,
                                    color: _theme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Icon(
                                  Icons.rotate_right_rounded,
                                  size: 12,
                                  color: _theme.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );

                  if (isUsed) return card;

                  return Draggable<int>(
                    data: index,
                    affinity: Axis.vertical,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Transform.scale(
                        scale: 1.18,
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: _PieceMiniPreview(
                            piece: piece,
                            quarterTurns: discreteTurns,
                            color: uiColorForBead(piece.color),
                            symbol: _colorBlindMode
                                ? symbolForBead(piece.color)
                                : null,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: card),
                    child: GestureDetector(
                      onTap: () => _selectPiece(index),
                      child: card,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                tooltip: 'Rotate 90°',
                onPressed: _selectedPieceIndex != null && !_levelCompleted
                    ? _rotateSelectedPiece
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: _theme.primarySoft,
                  foregroundColor: _theme.primary,
                  side: BorderSide(color: _theme.border),
                ),
                icon: AnimatedRotation(
                  turns: _rotateButtonTurns * 0.25,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.rotate_right_rounded),
                ),
              ),
              Text(
                'Rotate',
                style: gameStyle(
                  size: 10.5,
                  weight: 650,
                  color: _theme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color uiColorForBead(BeadColor color) {
  switch (color) {
    case BeadColor.empty:
      return const Color(0xFFE2E8F0);
    case BeadColor.red:
      return const Color(0xFFF2383D);
    case BeadColor.yellow:
      return const Color(0xFFFCCC24);
    case BeadColor.blue:
      return const Color(0xFF2485FA);
    case BeadColor.purple:
      return const Color(0xFF9E47EB);
    case BeadColor.cyan:
      return const Color(0xFF1AD6EB);
  }
}

String symbolForBead(BeadColor color) {
  switch (color) {
    case BeadColor.empty:
      return '';
    case BeadColor.red:
      return '●';
    case BeadColor.yellow:
      return '▲';
    case BeadColor.blue:
      return '■';
    case BeadColor.purple:
      return '★';
    case BeadColor.cyan:
      return '◆';
  }
}

/// Celebratory confetti & radial sparkle burst drawn over the 3D viewport on win.
class _ConfettiSparklePainter extends CustomPainter {
  const _ConfettiSparklePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width * 0.5, size.height * 0.45);
    final fade = (1.0 - ((progress - 0.55) / 0.45).clamp(0.0, 1.0));
    final rng = math.Random(42);
    const palette = [
      Color(0xFFF2383D),
      Color(0xFFFCCC24),
      Color(0xFF2485FA),
      Color(0xFF9E47EB),
      Color(0xFF1AD6EB),
      Color(0xFF16A34A),
    ];

    final maxRadius = math.min(size.width, size.height) * 0.58;
    final burstT = Curves.easeOutCubic.transform(progress);

    for (int i = 0; i < 36; i++) {
      final angle = rng.nextDouble() * math.pi * 2.0;
      final speed = 0.45 + rng.nextDouble() * 0.65;
      final dist = maxRadius * speed * burstT;
      final gravityY = progress * progress * 85.0;
      final px = center.dx + math.cos(angle) * dist;
      final py = center.dy + math.sin(angle) * dist + gravityY;
      final rot = angle + progress * (rng.nextBool() ? 6.0 : -6.0);
      final color = palette[i % palette.length].withValues(alpha: fade * 0.9);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);
      final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4.5, -2.5, 9.0, 5.0),
        const Radius.circular(2.0),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiSparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _UnfoldedTargetGrid extends StatelessWidget {
  const _UnfoldedTargetGrid({
    required this.target,
    required this.board,
    required this.cellSize,
    this.colorBlindMode = false,
  });

  final CubeBoard target;
  final CubeBoard board;
  final double cellSize;
  final bool colorBlindMode;

  @override
  Widget build(BuildContext context) {
    final faceWidth = cellSize * CubeTopology.gridSize;
    Widget buildFace(CubeFace face, String label) {
      return Container(
        width: faceWidth,
        height: faceWidth,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF94A3B8), width: 0.6),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                for (int r = 0; r < CubeTopology.gridSize; r++)
                  Row(
                    children: [
                      for (int c = 0; c < CubeTopology.gridSize; c++)
                        Builder(
                          builder: (context) {
                            final coord = CubeCoord(face, r, c);
                            final targetColor = target.get(coord);
                            final filled = board.get(coord) == targetColor &&
                                targetColor != BeadColor.empty;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: cellSize - 0.3,
                              height: cellSize - 0.3,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: targetColor == BeadColor.empty
                                    ? const Color(0xFFF8FAFC)
                                    : uiColorForBead(targetColor).withValues(
                                        alpha: filled ? 1.0 : 0.48,
                                      ),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 0.25,
                                ),
                              ),
                              child: colorBlindMode &&
                                      targetColor != BeadColor.empty &&
                                      cellSize >= 10
                                  ? Text(
                                      symbolForBead(targetColor),
                                      style: gameStyle(
                                        size: 7.5,
                                        weight: 700,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                    ],
                  ),
              ],
            ),
            if (cellSize >= 10)
              IgnorePointer(
                child: Text(
                  label,
                  style: gameStyle(
                    size: 11,
                    weight: 700,
                    color: Colors.black.withValues(alpha: 0.22),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: faceWidth),
            buildFace(CubeFace.top, 'T'),
            SizedBox(width: faceWidth * 2),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildFace(CubeFace.left, 'L'),
            buildFace(CubeFace.front, 'F'),
            buildFace(CubeFace.right, 'R'),
            buildFace(CubeFace.back, 'B'),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: faceWidth),
            buildFace(CubeFace.bottom, 'D'),
            SizedBox(width: faceWidth * 2),
          ],
        ),
      ],
    );
  }
}

class _IsometricTargetCubePainter extends CustomPainter {
  const _IsometricTargetCubePainter({
    required this.target,
    required this.viewPreset,
  });

  final CubeBoard target;
  final int viewPreset;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.52;
    final scale = math.min(size.width, size.height) * 0.42;

    const cos30 = 0.8660254;
    const sin30 = 0.5;

    Offset project(double x, double y, double z) {
      final sx = cx + (x - z) * cos30 * scale;
      final sy = cy + ((x + z) * sin30 - y) * scale;
      return Offset(sx, sy);
    }

    final sideFaces = [
      CubeFace.front,
      CubeFace.right,
      CubeFace.back,
      CubeFace.left,
    ];
    final leftFace = sideFaces[viewPreset % 4];
    final rightFace = sideFaces[(viewPreset + 1) % 4];

    void drawFace(
      CubeFace face,
      Offset Function(double u, double v) mapper,
      double shade,
    ) {
      const n = CubeTopology.gridSize;
      for (int r = 0; r < n; r++) {
        for (int c = 0; c < n; c++) {
          final u0 = c / n;
          final u1 = (c + 1) / n;
          final v0 = r / n;
          final v1 = (r + 1) / n;
          final path = Path()
            ..moveTo(mapper(u0, v0).dx, mapper(u0, v0).dy)
            ..lineTo(mapper(u1, v0).dx, mapper(u1, v0).dy)
            ..lineTo(mapper(u1, v1).dx, mapper(u1, v1).dy)
            ..lineTo(mapper(u0, v1).dx, mapper(u0, v1).dy)
            ..close();

          final color = target.get(CubeCoord(face, r, c));
          final base = color == BeadColor.empty
              ? const Color(0xFFF1F5F9)
              : uiColorForBead(color);
          final shaded = Color.lerp(base, Colors.black, shade)!;
          canvas.drawPath(path, Paint()..color = shaded);
          canvas.drawPath(
            path,
            Paint()
              ..color = const Color(0xFF94A3B8).withValues(alpha: 0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        }
      }
    }

    drawFace(
      CubeFace.top,
      (u, v) => project(-1 + 2 * u, 1, -1 + 2 * v),
      0.0,
    );
    drawFace(
      leftFace,
      (u, v) => project(-1 + 2 * u, 1 - 2 * v, 1),
      0.08,
    );
    drawFace(
      rightFace,
      (u, v) => project(1, 1 - 2 * v, 1 - 2 * u),
      0.18,
    );
  }

  @override
  bool shouldRepaint(_IsometricTargetCubePainter oldDelegate) =>
      oldDelegate.viewPreset != viewPreset || oldDelegate.target != target;
}

class _PieceMiniPreview extends StatelessWidget {
  const _PieceMiniPreview({
    required this.piece,
    required this.quarterTurns,
    required this.color,
    this.symbol,
  });

  final PieceDefinition piece;
  final int quarterTurns;
  final Color color;
  final String? symbol;

  @override
  Widget build(BuildContext context) {
    final cells = piece.rotatedCells(quarterTurns);
    var minR = 0;
    var maxR = 0;
    var minC = 0;
    var maxC = 0;
    for (final c in cells) {
      minR = math.min(minR, c.dr);
      maxR = math.max(maxR, c.dr);
      minC = math.min(minC, c.dc);
      maxC = math.max(maxC, c.dc);
    }
    final rows = maxR - minR + 1;
    final cols = maxC - minC + 1;
    final cellSize = (34.0 / math.max(rows, cols)).clamp(6.0, 12.0);

    return Center(
      child: SizedBox(
        width: cols * cellSize,
        height: rows * cellSize,
        child: Stack(
          children: [
            for (final c in cells)
              Positioned(
                left: (c.dc - minC) * cellSize + 0.8,
                top: (c.dr - minR) * cellSize + 0.8,
                width: cellSize - 1.6,
                height: cellSize - 1.6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2.5),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.12),
                      width: 0.6,
                    ),
                  ),
                  child: symbol != null
                      ? Center(
                          child: Text(
                            symbol!,
                            style: gameStyle(
                              size: 6.5,
                              weight: 700,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
