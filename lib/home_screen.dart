import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'services/shape_detector.dart';
import 'services/sketch_service.dart';
import 'models/sketch.dart';
import 'walkthrough_screen.dart';

/// Centralized style constants for the Home Screen.
/// Edit these values to change colors, sizes, and text across the page.
class _HomeScreenStyle {
  // --- Colors ---
  static const Color pageBackground = Color(0xFF271131); // Dark purple background
  static const Color headerBackground = Color(0xFFBF78D9); // Purple header
  static const Color uploadBoxOuterBg = pageBackground; // Upload box container background
  static const Color uploadBoxBorderColor = Color(0xFF78488D); // Border color for upload box
  static const Color uploadBoxIconCircle = Color(0xFF78488D); // Upload badge background (#78488D)
  static const Color uploadBadgeBorderColor = Color(0xFFC983E3); // Upload badge border (#C983E3)
  static const Color sectionTitleColor = Color(0xFFA599AB);
  static const Color cardBorderColor = Colors.white;
  static const Color emptyStateBg = Color(0xFFA599AB); // Background color for empty state box
  static const Color emptyStateIconColor = emptyStateBg; // New constant: icon color for empty state box
  static const Color coinPillColor = Color(0xFF3A1E42); // Darker purple for coin counter
  static const Color plusButtonColor = Color(0xFF3A1E42); // Plus button background
  static const Color coinIconColor = Color(0xFFA44D37); // Coin fill #A44D37
  static const Color coinIconBorderColor = Color(0xFFCA7B65); // Coin border #CA7B65
  static const double coinIconSize = 20.0;
  static const double coinIconBorderSize = 5.0; // Increased coin border thickness
  static const double uploadBadgeBorderWidth = 5.0; // Increased upload badge border thickness

  // --- Dimensions ---
  static const double headerPaddingTop = 100.0; // Increased to shift ArtHaven down further
  static const double headerPaddingBottom = 25.0; // Reduced to be closer to upload button
  static const double cornerRadiusLarge = 24.0;
  static const double cardBorderWidth = 3.0;
  static const double cardWidth = 345.0; // New constant: fixed width for sketch cards
  static const double cardHeight = 100.0; // New constant: fixed height for sketch cards
  static const double progressBarHeight = 10.0;

  // --- Dash Patterns [dash length, gap length] ---
  static const List<double> cardDashPattern = [20, 10];
  static const List<double> emptyStateDashPattern = [20, 10];

  // --- Text Styles ---
  static const String titlePart1 = 'Art';
  static const String titlePart2 = 'Haven';
  static const String uploadTitle = 'upload a photo';
  static const String uploadSubtitle = 'snap or pick a drawing';
  static const String sectionTitle = 'RECENT SKETCHES';
  static const String emptyStateTitle = 'No Sketches';
  static const String emptyStateSubtitle = 'upload a picture to get started';
  static const double headerTitleToUploadSpacing = 12.0; // Distance between title and upload button
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  final LocalShapeDetector _detector = LocalShapeDetector();
  final SketchService _sketchService = SketchService();

  @override
  void initState() {
    super.initState();
    _detector.initialize();
    _sketchService.addListener(_onSketchesUpdated);

  }

  @override
  void dispose() {
    _detector.dispose();
    _sketchService.removeListener(_onSketchesUpdated);
    super.dispose();
  }

  void _onSketchesUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _pickAndUploadImage() async {
    if (_sketchService.coins < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need 10 coins to start a new sketch.'),
          duration: Duration(seconds: 2),
        ),
      );
      _showCoinShopDialog();
      return;
    }

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isLoading = true);
    try {
      final file = File(picked.path);
      final decodedImage = await decodeImageFromList(await file.readAsBytes());
      final imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

      final result = await _detector.analyzeImage(file);
      if (result != null) {
        _sketchService.deductCoins(10);

        final newSketch = Sketch(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Untitled Sketch ${_sketchService.sketches.length + 1}',
          imageFile: file,
          data: result,
          imageSize: imageSize,
          themeColor: const Color(0xFF93E6CA), // Latest sketch is green
        );

        _sketchService.addSketch(newSketch);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WalkthroughScreen(
                imageFile: file,
                data: result,
                imageSize: imageSize,
                sketchId: newSketch.id,
                initialStep: 1,
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No face detected — try another photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resumeSketch(Sketch sketch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkthroughScreen(
          imageFile: sketch.imageFile,
          data: sketch.data,
          imageSize: sketch.imageSize,
          sketchId: sketch.id,
          initialStep: sketch.currentStep,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter out completed sketches (currentStep >= 16)
    final sketches = _sketchService.sketches.where((s) => s.currentStep < 16).toList();

    return Scaffold(
      backgroundColor: _HomeScreenStyle.pageBackground,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16), // Padding above title
                  Text(
                    _HomeScreenStyle.sectionTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: _HomeScreenStyle.sectionTitleColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (sketches.isEmpty) 
                    Center(child: _buildEmptyState())
                  else
                    ...List.generate(sketches.length, (index) {
                      return Center(child: _buildSketchCard(sketches[index], index: index, showBorder: index == 0));
                    }),
                ],
              ),
            ),
          ),
          // Peacock widget with tap animation and speech bubbles
          const PeacockWidget(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: _HomeScreenStyle.headerPaddingTop, 
        bottom: _HomeScreenStyle.headerPaddingBottom, 
        left: 24, 
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: _HomeScreenStyle.headerBackground,
        image: DecorationImage(
          image: AssetImage('assets/header_banner.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 32,
                    color: _HomeScreenStyle.pageBackground,
                  ),
                  children: const [
                    TextSpan(
                      text: _HomeScreenStyle.titlePart1,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: _HomeScreenStyle.titlePart2,
                      style: TextStyle(fontWeight: FontWeight.w300), // Lighter Haven
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildCoinCounter(),
                  const SizedBox(width: 8),
                  _buildPlusButton(),
                ],
              ),
            ],
          ),
          SizedBox(height: _HomeScreenStyle.headerTitleToUploadSpacing),
          _buildUploadButton(),
        ],
      ),
    );
  }

  Widget _buildCoinCounter() {
    return ListenableBuilder(
      listenable: _sketchService,
      builder: (context, _) {
        final bool isLifetime = _sketchService.coins >= 999999;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _HomeScreenStyle.coinPillColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLifetime ? '∞' : '${_sketchService.coins}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isLifetime ? 20 : 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: _HomeScreenStyle.coinIconSize,
                height: _HomeScreenStyle.coinIconSize,
                decoration: BoxDecoration(
                  color: isLifetime ? const Color(0xFFB88A2E) : _HomeScreenStyle.coinIconColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isLifetime ? const Color(0xFFE3BA48) : _HomeScreenStyle.coinIconBorderColor,
                    width: _HomeScreenStyle.coinIconBorderSize,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _buyProductPackage({
    required String productId,
    required int coinAmount,
    required String label,
  }) async {
    try {
      final offerings = await Purchases.getOfferings();

      Package? matchedPackage;
      if (offerings.current != null) {
        for (final p in offerings.current!.availablePackages) {
          if (p.storeProduct.identifier == productId || p.identifier == productId) {
            matchedPackage = p;
            break;
          }
        }
      }
      if (matchedPackage == null) {
        for (final offering in offerings.all.values) {
          for (final p in offering.availablePackages) {
            if (p.storeProduct.identifier == productId || p.identifier == productId) {
              matchedPackage = p;
              break;
            }
          }
          if (matchedPackage != null) break;
        }
      }

      final package = matchedPackage ??
          offerings.current?.availablePackages.firstOrNull ??
          (offerings.all.isNotEmpty
              ? offerings.all.values.first.availablePackages.firstOrNull
              : null);

      if (package != null) {
        await Purchases.purchasePackage(package);
      }

      _sketchService.claimReward(coinAmount);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label Unlocked!')),
        );
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return; // user backed out — no error needed
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase failed. Please try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase failed. Please try again.')),
        );
      }
    }
  }

  void _showCoinShopDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7FC),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF683282),
                width: 7,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 32,
                      color: Color(0xFF230F30),
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'Coin',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ' Shop',
                        style: TextStyle(fontWeight: FontWeight.w300),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Row 1: 10 Coins ($1.99)
                GestureDetector(
                  onTap: () => _buyProductPackage(
                    productId: 'buy10',
                    coinAmount: 10,
                    label: '10 Coins',
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.only(left: 66, right: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF641882),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '\$1.99',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 14,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA44D37),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFCA7B65),
                                width: 8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '10',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Row 2: 30 Coins ($4.99) - Flipped Layout
                GestureDetector(
                  onTap: () => _buyProductPackage(
                    productId: 'buy30',
                    coinAmount: 30,
                    label: '30 Coins',
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.only(left: 20, right: 66),
                          decoration: BoxDecoration(
                            color: const Color(0xFF641882),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                '\$4.99',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 14,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA44D37),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFCA7B65),
                                width: 8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '30',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Row 3: Lifetime Access / Infinity ($19.99)
                GestureDetector(
                  onTap: () => _buyProductPackage(
                    productId: 'buylifetime',
                    coinAmount: 999999,
                    label: 'Lifetime Access',
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.only(left: 66, right: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF641882),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '\$19.99',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 14,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFFB88A2E),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE3BA48),
                                width: 8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Transform.translate(
                              offset: const Offset(0, -3),
                              child: const Text(
                                '∞',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlusButton() {
    return GestureDetector(
      onTap: _showCoinShopDialog,
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: _HomeScreenStyle.plusButtonColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _pickAndUploadImage,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _HomeScreenStyle.uploadBoxOuterBg,
          border: Border.all(color: _HomeScreenStyle.uploadBoxBorderColor, width: 7), // Added requested border
          borderRadius: BorderRadius.circular(_HomeScreenStyle.cornerRadiusLarge),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_HomeScreenStyle.cornerRadiusLarge),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _HomeScreenStyle.uploadBoxIconCircle,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _HomeScreenStyle.uploadBadgeBorderColor,
                    width: _HomeScreenStyle.uploadBadgeBorderWidth,
                  ),
                ),
                alignment: Alignment.center,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '10',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _HomeScreenStyle.uploadTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _HomeScreenStyle.uploadSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSketchCard(Sketch sketch, {required int index, required bool showBorder}) {
    final bool isGreen = index == 0;
    final Color themeColor = isGreen ? const Color(0xFF93E6CA) : const Color(0xFF93A2E6);
    final Color progressColor = isGreen ? const Color(0xFF2D5C4A) : const Color(0xFF24224C);
    final Color stepTextColor = isGreen ? const Color(0xFF3C6154) : const Color(0xFF454B78);
    final Color coinBorderColor = isGreen ? const Color(0xFF386758) : const Color(0xFF383A67);

    final double screenWidth = MediaQuery.of(context).size.width;
    final double maxCardWidth = min(_HomeScreenStyle.cardWidth, screenWidth - 48); // Account for screen padding

    Widget cardContent = Container(
      width: maxCardWidth, // Use responsive width
      height: _HomeScreenStyle.cardHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: themeColor,
        borderRadius: BorderRadius.circular(_HomeScreenStyle.cornerRadiusLarge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically in Row
        children: [
          Container(
            width: 57,
            height: 57,
            decoration: BoxDecoration(
              color: progressColor, // Fill color matches progress fill bar color
              shape: BoxShape.circle,
              border: Border.all(
                color: coinBorderColor, // Border color #383A67
                width: 7,
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              '+2',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center text vertically
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Take only needed height
              children: [
                Text(
                  sketch.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'step ${sketch.currentStep} of 8',
                  style: TextStyle(
                    fontSize: 12,
                    color: stepTextColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildProgressBar(sketch.currentStep / 8, progressColor),
              ],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => _resumeSketch(sketch),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: showBorder
            ? DottedBorder(
                options: RoundedRectDottedBorderOptions(
                  radius: const Radius.circular(_HomeScreenStyle.cornerRadiusLarge),
                  dashPattern: _HomeScreenStyle.cardDashPattern,
                  color: _HomeScreenStyle.cardBorderColor,
                  strokeWidth: _HomeScreenStyle.cardBorderWidth,
                ),
                child: cardContent,
              )
            : cardContent,
      ),
    );
  }

  Widget _buildProgressBar(double progress, Color color) {
    return Container(
      height: _HomeScreenStyle.progressBarHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(_HomeScreenStyle.progressBarHeight / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(_HomeScreenStyle.progressBarHeight / 2),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double maxCardWidth = min(_HomeScreenStyle.cardWidth, screenWidth - 48);

    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: const Radius.circular(_HomeScreenStyle.cornerRadiusLarge),
        dashPattern: _HomeScreenStyle.emptyStateDashPattern, // Customizable dash pattern
        color: _HomeScreenStyle.cardBorderColor,
        strokeWidth: _HomeScreenStyle.cardBorderWidth,
      ),
      child: Container(
        width: maxCardWidth, // Use responsive width
        height: _HomeScreenStyle.cardHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _HomeScreenStyle.emptyStateBg,
          borderRadius: BorderRadius.circular(_HomeScreenStyle.cornerRadiusLarge),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF130E1F),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '?',
                style: TextStyle(
                  color: _HomeScreenStyle.emptyStateIconColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _HomeScreenStyle.emptyStateTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _HomeScreenStyle.pageBackground, // Title matches background color
                    ),
                  ),
                  const Text(
                    _HomeScreenStyle.emptyStateSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: _HomeScreenStyle.pageBackground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PeacockWidget extends StatefulWidget {
  const PeacockWidget({super.key});

  @override
  State<PeacockWidget> createState() => _PeacockWidgetState();
}

class _PeacockWidgetState extends State<PeacockWidget> {
  final List<String> _messages = [
    "hey, I'm Loomi!",
    "finish sketches to earn coins.",
    "start with a ball. every head does.",
    "wobbly lines are totally fine.",
    "squint at your photo to see the big shapes.",
    "slow down. nobody's timing you.",
    "every artist's first sketch looks rough.",
    "dashed lines show ideal proportions, solid lines come from your photo.",
    "try a new face today!",
    "big shapes first. details come last.",
    "step back from your page every now and then.",
    "a crooked circle still works. keep going!",
    "practice pays for more practice.",
    "compare your sketch to your last one, not a pro's.",
    "a little drawing every day adds up fast!",
    "keep your pencil moving. hesitation makes shaky lines.",
    "every face is different. that's what makes it fun!",
    "finished a sketch? that's a win.",
  ];

  late String _currentMessage;
  double _alignmentX = 0.0;
  double _opacity = 1.0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _pickNewRandomState();
  }

  void _pickNewRandomState() {
    _currentMessage = _messages[_random.nextInt(_messages.length)];
    // Random alignment X between -0.6 and 0.6 so it stays within screen bounds
    _alignmentX = _random.nextDouble() * 1.2 - 0.6;
  }

  Future<void> _onTap() async {
    setState(() {
      _opacity = 0.0;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    setState(() {
      _pickNewRandomState();
      _opacity = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment(_alignmentX, 0.0),
            child: AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 200),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                child: CustomPaint(
                  painter: SpeechBubblePainter(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                    child: Text(
                      _currentMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF271131),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Image.asset(
            'assets/peacock.png',
            width: double.infinity,
            fit: BoxFit.fitWidth,
          ),
        ],
      ),
    );
  }
}

class SpeechBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E2E2)
      ..style = PaintingStyle.fill;

    final path = Path();
    final double radius = 24.0;
    final double tailWidth = 16.0;
    final double tailHeight = 10.0;

    // Rounded rectangle rect for bubble body
    final rect = Rect.fromLTWH(0, 0, size.width, size.height - tailHeight);
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    path.addRRect(rRect);

    // Tail (triangle pointing down at bottom center)
    final double centerX = size.width / 2;
    path.moveTo(centerX - tailWidth / 2, size.height - tailHeight);
    path.lineTo(centerX, size.height);
    path.lineTo(centerX + tailWidth / 2, size.height - tailHeight);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
