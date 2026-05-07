import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

class FriendsModel extends ChangeNotifier {
  FriendsModel(this._apiService);

  final ApiService _apiService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<dynamic> _friends = [];
  List<dynamic> get friends => List.unmodifiable(_friends);

  Future<void> loadFriends() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.getFriendsList();
      _friends = res ?? [];
    } catch (_) {
      _friends = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteFriend(dynamic id) async {
    final int parsedId = id is num
        ? id.toInt()
        : int.tryParse(id.toString()) ?? 0;
    final ok = await _apiService.deleteFriend(parsedId);
    if (ok) {
      _friends.removeWhere((f) {
        final fid = f['user_id'] ?? f['id'];
        if (fid is num) return fid.toInt() == parsedId;
        return fid.toString() == parsedId.toString();
      });
      notifyListeners();
    }
    return ok;
  }

  Future<void> refresh() async => await loadFriends();
}
