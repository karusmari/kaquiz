import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'api_service.dart';

class MapTrackingService {
  const MapTrackingService();

  Future<LocationPermission> requestLocationPermission() {
    return Geolocator.requestPermission();
  }

  Timer startLocationTimer({
    required ApiService apiService,
    required void Function(LatLng position) onPositionUpdated,
    required void Function(String message) onError,
    Duration interval = const Duration(seconds: 5),
  }) {
    return Timer.periodic(interval, (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        onPositionUpdated(LatLng(position.latitude, position.longitude));
        await apiService.updateLocation(position.latitude, position.longitude);
        print("Location updated: ${position.latitude}, ${position.longitude}");
      } catch (e) {
        onError("Error updating location: $e");
      }
    });
  }

  Timer startFriendsTimer({
    required ApiService apiService,
    required void Function(List<Marker> markers) onMarkersUpdated,
    required void Function(String message) onError,
    Duration interval = const Duration(seconds: 5),
  }) {
    return Timer.periodic(interval, (timer) async {
      try {
        final response = await apiService.getFriendsLocations();
        if (response != null) {
          final markers = buildFriendMarkers(response);
          onMarkersUpdated(markers);
          print("Friends locations loaded: ${markers.length} friends");
        }
      } catch (e) {
        onError("Error loading friends locations: $e");
      }
    });
  }

  List<Marker> buildFriendMarkers(List<dynamic> response) {
    return response.map((friend) {
      final lat = friend['latitude'] as double;
      final lng = friend['longitude'] as double;
      final userId = friend['user_id'] ?? 'unknown';

      return Marker(
        point: LatLng(lat, lng),
        child: Tooltip(
          message: "Friend #$userId",
          child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
        ),
      );
    }).toList();
  }
}
