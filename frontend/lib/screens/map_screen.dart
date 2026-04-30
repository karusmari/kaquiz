import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/map_tracking_service.dart';
import '../widgets/dialogs/add_friend_dialog.dart';
import '../widgets/dialogs/friends_list_dialog.dart';
import '../widgets/dialogs/notifications_dialog.dart';
import '../widgets/dialogs/search_friends_dialog.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.initialAvatarUrl});

  final String? initialAvatarUrl;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiService _apiService = ApiService();
  final MapTrackingService _trackingService = const MapTrackingService();
  final MapController _mapController = MapController();
  Timer? _locationTimer;
  Timer? _friendsTimer;
  Timer? _notificationsTimer;
  LatLng _currentPosition = const LatLng(60.097, 19.934);
  List<Marker> _friendMarkers = [];
  int _pendingInvitesCount = 0;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.initialAvatarUrl;
    _initLocation();
    _loadFriendsLocations();
    _loadPendingInvites();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    try {
      final profile = await _apiService.getMyProfile();
      if (!mounted || profile == null) return;
      setState(() {
        _avatarUrl = profile['avatar'] as String?;
      });
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _initLocation() async {
    final permission = await _trackingService.requestLocationPermission();
    if (permission == LocationPermission.denied) return;

    _locationTimer = _trackingService.startLocationTimer(
      apiService: _apiService,
      onPositionUpdated: (position) {
        if (!mounted) return;
        setState(() {
          _currentPosition = position;
        });
      },
      onError: (message) => print(message),
    );
  }

  Future<void> _loadFriendsLocations() async {
    _friendsTimer = _trackingService.startFriendsTimer(
      apiService: _apiService,
      onMarkersUpdated: (markers) {
        if (!mounted) return;
        setState(() {
          _friendMarkers = markers;
        });
      },
      onError: (message) => print(message),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _friendsTimer?.cancel();
    _notificationsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.person_add),
          tooltip: "Add friend by email",
          onPressed: _showAddFriendDialog,
        ),
        title: const Text("FriendSPY"),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: "My friends",
            onPressed: _showFriendsListDialog,
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: "Notifications",
                onPressed: _showNotificationsDialog,
              ),
              if (_pendingInvitesCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$_pendingInvitesCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Search friends",
            onPressed: _showSearchDialog,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 18, color: Colors.black54)
                  : null,
            ),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: _currentPosition, initialZoom: 14),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.kaquiz',
          ),
          MarkerLayer(
            markers: [
              // Meie enda marker
              Marker(
                point: _currentPosition,
                child: Tooltip(
                  message: "You are here",
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
              ),
              // Sõprade markerid
              ..._friendMarkers,
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadPendingInvites() async {
    _notificationsTimer = Timer.periodic(const Duration(seconds: 15), (
      timer,
    ) async {
      try {
        final invites = await _apiService.getPendingInvites();
        setState(() {
          _pendingInvitesCount = invites?.length ?? 0;
        });
      } catch (e) {
        print("Error loading pending invites: $e");
      }
    });
  }

  void _showAddFriendDialog() {
    showAddFriendDialog(context, _apiService);
  }

  void _showFriendsListDialog() {
    showFriendsListDialog(context, _apiService, () => setState(() {}));
  }

  void _showNotificationsDialog() {
    showNotificationsDialog(context, _apiService, () => setState(() {}));
  }

  void _showSearchDialog() {
    showSearchFriendsDialog(context, _apiService);
  }
}
