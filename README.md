# ArtHaven

Learn to draw faces with the Loomis method. Pick a photo and ArtHaven builds a
step-by-step construction guide from the face's own landmarks. Everything runs
on-device, so your photos never leave your phone.

Built for the Shipaton 2026 Next Gen Award.
Demo video: [YouTube link]

## Key Features

### 1. Guided Sketching Walkthrough
- **Step-by-Step Breakdown:** Breaks down portrait sketching into structured steps (from foundational spheres and big shapes to detailed features).
- **Dual Guidance Lines:** Dashed lines indicate ideal anatomical proportions, while solid lines reflect features directly derived from your source photo.
- **Progress Tracking:** Tracks your progress across steps and awards coins upon completion.

### 2. AI Face & Shape Detection
- Integrates local shape and facial landmark detection (`LocalShapeDetector`) to analyze user-uploaded photos.
- Automatically extracts facial features, head proportions, and structure to generate customized sketching guides.

### 3. Loomi the Peacock Assistant 
- An interactive assistant residing at the bottom of the home screen.
- **Interactive Speech Bubbles:** Tapping Loomi fades in a randomized tip, greeting, or encouragement from a curated collection of artist wisdom ("hey, I'm Loomi!", "start with a ball. every head does.", "big shapes first. details come last.", etc.).
- **Dynamic Positioning:** Speech bubbles feature a custom speech bubble tail and randomly shift horizontal positions with a smooth fade-in animation on every tap.

### 4. Coin Economy & Shop
- **Coin Balance:** Users start with an initial coin balance to initiate sketches (10 coins per new sketch).
- **Rewards:** Finish sketches to earn coin rewards (+2 coins per step/milestone).
- **Coin Shop:** Powered by RevenueCat and Google Play Billing, allowing users to purchase coin bundles ($1.99, $4.99) or unlock Lifetime Access (Infinity `∞`) for unlimited sketching.

### 5. Adaptive Sketch Cards Dashboard
- Displays recent unfinished sketches with live progress bars, step counters, and dynamic theme colors:
  - **Latest Sketch:** Highlighted in Mint Green (`#93E6CA`).
  - **Older Unfinished Sketches:** Styled in Periwinkle Blue (`#93A2E6`).
- Completed sketches (16/16 steps) transition out of the active list.

---

## Project Architecture

```tree
lib/
├── main.dart               # App entry point & initialization
├── home_screen.dart        # Dashboard, coin counter, recent sketches, & Loomi widget
├── walkthrough_screen.dart # Interactive step-by-step sketching workflow
├── completion_screen.dart  # Sketch completion & reward celebration screen
├── models/
│   └── sketch.dart         # Data model representing a user sketch
├── services/
│   ├── shape_detector.dart # Face, pose, and shape analysis service
│   └── sketch_service.dart # State management (`ChangeNotifier`) & SharedPreferences storage
├── painters/
│   └── artist_painter.dart # Custom painters for rendering guidance lines & overlays
└── utils/
    ├── ear_contour.dart
    ├── face_feature_math.dart
    ├── neck_math.dart
    ├── rough_guide_renderer.dart
    └── sphere_math.dart
```

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (SDK version ^3.12.2 or higher)
- Android Studio / VS Code with Flutter & Dart plugins

### Installation & Running
1. Clone the repository or open the project folder in Android Studio.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app on an emulator or connected device:
   ```bash
   flutter run
   ```

---

## Versioning & Configuration
- **Package Name:** `com.rain.arthaven`
- **Version:** `1.0.1+6`
- **Billing Permission:** Configured with `com.android.vending.BILLING` in `AndroidManifest.xml`.
