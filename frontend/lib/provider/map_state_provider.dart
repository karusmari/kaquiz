import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../services/map_tracking_service.dart';

// represents the current lifecycle and structural health of the GPS subsystems
enum LocationInitializationStatus { loading, ready, permissionDenied, error }

class MapStateModel extends ChangeNotifier {
  MapStateModel(this._apiService);

  final ApiService _apiService;
  final MapTrackingService _trackingService = MapTrackingService();

  // background timers for location tracking and data refreshing loops, 
  // stored here to allow proper cancellation when the screen is destroyed or user signs out
  Timer? _locationTimer;
  Timer? _initialLocationRetryTimer;
  Timer? _friendsTimer;
  Timer? _notificationsTimer;

  // lifecycle control flags to prevent multiple overlapping loops and async operations from running simultaneously
  bool _initialized = false;
  bool _refreshingFriends = false;
  bool _refreshingInvites = false;

  LocationInitializationStatus _locationStatus =
      LocationInitializationStatus.loading;
  
  // default initial position for fallback - Mariehamn,Åland
  LatLng _currentPosition = const LatLng(60.097, 19.934);

  // public getters for the current map state that the UI can reactively listen to
  LatLng get currentPosition => _currentPosition;
  LocationInitializationStatus get locationStatus => _locationStatus;

  List<Marker> _friendMarkers = [];
  List<Marker> get friendMarkers => List.unmodifiable(_friendMarkers);

  // Raw dynamic storage keeping track of the last processed payload structure.
  // Acts as a mirror comparison matrix to short-circuit redundant layout triggers.
  List<dynamic> _lastFriendsData = [];

  int _pendingInvitesCount = 0;
  int get pendingInvitesCount => _pendingInvitesCount;

  // Structural flag ensuring camera snapping/movement events only execute 
  // on the first successful telemetry lock, avoiding map manipulation while dragging.
  bool _isFirstLocationUpdate = true;

  /// Main initialization gateway. Sets up hardware layers, pulls the primary 
  /// dataset snapshot, and schedules asynchronous looping intervals.
  Future<void> initialize({
    required void Function(Map<String, dynamic> friend) onFriendTapped,
    void Function(LatLng position)? onPositionUpdated,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _locationStatus = LocationInitializationStatus.loading;

    // Sequence the initial async setup requests. 
    // They are awaited sequentially to build a cohesive initial map snapshot.
    await _initLocation(onPositionUpdated: onPositionUpdated);
    await refreshFriends(onFriendTapped: onFriendTapped);
    await refreshPendingInvites();

    // if the user signed out while the network requests above were still loading, 
    // abort starting the background loops immediately
    if (!_initialized) return;

    // Fire up recurring background polling processes for friends' locations and pending invites, passing the necessary callbacks to handle UI updates on data changes.
    _startFriendsTimer(onFriendTapped: onFriendTapped);
    _startNotificationsTimer();
  }

  /// Authorization layer validating permission structures before querying OS location sensors.
  Future<void> _initLocation({
    void Function(LatLng position)? onPositionUpdated,
  }) async {
    final permission = await _trackingService.requestLocationPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _locationStatus = LocationInitializationStatus.permissionDenied;
      notifyListeners(); // Force UI update to show permission recovery viewport
      return;
    }

    // Permissions cleared, proceed to resolve current geographic position and start the regular location update loop
    await _resolveInitialLocation(onPositionUpdated: onPositionUpdated);
  }

  /// Communicates with system location hardware to acquire an accurate high-priority initial lock.
  Future<void> _resolveInitialLocation({
    void Function(LatLng position)? onPositionUpdated,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Cancel any active retry loops since a valid location fix was successfully achieved
      _initialLocationRetryTimer?.cancel();

      _currentPosition = LatLng(position.latitude, position.longitude);
      _locationStatus = LocationInitializationStatus.ready;

      // Only update map position on initial load, not on every refresh
      if (_isFirstLocationUpdate) {
        _isFirstLocationUpdate = false;
        onPositionUpdated?.call(_currentPosition);
      }
      notifyListeners();

      // launch the 5-second recurring telemetry loop that forwards location updates to the backend 
      // and updates the internal state with the latest position
      _locationTimer = _trackingService.startLocationTimer(
        apiService: _apiService,
        onPositionUpdated: (position) {
          _currentPosition = position;
          // Don't move the map on every location update, only update internal state
          notifyListeners();
        },
        onError: (message) => debugPrint(message),
      );
    } catch (e) {
      debugPrint('Error getting initial location: $e');
      
      // Prevent state modifications if shutdown was triggered while catching the error
      if (!_initialized) return;

      _locationStatus = LocationInitializationStatus.loading;
      notifyListeners();

      // Hardware fallback loop: Retry location capture sequence every 2 seconds if GPS signal is temporarily lost.
      _initialLocationRetryTimer?.cancel();
      _initialLocationRetryTimer = Timer(const Duration(seconds: 2), () {
        if (!_initialized ||
            _locationStatus != LocationInitializationStatus.loading) {
          return;
        }
        _resolveInitialLocation(onPositionUpdated: onPositionUpdated);
      });
    }
  }
  
  /// Hits the Go backend service to retrieve telemetry parameters for all linked friends.
  Future<void> refreshFriends({
    required void Function(Map<String, dynamic> friend) onFriendTapped,
  }) async {
    if (_refreshingFriends || !_initialized) return;
    _refreshingFriends = true;

    try {
      final response = await _apiService.getFriendsLocations();
      if (response == null) return;

    if (listEquals(_lastFriendsData, response)) {
        return; 
      }

      _lastFriendsData = response;

      _friendMarkers = _trackingService.buildFriendMarkers(
        List<Map<String, dynamic>>.from(response),
        onFriendTapped: onFriendTapped,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing friends data: $e');
    } finally {
      _refreshingFriends = false;
    }
  }

  /// Loops through local memory cache layers to query a specific friend's coordinate target by ID.
  LatLng? getFriendLocation(int friendId) {
  try {
    // find the object matching the friend ID parameters safely
    final friend = _lastFriendsData.firstWhere(
      (f) => f['id'] == friendId || f['user_id'] == friendId
    );
    
    final double lat = double.parse(friend['latitude'].toString());
    final double lng = double.parse(friend['longitude'].toString());

    return LatLng(lat, lng);
  } catch (e) {
    debugPrint('Could not find friend location: $e');
    return null;
  }
}

  /// Pulls pending social transaction alert snapshots to update contextual UI notification badge counters.
  Future<void> refreshPendingInvites() async {
    if (_refreshingInvites || !_initialized) return;
    _refreshingInvites = true;

    try {
      final invites = await _apiService.getPendingInvites();
      final newCount = invites?.length ?? 0;

      if (_pendingInvitesCount != newCount) {
          _pendingInvitesCount = newCount;
          notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing pending invites: $e');
    } finally {
      _refreshingInvites = false;
    }
  }

  /// Schedules recurring polling checks targeting friend location endpoints every 5 seconds.
  void _startFriendsTimer({
    required void Function(Map<String, dynamic> friend) onFriendTapped,
  }) {
    _friendsTimer?.cancel();
    _friendsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refreshFriends(onFriendTapped: onFriendTapped);
    });
  }
  
  /// Schedules recurring background scans querying notification states every 10 seconds.
  void _startNotificationsTimer() {
    _notificationsTimer?.cancel();
    _notificationsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      refreshPendingInvites();
    });
  }

  void shutdown() {
    // Flip initialization flag immediately so cascading async gaps recognize unmounted states instantly
    _initialized = false;
    // Clear out active loop streams completely
    _locationTimer?.cancel();
    _initialLocationRetryTimer?.cancel();
    _friendsTimer?.cancel();
    _notificationsTimer?.cancel();
  }

  @override
  void dispose() {
    shutdown();
    super.dispose();
  }
}
