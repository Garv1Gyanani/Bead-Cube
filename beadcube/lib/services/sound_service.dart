import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Tactile sound effects manager using bundled `.wav` assets + haptics.
class SoundService {
  AudioPlayer? _snapPlayer;
  AudioPlayer? _tickPlayer;
  AudioPlayer? _winPlayer;

  bool enabled = true;

  void playTick() {
    HapticFeedback.selectionClick();
    if (!enabled) return;
    _safePlay(
      () => _tickPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop),
      'audio/rotate.wav',
      volume: 0.55,
    );
  }

  void playSnap() {
    HapticFeedback.mediumImpact();
    if (!enabled) return;
    _safePlay(
      () => _snapPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop),
      'audio/snap.wav',
      volume: 0.78,
    );
  }

  void playError() {
    HapticFeedback.lightImpact();
    if (!enabled) return;
    _safePlay(
      () => _tickPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop),
      'audio/error.wav',
      volume: 0.52,
    );
  }

  void playWin() {
    HapticFeedback.heavyImpact();
    if (!enabled) return;
    _safePlay(
      () => _winPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop),
      'audio/win.wav',
      volume: 0.85,
    );
  }

  Future<void> _safePlay(
    AudioPlayer Function() getPlayer,
    String assetPath, {
    required double volume,
  }) async {
    try {
      final player = getPlayer();
      await player.stop();
      await player.play(AssetSource(assetPath), volume: volume);
    } catch (_) {
      // Gracefully ignore missing plugin channels in unit tests or unsupported hosts.
    }
  }

  void dispose() {
    try {
      _snapPlayer?.dispose();
      _tickPlayer?.dispose();
      _winPlayer?.dispose();
    } catch (_) {}
  }
}
