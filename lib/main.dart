import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'home_screen.dart';
import 'services/sketch_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SketchService().loadCoins();

  await Purchases.setLogLevel(LogLevel.debug);
  await Purchases.configure(PurchasesConfiguration('goog_qwcTDDMEqXjwoIMdpWuMHHFjjys'));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArtHaven',
      home: const HomeScreen(),
    );
  }
}
