import 'dart:math';
import 'package:flutter/material.dart';

import '../services/shape_detector.dart';
import '../utils/neck_math.dart';
import '../utils/face_feature_math.dart';
import '../utils/rough_guide_renderer.dart';

class ArtistPainter extends CustomPainter {
  final DeconstructedData data;
  final Size originalImageSize;
  final int walkthroughStep;
  final bool showOriginalImage;

  ArtistPainter({
    required this.data,
    required this.originalImageSize,
    this.walkthroughStep = 0, // 0 means show everything
    this.showOriginalImage = false,
  });

  static final RoughGuideRenderer _roughLine = RoughGuideRenderer(
    color: const Color(0xFF2B3A42),
    strokeWidth: 0.6,
    roughness: 0.6,
    bowing: 0.3,
    seed: 42,
  );
  static final RoughGuideRenderer _roughGuide = RoughGuideRenderer(
    color: const Color(0xFF2B3A42).withValues(alpha: 0.75),
    strokeWidth: 0.4,
    roughness: 0.7,
    bowing: 0.4,
    seed: 42,
  );
  static final RoughGuideRenderer _roughHair = RoughGuideRenderer(
    color: const Color(0xFF2B3A42).withValues(alpha: 0.6),
    strokeWidth: 0.5,
    roughness: 1.8,
    bowing: 1.0,
    seed: 42,
  );

  /// Computes the bounding rectangle encompassing the full final sketch
  /// (including hair outlines, cranial structure, ears, chin, and guidelines)
  /// plus padding.
  static Rect getSketchBounds(DeconstructedData data, Size originalImageSize) {
    double minX = 0;
    double minY = 0;
    double maxX = originalImageSize.width;
    double maxY = originalImageSize.height;

    minX = min(minX, data.cranialRect.left);
    minY = min(minY, data.cranialRect.top);
    maxX = max(maxX, data.cranialRect.right);
    maxY = max(maxY, data.cranialRect.bottom);

    minY = min(minY, data.hairlineY);
    maxY = max(maxY, data.chinY);
    minX = min(minX, data.leftSideX);
    maxX = max(maxX, data.rightSideX);

    for (final p in data.meshPoints) {
      minX = min(minX, p.dx);
      minY = min(minY, p.dy);
      maxX = max(maxX, p.dx);
      maxY = max(maxY, p.dy);
    }

    for (final contour in data.hairContours) {
      for (final p in contour) {
        minX = min(minX, p.dx);
        minY = min(minY, p.dy);
        maxX = max(maxX, p.dx);
        maxY = max(maxY, p.dy);
      }
    }

    for (final contour in data.earContours) {
      for (final p in contour) {
        minX = min(minX, p.dx);
        minY = min(minY, p.dy);
        maxX = max(maxX, p.dx);
        maxY = max(maxY, p.dy);
      }
    }

    final double width = maxX - minX;
    final double height = maxY - minY;
    final double padX = max(width * 0.04, 8.0);
    final double padY = max(height * 0.04, 8.0);

    return Rect.fromLTRB(
      minX - padX,
      minY - padY,
      maxX + padX,
      maxY + padY,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect sketchBounds = getSketchBounds(data, originalImageSize);
    final double scaleX = size.width / sketchBounds.width;
    final double scaleY = size.height / sketchBounds.height;

    Offset scalePoint(num x, num y) => Offset(
      (x - sketchBounds.left) * scaleX,
      (y - sketchBounds.top) * scaleY,
    );

    final Offset sphereCenter = scalePoint(
      data.cranialRect.center.dx,
      data.cranialRect.center.dy,
    );
    final double sphereRadius = min(
      data.cranialRect.width * scaleX,
      data.cranialRect.height * scaleY,
    ) / 2;

    final bool isPolish = walkthroughStep == 16;

    // --- 1. Head Construction (HIDDEN in Step 16) ---
    if (!isPolish) {
      _drawBaseCranium(canvas, sphereCenter, sphereRadius, scalePoint(0, data.chinY).dy);
      if (walkthroughStep == 1) return;

      _drawSquareAndChin(canvas, sphereCenter, sphereRadius);
      if (walkthroughStep == 2) return;

      _drawDottedGuidelines(canvas, scalePoint, sphereCenter, sphereRadius);
      if (walkthroughStep == 3) return;
    }

    // --- 2. Jaw Logic ---
    if (walkthroughStep == 5) {
      _drawActualSilhouette(canvas, scalePoint);
    }
    _drawSymmetricalJaw(canvas, sphereCenter, scalePoint);
    if (walkthroughStep == 4 || walkthroughStep == 5) return;

    if (data.meshPoints.length < 468) return;
    final List<Offset> mesh = data.meshPoints.map((p) => scalePoint(p.dx, p.dy)).toList();

    // --- 3. Brows ---
    _drawEyebrows(canvas, mesh);
    if (walkthroughStep == 6) return;

    // --- 4. Nose ---
    if (!isPolish) {
      _drawNoseConstruction(canvas, mesh);
    }
    if (walkthroughStep == 7) {
      final nose = generateNoseGuide(mesh);
      final double topY = scalePoint(0, data.browY).dy;
      final double bottomY = nose.tipCenter.dy + nose.tipRadius;
      _drawDottedLine(canvas, Offset(nose.leftNostrilCenter.dx - (nose.nostrilRadius * 0.5), topY), Offset(nose.leftNostrilCenter.dx - (nose.nostrilRadius * 0.5), bottomY));
      _drawDottedLine(canvas, Offset(nose.rightNostrilCenter.dx + (nose.nostrilRadius * 0.5), topY), Offset(nose.rightNostrilCenter.dx + (nose.nostrilRadius * 0.5), bottomY));
      return;
    }

    final nose = generateNoseGuide(mesh);
    if (isPolish) {
      _roughLine.drawOpenPoints(canvas, nose.leftBridge);
      _roughLine.drawOpenPoints(canvas, nose.rightBridge);
      _roughLine.drawOpenPoints(canvas, nose.bottomContour);
    } else {
      _drawDottedPath(canvas, nose.leftBridge);
      _drawDottedPath(canvas, nose.rightBridge);
      _drawDottedPath(canvas, nose.bottomContour);
    }
    if (walkthroughStep == 8) return;

    // --- 5. Lips ---
    if (!isPolish) {
      _drawLipConstruction(canvas, mesh);
    }
    if (walkthroughStep == 9) return;

    _drawLipOutlines(canvas, mesh);
    if (walkthroughStep == 10) return;

    // --- 6. Eyes ---
    _drawEyePupils(canvas, mesh);
    if (walkthroughStep == 11) return;

    _drawEyeContours(canvas, mesh);
    if (walkthroughStep == 12) return;

    // --- 7. Ears ---
    if (data.earContours.isNotEmpty) {
      if (walkthroughStep >= 13) {
        _drawApproximateEars(canvas, sphereCenter, sphereRadius, scalePoint);
      }

      if (walkthroughStep == 14) {
        _drawRealEarDotted(canvas, scalePoint);
      }
    }
    if (walkthroughStep == 13 || walkthroughStep == 14) {
      return;
    }

    // --- 8. Hair ---
    _drawHairSilhouette(canvas, scalePoint);
    if (walkthroughStep == 15) return;

    if (!isPolish) {
      _drawNeck(canvas, sphereCenter, sphereRadius, data.headYaw, data.headPitch, data.headRoll);
    }
  }

  // --- Helper Methods ---

  void _drawBaseCranium(Canvas canvas, Offset center, double radius, double chinY) {
    _roughLine.drawOval(canvas, Rect.fromCenter(center: center, width: radius * 2, height: radius * 2));
    _roughLine.drawLine(canvas, Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius));
    _roughLine.drawLine(canvas, Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy));
    _roughLine.drawLine(canvas, Offset(center.dx, center.dy - radius), Offset(center.dx, chinY));
  }

  void _drawSquareAndChin(Canvas canvas, Offset center, double radius) {
    final double s = radius * sqrt(2);
    final double halfS = s / 2;
    _roughLine.drawClosedPoints(canvas, [
      Offset(center.dx - halfS, center.dy - halfS),
      Offset(center.dx + halfS, center.dy - halfS),
      Offset(center.dx + halfS, center.dy + halfS),
      Offset(center.dx - halfS, center.dy + halfS),
    ]);
    _roughGuide.drawLine(canvas, Offset(center.dx - halfS, center.dy), Offset(center.dx + halfS, center.dy));
    _roughLine.drawLine(canvas, Offset(center.dx - halfS, center.dy + s), Offset(center.dx + halfS, center.dy + s));
  }

  void _drawDottedGuidelines(Canvas canvas, Offset Function(num x, num y) scalePoint, Offset center, double radius) {
    final double s = radius * sqrt(2);
    final double halfS = s / 2;
    final double halfWidth = radius * 0.95;
    for (final y in [data.hairlineY, data.browY, data.noseY, data.chinY]) {
      final double yScaled = scalePoint(0, y).dy;
      _drawDottedLine(canvas, Offset(center.dx - halfWidth, yScaled), Offset(center.dx + halfWidth, yScaled));
    }
    final double leftX = scalePoint(data.leftSideX, 0).dx;
    final double rightX = scalePoint(data.rightSideX, 0).dx;
    final double chinY = scalePoint(0, data.chinY).dy;
    _drawDottedLine(canvas, Offset(leftX, center.dy - halfS), Offset(leftX, chinY));
    _drawDottedLine(canvas, Offset(rightX, center.dy - halfS), Offset(rightX, chinY));
  }

  void _drawSymmetricalJaw(Canvas canvas, Offset center, Offset Function(num x, num y) scalePoint) {
    final jaw = generateJawGuide(data.meshPoints);
    final double centerX = center.dx;
    final Offset lJawPoint = scalePoint(jaw.leftJaw.dx, jaw.leftJaw.dy);
    final Offset rJawPoint = scalePoint(jaw.rightJaw.dx, jaw.rightJaw.dy);
    final double lJawDist = (centerX - lJawPoint.dx).abs();
    final double rJawDist = (rJawPoint.dx - centerX).abs();
    final double symJawHalfWidth = max(lJawDist, rJawDist);
    final double symJawY = (lJawPoint.dy + rJawPoint.dy) / 2;
    final double leftSideX = scalePoint(data.leftSideX, 0).dx;
    final double rightSideX = scalePoint(data.rightSideX, 0).dx;
    final double faceWidth = (rightSideX - leftSideX).abs();
    final double symChinHalfWidth = faceWidth / 6;
    final double symChinY = scalePoint(0, data.chinY).dy;

    final lJaw = Offset(centerX - symJawHalfWidth, symJawY);
    final rJaw = Offset(centerX + symJawHalfWidth, symJawY);
    final lChin = Offset(centerX - symChinHalfWidth, symChinY);
    final rChin = Offset(centerX + symChinHalfWidth, symChinY);
    final lAnchor = Offset(leftSideX, center.dy);
    final rAnchor = Offset(rightSideX, center.dy);

    _roughLine.drawLine(canvas, lAnchor, lJaw);
    _roughLine.drawLine(canvas, lJaw, lChin);
    _roughLine.drawLine(canvas, lChin, rChin);
    _roughLine.drawLine(canvas, rChin, rJaw);
    _roughLine.drawLine(canvas, rJaw, rAnchor);
  }

  void _drawActualSilhouette(Canvas canvas, Offset Function(num x, num y) scalePoint) {
    final silhouette = generateFaceSilhouette(data.meshPoints);
    final scaledSilhouette = silhouette.map((p) => scalePoint(p.dx, p.dy)).toList();
    _drawDottedPath(canvas, scaledSilhouette, isClosed: true);
  }

  void _drawEyebrows(Canvas canvas, List<Offset> mesh) {
    for (final brow in generateEyebrowGuides(mesh)) {
      _roughGuide.drawOpenPoints(canvas, brow);
    }
  }

  void _drawNoseConstruction(Canvas canvas, List<Offset> mesh) {
    final nose = generateNoseGuide(mesh);
    _roughGuide.drawCircle(canvas, nose.tipCenter, nose.tipRadius);
    _roughGuide.drawCircle(canvas, nose.leftNostrilCenter, nose.nostrilRadius);
    _roughGuide.drawCircle(canvas, nose.rightNostrilCenter, nose.nostrilRadius);
  }

  void _drawEyePupils(Canvas canvas, List<Offset> mesh) {
    for (final eye in generateEyeGuides(mesh)) {
      if (eye.irisRadius > 0) {
        _roughGuide.drawCircle(canvas, eye.irisCenter, eye.irisRadius);
        _roughGuide.drawCircle(canvas, eye.irisCenter, eye.pupilRadius);
      }
    }
  }

  void _drawEyeContours(Canvas canvas, List<Offset> mesh) {
    for (final eye in generateEyeGuides(mesh)) {
      _roughGuide.drawOpenPoints(canvas, eye.contour);
    }
  }

  void _drawApproximateEars(Canvas canvas, Offset sphereCenter, double sphereRadius, Offset Function(num x, num y) scalePoint) {
    final double leftEyeY = scalePoint(0, data.meshPoints[473].dy).dy;
    final double rightEyeY = scalePoint(0, data.meshPoints[468].dy).dy;
    final double earTop = (leftEyeY + rightEyeY) / 2;

    final double earBottom = scalePoint(0, data.noseY).dy; 
    final double earHeight = (earBottom - earTop).abs();
    final double earWidth = earHeight * 0.32;

    final double leftSideX = scalePoint(data.leftSideX, 0).dx;
    final double rightSideX = scalePoint(data.rightSideX, 0).dx;

    final double centerY = (earTop + earBottom) / 2;
    final double inwardShift = earWidth * 0.2;
    
    // Left Ear
    canvas.save();
    canvas.translate(leftSideX + inwardShift, centerY);
    canvas.rotate(-12 * pi / 180);
    _roughLine.drawOval(canvas, Rect.fromLTRB(-earWidth, -earHeight / 2, 0, earHeight / 2));
    canvas.restore();

    // Right Ear
    canvas.save();
    canvas.translate(rightSideX - inwardShift, centerY);
    canvas.rotate(12 * pi / 180);
    _roughLine.drawOval(canvas, Rect.fromLTRB(0, -earHeight / 2, earWidth, earHeight / 2));
    canvas.restore();
  }

  void _drawRealEarDotted(Canvas canvas, Offset Function(num x, num y) scalePoint) {
    for (final samples in data.earContours) {
      if (samples.length < 3) continue;

      final scaled = samples.map((p) => scalePoint(p.dx, p.dy)).toList();
      final n = scaled.length;
      Offset at(int i) => scaled[((i % n) + n) % n];

      final path = Path();
      path.moveTo(at(0).dx, at(0).dy);

      for (int i = 0; i < n; i++) {
        final p1 = at(i);
        final p2 = at(i + 1);
        final p0 = at(i - 1);
        final p3 = at(i + 2);
        
        final cp1 = p1 + (p2 - p0) / 6.0;
        final cp2 = p2 - (p3 - p1) / 6.0;
        
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      }
      path.close();

      _drawDottedPathObject(canvas, path);
    }
  }

  void _drawDottedPathObject(Canvas canvas, Path path) {
    for (final metric in path.computeMetrics()) {
      const double dash = 4.0, space = 6.0;
      double distance = 0.0;
      while (distance < metric.length) {
        final end = min(distance + dash, metric.length);
        final extract = metric.extractPath(distance, end);
        _roughGuide.drawPath(canvas, extract);
        distance += dash + space;
      }
    }
  }

  void _drawLipConstruction(Canvas canvas, List<Offset> mesh) {
    final lips = generateLipGuides(mesh);
    _roughGuide.drawCircle(canvas, lips.upperLeft.center, lips.upperLeft.radius);
    _roughGuide.drawCircle(canvas, lips.upperRight.center, lips.upperRight.radius);
    _roughGuide.drawCircle(canvas, lips.lowerCenter.center, lips.lowerCenter.radius);
  }

  void _drawLipOutlines(Canvas canvas, List<Offset> mesh) {
    final lips = generateLipGuides(mesh);
    _roughGuide.drawOpenPoints(canvas, lips.upperOutline);
    _roughGuide.drawOpenPoints(canvas, lips.lowerOutline);
    _roughGuide.drawOpenPoints(canvas, lips.mouthLine);
  }

  void _drawNeck(Canvas canvas, Offset center, double radius, double yaw, double pitch, double roll) {
    final rings = generateNeckRings(cfg: const NeckConfig(), headYaw: yaw, headPitch: pitch, headRoll: roll, poseLandmarks: data.poseLandmarks);
    for (final ring in rings) {
      final path = Path();
      bool penDown = false;
      for (final v in ring) {
        final visible = v.z > -0.02;
        final projected = Offset(center.dx + v.x * radius, center.dy + v.y * radius);
        if (!visible) { penDown = false; continue; }
        if (!penDown) { path.moveTo(projected.dx, projected.dy); penDown = true; }
        else { path.lineTo(projected.dx, projected.dy); }
      }
      _roughGuide.drawPath(canvas, path);
    }
  }

  void _drawHairSilhouette(Canvas canvas, Offset Function(num x, num y) scalePoint) {
    for (final contour in data.hairContours) {
      final scaled = contour.map((p) => scalePoint(p.dx, p.dy)).toList();
      _roughHair.drawClosedPoints(canvas, scaled);
    }
  }

  void _drawDottedLine(Canvas canvas, Offset start, Offset end) {
    const double dash = 4.0, space = 4.0;
    final double dist = (end - start).distance;
    final int count = (dist / (dash + space)).floor();
    final Offset unit = (end - start) / dist;
    for (int i = 0; i < count; i++) {
      final Offset s = start + unit * (i * (dash + space));
      final Offset e = s + unit * dash;
      _roughGuide.drawLine(canvas, s, e);
    }
  }

  void _drawDottedPath(Canvas canvas, List<Offset> points, {bool isClosed = false}) {
    if (points.length < 2) return;
    for (int i = 0; i < (isClosed ? points.length : points.length - 1); i++) {
      _drawDottedLine(canvas, points[i], points[(i + 1) % points.length]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
