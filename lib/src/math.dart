import 'dart:math' as math;

/// Lightweight immutable 3D vector for `voxblend` root-motion deltas.
final class BlendVec3 {
  final double x;
  final double y;
  final double z;

  const BlendVec3(this.x, this.y, this.z);

  static const zero = BlendVec3(0.0, 0.0, 0.0);

  BlendVec3 operator +(BlendVec3 o) => BlendVec3(x + o.x, y + o.y, z + o.z);
  BlendVec3 operator -(BlendVec3 o) => BlendVec3(x - o.x, y - o.y, z - o.z);
  BlendVec3 operator *(double s) => BlendVec3(x * s, y * s, z * s);

  double get length => math.sqrt(x * x + y * y + z * z);

  static BlendVec3 lerp(BlendVec3 a, BlendVec3 b, double t) => BlendVec3(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t,
      );
}
