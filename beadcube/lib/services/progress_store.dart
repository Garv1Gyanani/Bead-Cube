import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visual world themes with full uniform UI color palettes.
enum CubeTheme {
  sky(
    label: 'Sky',
    gradient: [Color(0xFFCDE8FA), Color(0xFFE7F4FD), Color(0xFFF4FAFF)],
    primary: Color(0xFF2B6CB0),
    primarySoft: Color(0xFFE0F2FE),
    textPrimary: Color(0xFF1A365D),
    textSecondary: Color(0xFF4A6B8C),
    surface: Color(0xFFF8FCFF),
    border: Color(0xFFB9DCF5),
  ),
  sunset(
    label: 'Sunset',
    gradient: [Color(0xFFFDE0D4), Color(0xFFFFF0E8), Color(0xFFFFFAF7)],
    primary: Color(0xFFC2410C),
    primarySoft: Color(0xFFFFEDD5),
    textPrimary: Color(0xFF431407),
    textSecondary: Color(0xFF9A3412),
    surface: Color(0xFFFFFBF8),
    border: Color(0xFFFED7AA),
  ),
  nightGarden(
    label: 'Night Garden',
    gradient: [Color(0xFFD6E0F5), Color(0xFFE9EFFB), Color(0xFFF6F8FD)],
    primary: Color(0xFF4338CA),
    primarySoft: Color(0xFFE0E7FF),
    textPrimary: Color(0xFF1E1B4B),
    textSecondary: Color(0xFF4F46E5),
    surface: Color(0xFFF9FAFF),
    border: Color(0xFFC7D2FE),
  ),
  candy(
    label: 'Candy',
    gradient: [Color(0xFFFCE0F1), Color(0xFFFFEFF8), Color(0xFFFFF8FC)],
    primary: Color(0xFFBE185D),
    primarySoft: Color(0xFFFCE7F3),
    textPrimary: Color(0xFF500724),
    textSecondary: Color(0xFF9D174D),
    surface: Color(0xFFFFFAFD),
    border: Color(0xFFFBCFE8),
  ),
  ocean(
    label: 'Ocean',
    gradient: [Color(0xFFC6EFEF), Color(0xFFE3F8F8), Color(0xFFF3FCFC)],
    primary: Color(0xFF0F766E),
    primarySoft: Color(0xFFCCFBF1),
    textPrimary: Color(0xFF134E4A),
    textSecondary: Color(0xFF0F766E),
    surface: Color(0xFFF7FEFD),
    border: Color(0xFF99F6E4),
  );

  const CubeTheme({
    required this.label,
    required this.gradient,
    required this.primary,
    required this.primarySoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
    required this.border,
  });

  final String label;
  final List<Color> gradient;
  final Color primary;
  final Color primarySoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color surface;
  final Color border;
}

/// Official static website & Privacy Policy URLs (deployed on Netlify).
const String kLandingPageUrl = 'https://beadcube.netlify.app';
const String kPrivacyPolicyUrl = 'https://beadcube.netlify.app/privacy-policy';

/// Persists level completion stars, daily hint quota, and theme/audio settings.
class ProgressStore {
  static const int maxDailyHints = 4;

  static const _starsPrefix = 'level_stars_';
  static const _soundKey = 'sound_enabled';
  static const _themeKey = 'selected_theme';
  static const _colorBlindKey = 'color_blind_mode';
  static const _autoNextKey = 'auto_next_enabled';
  static const _dailyHintsDateKey = 'daily_hints_date';
  static const _dailyHintsUsedKey = 'daily_hints_used';
  static const _dailySolvedDateKey = 'daily_solved_date';
  static const _dailyStreakKey = 'daily_streak_count';

  static String _dateStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<Map<int, int>> loadStars(int levelCount) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <int, int>{};
    for (int i = 1; i <= levelCount; i++) {
      final stars = prefs.getInt('$_starsPrefix$i');
      if (stars != null && stars > 0) {
        result[i] = stars;
      }
    }
    return result;
  }

  Future<void> saveLevelStars(int levelNumber, int stars) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getInt('$_starsPrefix$levelNumber') ?? 0;
    if (stars > existing) {
      await prefs.setInt('$_starsPrefix$levelNumber', stars);
    }
  }

  Future<bool> loadSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundKey) ?? true;
  }

  Future<void> saveSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, enabled);
  }

  Future<CubeTheme> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_themeKey);
    return CubeTheme.values.firstWhere(
      (t) => t.name == name,
      orElse: () => CubeTheme.sky,
    );
  }

  Future<void> saveTheme(CubeTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
  }

  Future<bool> loadColorBlindMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_colorBlindKey) ?? false;
  }

  Future<void> saveColorBlindMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_colorBlindKey, enabled);
  }

  Future<bool> loadAutoNextEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoNextKey) ?? true;
  }

  Future<void> saveAutoNextEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoNextKey, enabled);
  }

  /// Returns how many hints (`0..4`) remain for [now]'s calendar date.
  Future<int> loadRemainingDailyHints([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateStamp(now ?? DateTime.now());
    final savedDate = prefs.getString(_dailyHintsDateKey);
    if (savedDate != today) {
      await prefs.setString(_dailyHintsDateKey, today);
      await prefs.setInt(_dailyHintsUsedKey, 0);
      return maxDailyHints;
    }
    final used = prefs.getInt(_dailyHintsUsedKey) ?? 0;
    return (maxDailyHints - used).clamp(0, maxDailyHints);
  }

  /// Consumes 1 daily hint if available for [now]'s calendar date.
  ///
  /// Returns `(consumed: true, remaining: X)` on success, or
  /// `(consumed: false, remaining: 0)` when all 4 daily hints are already used.
  Future<({bool consumed, int remaining})> consumeDailyHint([
    DateTime? now,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateStamp(now ?? DateTime.now());
    final savedDate = prefs.getString(_dailyHintsDateKey);
    var used = savedDate == today ? (prefs.getInt(_dailyHintsUsedKey) ?? 0) : 0;

    if (used >= maxDailyHints) {
      await prefs.setString(_dailyHintsDateKey, today);
      await prefs.setInt(_dailyHintsUsedKey, maxDailyHints);
      return (consumed: false, remaining: 0);
    }

    used++;
    await prefs.setString(_dailyHintsDateKey, today);
    await prefs.setInt(_dailyHintsUsedKey, used);
    return (
      consumed: true,
      remaining: (maxDailyHints - used).clamp(0, maxDailyHints),
    );
  }

  /// Computes 1–3 stars based on hints and undos used (never on speed).
  static int computeStars({required int hintsUsed, required int undosUsed}) {
    if (hintsUsed == 0 && undosUsed <= 1) return 3;
    if (hintsUsed <= 1 && undosUsed <= 3) return 2;
    return 1;
  }

  /// Returns the highest unlocked 0-based level index (`0 .. totalLevels - 1`)
  /// given [levelStars].
  ///
  /// Level 1 (`index 0`) is always unlocked. Level `k + 1` (`index k`) unlocks
  /// strictly after Level `k` has been completed (`(levelStars[k] ?? 0) > 0`).
  static int maxUnlockedLevelIndex(Map<int, int> levelStars, int totalLevels) {
    if (totalLevels <= 1) return 0;
    var unlocked = 0;
    for (int levelNum = 1; levelNum < totalLevels; levelNum++) {
      if ((levelStars[levelNum] ?? 0) > 0) {
        unlocked = levelNum;
      } else {
        break;
      }
    }
    return unlocked.clamp(0, totalLevels - 1);
  }

  /// Whether 0-based [levelIndex] is unlocked given [levelStars].
  static bool isLevelUnlocked(
    int levelIndex,
    Map<int, int> levelStars,
    int totalLevels,
  ) {
    if (levelIndex < 0 || levelIndex >= totalLevels) return false;
    return levelIndex <= maxUnlockedLevelIndex(levelStars, totalLevels);
  }

  /// Whether today's Daily Cube has already been solved.
  Future<bool> isDailyCompletedToday([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dailySolvedDateKey) ==
        _dateStamp(now ?? DateTime.now());
  }

  /// Current consecutive Daily Cube streak.
  Future<int> loadDailyStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyStreakKey) ?? 0;
  }

  /// Marks today's Daily Cube solved and updates the streak counter.
  Future<int> markDailyCompleted([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final currentDay = now ?? DateTime.now();
    final today = _dateStamp(currentDay);
    final lastSolved = prefs.getString(_dailySolvedDateKey);
    if (lastSolved == today) {
      return prefs.getInt(_dailyStreakKey) ?? 1;
    }

    final yesterday = _dateStamp(
      DateTime(currentDay.year, currentDay.month, currentDay.day - 1),
    );
    final prevStreak = prefs.getInt(_dailyStreakKey) ?? 0;
    final nextStreak = lastSolved == yesterday ? prevStreak + 1 : 1;

    await prefs.setString(_dailySolvedDateKey, today);
    await prefs.setInt(_dailyStreakKey, nextStreak);
    return nextStreak;
  }

  /// Resets campaign stars and daily streak while preserving audio/theme prefs.
  Future<void> resetAllProgress(int totalLevels) async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 1; i <= totalLevels; i++) {
      await prefs.remove('$_starsPrefix$i');
    }
    await prefs.remove(_dailySolvedDateKey);
    await prefs.remove(_dailyStreakKey);
  }

  /// Loads all persisted player state in one batch during the splash screen.
  Future<InitialGameData> loadInitialData(int totalLevels) async {
    final stars = await loadStars(totalLevels);
    final sound = await loadSoundEnabled();
    final theme = await loadTheme();
    final colorBlind = await loadColorBlindMode();
    final autoNext = await loadAutoNextEnabled();
    final dailyHints = await loadRemainingDailyHints();
    final dailyDone = await isDailyCompletedToday();
    final streak = await loadDailyStreak();
    return InitialGameData(
      levelStars: stars,
      soundEnabled: sound,
      theme: theme,
      colorBlindMode: colorBlind,
      autoNextEnabled: autoNext,
      remainingDailyHints: dailyHints,
      dailyCompletedToday: dailyDone,
      dailyStreak: streak,
    );
  }
}

/// Preloaded player state passed from the splash screen into the game page.
class InitialGameData {
  const InitialGameData({
    this.levelStars = const <int, int>{},
    this.soundEnabled = true,
    this.theme = CubeTheme.sky,
    this.colorBlindMode = false,
    this.autoNextEnabled = true,
    this.remainingDailyHints = ProgressStore.maxDailyHints,
    this.dailyCompletedToday = false,
    this.dailyStreak = 0,
  });

  final Map<int, int> levelStars;
  final bool soundEnabled;
  final CubeTheme theme;
  final bool colorBlindMode;
  final bool autoNextEnabled;
  final int remainingDailyHints;
  final bool dailyCompletedToday;
  final int dailyStreak;
}
