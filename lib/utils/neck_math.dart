import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'sphere_math.dart'; // Vec3, rotateHead

/// ---------------------------------------------------------------------
/// Canonical neck cylinder, defined in the SAME unit-sphere space as your
/// cranium (radius 1 = cranial radius). Tune these against reference
/// photos the same way you tuned ear azimuth/height.
/// ---------------------------------------------------------------------
class NeckConfig {
  final double topRadius;
  final double bottomRadius;
  final double length;
  final double chinLatitude; // where on the cranial sphere the neck attaches
  final double backOffsetZ;  // neck sits slightly behind the chin, not under it

  const NeckConfig({
    this.topRadius = 0.35,
    this.bottomRadius = 0.45,
    this.length = 0.9,
    this.chinLatitude = 0.75, // matches ArtistPainter's _chinLat exactly
    this.backOffsetZ = -0.15,
  });
}

/// The chin anchor point on the cranial sphere, BEFORE head rotation —
/// same parametrization as generateParallel, evaluated at longitude 0
/// (straight ahead) since the chin sits at the front of the skull.
/// NOTE: this space is y-DOWN, same as ArtistPainter (positive y = lower
/// on screen), not y-up math convention.
Vec3 chinAnchorLocal(double chinLatitude) {
  return Vec3(0, sin(chinLatitude), cos(chinLatitude));
}

/// Generates one ring of points around the neck cylinder at height t
/// (0 = top/attachment at the chin, 1 = bottom/shoulders), in LOCAL neck
/// space (before neck rotation is applied). y-DOWN: increasing t moves
/// down the screen, away from the head, toward the shoulders.
List<Vec3> _neckRingLocal(NeckConfig cfg, double t, int segments) {
  final radius = cfg.topRadius + (cfg.bottomRadius - cfg.topRadius) * t;
  final y = t * cfg.length; // top at y=0, extends DOWN (positive y)
  final points = <Vec3>[];
  for (int i = 0; i <= segments; i++) {
    final theta = 2 * pi * i / segments;
    points.add(Vec3(radius * cos(theta), y, radius * sin(theta)));
  }
  return points;
}

/// Computes neck roll (radians) from real shoulder landmarks, if present.
/// Falls back to 0 if shoulders weren't detected (e.g. pose detector found
/// no body, only a face crop).
double neckRollFromShoulders(Map<PoseLandmarkType, PoseLandmark> poseLandmarks) {
  final left = poseLandmarks[PoseLandmarkType.leftShoulder];
  final right = poseLandmarks[PoseLandmarkType.rightShoulder];
  if (left == null || right == null) return 0.0;
  // Note: image y-axis grows downward, so this is already the correct
  // sign convention to match rotateHead's roll usage below.
  return atan2(right.y - left.y, right.x - left.x);
}

/// Full neck ring set, rotated and ready to hand to the same
/// project-to-screen step you already use for meridian/parallel points.
/// Returns rings in WORLD unit-sphere space (same space generateMeridian/
/// generateParallel output lives in) — your existing painter can project
/// these exactly the same way it already projects cranial points.
List<List<Vec3>> generateNeckRings({
  required NeckConfig cfg,
  required double headYaw,
  required double headPitch,
  required double headRoll,
  required Map<PoseLandmarkType, PoseLandmark> poseLandmarks,
  int rings = 4,
  int segments = 32,
  double neckYawDamping = 0.4, // neck turns less than the head does
}) {
  // 1. Where the chin ends up after the HEAD's own rotation — this is the
  //    world-space attachment point for the neck top.
  final chinLocal = chinAnchorLocal(cfg.chinLatitude);
  final chinWorld = rotateHead(chinLocal, headYaw, headPitch, headRoll);
  final neckTopWorld = chinWorld + Vec3(0, 0, cfg.backOffsetZ);

  // 2. Neck's OWN rotation — independent of the head's. This is the fix
  //    for the neck not reading as 3D: right now if neck geometry reuses
  //    headYaw/headPitch/headRoll directly, it rotates in lockstep with
  //    the head, which is anatomically wrong and looks flat.
  final neckYaw = headYaw * neckYawDamping;
  final neckPitch = 0.0; // start at 0; consider damping headPitch similarly if it looks stiff
  final neckRoll = neckRollFromShoulders(poseLandmarks);

  // 3. Build + rotate + translate each ring.
  final result = <List<Vec3>>[];
  for (int r = 0; r < rings; r++) {
    final t = r / (rings - 1);
    final localRing = _neckRingLocal(cfg, t, segments);
    final worldRing = localRing.map((p) {
      final rotated = rotateHead(p, neckYaw, neckPitch, neckRoll);
      return rotated + neckTopWorld;
    }).toList();
    result.add(worldRing);
  }
  return result;
}