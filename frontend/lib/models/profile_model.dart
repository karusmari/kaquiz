import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

class ProfileModel extends ChangeNotifier {
  ProfileModel(this._apiService);

  final ApiService _apiService;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? get profile => _profile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSavingName = false;
  bool get isSavingName => _isSavingName;

  String? get name => _profile?['name']?.toString();
  String? get email => _profile?['email']?.toString();
  String? get avatar => _profile?['avatar']?.toString();

  Future<void> loadMyProfile({bool forceRefresh = false}) async {
    if (_isLoading || (!forceRefresh && _profile != null)) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _apiService.getMyProfile();
      if (profile != null) {
        _profile = profile;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateDisplayName(String name) async {
    final updatedName = name.trim();
    if (updatedName.isEmpty) return false;

    _isSavingName = true;
    notifyListeners();

    try {
      final updatedProfile = await _apiService.updateUserProfile(
        name: updatedName,
      );
      if (updatedProfile == null) return false;

      _profile = updatedProfile;
      notifyListeners();
      return true;
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

    _profile = updatedProfile;
    notifyListeners();
    return true;
  }
}
