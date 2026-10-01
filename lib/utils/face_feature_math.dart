import 'dart:ui';

/// Pure geometry for eye, eyebrow, and nose guides, built directly from
/// MediaPipe Face Landmarker's 478-point mesh (indices 0-477, with the
/// iris ring at 468-477 present whenever the mesh was generated with
/// attention/iris refinement enabled). No widget or canvas dependencies,
/// mirroring sphere_math.dart / neck_math.dart's pattern.
///
/// This is a direct port of the facial-feature guide cell in
/// arthaven.py -- same indices, same ratio constants, same formulas.
/// Calibrate the constants below in lockstep with the Colab notebook;
/// they're duplicated by necessity (Dart vs Python), not by design.
///
/// All functions take `mesh`: the full 478-point list in PIXEL space
/// (already scaled to whatever canvas/image space you're drawing into),
/// indexed exactly like MediaPipe -- mesh[168] is the same physical
/// landmark here as pt(168) in the Colab.

// ---- MediaPipe indices (identical to arthaven.py) ----

const int kNoseBridgeTop = 168; // between the brows, top of the nose bridge
const int kNoseTip = 1;
const int kNoseBottom = 2; // septum base, between the two nostrils
const int kLeftNostril = 129; // left ala (outer nostril edge)
const int kRightNostril = 358; // right ala

const int kLeftIrisCenter = 473;
const List<int> kLeftIrisRing = [474, 475, 476, 477];
const int kRightIrisCenter = 468;
const List<int> kRightIrisRing = [469, 470, 471, 472];

// Standard MediaPipe 16-point eye contours (eyelid outline).
const List<int> kLeftEyeContour = [
  33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246,
];
const List<int> kRightEyeContour = [
  263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388,
  466,
];

// Eyelid creases
const List<int> kLeftEyelidCrease = [226, 113, 225, 224, 223, 222, 221, 189, 244];
const List<int> kRightEyelidCrease = [446, 342, 445, 444, 443, 442, 441, 413, 464];

// Lash anchor indices (subsets of the eyelid contour)
const List<int> kLeftUpperLashIndices = [160, 159, 158, 157, 173];
const List<int> kLeftLowerLashIndices = [144, 145, 153, 154, 155];
const List<int> kRightUpperLashIndices = [387, 386, 385, 384, 398];
const List<int> kRightLowerLashIndices = [373, 374, 380, 381, 382];

// Accurate eyebrow paths (10 points each)
const List<int> kLeftEyebrow = [46, 53, 52, 65, 55, 107, 66, 105, 63, 70];
const List<int> kRightEyebrow = [276, 283, 282, 295, 285, 336, 296, 334, 293, 300];

// Jaw and Chin indices
const int kLeftJawAngle = 58;
const int kRightJawAngle = 288;
const int kLeftChinWidth = 176;
const int kRightChinWidth = 379;

// Lip construction indices
const int kUpperLipPeakLeft = 37;
const int kUpperLipPeakRight = 267;
const int kUpperLipInnerLeft = 82;
const int kUpperLipInnerRight = 312;
const int kLowerLipBottom = 17;
const int kLowerLipInnerCenter = 14;

// Detailed lip outlines
const List<int> kUpperLipOuter = [61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291];
const List<int> kUpperLipInner = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308];
const List<int> kLowerLipOuter = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291];
const List<int> kLowerLipInner = [78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308];

// Face silhouette (jawline and forehead)
const List<int> kFaceSilhouette = [
  10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378,
  152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109
];

// Nose bridge side indices (removed top segments for a cleaner look)
const List<int> kLeftNoseBridge = [174, 102];
const List<int> kRightNoseBridge = [399, 331];

// Nose bottom contour indices (connecting wings and base)
const List<int> kNoseBottomContour = [129, 98, 97, 2, 326, 327, 358];

// ---- Tunable ratios -- same names/values as arthaven.py; calibrate both
// files together against real reference photos. ----

/// Pupil circle radius as a fraction of the iris circle's radius.
const double kPupilRadiusRatio = 0.42;

/// Nostril circle radius, same reference span as the tip circle.
const double kNostrilRadiusRatio = 0.09;

/// How far each nostril circle is blended from the ala landmark toward
/// the septum base (NOSE_BOTTOM). 0 = at the ala, 1 = at the septum base.
const double kNostrilInwardRatio = 0.4;

class EyeGuide {
  /// 16-point closed eyelid outline.
  final List<Offset> contour;
  final Offset irisCenter;
  final double irisRadius;
  final double pupilRadius;

  final List<Offset> eyelidCrease;

  const EyeGuide({
    required this.contour,
    required this.irisCenter,
    required this.irisRadius,
    required this.pupilRadius,
    required this.eyelidCrease,
  });
}

class NoseGuide {
  final List<Offset> leftBridge;
  final List<Offset> rightBridge;
  final List<Offset> bottomContour;
  final Offset tipCenter;
  final double tipRadius;
  final Offset leftNostrilCenter;
  final Offset rightNostrilCenter;
  final double nostrilRadius;

  const NoseGuide({
    required this.leftBridge,
    required this.rightBridge,
    required this.bottomContour,
    required this.tipCenter,
    required this.tipRadius,
    required this.leftNostrilCenter,
    required this.rightNostrilCenter,
    required this.nostrilRadius,
  });
}

class JawGuide {
  final Offset leftJaw;
  final Offset rightJaw;
  final Offset leftChin;
  final Offset rightChin;

  const JawGuide({
    required this.leftJaw,
    required this.rightJaw,
    required this.leftChin,
    required this.rightChin,
  });
}

class LipBall {
  final Offset center;
  final double radius;
  const LipBall(this.center, this.radius);
}

class LipGuide {
  final LipBall upperLeft;
  final LipBall upperRight;
  final LipBall lowerCenter;

  // Detailed outlines
  final List<Offset> upperOutline;
  final List<Offset> lowerOutline;
  final List<Offset> mouthLine;

  const LipGuide({
    required this.upperLeft,
    required this.upperRight,
    required this.lowerCenter,
    required this.upperOutline,
    required this.lowerOutline,
    required this.mouthLine,
  });
}

Offset _pt(List<Offset> mesh, int idx) => mesh[idx];

EyeGuide _buildEyeGuide(
    List<Offset> mesh,
    List<int> contourIdxs,
    int irisCenterIdx,
    List<int> irisRingIdxs,
    List<int> creaseIdxs,
    ) {
  final contour = contourIdxs.map((i) => _pt(mesh, i)).toList();

  // If the iris indices are beyond the mesh length, we skip iris/pupil
  // calculation and return zeros/identity.
  if (irisCenterIdx >= mesh.length || irisRingIdxs.any((i) => i >= mesh.length)) {
    return EyeGuide(
      contour: contour,
      irisCenter: Offset.zero,
      irisRadius: 0,
      pupilRadius: 0,
      eyelidCrease: creaseIdxs.map((i) => _pt(mesh, i)).toList(),
    );
  }

  final center = _pt(mesh, irisCenterIdx);

  double ringDistanceSum = 0;
  for (final i in irisRingIdxs) {
    ringDistanceSum += (_pt(mesh, i) - center).distance;
  }
  final irisRadius = ringDistanceSum / irisRingIdxs.length;
  final pupilRadius = irisRadius * kPupilRadiusRatio;

  return EyeGuide(
    contour: contour,
    irisCenter: center,
    irisRadius: irisRadius,
    pupilRadius: pupilRadius,
    eyelidCrease: creaseIdxs.map((i) => _pt(mesh, i)).toList(),
  );
}

/// Builds both eye guides (contour + iris + pupil + crease). 
/// Safely handles 468-point meshes by skipping iris/pupil data if the 
/// indices are missing.
List<EyeGuide> generateEyeGuides(List<Offset> mesh) {
  return [
    _buildEyeGuide(
      mesh,
      kLeftEyeContour,
      kLeftIrisCenter,
      kLeftIrisRing,
      kLeftEyelidCrease,
    ),
    _buildEyeGuide(
      mesh,
      kRightEyeContour,
      kRightIrisCenter,
      kRightIrisRing,
      kRightEyelidCrease,
    ),
  ];
}

/// Builds both eyebrow contours as closed 10-point polygons.
List<List<Offset>> generateEyebrowGuides(List<Offset> mesh) {
  return [
    kLeftEyebrow.map((i) => _pt(mesh, i)).toList(),
    kRightEyebrow.map((i) => _pt(mesh, i)).toList(),
  ];
}

/// Builds the face silhouette outline (jawline and forehead).
List<Offset> generateFaceSilhouette(List<Offset> mesh) {
  return kFaceSilhouette.map((i) => _pt(mesh, i)).toList();
}

/// Builds the nose guide: bridge paths, tip circle, two nostril circles, and bottom contour.
NoseGuide generateNoseGuide(List<Offset> mesh) {
  final tip = _pt(mesh, kNoseTip);
  final bottom = _pt(mesh, kNoseBottom);

  // The central ball (tip) is centered on the nose tip (Landmark 1)
  // and its bottom edge reaches the base of the nose (Landmark 2).
  final tipRadius = (tip - bottom).distance;
  final tipCenter = tip;

  // The side balls (nostrils) are smaller and tucked into the central ball.
  final nostrilRadius = tipRadius * 0.65;

  Offset inwardNostrilCenter(int alaIdx) {
    final ala = _pt(mesh, alaIdx);
    // Blend the outer ala landmark inward toward the septum (bottom) 
    // to create the overlap shown in the three-ball construction method.
    final double inwardX = ala.dx + (bottom.dx - ala.dx) * 0.45;
    // Align the bottom of the nostril balls with the bottom of the tip ball.
    final double targetBottomY = tipCenter.dy + tipRadius;
    return Offset(inwardX, targetBottomY - nostrilRadius);
  }

  return NoseGuide(
    leftBridge: kLeftNoseBridge.map((i) => _pt(mesh, i)).toList(),
    rightBridge: kRightNoseBridge.map((i) => _pt(mesh, i)).toList(),
    bottomContour: kNoseBottomContour.map((i) => _pt(mesh, i)).toList(),
    tipCenter: tipCenter,
    tipRadius: tipRadius,
    leftNostrilCenter: inwardNostrilCenter(kLeftNostril),
    rightNostrilCenter: inwardNostrilCenter(kRightNostril),
    nostrilRadius: nostrilRadius,
  );
}

/// Builds the jaw block-in guide: four points defining the jaw structure.
JawGuide generateJawGuide(List<Offset> mesh) {
  return JawGuide(
    leftJaw: _pt(mesh, kLeftJawAngle),
    rightJaw: _pt(mesh, kRightJawAngle),
    leftChin: _pt(mesh, kLeftChinWidth),
    rightChin: _pt(mesh, kRightChinWidth),
  );
}

/// Builds the lip construction guides: three circles that fit precisely 
/// between the upper and lower edges of the lips, plus detailed outlines.
LipGuide generateLipGuides(List<Offset> mesh) {
  LipBall buildBall(int topIdx, int bottomIdx) {
    final top = _pt(mesh, topIdx);
    final bottom = _pt(mesh, bottomIdx);
    final center = (top + bottom) * 0.5;
    final radius = (top - bottom).distance * 0.5;
    return LipBall(center, radius);
  }

  return LipGuide(
    upperLeft: buildBall(kUpperLipPeakLeft, kUpperLipInnerLeft),
    upperRight: buildBall(kUpperLipPeakRight, kUpperLipInnerRight),
    lowerCenter: buildBall(kLowerLipInnerCenter, kLowerLipBottom),
    upperOutline: kUpperLipOuter.map((i) => _pt(mesh, i)).toList(),
    lowerOutline: kLowerLipOuter.map((i) => _pt(mesh, i)).toList(),
    mouthLine: kUpperLipInner.map((i) => _pt(mesh, i)).toList(),
  );
}