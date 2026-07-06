import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CreditManager extends ChangeNotifier {
  int _credits = 3; // Give 3 free credits on fresh install
  bool _isInitialized = false;

  int get credits => _credits;
  bool get isInitialized => _isInitialized;

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/user_credits_v1.json');
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content);
        _credits = data['credits'] as int? ?? 3;
      } else {
        // Save initial 3 credits
        await save();
      }
    } catch (e) {
      debugPrint("Error loading credits: $e");
    }
    _isInitialized = true;
    notifyListeners();
  }

  bool shouldSaveToFile = true;

  Future<void> save() async {
    if (!shouldSaveToFile) return;
    try {
      final file = await _localFile;
      final content = json.encode({
        'credits': _credits,
      });
      await file.writeAsString(content);
    } catch (e) {
      debugPrint("Error saving credits: $e");
    }
  }

  Future<void> addCredits(int amount) async {
    _credits += amount;
    await save();
    notifyListeners();
  }

  bool useCredit() {
    if (_credits > 0) {
      _credits -= 1;
      save();
      notifyListeners();
      return true;
    }
    return false;
  }
}
