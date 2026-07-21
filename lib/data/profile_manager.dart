import 'package:flutter/foundation.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';
import '../services/network_client.dart';

class ProfileManager extends ChangeNotifier {
  final ProfileService _profileService = ProfileService();
  Profile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadProfile({bool force = false}) async {
    // Guards against both "already loaded" and "already in flight" - without
    // the latter, two near-simultaneous callers (e.g. MainShell's startup
    // init and ProfileScreen's own mount-time call) could each see _profile
    // still null and both fire a network request. `force` (the profile
    // error state's explicit Retry button) always bypasses this and runs
    // fresh regardless.
    if (!force && (_profile != null || _isLoading)) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _profileService.getProfile();
      _isLoading = false;
    } catch (e) {
      _errorMessage = friendlyNetworkErrorMessage(e);
      _isLoading = false;
    }
    notifyListeners();
  }

  void updateProfile(Profile updated) {
    _profile = updated;
    notifyListeners();
  }

  void clear() {
    _profile = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
