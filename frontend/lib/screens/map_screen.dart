import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../provider/map_state_provider.dart';
import '../provider/profile_provider.dart';
import '../services/api_service.dart';
import '../widgets/dialogs/add_friend_dialog.dart';
import '../widgets/dialogs/friends_list_dialog.dart';
import '../widgets/dialogs/notifications_dialog.dart';
import '../widgets/dialogs/search_friends_dialog.dart';
import '../widgets/dialogs/profile_dialog.dart';
import '../widgets/dialogs/friend_info_dialog.dart';
import '../utils/image_utils.dart';
import 'login_screen.dart';

const double _maxMapZoom = 18.0;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.initialAvatarUrl});
  final String? initialAvatarUrl;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // execute initialization code immediately after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMapInitialization();
    });
  }

  @override
  void dispose() {
    // disposing the map controller to free up resources and prevent memory leaks when the screen is destroyed
    _mapController.dispose();
    super.dispose();
  }

  // sets up the location tracking loop and configures map interaction triggers
  void _startMapInitialization() {
    if (!mounted) return;
    final mapState = context.read<MapStateModel>();

    // reset any existing tracking streams to prevent multiple active loops running simultaneously
    mapState.shutdown();
    mapState.initialize(
      onFriendTapped: (friend) =>
          FriendInfoDialog.show(context, friendData: friend),
      onPositionUpdated: (pos) => _mapController.move(pos, 14),
    );
  }

  // centers and zooms the map camera onto a specific friend's current GPS coordinates
  Future<void> _focusFriendOnMap(int friendId) async {
    final mapState = context.read<MapStateModel>();
    final target = mapState.getFriendLocation(friendId);

    if (target != null) {
      // safety check to ensure the widget is still attached to the tree before manipulating the map layout
      if (!mounted) return;
      _mapController.move(target, 16);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend location not available')),
      );
    }
  }

  // when user taps on the friends list menu item, a dialog is shown
  void _showFriendsList() {
    showFriendsListDialog(
      context,
      _apiService,
      () => context.read<MapStateModel>().refreshFriends(
        onFriendTapped: (f) => FriendInfoDialog.show(context, friendData: f),
      ),
      _focusFriendOnMap,
    );
  }

  // standard sign-out sequence. Drops GPS streams, hits the blacklist API and resets navigation stack
  Future<void> _handleSignOut() async {
    final navigator = Navigator.of(context);

    // stop fetching locations immediately so we dont send requests with an invalid token
    context.read<MapStateModel>().shutdown();

    await _apiService.signOut();

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // re-render sub-trees efficiently when either the map state tracker or user profile settings update
    return Consumer2<MapStateModel, ProfileProvider>(
      builder: (context, mapState, profile, _) {
        final status = mapState.locationStatus;

        // use the profile provider avatar if available, otherwise fall back to the login-provided token parameter
        final myAvatar = profile.avatar ?? widget.initialAvatarUrl;

        return Scaffold(
          appBar: _buildAppBar(mapState, myAvatar),
          body: _buildBody(mapState, status),
          floatingActionButton: status == LocationInitializationStatus.ready
              ? FloatingActionButton(
                  onPressed: () =>
                      _mapController.move(mapState.currentPosition, 14),
                  child: const Icon(Icons.my_location),
                )
              : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(MapStateModel mapState, String? avatar) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _showMainMenu(mapState),
      ),
      title: Image.asset('assets/appbar.png', height: 30),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () =>
              showSearchFriendsDialog(context, _apiService, _focusFriendOnMap),
        ),
        _buildNotificationBadge(mapState),
        _buildUserAvatar(avatar),
      ],
    );
  }

  Widget _buildBody(
    MapStateModel mapState,
    LocationInitializationStatus status,
  ) {
    switch (status) {
      case LocationInitializationStatus.loading:
        return _statusView(
          Icons.location_searching,
          'Finding you...',
          'Waiting for GPS',
        );
      case LocationInitializationStatus.permissionDenied:
        return _statusView(
          Icons.location_off,
          'GPS Disabled',
          'Please enable location permissions.',
          action: ElevatedButton(
            onPressed: _startMapInitialization,
            child: const Text('Try Again'),
          ),
        );
      case LocationInitializationStatus.error:
        return _statusView(
          Icons.error_outline,
          'Error',
          'Could not initialize map.',
          action: ElevatedButton(
            onPressed: _startMapInitialization,
            child: const Text('Retry'),
          ),
        );
      case LocationInitializationStatus.ready:
        return _buildMap(mapState);
    }
  }

  Widget _buildMap(MapStateModel mapState) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: mapState.currentPosition,
        initialZoom: 14,
        maxZoom: _maxMapZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          maxZoom: _maxMapZoom,
          userAgentPackageName: 'com.example.kaquiz',
        ),
        MarkerLayer(
          markers: [
            // my location marker (always on top of the stack so it doesn't get hidden behind friend markers)
            Marker(
              point: mapState.currentPosition,
              width: 80,
              height: 80,
              child: const Icon(
                Icons.my_location,
                color: Colors.deepPurple,
                size: 40,
              ),
            ),
            // friends markers that are coming from the map state provider 
            ...mapState.friendMarkers,
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationBadge(MapStateModel mapState) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () => NotificationsDialog.show(
            context,
            apiService: _apiService,
            onChanged: () => mapState.refreshPendingInvites(),
          ),
        ),
        // display alert count values if anything is pending action
        if (mapState.pendingInvitesCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: Colors.red,
              child: Text(
                '${mapState.pendingInvitesCount}',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserAvatar(String? avatar) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, left: 8),
      child: GestureDetector(
        onTap: () => MyProfileDialog.show(context, initialAvatarUrl: avatar),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: getAvatarProvider(avatar),
          child: avatar == null ? const Icon(Icons.person, size: 18) : null,
        ),
      ),
    );
  }

  Widget _statusView(
    IconData icon,
    String title,
    String msg, {
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 50, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(msg),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }

  void _showMainMenu(MapStateModel mapState) {
    showMenu<int>(
      context: context,
      position: const RelativeRect.fromLTRB(0, 80, 0, 0),
      items: [
        const PopupMenuItem(
          value: 0,
          child: ListTile(
            leading: Icon(Icons.person_add),
            title: Text('Add Friend'),
          ),
        ),
        const PopupMenuItem(
          value: 1,
          child: ListTile(
            leading: Icon(Icons.group),
            title: Text('My Friends'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 2,
          child: ListTile(leading: Icon(Icons.logout), title: Text('Sign Out')),
        ),
      ],
    ).then((value) {
      if (value == 0) showAddFriendDialog(context, _apiService);
      if (value == 1) _showFriendsList();
      if (value == 2) _handleSignOut();
    });
  }
}
