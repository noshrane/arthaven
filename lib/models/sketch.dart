import 'dart:io';
import 'package:flutter/material.dart';
import '../services/shape_detector.dart';

class Sketch {
  final String id;
  String name;
  final File imageFile;
  final DeconstructedData data;
  final Size imageSize;
  int currentStep;
  final Color themeColor;

  Sketch({
    required this.id,
    required this.name,
    required this.imageFile,
    required this.data,
    required this.imageSize,
    this.currentStep = 1,
    required this.themeColor,
  });
}
