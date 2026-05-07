import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../provider/map_state_provider.dart';
import '../provider/profile_provider.dart';
import '../services/api_service.dart';
import '../widgets/dialogs/add_friend_dialog.dart';
import '../widgets/dialogs/friends_list_dialog.dart';
import '../widgets/dialogs/notifications_dialog.dart';
import '../widgets/dialogs/search_friends_dialog.dart';
import 'login_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.initialAvatarUrl});

  final String? initialAvatarUrl;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  final TextEditingController nameController = TextEditingController();

  // freeing the memory only when the MapScreen actually closes and not when navigating to dialogs or other screens on top of it
  @override
  void dispose() {
    nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Widget _buildLocationStatusBody({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.blueGrey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blueGrey.shade700,
                height: 1.4,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action],
          ],
        ),
      ),
    );
  }

  void _startMapInitialization() {
    if (!mounted) return;

    final mapState = context.read<MapStateModel>();
    mapState.shutdown();
    mapState.initialize(
      onFriendTapped: _showFriendInfoDialog,
      onPositionUpdated: (position) {
        if (mounted) {
          _mapController.move(position, 14);
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startMapInitialization();
      context.read<ProfileProvider>().loadMyProfile();
    });
  }

  ImageProvider? _avatarImageProvider(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return null;
    }

    if (avatar.startsWith('data:image/')) {
      final commaIndex = avatar.indexOf(',');
      if (commaIndex != -1 && commaIndex < avatar.length - 1) {
        final base64Part = avatar.substring(commaIndex + 1);
        return MemoryImage(base64Decode(base64Part));
      }
    }

    return NetworkImage(avatar);
  }

  String _formatLastSeen(dynamic updatedAt) {
    if (updatedAt == null) return 'Unknown';

    final parsed = DateTime.tryParse(updatedAt.toString())?.toLocal();
    if (parsed == null) return updatedAt.toString();

    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final date =
        '${twoDigits(parsed.day)}.${twoDigits(parsed.month)}.${parsed.year}';
    final time =
        '${twoDigits(parsed.hour)}:${twoDigits(parsed.minute)}:${twoDigits(parsed.second)}';
    return '$date $time';
  }

  Future<void> _showFriendInfoDialog(Map<String, dynamic> friend) async {
    final avatarUrl = friend['avatar'] as String?;
    final friendName = friend['name']?.toString() ?? 'Unknown';
    final lastSeen = _formatLastSeen(friend['updated_at']);
    final latitude = (friend['latitude'] as num?)?.toDouble();
    final longitude = (friend['longitude'] as num?)?.toDouble();

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: _avatarImageProvider(avatarUrl),
              child: _avatarImageProvider(avatarUrl) == null
                  ? const Icon(Icons.person, color: Colors.black54)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                friendName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.schedule, 'Last seen', lastSeen),
            const SizedBox(height: 10),
            _infoRow(
              Icons.place,
              'Coordinates',
              latitude != null && longitude != null
                  ? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
                  : 'Unknown',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _focusFriendOnMap(int friendId) async {
    try {
      final response = await _apiService.getFriendsLocations();
      if (response == null) return;

      final locations = <int, LatLng>{};
      for (final friend in response) {
        final id = (friend['user_id'] as num).toInt();
        locations[id] = LatLng(
          (friend['latitude'] as num).toDouble(),
          (friend['longitude'] as num).toDouble(),
        );
      }

      final target = locations[friendId];
      if (target != null) {
        _mapController.move(target, 16);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend location is not available yet')),
        );
      }
    } catch (e) {
      debugPrint('Error focusing friend on map: $e');
    }
  }

  Future<void> _showMyProfileDialog() async {
    final profileProvider = context.read<ProfileProvider>();
    await profileProvider.loadMyProfile();

    if (!mounted) return;

    final currentName= profileProvider.name ?? '';
    nameController.text = currentName;

    await showDialog(
      context: context,
      builder: (dialogContext) {
          String? dialogAvatar = profileProvider.avatar ?? widget.initialAvatarUrl;

          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                title: const Text(
                  'My profile',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color.fromARGB(255, 219, 206, 225),
                                const Color.fromARGB(255, 198, 175, 195),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );

                                  if (picked == null) return;

                                  final bytes = await picked.readAsBytes();
                                  final mimeType =
                                      picked.mimeType ?? 'image/jpeg';
                                  final avatarDataUrl =
                                      'data:$mimeType;base64,${base64Encode(bytes)}';

                                  final ok = await profileProvider.updateAvatar(
                                    avatarDataUrl,
                                  );
                                  if (!ok || !mounted) return;

                                  setStateDialog(() {
                                    dialogAvatar =
                                        profileProvider.avatar ?? dialogAvatar;
                                  });
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 42,
                                      backgroundColor: Colors.white,
                                      backgroundImage:
                                          (dialogAvatar != null &&
                                              dialogAvatar!.isNotEmpty)
                                          ? _avatarImageProvider(dialogAvatar)
                                          : null,
                                      child:
                                          (dialogAvatar == null ||
                                              dialogAvatar!.isEmpty)
                                          ? const Icon(Icons.person, size: 40)
                                          : null,
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                            255,
                                            145,
                                            189,
                                            228,
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Tap the avatar to change photo',
                                style: TextStyle(
                                  color: Colors.blueGrey.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Display name',
                          style: TextStyle(
                            color: Colors.blueGrey.shade800,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'This is the name your friends will see.',
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameController,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your display name',
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.blueGrey.shade400,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Logged in as',
                          style: TextStyle(
                            color: Colors.blueGrey.shade800,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 18,
                                color: Colors.blueGrey.shade700,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  profileProvider.email ?? '',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade900,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('Close'),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () async {
                                final newName = nameController.text.trim();

                                final ok = await profileProvider.updateDisplayName(newName);
                                if (dialogContext.mounted) Navigator.of(dialogContext).pop();

                                if (!ok && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to save name. See console for details.'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
  }


  void _showAddFriendDialog() {
    showAddFriendDialog(context, _apiService);
  }

  void _showFriendsListDialog() {
    showFriendsListDialog(
      context,
      _apiService,
      () => context.read<MapStateModel>().refreshFriends(
        onFriendTapped: _showFriendInfoDialog,
      ),
      _focusFriendOnMap,
    );
  }

  void _showNotificationsDialog() {
    showNotificationsDialog(
      context,
      _apiService,
      () => context.read<MapStateModel>().refreshPendingInvites(),
    );
  }

  void _showSearchDialog() {
    showSearchFriendsDialog(context, _apiService, _focusFriendOnMap);
  }

  Future<void> _showAppMenu() async {
    final navigator = Navigator.of(context);
    final mapState = context.read<MapStateModel>();

    final action = await showMenu<int>(
      context: context,
      position: const RelativeRect.fromLTRB(0, 80, 0, 0),
      items: const [
        PopupMenuItem(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.person_add, size: 20),
              SizedBox(width: 12),
              Text('Add friend'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.group, size: 20),
              SizedBox(width: 12),
              Text('My friends'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 3,
          child: Row(
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 12),
              Text('Sign out'),
            ],
          ),
        ),
      ],
    );

    if (action == null) return;

    switch (action) {
      case 0:
        _showAddFriendDialog();
        break;
      case 1:
        _showFriendsListDialog();
        break;
      case 3:
        mapState.shutdown();
        await _apiService.signOut();
        if (!mounted) return;
        navigator.pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MapStateModel, ProfileProvider>(
      builder: (context, mapState, profileProvider, _) {
        final avatarUrl = profileProvider.avatar ?? widget.initialAvatarUrl;
        final locationStatus = mapState.locationStatus;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: _showAppMenu,
            ),
            title: Image.asset(
              'assets/appbar.png',
              height: 30,
              fit: BoxFit.contain,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search friends',
                onPressed: _showSearchDialog,
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    tooltip: 'Notifications',
                    onPressed: _showNotificationsDialog,
                  ),
                  if (mapState.pendingInvitesCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          '${mapState.pendingInvitesCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: _showMyProfileDialog,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? _avatarImageProvider(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.black54,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          body: locationStatus == LocationInitializationStatus.loading
              ? _buildLocationStatusBody(
                  icon: Icons.location_searching,
                  title: 'Finding your location',
                  message:
                      'Waiting for the first GPS fix so the map opens on your real position.',
                )
              : locationStatus == LocationInitializationStatus.permissionDenied
              ? _buildLocationStatusBody(
                  icon: Icons.location_off,
                  title: 'Location access is needed',
                  message:
                      'Enable location permission to open the map on your current position.',
                  action: ElevatedButton(
                    onPressed: _startMapInitialization,
                    child: const Text('Try again'),
                  ),
                )
              : locationStatus == LocationInitializationStatus.error
              ? _buildLocationStatusBody(
                  icon: Icons.error_outline,
                  title: 'Could not load location',
                  message:
                      'The app could not read your current position. Try again once location services are available.',
                  action: ElevatedButton(
                    onPressed: _startMapInitialization,
                    child: const Text('Retry'),
                  ),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapState.currentPosition,
                    initialZoom: 14,
                    minZoom: 4,
                    maxZoom: 20,
                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(
                        const LatLng(-85.05112878, -180),
                        const LatLng(85.05112878, 180),
                      ),
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.kaquiz',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: mapState.currentPosition,
                          width: 120,
                          height: 84,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.my_location,
                                color: Color.fromARGB(255, 127, 97, 128),
                                size: 40,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'You are here',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...mapState.friendMarkers,
                      ],
                    ),
                  ],
                ),
          floatingActionButton:
              locationStatus == LocationInitializationStatus.ready
              ? FloatingActionButton(
                  onPressed: () {
                    _mapController.move(mapState.currentPosition, 14);
                  },
                  tooltip: 'Center on my location',
                  child: const Icon(Icons.my_location),
                )
              : null,
        );
      },
    );
  }
}
