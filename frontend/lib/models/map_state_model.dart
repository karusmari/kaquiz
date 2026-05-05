import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../services/map_tracking_service.dart';

class MapStateModel extends ChangeNotifier {
  MapStateModel(this._apiService);

  final ApiService _apiService;
  final MapTrackingService _trackingService = MapTrackingService();

  Timer? _locationTimer;
  Timer? _friendsTimer;
  Timer? _notificationsTimer;
  bool _initialized = false;
  bool _refreshingFriends = false;
  bool _refreshingInvites = false;

  LatLng _currentPosition = const LatLng(60.097, 19.934);
  LatLng get currentPosition => _currentPosition;

  List<Marker> _friendMarkers = [];
  List<Marker> get friendMarkers => List.unmodifiable(_friendMarkers);

  int _pendingInvitesCount = 0;
  int get pendingInvitesCount => _pendingInvitesCount;

  Future<void> initialize({
    required void Function(Map<String, dynamic> friend) onFriendTapped,
    void Function(LatLng position)? onPositionUpdated,
  }) async {
    if (_initialized) return;
    _initialized = true;

    await _initLocation(onPositionUpdated: onPositionUpdated);
    await refreshFriends(onFriendTapped: onFriendTapped);
    await refreshPendingInvites();

    _startFriendsTimer(onFriendTapped: onFriendTapped);
    _startNotificationsTimer();
  }

  Future<void> _initLocation({
    void Function(LatLng position)? onPositionUpdated,
  }) async {
    final permission = await _trackingService.requestLocationPermission();
    if (permission == LocationPermission.denied) return;

    try {
      final position = await Geolocator.getCurrentPosition();
      _currentPosition = LatLng(position.latitude, position.longitude);
      onPositionUpdated?.call(_currentPosition);
      notifyListeners();

      _locationTimer = _trackingService.startLocationTimer(
        apiService: _apiService,
        onPositionUpdated: (position) {
          _currentPosition = position;
          onPositionUpdated?.call(position);
          notifyListeners();
        },
        onError: (message) => debugPrint(message),
      );
    } catch (e) {
      debugPrint('Error getting initial location: $e');
    }
  }

  Future<void> refreshFriends({
    required void Function(Map<String, dynamic> friend) onFriendTapped,
  }) async {
    if (_refreshingFriends) return;
    _refreshingFriends = true;

    try {
      final response = await _apiService.getFriendsLocations();
      if (response == null) return;

      _friendMarkers = _trackingService.buildFriendMarkers(
        response,
        onFriendTapped: onFriendTapped,
      );
      notifyListeners();
    } finally {
      _refreshingFriends = false;
    }
  }

  Future<void> refreshPendingInvites() async {
    if (_refreshingInvites) return;
    _refreshingInvites = true;

    try {
      final invites = await _apiService.getPendingInvites();
      _pendingInvitesCount = invites?.length ?? 0;
      notifyListeners();
    } finally {
      _refreshingInvites = false;
    }
  }

  void _startFriendsTimer({
    required void Function(Map<String, dynamic> friend) onFriendTapped,
  }) {
    _friendsTimer?.cancel();
    _friendsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refreshFriends(onFriendTapped: onFriendTapped);
    });
  }

  void _startNotificationsTimer() {
    _notificationsTimer?.cancel();
    _notificationsTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshPendingInvites();
    });
  }

  void shutdown() {
    _locationTimer?.cancel();
    _friendsTimer?.cancel();
    _notificationsTimer?.cancel();
    _initialized = false;
  }

  @override
  void dispose() {
    shutdown();
    super.dispose();
  }
}
