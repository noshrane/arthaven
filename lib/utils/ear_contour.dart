// ear_contour.dart
//
// Converts raw boolean segmentation masks into smooth outlines.

import 'dart:math';
import 'dart:ui';

class EarContourExtractor {
  /// Samples 12 extremal points at even angular intervals around the mask's
  /// centroid. This provides a clean, noise-robust control set for splines.
  static List<List<Offset>> extractAllRadialPoints({
    required List<List<bool>> mask,
    int minBlobSize = 40,
    int numSamples = 12,
  }) {
    final h = mask.length;
    if (h == 0) return [];
    final w = mask[0].length;

    final blobs = _allComponents(mask, h, w, minBlobSize);
    final results = <List<Offset>>[];

    for (final blob in blobs) {
      double sumX = 0, sumY = 0;
      int count = 0;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          if (blob[y][x]) {
            sumX += x;
            sumY += y;
            count++;
          }
        }
      }
      if (count == 0) continue;
      final centroid = Offset(sumX / count, sumY / count);

      final samples = <Offset>[];
      final maxRadius = sqrt(w * w + h * h);
      
      for (int i = 0; i < numSamples; i++) {
        final angle = (i * 2 * pi) / numSamples;
        final dirX = cos(angle);
        final dirY = sin(angle);

        Offset? extremal;
        for (double r = 0; r < maxRadius; r += 1.0) {
          final px = (centroid.dx + dirX * r).round();
          final py = (centroid.dy + dirY * r).round();
          
          if (px >= 0 && px < w && py >= 0 && py < h) {
            if (blob[py][px]) {
              extremal = Offset(px.toDouble(), py.toDouble());
            }
          } else {
            break;
          }
        }
        
        if (extremal != null) {
          samples.add(extremal);
        }
      }

      if (samples.length >= 3) {
        results.add(samples);
      }
    }

    return results;
  }

  /// Returns the simplified control points for ALL detected mask blobs.
  /// Used for complex shapes like hair silhouettes.
  static List<List<Offset>> extractAllSimplifiedPoints({
    required List<List<bool>> mask,
    int minBlobSize = 40,
    double simplifyEpsilon = 2.0,
  }) {
    final h = mask.length;
    if (h == 0) return [];
    final w = mask[0].length;

    final blobs = _allComponents(mask, h, w, minBlobSize);
    final results = <List<Offset>>[];

    for (final blob in blobs) {
      final boundary = _traceBoundary(blob, h, w);
      if (boundary.length >= 4) {
        final simplified = _simplifyRDP(boundary, simplifyEpsilon);
        if (simplified.length >= 4) {
          results.add(simplified);
        }
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  static const List<List<int>> _fourNeighbors = [
    [-1, 0], [1, 0], [0, -1], [0, 1],
  ];

  static List<List<List<bool>>> _allComponents(
      List<List<bool>> mask, int h, int w, int minBlobSize) {
    final labels = List.generate(h, (_) => List<int>.filled(w, 0));
    int currentLabel = 0;
    final sizes = <int, int>{};

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (mask[y][x] && labels[y][x] == 0) {
          currentLabel++;
          int size = 0;
          final queue = [[y, x]];
          labels[y][x] = currentLabel;
          while (queue.isNotEmpty) {
            final cur = queue.removeLast();
            final cy = cur[0], cx = cur[1];
            size++;
            for (final d in _fourNeighbors) {
              final ny = cy + d[0], nx = cx + d[1];
              if (ny >= 0 && ny < h && nx >= 0 && nx < w &&
                  mask[ny][nx] && labels[ny][nx] == 0) {
                labels[ny][nx] = currentLabel;
                queue.add([ny, nx]);
              }
            }
          }
          sizes[currentLabel] = size;
        }
      }
    }

    final results = <List<List<bool>>>[];
    for (final entry in sizes.entries) {
      if (entry.value >= minBlobSize) {
        final label = entry.key;
        results.add(List.generate(h, (y) => List.generate(w, (x) => labels[y][x] == label)));
      }
    }
    return results;
  }

  static const List<List<int>> _moore = [
    [0, -1], [-1, -1], [-1, 0], [-1, 1], [0, 1], [1, 1], [1, 0], [1, -1],
  ];

  static List<Offset> _traceBoundary(List<List<bool>> blob, int h, int w) {
    int? startY, startX;
    outer:
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (blob[y][x]) { startY = y; startX = x; break outer; }
      }
    }
    if (startY == null) return [];

    final boundary = <Offset>[Offset(startX!.toDouble(), startY.toDouble())];
    int cy = startY, cx = startX;
    int searchDir = 0;

    while (true) {
      bool found = false;
      for (int i = 0; i < 8; i++) {
        final dirIndex = (searchDir + i) % 8;
        final ny = cy + _moore[dirIndex][0], nx = cx + _moore[dirIndex][1];
        if (ny >= 0 && ny < h && nx >= 0 && nx < w && blob[ny][nx]) {
          cy = ny; cx = nx; searchDir = (dirIndex + 5) % 8;
          boundary.add(Offset(cx.toDouble(), cy.toDouble()));
          found = true; break;
        }
      }
      if (!found || (cy == startY && cx == startX) || boundary.length > h * w) break;
    }
    return boundary;
  }

  static List<Offset> _simplifyRDP(List<Offset> points, double epsilon) {
    if (points.length < 3) return points;
    double maxDist = 0;
    int index = 0;
    final start = points.first, end = points.last;
    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpendicularDistance(points[i], start, end);
      if (d > maxDist) { maxDist = d; index = i; }
    }
    if (maxDist > epsilon) {
      final left = _simplifyRDP(points.sublist(0, index + 1), epsilon);
      final right = _simplifyRDP(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [start, end];
    }
  }

  static double _perpendicularDistance(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy, mag = sqrt(dx * dx + dy * dy);
    if (mag == 0) return (p - a).distance;
    final u = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / (mag * mag);
    return (p - Offset(a.dx + u * dx, a.dy + u * dy)).distance;
  }
}
