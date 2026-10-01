import 'dart:math';

/// A simple 3D vector used for placing points on the cranial "Loomis sphere".
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
}

/// Rotates a point on the unit sphere by the head's yaw, pitch, and roll
/// (all in radians). Order: yaw (turn), then pitch (nod), then roll (tilt) —
/// matches how ML Kit reports headEulerAngleY/X/Z.
Vec3 rotateHead(Vec3 p, double yaw, double pitch, double roll) {
  // Yaw: rotate around the vertical (Y) axis
  final cosY = cos(yaw), sinY = sin(yaw);
  final x1 = p.x * cosY + p.z * sinY;
  final z1 = -p.x * sinY + p.z * cosY;
  final y1 = p.y;

  // Pitch: rotate around the horizontal (X) axis
  final cosP = cos(pitch), sinP = sin(pitch);
  final y2 = y1 * cosP - z1 * sinP;
  final z2 = y1 * sinP + z1 * cosP;
  final x2 = x1;

  // Roll: rotate around the depth (Z) axis
  final cosR = cos(roll), sinR = sin(roll);
  final x3 = x2 * cosR - y2 * sinR;
  final y3 = x2 * sinR + y2 * cosR;

  return Vec3(x3, y3, z2);
}

/// Generates points along a meridian (a line of constant longitude, like the
/// center line running from top of head to chin) on the unit sphere.
List<Vec3> generateMeridian(
    double longitude, {
      double latStart = -1.4,
      double latEnd = 1.4,
      int steps = 24,
    }) {
  final points = <Vec3>[];
  for (int i = 0; i <= steps; i++) {
    final t = i / steps;
    final lat = latStart + (latEnd - latStart) * t;
    points.add(Vec3(
      cos(lat) * sin(longitude),
      sin(lat),
      cos(lat) * cos(longitude),
    ));
  }
  return points;
}

/// Generates points along a parallel (a line of constant latitude, like the
/// brow line or nose line that wraps horizontally around the skull) on the
/// unit sphere.
List<Vec3> generateParallel(
    double latitude, {
      int steps = 48,
    }) {
  final points = <Vec3>[];
  for (int i = 0; i <= steps; i++) {
    final t = i / steps;
    final lon = -pi + (2 * pi) * t;
    points.add(Vec3(
      cos(latitude) * sin(lon),
      sin(latitude),
      cos(latitude) * cos(lon),
    ));
  }
  return points;
}