import 'dart:math' as math;

import 'math.dart';

/// Authored sprite-sheet or skeletal motion clip metadata with optional root velocity.
final class MotionClip {
  final String name;
  final double durationSeconds;
  final int frameCount;
  final bool loop;
  final BlendVec3 rootVelocity;

  const MotionClip({
    required this.name,
    this.durationSeconds = 1.0,
    this.frameCount = 8,
    this.loop = true,
    this.rootVelocity = BlendVec3.zero,
  });
}

/// Instantaneous sampled frame & root-motion displacement emitted by [MotionClipSampler].
final class MotionClipSample {
  final String clipName;
  final double normalizedTime;
  final int frameIndex;
  final BlendVec3 rootDelta;

  const MotionClipSample({
    required this.clipName,
    required this.normalizedTime,
    required this.frameIndex,
    required this.rootDelta,
  });
}

/// Evaluates normalized playback cursor, discrete sprite frame index & wrap-safe root deltas.
final class MotionClipSampler {
  const MotionClipSampler._();

  static MotionClipSample sample(
    MotionClip clip, {
    required double timeSeconds,
    required double deltaTime,
  }) {
    final dur = math.max(1e-4, clip.durationSeconds);
    final rawNorm = timeSeconds / dur;
    final norm = clip.loop
        ? (rawNorm % 1.0 + 1.0) % 1.0
        : rawNorm.clamp(0.0, 1.0).toDouble();

    final count = math.max(1, clip.frameCount);
    final frameIdx = norm >= 1.0 - 1e-6 && !clip.loop
        ? count - 1
        : (norm * count).floor().clamp(0, count - 1);

    final effectiveDt = (!clip.loop && rawNorm >= 1.0)
        ? 0.0
        : math.max(0.0, deltaTime);

    return MotionClipSample(
      clipName: clip.name,
      normalizedTime: norm,
      frameIndex: frameIdx,
      rootDelta: clip.rootVelocity * effectiveDt,
    );
  }
}
