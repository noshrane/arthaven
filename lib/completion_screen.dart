import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/sketch_service.dart';

/// Centralized style constants for the Completion Screen.
class _CompletionScreenStyle {
  static const Color backgroundColor = Color(0xFF130E1F); // Dark navy/purple
  static const Color primaryPurple = Color(0xFFBF78D9); // Vibrant purple
  static const Color buttonColor = Color(0xFFC77DDE); // Button purple
  static const Color textColor = Colors.white70;
  static const double imageSize = 180.0;
  static const double buttonHeight = 56.0;
}

class CompletionScreen extends StatefulWidget {
  final String? sketchId;
  const CompletionScreen({super.key, this.sketchId});

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
  @override
  void initState() {
    super.initState();
    _triggerCelebrationVibration();
  }

  Future<void> _triggerCelebrationVibration() async {
    for (int i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 70));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _CompletionScreenStyle.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Peacock Image
              Image.asset(
                'assets/peacock-only.png',
                height: _CompletionScreenStyle.imageSize,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 60),
              // Main Title
              const Text(
                'Amazing job!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _CompletionScreenStyle.primaryPurple,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Subtitle
              const Text(
                'You’ve successfully completed a sketch.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _CompletionScreenStyle.textColor,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              // Claim Coins Button
              SizedBox(
                width: double.infinity,
                height: _CompletionScreenStyle.buttonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    _triggerCelebrationVibration();
                    // Claim reward (+2 coins)
                    SketchService().claimReward(2);
                    // Return to home
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _CompletionScreenStyle.buttonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'CLAIM COINS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
