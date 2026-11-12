import 'dart:math' as math;

import 'math.dart';
import 'motion_clip.dart';

/// Clip sample placed along a 1D scalar parameter axis.
final class BlendSample1D {
  final MotionClip clip;
  final double position;

  const BlendSample1D({
    required this.clip,
    required this.position,
  });
}

/// Clip sample placed on a 2D directional/speed blend plane `(x, y)`.
final class BlendSample2D {
  final MotionClip clip;
  final double x;
  final double y;

  const BlendSample2D({
    required this.clip,
    required this.x,
    required this.y,
  });
}

/// Evaluated blend weights and combined root-motion velocity from a blendspace.
final class BlendSpaceResult {
  final Map<String, double> weightsByClip;
  final String dominantClipName;
  final BlendVec3 blendedRootVelocity;

  const BlendSpaceResult({
    required this.weightsByClip,
    required this.dominantClipName,
    required this.blendedRootVelocity,
  });
}

/// 1D sorted piecewise-linear animation blendspace.
final class BlendSpace1D {
  final List<BlendSample1D> samples;

  BlendSpace1D(List<BlendSample1D> samples)
      : samples = List<BlendSample1D>.from(samples)
          ..sort((a, b) => a.position.compareTo(b.position));

  BlendSpaceResult evaluate(double parameter) {
    if (samples.isEmpty) {
      return const BlendSpaceResult(
        weightsByClip: {},
        dominantClipName: '',
        blendedRootVelocity: BlendVec3.zero,
      );
    }
    if (samples.length == 1 || parameter <= samples.first.position) {
      final first = samples.first;
      return BlendSpaceResult(
        weightsByClip: {first.clip.name: 1.0},
        dominantClipName: first.clip.name,
        blendedRootVelocity: first.clip.rootVelocity,
      );
    }
    if (parameter >= samples.last.position) {
      final last = samples.last;
      return BlendSpaceResult(
        weightsByClip: {last.clip.name: 1.0},
        dominantClipName: last.clip.name,
        blendedRootVelocity: last.clip.rootVelocity,
      );
    }

    for (var i = 0; i < samples.length - 1; i++) {
      final a = samples[i];
      final b = samples[i + 1];
      if (parameter >= a.position && parameter <= b.position) {
        final span = b.position - a.position;
        final t = span <= 1e-6 ? 0.0 : (parameter - a.position) / span;
        final wA = 1.0 - t;
        final wB = t;
        return BlendSpaceResult(
          weightsByClip: {a.clip.name: wA, b.clip.name: wB},
          dominantClipName: wA >= wB ? a.clip.name : b.clip.name,
          blendedRootVelocity: a.clip.rootVelocity * wA + b.clip.rootVelocity * wB,
        );
      }
    }

    final fallback = samples.first;
    return BlendSpaceResult(
      weightsByClip: {fallback.clip.name: 1.0},
      dominantClipName: fallback.clip.name,
      blendedRootVelocity: fallback.clip.rootVelocity,
    );
  }
}

/// 2D inverse-distance normalized directional blendspace (e.g. strafeX vs forwardSpeed).
final class BlendSpace2D {
  final List<BlendSample2D> samples;
  final double falloffPower;

  const BlendSpace2D(
    this.samples, {
    this.falloffPower = 2.0,
  });

  BlendSpaceResult evaluate(double px, double py) {
    if (samples.isEmpty) {
      return const BlendSpaceResult(
        weightsByClip: {},
        dominantClipName: '',
        blendedRootVelocity: BlendVec3.zero,
      );
    }

    // Exact match guard.
    for (final s in samples) {
      final dx = px - s.x;
      final dy = py - s.y;
      if (dx * dx + dy * dy <= 1e-10) {
        return BlendSpaceResult(
          weightsByClip: {s.clip.name: 1.0},
          dominantClipName: s.clip.name,
          blendedRootVelocity: s.clip.rootVelocity,
        );
      }
    }

    final rawWeights = <double>[];
    var sumW = 0.0;
    for (final s in samples) {
      final dist = math.sqrt((px - s.x) * (px - s.x) + (py - s.y) * (py - s.y));
      final w = 1.0 / math.pow(dist, falloffPower);
      rawWeights.add(w);
      sumW += w;
    }

    final weightsMap = <String, double>{};
    var vel = BlendVec3.zero;
    var bestIdx = 0;
    var bestW = -1.0;

    for (var i = 0; i < samples.length; i++) {
      final normW = sumW <= 1e-12 ? (i == 0 ? 1.0 : 0.0) : rawWeights[i] / sumW;
      final clip = samples[i].clip;
      weightsMap[clip.name] = (weightsMap[clip.name] ?? 0.0) + normW;
      vel = vel + clip.rootVelocity * normW;
      if (normW > bestW) {
        bestW = normW;
        bestIdx = i;
      }
    }

    return BlendSpaceResult(
      weightsByClip: weightsMap,
      dominantClipName: samples[bestIdx].clip.name,
      blendedRootVelocity: vel,
    );
  }
}
