import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dotted_border/dotted_border.dart';
import 'services/shape_detector.dart';
import 'painters/artist_painter.dart';

import 'services/sketch_service.dart';
import 'completion_screen.dart';

class WalkthroughScreen extends StatefulWidget {
  final File imageFile;
  final DeconstructedData data;
  final Size imageSize;
  final String? sketchId;
  final int initialStep;

  const WalkthroughScreen({
    super.key,
    required this.imageFile,
    required this.data,
    required this.imageSize,
    this.sketchId,
    this.initialStep = 1,
  });

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  late int _currentStep;
  static const int _totalSteps = 16;
  String _sketchName = 'Untitled Sketch';

  bool _showReferenceImage = false;

  // Style Variables
  final Color _headerBgColor = Colors.white;
  final Color _progressBarBgColor = const Color(0xFFD8B4E2); // Light purple
  final Color _progressBarFillColor = const Color(0xFF3F224C); // Dark purple
  final Color _navButtonColor = const Color(0xFFC77DDE);
  final Color _primaryDarkColor = const Color(0xFF3F224C);
  
  final double _progressBarHeight = 18.0;
  final double _bannerTopPadding = 50.0;
  final double _bannerBottomPadding = 20.0;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    
    // Find the sketch name
    if (widget.sketchId != null) {
      final sketch = SketchService().sketches.firstWhere(
        (s) => s.id == widget.sketchId,
        orElse: () => SketchService().sketches.first, // Fallback
      );
      _sketchName = sketch.name;
    }
  }

  void _updateProgress() {
    if (widget.sketchId != null) {
      SketchService().updateSketchStep(widget.sketchId!, _currentStep);
    }
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _sketchName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Sketch'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                setState(() => _sketchName = newName);
                if (widget.sketchId != null) {
                  SketchService().renameSketch(widget.sketchId!, newName);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 12),
              child: Column(
                children: [
                  _buildStepIndicator(),
                  const SizedBox(height: 16),
                  _buildDrawingArea(),
                  if (_currentStep == 16) ...[
                    const SizedBox(height: 12),
                    _buildReferenceToggle(),
                  ],
                  const SizedBox(height: 16),
                  _buildInstructions(),
                  const SizedBox(height: 20),
                  _buildTipBox(),
                ],
              ),
            ),
          ),
          _buildNextButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: _bannerTopPadding,
        bottom: _bannerBottomPadding,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: _headerBgColor,
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(Icons.chevron_left, size: 28, color: _primaryDarkColor),
                  onPressed: () {
                    _updateProgress();
                    Navigator.pop(context);
                  },
                ),
              ),
              GestureDetector(
                onTap: _showRenameDialog,
                child: Text(
                  _sketchName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Thick Progress Bar
          Container(
            height: _progressBarHeight,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _progressBarBgColor,
              borderRadius: BorderRadius.circular(_progressBarHeight / 2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _currentStep / _totalSteps,
              child: Container(
                decoration: BoxDecoration(
                  color: _progressBarFillColor,
                  borderRadius: BorderRadius.circular(_progressBarHeight / 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _navButtonColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$_currentStep',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDrawingArea() {
    final Rect sketchBounds = ArtistPainter.getSketchBounds(widget.data, widget.imageSize);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9), // Grey background
        borderRadius: BorderRadius.circular(24),
        image: (_showReferenceImage && _currentStep == 16)
            ? DecorationImage(
                image: FileImage(widget.imageFile),
                fit: BoxFit.cover,
                opacity: 0.6, // Slight opacity to make sketch visible
              )
            : null,
      ),
      child: AspectRatio(
        aspectRatio: sketchBounds.width / sketchBounds.height,
        child: CustomPaint(
          painter: ArtistPainter(
            data: widget.data,
            originalImageSize: widget.imageSize,
            walkthroughStep: _currentStep,
            showOriginalImage: _showReferenceImage,
          ),
        ),
      ),
    );
  }

  Widget _buildReferenceToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Show Reference Photo',
          style: TextStyle(
            color: _primaryDarkColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: _showReferenceImage,
          activeTrackColor: _navButtonColor,
          onChanged: (val) {
            HapticFeedback.selectionClick();
            setState(() => _showReferenceImage = val);
          },
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    String mainText = 'Draw the ';
    String boldText = 'cranium';

    if (_currentStep == 2) {
      mainText = 'Draw the ';
      boldText = 'biggest square possible';
    } else if (_currentStep == 3) {
      mainText = 'Compare with ';
      boldText = 'real proportions';
    } else if (_currentStep == 4) {
      mainText = 'Draw the ';
      boldText = 'jawline';
    } else if (_currentStep == 5) {
      mainText = 'Compare with ';
      boldText = 'real jawline';
    } else if (_currentStep == 6) {
      mainText = 'Outline the ';
      boldText = 'brows';
    } else if (_currentStep == 7) {
      mainText = 'Draw the ';
      boldText = 'nose structure';
    } else if (_currentStep == 8) {
      mainText = 'Compare with ';
      boldText = 'nose bridge and base';
    } else if (_currentStep == 9) {
      mainText = 'Draw circles for the ';
      boldText = 'lips structure';
    } else if (_currentStep == 10) {
      mainText = 'Outline the ';
      boldText = 'lips';
    } else if (_currentStep == 11) {
      mainText = 'Draw the ';
      boldText = 'eye pupils';
    } else if (_currentStep == 12) {
      mainText = 'Outline the ';
      boldText = 'eyes';
    } else if (_currentStep == 13) {
      mainText = 'Draw the ';
      boldText = 'approximate ears';
    } else if (_currentStep == 14) {
      mainText = 'Compare with ';
      boldText = 'real ear shapes';
    } else if (_currentStep == 15) {
      mainText = 'Draw the ';
      boldText = 'hair outline';
    } else if (_currentStep == 16) {
      mainText = 'Polish the ';
      boldText = 'final details';
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(fontSize: 28, color: Colors.black),
        children: [
          TextSpan(text: mainText),
          TextSpan(
            text: boldText,
            style: TextStyle(fontWeight: FontWeight.bold, color: _navButtonColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTipBox() {
    String tipText = 'keep lines light - you\'ll refine them later';
    if (_currentStep == 3) {
      tipText = 'The dotted lines show where the real features lie. This particular face measures a bit differently - you can adjust your lines, or keep practicing with the standard guide.';
    } else if (_currentStep == 4) {
      tipText = 'Connect the sides of the head to the jaw and chin using straight, confident lines. This creates a solid structural base for the lower face.';
    } else if (_currentStep == 5) {
      tipText = 'The dotted lines show your actual jaw and chin shape. You can choose to adjust your sketch for more accuracy or move on to the next step.';
    } else if (_currentStep == 6) {
      tipText = 'Draw the simple outline of the brows. Use the horizontal brow line to ensure they are positioned correctly and balanced.';
    } else if (_currentStep == 7) {
      tipText = 'Draw the three circles of the nose: one for the tip and two smaller ones for the nostrils. Use the vertical guidelines to keep the width accurate relative to the face.';
    } else if (_currentStep == 8) {
      tipText = 'Connect the bridge to the nostrils and refine the bottom edge. Notice how the three circles guide the shape of the nose tip and wings.';
    } else if (_currentStep == 9) {
      tipText = 'Draw three circles to estimate the size and placement of both upper and lower lips. This builds a proportional base for the mouth.';
    } else if (_currentStep == 10) {
      tipText = 'Use the circles to guide you in drawing the lips, following the natural curves and the mouth line between them.';
    } else if (_currentStep == 11) {
      tipText = 'Draw a circle to represent the iris and pupil. Some of it might be covered by the eyelid, but the structure remains a full circle.';
    } else if (_currentStep == 12) {
      tipText = 'Try to follow the eye shape as closely as possible, using the pupils as a guide for placement.';
    } else if (_currentStep == 13) {
      tipText = 'Ears typically sit on the sides of the head between the brow and nose lines. Sketch them symmetrically to establish their position.';
    } else if (_currentStep == 14) {
      tipText = 'Compare your sketch with the exact ear outlines detected from the photo. Notice any differences in tilt or size.';
    } else if (_currentStep == 15) {
      tipText = 'Note the hairline guideline. Draw an approximate outline, paying attention to the space between the outer edge of the hair and the skull or ears.';
    } else if (_currentStep == 16) {
      tipText = 'Now, erase your guidelines and circles. Focus on adding fine details like eyelid creases and defining the eye corners.';
    }

    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: const Radius.circular(16),
        dashPattern: const [6, 3],
        color: Colors.black26,
        strokeWidth: 1,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EBF9), // Light purple background
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _primaryDarkColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                tipText,
                style: TextStyle(color: _primaryDarkColor, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          // Back Button
          if (_currentStep > 1)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 60,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _currentStep--);
                    _updateProgress();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navButtonColor.withValues(alpha: 0.2),
                    foregroundColor: _navButtonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.chevron_left, size: 32),
                ),
              ),
            ),
          // Next Button
          Expanded(
            child: SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  if (_currentStep < _totalSteps) {
                    HapticFeedback.mediumImpact();
                    setState(() => _currentStep++);
                    _updateProgress();
                  } else {
                    HapticFeedback.heavyImpact();
                    HapticFeedback.vibrate();
                    // Navigate to CompletionScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CompletionScreen(sketchId: widget.sketchId),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navButtonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _currentStep == _totalSteps ? 'COMPLETE' : 'NEXT STEP',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
