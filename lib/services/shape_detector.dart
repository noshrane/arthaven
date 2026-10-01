import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../utils/ear_contour.dart';

class DeconstructedData {
  final Rect cranialRect;
  final double headRoll;
  final double headPitch;
  final double headYaw; // side-to-side turning
  final Offset faceCenter;

  // Python-ported 2D guides
  final double hairlineY;
  final double browY;
  final double noseY;
  final double chinY;
  final double leftSideX;
  final double rightSideX;
  final double sideTopY;
  final double sideBottomY;

  /// Lists of points defining the detected ear outlines, in PIXEL coordinates.
  final List<List<Offset>> earContours;

  /// Lists of points defining the detected hair outlines, in PIXEL coordinates.
  final List<List<Offset>> hairContours;

  /// Full 478-point MediaPipe face mesh, in PIXEL coordinates already
  /// scaled to the source image's width/height -- index-for-index the
  /// same layout as arthaven.py's `pts` array, including the iris ring
  /// at indices 468-477. Replaces ML Kit's faceLandmarks/faceContours
  /// maps: those had no MediaPipe-compatible indexing and no iris data
  /// at all, which is what the eye/nose/eyebrow guides need.
  final List<Offset> meshPoints;

  // Detailed Body Landmarks (unchanged -- still ML Kit)
  final Map<PoseLandmarkType, PoseLandmark> poseLandmarks;

  DeconstructedData({
    required this.cranialRect,
    required this.headRoll,
    required this.headPitch,
    required this.headYaw,
    required this.faceCenter,
    required this.hairlineY,
    required this.browY,
    required this.noseY,
    required this.chinY,
    required this.leftSideX,
    required this.rightSideX,
    required this.sideTopY,
    required this.sideBottomY,
    required this.earContours,
    required this.hairContours,
    required this.meshPoints,
    required this.poseLandmarks,
  });
}

class LocalShapeDetector {
  FaceDetectorProcessor? _faceDetectorProcessor;
  FaceMeshProcessor? _faceMeshProcessor;
  FaceMeshInferencePipeline? _pipeline;
  OrtSession? _earParsingSession;

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.single),
  );

  bool _initialized = false;

  /// Must be awaited once before the first analyzeImage() call.
  /// FaceDetectorProcessor/FaceMeshProcessor load their .task models
  /// asynchronously (unlike ML Kit's sync constructors), so this can't
  /// happen inline in field initializers the way the old version did --
  /// call this from wherever LocalShapeDetector is first constructed
  /// (e.g. in the consuming screen's initState, before the first photo
  /// is analyzed).
  Future<void> initialize() async {
    if (_initialized) return;
    _faceDetectorProcessor = await FaceDetectorProcessor.create();
    // enableAttentionMesh: true is what gives us all 478 points -- iris
    // included -- in a single inference pass, matching arthaven.py's
    // refined MediaPipe Face Landmarker output index-for-index.
    _faceMeshProcessor = await FaceMeshProcessor.create(
      enableAttentionMesh: true,
    );
    _pipeline = FaceMeshInferencePipeline(
      detector: _faceDetectorProcessor!,
      mesh: _faceMeshProcessor!,
    );

    final ort = OnnxRuntime();
    _earParsingSession = await ort.createSessionFromAsset(
      'assets/models/face_parsing_bisenet_quantized.onnx',
    );

    _initialized = true;
  }

  /// [imageFile] is the same picked photo used elsewhere in the app.
  /// Decoded once here into raw RGBA pixels for the face mesh, and
  /// passed by file path to ML Kit for pose detection exactly as
  /// before -- pose detection is untouched by this migration.
  ///
  /// NOTE: signature changed from analyzeImage(InputImage) to
  /// analyzeImage(File) -- mediapipe_face_mesh needs raw decoded pixels,
  /// not ML Kit's InputImage wrapper, so the caller needs a one-line
  /// update to pass the File/path it already has instead of building an
  /// InputImage first.
  Future<DeconstructedData?> analyzeImage(File imageFile) async {
    if (!_initialized) await initialize();

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // Force RGBA byte order/no palette, matching what FaceMeshImage
    // expects for a decoded-image input.
    final rgba = decoded.convert(numChannels: 4);
    final width = rgba.width;
    final height = rgba.height;

    final meshImage = FaceMeshImage(
      pixels: rgba.getBytes(order: img.ChannelOrder.rgba),
      width: width,
      height: height,
    );

    final result = _pipeline!.process(meshImage);
    final meshResult = result.meshResult;
    if (meshResult == null) return null;

    final List<Offset> meshPoints = meshResult.landmarks
        .map((lm) => Offset(lm.x * width, lm.y * height))
        .toList();

    final geometry = meshResult.estimateGeometry();
    final pose = geometry.headPose;
    final double roll = pose.rollDegrees * pi / 180.0;
    final double pitch = pose.pitchDegrees * pi / 180.0;
    final double yaw = pose.yawDegrees * pi / 180.0;

    // --- Cranial circle: Ported from arthaven.py ---
    // Uses specific landmark vertical spans to find a perfect circle for
    // front-facing photos, instead of a mesh-wide bounding box.
    const double topOfHeadExtra = 2.2;
    const double bottomMargin = 0.0;

    final browYForHead = (meshPoints[105].dy + meshPoints[334].dy) / 2;
    final browToHairline = browYForHead - meshPoints[10].dy;
    final topOfHeadY = meshPoints[10].dy - (browToHairline * topOfHeadExtra);

    final lipMidY = (meshPoints[13].dy + meshPoints[14].dy) / 2;
    final faceCenterX = (meshPoints[454].dx + meshPoints[234].dx) / 2;

    final rawSpan = lipMidY - topOfHeadY;
    final sphereDiameter = rawSpan / (1 - bottomMargin);
    final sphereRadius = sphereDiameter / 2;
    final sphereCenterY = topOfHeadY + sphereRadius;

    final Rect cranialRect = Rect.fromCenter(
      center: Offset(faceCenterX, sphereCenterY),
      width: sphereDiameter,
      height: sphereDiameter,
    );

    // --- Additional 2D Guides: Ported from arthaven.py ---
    final double browY = browYForHead;
    final double noseY = meshPoints[1].dy;
    final double chinY = meshPoints[152].dy;

    const double crownToBrowLineRatio = 0.5;
    final double crownY = sphereCenterY - sphereRadius;
    final double hairlineY = crownY + (browY - crownY) * crownToBrowLineRatio;

    final double leftSideX = meshPoints[234].dx;
    final double rightSideX = meshPoints[454].dx;

    const double sideLineTopMargin = 0.15;
    final double sideTopY = crownY - (sphereRadius * sideLineTopMargin);
    final double sideBottomY = chinY;

    // Pose detection is untouched -- still ML Kit, still fed the same
    // file path it always was.
    final poseInputImage = InputImage.fromFilePath(imageFile.path);
    final poses = await _poseDetector.processImage(poseInputImage);
    final pose_ = poses.isNotEmpty ? poses.first : null;

    // --- Ear Parsing (BiSeNet ONNX): Ported from arthaven.py ---
    // Resizes the photo to 512x512 and runs the parsing model to extract
    // precise ear outlines, matching the Colab's Cell 13 logic.
    final earContours = <List<Offset>>[];
    try {
      final resized = img.copyResize(decoded, width: 512, height: 512);
      const mean = [0.485, 0.456, 0.406];
      const std = [0.229, 0.224, 0.225];
      final input = Float32List(1 * 3 * 512 * 512);
      int idx = 0;
      for (int c = 0; c < 3; c++) {
        for (int y = 0; y < 512; y++) {
          for (int x = 0; x < 512; x++) {
            final pixel = resized.getPixel(x, y);
            final raw = c == 0 ? pixel.r : (c == 1 ? pixel.g : pixel.b);
            input[idx++] = (raw / 255.0 - mean[c]) / std[c];
          }
        }
      }

      final inputTensor = await OrtValue.fromList(input, [1, 3, 512, 512]);
      final inputName = _earParsingSession!.inputNames[0];
      final outputName = _earParsingSession!.outputNames[0];

      final outputs = await _earParsingSession!.run({inputName: inputTensor});
      final rawOutput = await outputs[outputName]!.asList();
      inputTensor.dispose();
      for (final t in outputs.values) {
        t.dispose();
      }

      // Flatten and extract masks:
      // Ear mask (classes 7=L_EAR, 8=R_EAR)
      // Hair mask (class 17)
      final outputData = _flattenToDoubles(rawOutput);
      const numClasses = 19;
      const size = 512;
      const planeSize = size * size;
      final earBoolMask = List.generate(size, (_) => List<bool>.filled(size, false));
      final hairBoolMask = List.generate(size, (_) => List<bool>.filled(size, false));

      for (int p = 0; p < planeSize; p++) {
        double best = double.negativeInfinity;
        int bestClass = 0;
        for (int c = 0; c < numClasses; c++) {
          final v = outputData[c * planeSize + p];
          if (v > best) {
            best = v;
            bestClass = c;
          }
        }
        if (bestClass == 7 || bestClass == 8) {
          earBoolMask[p ~/ size][p % size] = true;
        } else if (bestClass == 17) {
          hairBoolMask[p ~/ size][p % size] = true;
        }
      }

      final rawEarContours = EarContourExtractor.extractAllRadialPoints(
        mask: earBoolMask,
        minBlobSize: 40,
        numSamples: 12, // 30-degree intervals as suggested
      );

      final rawHairContours = EarContourExtractor.extractAllSimplifiedPoints(
        mask: hairBoolMask,
        minBlobSize: 100, // Avoid tiny stray blobs for hair
        simplifyEpsilon: 0.2, // Near-zero epsilon for raw silhouette accuracy
      );

      final scaleX = width / 512.0;
      final scaleY = height / 512.0;

      for (final rawContour in rawEarContours) {
        earContours.add(rawContour.map((p) => Offset(p.dx * scaleX, p.dy * scaleY)).toList());
      }

      final hairContours = <List<Offset>>[];
      for (final rawContour in rawHairContours) {
        hairContours.add(rawContour.map((p) => Offset(p.dx * scaleX, p.dy * scaleY)).toList());
      }

      return DeconstructedData(
        cranialRect: cranialRect,
        headRoll: roll,
        headPitch: pitch,
        headYaw: yaw,
        faceCenter: cranialRect.center,
        hairlineY: hairlineY,
        browY: browY,
        noseY: noseY,
        chinY: chinY,
        leftSideX: leftSideX,
        rightSideX: rightSideX,
        sideTopY: sideTopY,
        sideBottomY: sideBottomY,
        earContours: earContours,
        hairContours: hairContours,
        meshPoints: meshPoints,
        poseLandmarks: pose_?.landmarks ?? {},
      );
    } catch (e) {
      debugPrint('Ear/Hair parsing failed: $e');
    }

    return DeconstructedData(
      cranialRect: cranialRect,
      headRoll: roll,
      headPitch: pitch,
      headYaw: yaw,
      faceCenter: cranialRect.center,
      hairlineY: hairlineY,
      browY: browY,
      noseY: noseY,
      chinY: chinY,
      leftSideX: leftSideX,
      rightSideX: rightSideX,
      sideTopY: sideTopY,
      sideBottomY: sideBottomY,
      earContours: earContours,
      hairContours: const [],
      meshPoints: meshPoints,
      poseLandmarks: pose_?.landmarks ?? {},
    );
  }

  /// Recursively flattens a possibly nested List into a flat double list.
  List<double> _flattenToDoubles(dynamic data) {
    final result = <double>[];
    void walk(dynamic value) {
      if (value is List) {
        for (final item in value) {
          walk(item);
        }
      } else if (value is num) {
        result.add(value.toDouble());
      }
    }
    walk(data);
    return result;
  }

  void dispose() {
    _faceDetectorProcessor?.close();
    _faceMeshProcessor?.close();
    _earParsingSession?.close();
    _poseDetector.close();
  }

  /// Kept for backward compatibility with the old ML Kit-based grid
  /// helper -- now takes the cranial Rect directly instead of an ML Kit
  /// Face object, since that type no longer flows through this class.
  /// Superseded by the real mesh-derived guides for anything that needs
  /// actual facial-feature positions; this stays as a coarse 4x4 grid
  /// utility only.
  List<Offset> calculateMeshVertices(Rect box) {
    final double topY = box.top;
    final double browY = box.top + (box.height * 0.33);
    final double noseY = box.top + (box.height * 0.66);
    final double chinY = box.bottom;

    final double leftX = box.left;
    final double midLeftX = box.left + (box.width * 0.33);
    final double midRightX = box.left + (box.width * 0.66);
    final double rightX = box.right;

    return [
      Offset(leftX, topY), Offset(midLeftX, topY), Offset(midRightX, topY), Offset(rightX, topY),
      Offset(leftX, browY), Offset(midLeftX, browY), Offset(midRightX, browY), Offset(rightX, browY),
      Offset(leftX, noseY), Offset(midLeftX, noseY), Offset(midRightX, noseY), Offset(rightX, noseY),
      Offset(leftX, chinY), Offset(midLeftX, chinY), Offset(midRightX, chinY), Offset(rightX, chinY),
    ];
  }
}