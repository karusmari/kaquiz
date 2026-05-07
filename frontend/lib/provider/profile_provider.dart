import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._apiService);

  final ApiService _apiService;

  // using the user object
  User? _user;
  User? get user => _user;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSavingName = false;
  bool get isSavingName => _isSavingName;

  String? get name => _user?.name;
  String? get email => _user?.email;
  String? get avatar => _user?.avatar;

  Future<void> loadMyProfile({bool forceRefresh = false}) async {
    if (_isLoading || (!forceRefresh && _user != null)) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.getMyProfile();
      if (data != null) {
        _user = User.fromJson(data);
      }
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // updating the display name
  Future<bool> updateDisplayName(String newName) async {
    final updatedName = newName.trim();
    if (updatedName.isEmpty || updatedName == name) return false;

    _isSavingName = true;
    notifyListeners();

    try {
      final updatedProfile = await _apiService.updateUserProfile(name: updatedName);

      if (updatedProfile != null) {
      _user = User.fromJson(updatedProfile);
      notifyListeners();
      return true;
      }
      return false; // if API returns null, treat it as a failure and the app doesnt crash
    } catch (e) {
      debugPrint('Failed to update display name: $e');
      return false;
    } finally {
      _isSavingName = false;
      notifyListeners();
    }
  }

  Future<bool> updateAvatar(String avatarDataUrl) async {
    final updatedProfile = await _apiService.updateUserProfile(
      avatar: avatarDataUrl,
    );
    if (updatedProfile == null) return false;

    _user = User.fromJson(updatedProfile);
    notifyListeners();
    return true;
  }
}
