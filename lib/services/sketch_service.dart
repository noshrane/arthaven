import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sketch.dart';

class SketchService extends ChangeNotifier {
  static final SketchService _instance = SketchService._internal();
  factory SketchService() => _instance;
  SketchService._internal() {
    loadCoins();
  }

  static const String _coinsKey = 'user_coins';

  final List<Sketch> _sketches = [];
  List<Sketch> get sketches => List.unmodifiable(_sketches);

  int _coins = 30;
  int get coins => _coins;

  Future<void> loadCoins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_coinsKey)) {
        int saved = prefs.getInt(_coinsKey) ?? 30;
        if (saved < 30) {
          saved = 30;
          await prefs.setInt(_coinsKey, 30);
        }
        _coins = saved;
      } else {
        _coins = 30;
        await prefs.setInt(_coinsKey, _coins);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading coins: $e');
    }
  }

  Future<void> _saveCoins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_coinsKey, _coins);
    } catch (e) {
      debugPrint('Error saving coins: $e');
    }
  }

  void addSketch(Sketch sketch) {
    _sketches.insert(0, sketch);
    notifyListeners();
  }

  void updateSketchStep(String id, int step) {
    final index = _sketches.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sketches[index].currentStep = step;
      notifyListeners();
    }
  }

  void renameSketch(String id, String newName) {
    final index = _sketches.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sketches[index].name = newName;
      notifyListeners();
    }
  }

  void claimReward(int amount) {
    _coins += amount;
    _saveCoins();
    notifyListeners();
  }

  void deductCoins(int amount) {
    _coins = (_coins - amount).clamp(0, 999999);
    _saveCoins();
    notifyListeners();
  }
}
