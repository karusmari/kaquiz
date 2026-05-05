import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'api_service.dart';

class MapTrackingService {
  MapTrackingService();

  // Cache last avatar string per user and corresponding ImageProvider to
  // avoid recreating images on every polling tick which causes flicker.
  final Map<int, String> _lastAvatarById = {};
  final Map<int, ImageProvider> _avatarCache = {};

  Future<LocationPermission> requestLocationPermission() {
    return Geolocator.requestPermission();
  }

  Timer startLocationTimer({
    required ApiService apiService,
    required void Function(LatLng position) onPositionUpdated,
    required void Function(String message) onError,
    Duration interval = const Duration(seconds: 5),
  }) {
    bool isRunning = false;

    return Timer.periodic(interval, (timer) async {
      if (isRunning) return;
      isRunning = true;
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        onPositionUpdated(LatLng(position.latitude, position.longitude));
        await apiService.updateLocation(position.latitude, position.longitude);
        print("Location updated: ${position.latitude}, ${position.longitude}");
      } catch (e) {
        onError("Error updating location: $e");
      } finally {
        isRunning = false;
      }
    });
  }

  Timer startFriendsTimer({
    required ApiService apiService,
    required void Function(List<Marker> markers) onMarkersUpdated,
    required void Function(Map<String, dynamic> friend) onFriendTapped,
    required void Function(String message) onError,
    Duration interval = const Duration(seconds: 5),
  }) {
    // Keep a lightweight snapshot of last seen friend state to avoid
    // rebuilding markers when nothing relevant changed (position/avatar).
    final Map<int, Map<String, dynamic>> lastSnapshot = {};
    bool isRunning = false;

    return Timer.periodic(interval, (timer) async {
      if (isRunning) return;
      isRunning = true;
      try {
        final response = await apiService.getFriendsLocations();
        if (response == null) return;

        bool changed = false;
        final Map<int, Map<String, dynamic>> current = {};

        for (final friend in response) {
          final int userId = (friend['user_id'] as num).toInt();
          final double lat = (friend['latitude'] as num).toDouble();
          final double lng = (friend['longitude'] as num).toDouble();
          final String? avatar = friend['avatar'] as String?;
          final String updatedAt = friend['updated_at']?.toString() ?? '';

          current[userId] = {
            'lat': lat,
            'lng': lng,
            'avatar': avatar ?? '',
            'updatedAt': updatedAt,
          };

          final prev = lastSnapshot[userId];
          if (prev == null) {
            changed = true; // new friend
          } else {
            if (prev['lat'] != lat ||
                prev['lng'] != lng ||
                prev['avatar'] != (avatar ?? '') ||
                prev['updatedAt'] != updatedAt) {
              changed = true;
            }
          }
        }

        // Check for removed friends
        if (!changed && lastSnapshot.length != current.length) changed = true;

        if (changed) {
          lastSnapshot
            ..clear()
            ..addAll(current);
          final markers = buildFriendMarkers(
            response,
            onFriendTapped: onFriendTapped,
          );
          onMarkersUpdated(markers);
          print("Friends locations loaded: ${markers.length} friends");
        }
      } catch (e) {
        onError("Error loading friends locations: $e");
      } finally {
        isRunning = false;
      }
    });
  }

  List<Marker> buildFriendMarkers(
    List<dynamic> response, {
    required void Function(Map<String, dynamic> friend) onFriendTapped,
  }) {
    return response.map((friend) {
      final lat = friend['latitude'] as double;
      final lng = friend['longitude'] as double;
      final name = friend['name'] ?? "Friend #${friend['user_id']}";
      final avatar = friend['avatar'];

      // Build or reuse avatar provider from data URL or URL. Only recreate
      // when the avatar string actually changes for a given user to prevent
      // flicker caused by rebuilding MemoryImage/NetworkImage each tick.
      ImageProvider? avatarProvider;
      final int userId = (friend['user_id'] as num).toInt();
      if (avatar is String && avatar.isNotEmpty) {
        final last = _lastAvatarById[userId];
        if (last != null &&
            last == avatar &&
            _avatarCache.containsKey(userId)) {
          avatarProvider = _avatarCache[userId];
        } else {
          // avatar changed (or not cached) -> create provider and store it
          if (avatar.startsWith('data:image/')) {
            final commaIndex = avatar.indexOf(',');
            if (commaIndex != -1 && commaIndex < avatar.length - 1) {
              try {
                final base64Part = avatar.substring(commaIndex + 1);
                final bytes = base64Decode(base64Part);
                avatarProvider = MemoryImage(bytes);
              } catch (_) {
                avatarProvider = NetworkImage(avatar);
              }
            } else {
              avatarProvider = NetworkImage(avatar);
            }
          } else {
            avatarProvider = NetworkImage(avatar);
          }

          // update caches
          _lastAvatarById[userId] = avatar;
          _avatarCache[userId] = avatarProvider;
        }
      } else {
        // No avatar: clear caches for this user to avoid stale images
        _lastAvatarById.remove(userId);
        _avatarCache.remove(userId);
      }

      return Marker(
        point: LatLng(lat, lng),
        width: 80,
        height: 100,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onFriendTapped(Map<String, dynamic>.from(friend as Map)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: avatarProvider,
                child: avatarProvider == null
                    ? const Icon(Icons.person, size: 16, color: Colors.black54)
                    : null,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                ),
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
