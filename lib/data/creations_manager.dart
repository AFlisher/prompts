import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CreationItem {
  final String id;
  final String styleId;
  final String styleName;
  final String imagePath; // The resulting styled photo asset path
  final String? originalImagePath; // The user's input photo file path
  final DateTime createdAt;

  CreationItem({
    required this.id,
    required this.styleId,
    required this.styleName,
    required this.imagePath,
    this.originalImagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'styleId': styleId,
        'styleName': styleName,
        'imagePath': imagePath,
        'originalImagePath': originalImagePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CreationItem.fromJson(Map<String, dynamic> json) {
    return CreationItem(
      id: json['id'] as String,
      styleId: json['styleId'] as String,
      styleName: json['styleName'] as String,
      imagePath: json['imagePath'] as String,
      originalImagePath: json['originalImagePath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class CreationsManager extends ChangeNotifier {
  List<CreationItem> _creations = [];
  int _currentTab = 0;
  bool _isInitialized = false;
  bool shouldSaveToFile = true;

  List<CreationItem> get creations => List.unmodifiable(_creations);
  int get currentTab => _currentTab;
  bool get isInitialized => _isInitialized;

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/user_creations_v1.json');
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> data = json.decode(content);
        _creations = data.map((item) => CreationItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint("Error loading creations: $e");
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> save() async {
    if (!shouldSaveToFile) return;
    try {
      final file = await _localFile;
      final content = json.encode(_creations.map((c) => c.toJson()).toList());
      await file.writeAsString(content);
    } catch (e) {
      debugPrint("Error saving creations: $e");
    }
  }

  Future<void> addCreation(CreationItem item) async {
    _creations.insert(0, item); // Newest first
    await save();
    notifyListeners();
  }

  Future<void> deleteCreation(String id) async {
    _creations.removeWhere((c) => c.id == id);
    await save();
    notifyListeners();
  }

  void setTab(int index) {
    if (_currentTab != index) {
      _currentTab = index;
      notifyListeners();
    }
  }
}
