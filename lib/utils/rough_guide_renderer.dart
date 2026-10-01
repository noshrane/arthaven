// rough_guide_renderer.dart
//
// Adapts ArtistPainter's existing guide geometry (dart:ui Path objects from
// sphere_math.dart / neck_math.dart / ear_contour.dart, and raw point lists
// from the eye/nose/eyebrow guides) to sketchy, pencil-style rendering via
// the rough_flutter package, instead of plain canvas.drawPath/drawCircle.
//
// Setup:
//   1. flutter pub add rough_flutter
//   2. Import this file in ArtistPainter.dart
//   3. Create ONE RoughGuideRenderer (per guide color you use) as a field,
//      not inside paint() -- see notes at the bottom of this file for why.

import 'dart:ui';
import 'package:rough_flutter/rough_flutter.dart';

class RoughGuideRenderer {
  final Generator generator;
  final Paint strokePaint;
  final Paint fillPaint;

  /// [seed] MUST stay fixed across repaints. rough_flutter's "roughness"
  /// is randomized -- without a fixed seed, every repaint (pan, zoom,
  /// scroll) regenerates different jitter and the lines visibly vibrate
  /// instead of looking like a stable pencil sketch.
  RoughGuideRenderer({
    required Color color,
    double strokeWidth = 1.4,
    double roughness = 1.6,
    double bowing = 0.8,
    int seed = 42,
  })  : generator = Generator(
    DrawConfig.build(
      roughness: roughness,
      bowing: bowing,
      seed: seed,
      curveStepCount: 9,
      maxRandomnessOffset: 2,
    ),
    SolidFiller(), // guide lines are strokes only; fill unused here
  ),
        strokePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
        fillPaint = Paint()..color = const Color(0x00000000); // transparent fill

  /// Draws any dart:ui Path (open or closed, single or multi-contour) as a
  /// sketchy stroke. Each contour (each moveTo/lineTo run, e.g. the
  /// separate visible arcs left after hidden-line culling) is sampled and
  /// drawn as its OWN linearPath -- important: concatenating points across
  /// contours into a single linearPath would draw an unwanted connecting
  /// line across gaps that are deliberately supposed to stay open.
  void drawPath(Canvas canvas, Path path, {double sampleSpacing = 4.0}) {
    for (final metric in path.computeMetrics()) {
      final points = _sampleMetric(metric, sampleSpacing);
      if (points.length < 2) continue;
      final drawable = generator.linearPath(points);
      canvas.drawRough(drawable, strokePaint, fillPaint);
    }
  }

  /// Draws a sketchy oval/ellipse from a Rect (cranial sphere outline,
  /// foreshortened ear ellipses, etc). Works under an active canvas
  /// transform (translate/rotate) the same way canvas.drawOval does.
  void drawOval(Canvas canvas, Rect rect) {
    final drawable = generator.ellipse(
      rect.center.dx,
      rect.center.dy,
      rect.width,
      rect.height,
    );
    canvas.drawRough(drawable, strokePaint, fillPaint);
  }

  /// Draws a closed outline from a point list (eye contour, eyebrow,
  /// ear-cartilage inset) as a sketchy polygon.
  void drawClosedPoints(Canvas canvas, List<Offset> points) {
    if (points.length < 3) return;
    final drawable =
    generator.polygon(points.map((p) => PointD(p.dx, p.dy)).toList());
    canvas.drawRough(drawable, strokePaint, fillPaint);
  }

  /// Draws an open polyline (e.g. a single flow/strand line) from a point list.
  void drawOpenPoints(Canvas canvas, List<Offset> points) {
    if (points.length < 2) return;
    final drawable =
    generator.linearPath(points.map((p) => PointD(p.dx, p.dy)).toList());
    canvas.drawRough(drawable, strokePaint, fillPaint);
  }

  /// Draws a sketchy circle (iris, pupil, nose tip, nostrils, crosshair
  /// center, etc).
  ///
  /// NOTE: rough_flutter's generator.circle() takes DIAMETER as its third
  /// argument, not radius -- carried over from the original rough.js API.
  /// This method takes radius and doubles it for you so it matches how
  /// you're already calling cv2.circle()/canvas.drawCircle() with radius.
  void drawCircle(Canvas canvas, Offset center, double radius) {
    final drawable = generator.circle(center.dx, center.dy, radius * 2);
    canvas.drawRough(drawable, strokePaint, fillPaint);
  }

  /// Draws a straight sketchy line (crosshair, horizontal parallels,
  /// skull side guides).
  void drawLine(Canvas canvas, Offset start, Offset end) {
    final drawable = generator.line(start.dx, start.dy, end.dx, end.dy);
    canvas.drawRough(drawable, strokePaint, fillPaint);
  }

  List<PointD> _sampleMetric(PathMetric metric, double spacing) {
    final points = <PointD>[];
    final steps = (metric.length / spacing).ceil().clamp(2, 500);
    for (int i = 0; i <= steps; i++) {
      final distance = metric.length * (i / steps);
      final tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        points.add(PointD(tangent.position.dx, tangent.position.dy));
      }
    }
    return points;
  }
}

// ---------------------------------------------------------------------
// Example: wiring this into ArtistPainter.
//
// BEFORE (plain canvas):
//
//   final guidePaint = Paint()
//     ..color = color
//     ..style = PaintingStyle.stroke
//     ..strokeWidth = thickness;
//   canvas.drawPath(sphereMeridianPath, guidePaint);
//   canvas.drawCircle(irisCenter, irisRadius, guidePaint);
//   canvas.drawLine(crosshairStart, crosshairEnd, guidePaint);
//
// AFTER (sketchy):
//
//   class ArtistPainter extends CustomPainter {
//     // Create ONCE -- not inside paint(). If ArtistPainter is rebuilt
//     // on every gesture frame, hoist this up to the parent widget's
//     // State and pass it in instead, so the seed (and thus the sketch
//     // jitter pattern) stays stable across repaints.
//     final RoughGuideRenderer roughGuide = RoughGuideRenderer(
//       color: const Color(0xFFDC3C3C), // same reddish guide color you use now
//       strokeWidth: 1.4,
//       roughness: 1.6, // lower (~0.8-1.2) for a tighter, more controlled
//                        // construction-line look; higher (~2.5-3) for a
//                        // looser, more energetic sketch
//     );
//
//     @override
//     void paint(Canvas canvas, Size size) {
//       roughGuide.drawPath(canvas, sphereMeridianPath);
//       roughGuide.drawCircle(canvas, irisCenter, irisRadius);
//       roughGuide.drawLine(canvas, crosshairStart, crosshairEnd);
//       roughGuide.drawClosedPoints(canvas, leftEyeContourPoints);
//       // ...repeat for every guide element you currently draw directly.
//     }
//
//     @override
//     bool shouldRepaint(covariant ArtistPainter oldDelegate) => ...; // unchanged
//   }
//
// If you want different guide "families" to look visually distinct (e.g.
// the ear-cartilage guide lighter/less rough than the main head
// construction lines), create a second RoughGuideRenderer with a
// different color/roughness rather than reusing one for everything --
// that mirrors how you already split feature_color vs light_color in
// the Python overlay.